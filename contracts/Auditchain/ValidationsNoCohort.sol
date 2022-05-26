// SPDX-License-Identifier: MIT
pragma solidity =0.8.0;

import "./INodeOperations.sol";
import "./IMembers.sol";
import "./IValidationHelpers.sol";
import "./IQueue.sol";
import "./IMemberHelpers.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";

/**
 * @title Validations
 * Data subscriber can request financial document validation,
 * which will be validated by group of node operators. 
 */
contract ValidationsNoCohort is ReentrancyGuardUpgradeable {
    IMembers public members;
    IQueue public queue;
    IMemberHelpers public memberHelpers;
    INodeOperations public nodeOperations;
    IValidationHelpers public validationHelpers;

    mapping(address => uint256) public outstandingValidations;

    // Validation can be approved or disapproved. Initial status is undefined.
    enum ValidationStatus { Undefined, Yes, No }

    struct Validation {
        bool cohort;
        address requestor;
        uint256 validationTime;
        uint256 executionTime;
        string url;
        uint256 consensus;
        uint256 validationsCompleted;
        mapping(address => ValidationStatus) validatorChoice;
        mapping(address => uint256) validatorTime;
        mapping(address => string) validationUrl;
        mapping(address => uint256) winnerVotesPlus;
        mapping(address => uint256) winnerVotesMinus;
        mapping(address => bytes32) validationHash;
        uint64 winnerConfirmations;
        address winner;
        uint256 price;
    }

    mapping(address => mapping(bytes32 => bool)) public votes;
    mapping(uint256 => mapping(bytes32 => uint256)) public activeOperatorsStake;

    uint256 public recentTimestamp;
    bytes32 public recentValidationHash;
    uint256 public quorum; //first validation will be 100% quorum

    mapping(bytes32 => Validation) public validations; // track each validation

    event ValidationInitialized(address indexed user, bytes32 indexed validationHash, uint256 initTime, bytes32 documentHash, string url);
    event ValidatorValidated(address indexed validator, bytes32 indexed documentHash, uint256 indexed validationTime, 
                             ValidationStatus decision, string valUrl);

    event RequestExecuted(address indexed requestor, bytes32 indexed validationHash, bytes32 documentHash, uint256 consensus, 
                          uint256 quorum, uint256 timeExecuted, string url, address[] winners);

    event PaymentProcessed(bytes32 validationHash, address winner, uint256 pointsPlus, uint256 pointsMinus);
    event WinnerVoted(address validator, address winner, bool isValid);

    function initialize(
        address _members,
        address _memberHelpers,
        address _nodeOperations,
        address _validationHelpers,
        address _queue  ) external virtual {


        members = IMembers(_members);
        memberHelpers = IMemberHelpers(_memberHelpers);
        nodeOperations = INodeOperations(_nodeOperations);
        validationHelpers = IValidationHelpers(_validationHelpers);
        queue = IQueue(_queue);
        quorum = 100;
    }

    /**
     * @dev verify if requesting party has sufficient funds
     * @param requestor a user whose funds are checked
     * @return true or false
     */
    function checkIfRequestorHasFunds(address requestor, uint256 price) public view returns (bool)
    { 
        require(requestor != address(0), "VNC:checkIfRequestorHasFunds - address can't be 0)");
        return (memberHelpers.returnDepositAmount(requestor) > price * (outstandingValidations[requestor] + 1));
    }

    /**
     * @dev to be called by user to validate fin statements
     * @param documentHash - hashed document
     * @param url - location of the document
     */
  function initValNoCohort(bytes32 documentHash, string memory url, bool isCohort, uint256 price) external  {

        require(documentHash.length > 0, "VNC:initValNoCohort - Document hash value can't be 0");
        require(checkIfRequestorHasFunds(msg.sender, price),"VNC:initValNoCohort - Deposit additional funds.");
        require(members.userMap(msg.sender, IMembers.UserType(2)),"VNC:initValNoCohort - You have to register as data subscriber");

        uint256 validationTime = block.timestamp;
        bytes32 validationHash = keccak256(abi.encodePacked(documentHash, validationTime, msg.sender));

        outstandingValidations[msg.sender]++;
        Validation storage newValidation = validations[validationHash];

        newValidation.url = url;
        newValidation.validationTime = validationTime;
        newValidation.requestor = msg.sender;
        newValidation.cohort = isCohort;
        newValidation.price = price;

        assert(queue.addToQueue(price, validationHash, documentHash, url, msg.sender, validationTime));

        emit ValidationInitialized(msg.sender, validationHash, validationTime, documentHash, url);
    }

    /**
     *@dev each validator votes who is the winner
     *@param winners - list of candidates to vote on
     *@param vote - list of votes for each candidate
     *@param validationHash - val in question 
     */
    function voteWinner(address[] memory winners, bool[] memory vote, bytes32 validationHash ) external nonReentrant{

        require(votes[msg.sender][validationHash] == false, "VNC:voteWinner - voted already");
        require(members.userMap(msg.sender, IMembers.UserType(1)),"VNC:voteWinner - not registered as a validator");


        Validation storage validation = validations[validationHash];

        for (uint8 i = 0; i < winners.length; i++) {
            if (vote[i])
                validation.winnerVotesPlus[winners[i]] += 1;
            else
                validation.winnerVotesMinus[winners[i]] +=  1;

            votes[msg.sender][validationHash] = true;
            emit WinnerVoted(msg.sender, winners[i], vote[i]);
        }

        validation.winnerConfirmations++;
        uint256 operatorCount = returnValidatorCount(validationHash);
        uint256 currentQuorum = (validation.winnerConfirmations * 100) / operatorCount;

        if (currentQuorum >= members.requiredQuorum() && validation.winner == address(0)) {
            address winner = validationHelpers.selectWinner(validationHash, winners);
            validation.winner = winner;
            processPayments(validationHash, winner);
            assert(queue.removeFromQueue(validationHash));
        }
    }

    function returnValidatorCount(bytes32 _recentValidationHash) public view returns (uint256){

        (address[] memory nodeOperators, , , , , ) = collectValidationResults(_recentValidationHash);
        return nodeOperators.length;
    }

    /**
     *@dev returns list of registered validators 
     *@return list of addresses 
     */
    function returnValidatorList() public view returns (address[] memory) {
        address[] memory validatorsList = nodeOperations.returnNodeOperators();
        return validatorsList;
    }


     // This function is for compatibility with ValidationHelper contract which will serve
     // multiple versions requiring validation hash (still under development).

    function returnValidatorList( bytes32 vaHash ) public view returns (address[] memory) {
       return  returnValidatorList();

    }

    /**
     *@dev returns list of active validators
     *@return list of addresses 
     */
    function returnValidatorListActual(bytes32 validationHash) external view returns (address[] memory) {

        require(validationHash != bytes32(0), "VNC:returnValidatorListActual - invalid hash");

        Validation storage validation = validations[validationHash];
        uint256 j = 0;

        address[] memory validatorListActive = new address[](validation.validationsCompleted);
        address[] memory validatorsList = nodeOperations.returnNodeOperators();

        for (uint256 i = 0; i < validatorsList.length; i++) {
            if (validation.validatorChoice[validatorsList[i]] != ValidationStatus.Undefined) {
                validatorListActive[j] = validatorsList[i];
                j++;
            }
        }
        return validatorListActive;
    }

    /**
     * @dev get validation results
     * @param validationHash - consist of hash of hashed document and timestamp
     * @return array  of validators
     * @return array of stakes of each validator
     * @return array of validation choices for each validator
     */
    function collectValidationResults(bytes32 validationHash)
        public
        view
        returns (
            address[] memory,
            uint256[] memory,
            uint256[] memory,
            uint256[] memory,
            string[] memory,
            bytes32[] memory
        )
    {
        uint256 j = 0;
        Validation storage validation = validations[validationHash];

        address[] memory validatorsList = returnValidatorList();
        address[] memory validatorListActive = new address[](validation.validationsCompleted);
        uint256[] memory stake = new uint256[](validation.validationsCompleted);
        uint256[] memory validatorsValues = new uint256[](validation.validationsCompleted);
        uint256[] memory validationTime = new uint256[](validation.validationsCompleted);
        string[] memory validationUrl = new string[](validation.validationsCompleted);
        bytes32[] memory reportHash = new bytes32[](validation.validationsCompleted);

        for (uint256 i = 0; i < validatorsList.length; i++) {
            if (validation.validatorChoice[validatorsList[i]] != ValidationStatus.Undefined) {

                stake[j] = memberHelpers.returnDepositAmount(validatorsList[i]);
                validatorsValues[j] = uint256(validation.validatorChoice[validatorsList[i]]);
                validationTime[j] = validation.validatorTime[validatorsList[i]];
                validationUrl[j] = validation.validationUrl[validatorsList[i]];
                validatorListActive[j] = validatorsList[i];
                reportHash[j] = validation.validationHash[validatorsList[i]];
                j++;
            }
        }
        return (
            validatorListActive, stake, validatorsValues, validationTime, validationUrl, reportHash
        );
    }

    /**
     * @dev validators can check if specific document has been already validated by them
     * @param validationHash - consist of hash of hashed document and timestamp
     * @return validation choices used by validator
     */
    function isValidated(bytes32 validationHash) external view returns (ValidationStatus){

        return validations[validationHash].validatorChoice[msg.sender];
    }

    function hasVoted(bytes32 validationHash) external view returns (bool) {
        return votes[msg.sender][validationHash];
    }

    /**
     *@dev winner gets paid, requestor pays
     *@param validationHash - consist of hash of hashed document and timestamp
     *@param winner - address of the winner
     */
    function processPayments(bytes32 validationHash, address winner) internal {

        Validation storage validation = validations[validationHash];
        outstandingValidations[validation.requestor] -= 1;

        assert(memberHelpers.decreaseDeposit(validation.requestor,validation.price));
        assert(nodeOperations.increasePOWRewards(winner, validation.price));
        emit PaymentProcessed(validationHash, winner, validation.winnerVotesPlus[winner], validation.winnerVotesMinus[winner]);
    }

    /**
     * @dev to mark validation as executed. This happens when participation level reached "requiredQuorum"
     * @param validationHash - consist of hash of hashed document and timestamp
     * @param documentHash hash of the document
     */
    function executeValidation(bytes32 validationHash, bytes32 documentHash, uint256 _quorum) internal {

        Validation storage validation = validations[validationHash];
        validation.executionTime = block.timestamp;

        (address[] memory winners, uint256 consensus) = validationHelpers.determineWinners(validationHash);

        validation.consensus = consensus;
        recentTimestamp = validation.validationTime;
        recentValidationHash = validationHash;
        assert(queue.setValidatedFlag(validationHash));
        emit RequestExecuted(validation.requestor, validationHash, documentHash, consensus, _quorum, block.timestamp, validation.url,winners);
    }

    /**
     * @dev called by validator to approve or disapprove this validation
     * @param documentHash - hash of validated document
     * @param validationTime - time when validation has been initialized
     * @param decision - one of the ValidationStatus choices cast by validator
     */
    function validate(
        bytes32 documentHash,
        uint256 validationTime,
        address subscriber,
        ValidationStatus decision,
        string memory valUrl,
        bytes32 reportHash) external virtual nonReentrant {

        bytes32 validationHash = keccak256(abi.encodePacked(documentHash, validationTime, subscriber));

        Validation storage validation = validations[validationHash];

        require(members.userMap(msg.sender, IMembers.UserType(1)), "VNC:validate - not authorized.");
        require(validation.validationTime == validationTime,"VNC:validate - params don't match.");
        require(validation.validatorChoice[msg.sender] == ValidationStatus.Undefined, "VNC:validate - validated already.");
        require(nodeOperations.returnDelegatorLink(msg.sender) == address(0x0), "VNC:validate - delegated stake, can't validate");
        require(nodeOperations.isNodeOperator(msg.sender),"VNC:validate - not a node operator");

        validation.validatorChoice[msg.sender] = decision;
        validation.validatorTime[msg.sender] = block.timestamp;
        validation.validationUrl[msg.sender] = valUrl;
        validation.validationHash[msg.sender] = reportHash;

        validation.validationsCompleted++;

        uint256 stakeAmt = memberHelpers.returnDepositAmount(msg.sender);

        activeOperatorsStake[validation.validationTime][validationHash] += stakeAmt;

        emit ValidatorValidated(msg.sender, documentHash, validation.validatorTime[msg.sender], decision, valUrl);

        if (recentTimestamp > 0 && validation.executionTime == 0)
            // this is not first transaction and there was no execution
            quorum = (activeOperatorsStake[validationTime][validationHash] * 100) / (activeOperatorsStake[recentTimestamp][recentValidationHash]);

        if ((quorum >= members.requiredQuorum() || quorum == 100) && validation.executionTime == 0)
            // first transaction quorum is 100% for first validator
            executeValidation(validationHash, documentHash, quorum);

        assert(nodeOperations.increaseStakeRewards(msg.sender));
        assert(nodeOperations.increaseDelegatedStakeRewards(msg.sender));
    }

    function returnValidationRecord(bytes32 validationHash) external view 
    returns (
            bool cohort,
            address requestor,
            uint256 validationTime,
            uint256 executionTime,
            string memory url,
            uint256 consensus,
            uint256 validationsCompleted,
            uint64 winnerConfirmations,
            bool paymentSent,
            address winner
        )
    {
        Validation storage validation = validations[validationHash];

        cohort = validation.cohort;
        requestor = validation.requestor;
        validationTime = validation.validationTime;
        executionTime = validation.executionTime;
        url = validation.url;
        consensus = validation.consensus;
        validationsCompleted = validation.validationsCompleted;
        winnerConfirmations = validation.winnerConfirmations;
        winner = validation.winner;
        paymentSent = winner != address(0);
    }

    function returnValidationUrl(bytes32 validationHash, address user) external view returns (string memory url){

            Validation storage validation = validations[validationHash];
            url = validation.validationUrl[user];
    }

    function returnWinnerPoints(bytes32 validationHash, address user) external view returns (uint256 plus, uint256 minus){

        Validation storage validation = validations[validationHash];
        plus = validation.winnerVotesPlus[user];
        minus = validation.winnerVotesMinus[user];
    }
     
}
