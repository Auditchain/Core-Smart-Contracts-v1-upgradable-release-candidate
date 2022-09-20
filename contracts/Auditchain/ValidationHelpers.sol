// SPDX-License-Identifier: MIT
pragma solidity =0.8.0;

import "./MemberHelpers.sol";
import "./IQueue.sol";
import "./INodeOperations.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";


/**
 * @title contains set of functions used mostly by Validations contracts. 
 */
contract ValidationHelpers is AccessControlUpgradeable {

    
    enum ValidationStatus {Undefined, Yes, No}   // Validation can be approved or disapproved. Initial status is undefined.
    MemberHelpers public memberHelpers;
    IQueue public queue;
    INodeOperations public nodeOP;

    mapping(address => bool) public valAddresses;
    bytes32 public constant CONTROLLER_ROLE = keccak256("CONTROLLER_ROLE");


    event ReplaceCancelValidation(address indexed user, bytes32 validationHash, uint256 price);


    function initialize(address _memberHelpers, address _queue) external  {
        memberHelpers = MemberHelpers(_memberHelpers);
        queue = IQueue(_queue);
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }
    // allows on setting of validation contract address
    function setValAddress(address _valAddress) external {
        require(hasRole(CONTROLLER_ROLE, msg.sender), "VH:setValAddress - Caller is not a controller");
        require(_valAddress != address(0), "VH:setValAddress - address can't be 0");
        valAddresses[_valAddress] = true;
    }

        function setNodeOpAddress(address _nodeOpAddress) external {
        require(hasRole(CONTROLLER_ROLE, msg.sender), "VH:setNodeOpAddress - Caller is not a controller");
        require(_nodeOpAddress != address(0), "VH:setNodeOpAddress - address can't be 0");
        nodeOP= INodeOperations(_nodeOpAddress);
    }

    // allows verification of existing validation by comparing its init time and document hash
    function isHashAndTimeCorrect( bytes32 documentHash, uint256 _validationTime) external  view returns (bool){

        bytes32 validationHash = keccak256(abi.encodePacked(documentHash, _validationTime));

        (,,uint validationTime,,,,,,,,) = IValidations(msg.sender).validations(validationHash);
        if (validationTime == _validationTime)
            return true;
        else
            return false;
    }

    // returns validation info of winning node
    function returnWinnerStruct(bytes32 validationHash, address validationContract)external view returns (string memory valUrl, address winner, uint256 validationTime){

        require(validationHash != bytes32(0), "VH:returnWinnerStruct - hash can't be 0");
        require(valAddresses[validationContract], "VH:returnWinnerStruct - val contract not registered");


        (,,validationTime,,valUrl,,,,winner,,) = IValidations(validationContract).validations(validationHash);
        // valUrl = IValidations(validationContract).returnValidationUrl(validationHash, winner);

        return (valUrl, winner, validationTime);

    }


    /**
     * @dev replace or cancel existing validation waiting in the queue with new price
     * @param price - new price, if price is 0 only remove request
     * @param validationHash validation hash for request
     */
    function replaceCancelValidation(uint256 price, bytes32 validationHash, address validationContract) external {

        require(validationHash != bytes32(0), "VH:replaceCancelValidation-  Validation Hash can't be 0");
        require(valAddresses[validationContract], "VH:replaceCancelValidation - val contract not registered");

        (,address requestor,,,,,,,,,) = IValidations(validationContract).validations(validationHash);

        require(msg.sender == requestor , "VH:replaceCancelValidation - not yours");
        if (price == 0)
            assert(queue.removeFromQueue(validationHash));
        else
            assert(queue.replaceValidation(price, validationHash));
            
        emit ReplaceCancelValidation(msg.sender, validationHash, price);
    }

    /**
      *@dev winner is being selected by sum of negative and positive votes and total compared with scores of other validators
      *@param validationHash - hashed document hash with init time
      *@param winners - array of addresses to select winner from
     */
    function selectWinner(bytes32 validationHash, address[] memory winners) external view returns (address) {

        address winner = winners[0];

        for (uint8 i=1; i < winners.length; i++){
           (uint256 plus, uint256 minus) =  IValidations(msg.sender).returnWinnerPoints(validationHash, winners[i]);
           (uint256 plusBefore, uint256 minusBefore) =  IValidations(msg.sender).returnWinnerPoints(validationHash, winners[i-1]);

            if (plus > minus)
                if (plus - minus > plusBefore - minusBefore)
                    {winner = winners[i];}
        }
        return winner;
    }

    /**
      *@dev find out who won the validation race 
      *@param validationHash - hashed document hash with init time
     */
     function determineWinners(bytes32 validationHash) external  view returns (address[] memory, uint256){

        (address[] memory validator, uint256[] memory status, uint256[] memory validationTimes) = insertionSort (validationHash);

        uint256 consensus = determineConsensus(status);
        bool[] memory isWinner = new bool[](validator.length);
        bool done;
        uint256 i=0;
        uint256 topValidationTime = validationTimes[0];
        uint256 numFound=0;
        
        while (!done) {
            if (uint256(status[i]) == consensus && validationTimes[i] == topValidationTime){
                isWinner[i] = true;
                numFound ++;
            } 
         
            if (i + 1 == validator.length)
                done = true;
            else
                i++;
          }
        
        address[] memory winners = new address[](numFound);
        uint256 j;

        for (uint256 k = 0; k< validator.length; k++){

            if (isWinner[k]){
                winners[j] = validator[k];
                j++;
            }
        }
        return (winners, consensus);
    }


    /**
      * @dev  used during determination of validation winner
      * @param validationHash hashed document hash with init time
      * @return sorted list of validators with their choices and times
     */
    function insertionSort(bytes32 validationHash) internal view returns (address[] memory, uint256[] memory, uint256[] memory) {

        (address[] memory validator, ,uint256[] memory status, uint256[] memory validationTimes,,) =  IValidations(msg.sender).collectValidationResults(validationHash);

        uint length = validationTimes.length;
        
        for (uint i = 1; i < length; i++) {
            
            uint key = validationTimes[i];
            address user = validator[i];
            uint256 choice = status[i];
            uint j = i - 1;
            while ((int(j) > 0) && (validationTimes[j] > key)) {
                validationTimes[i] = validationTimes[j];
                validationTimes[i-1] = key; 
                validator[i] = validator[j];
                validator[i-1] = user;
                status[i] = status[j];
                status[i-1] =  choice; 
                j--;
            }
            validationTimes[j + 1] = key;
            validator[j+1] = user;
            status[j+1] = choice;
        }

        return (validator, status, validationTimes );
    }


    /**
      * @dev determine consensus of all validators
      * @param validation list of choices by validators
      * @return consensus which can be 1 or 2. 1 = acceptable 2 = failed
     */

    function determineConsensus(uint256[] memory validation) public pure returns(uint256 ) {

        uint256 yes;
        uint256 no;

        for (uint256 i=0; i< validation.length; i++) {

            if (validation[i] == uint256(ValidationStatus.Yes))
                yes++;
            else
                no++;
        }

        if (yes > no)
            return 1; // consensus is to approve
        else if (no > yes)
            return 2; // consensus is to disapprove
        else
            return 2; // consensus is tie - should not happen
    }


   /**
    * @dev to calculate state of the quorum for the validation
    * @param validationHash - consist of hash of hashed document and timestamp
    * @return number representing current participation level in percentage
    */
    function calculateVoteQuorum(bytes32 validationHash, address validationContract)external view returns (uint256)
    {

        require(validationHash != bytes32(0), "VH:calculateVoteQuorum - hash can't be 0");
        require(valAddresses[validationContract], "VH:calculateVoteQuorum - val contract not registered");

        uint256 totalStaked;
        uint256 currentlyVoted;

        address[] memory validatorsList = IValidations(validationContract).returnValidatorList(validationHash);
        (address[] memory validatorListActive, ,uint256[] memory choice,,,) =  IValidations(validationContract).collectValidationResults(validationHash);

        for (uint256 i = 0; i < validatorsList.length; i++) {
            totalStaked += memberHelpers.returnDepositAmount(validatorsList[i]);
             for (uint256 j=0; j< choice.length; j++){
                 if (validatorsList[i] == validatorListActive[j])
                    currentlyVoted += memberHelpers.returnDepositAmount(validatorsList[i]);
             }
        }
        if (currentlyVoted == 0)
            return 0;
        else
           return (currentlyVoted * 100) / totalStaked;

    }

    /**
     *@dev returns list of registered validators 
     *@return list of addresses 
     */
    function returnValidatorList() public view returns (address[] memory) {
        address[] memory validatorsList = nodeOP.returnNodeOperators();
        return validatorsList;
    }


    function returnValidatorCount(bytes32 _recentValidationHash, address validationContract) public view returns (uint256){

        (address[] memory nodeOperators, , , , , ) = IValidations(validationContract).collectValidationResults(_recentValidationHash);
        return nodeOperators.length;
    }


 
}