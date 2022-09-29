// SPDX-License-Identifier: MIT
pragma solidity =0.8.0;

import "./INodeOperations.sol";
import "./IMembers.sol";
import "./IValidationHelpers.sol";
import "./IQueue.sol";
import "./IMemberHelpers.sol";
import "./ICohortFactory.sol";
import "./ICohortFactory.sol";

import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";

/**
 * @title Validations
 * Data subscriber can request financial document validation,
 * which will be validated by group of node operators. 
 */
abstract contract Validations  is ReentrancyGuardUpgradeable {
    IMembers public members;
    IQueue public queue;
    IMemberHelpers public mH;
    INodeOperations public nodeOperations;
    IValidationHelpers public validationHelpers;
    ICohortFactory public cohortFactory;


    enum AuditTypes {Unknown, Financial, System, NFT, Type4, Type5, Type6}


    // Validation can be approved or disapproved. Initial status is undefined.
    enum ValidationStatus { Undefined, Yes, No }

    struct Validation {
        AuditTypes auditTypes;
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
        uint64 regNum;
    }

    mapping(address => mapping(bytes32 => bool)) public votes;
    // mapping(uint256 => mapping(bytes32 => uint256)) public actOpStake;
    mapping(address => uint256) public reg;
    mapping(address => uint256) public regP;
    mapping(bytes32 => Validation) public validations; // track each validation
   
    event ValidationInitialized(address indexed user, bytes32 indexed validationHash, uint256 initTime, bytes32 documentHash, string url, AuditTypes auditType);
    event ValidatorValidated(address indexed validator, bytes32 indexed documentHash, uint256 indexed validationTime, 
                             ValidationStatus decision, string valUrl);

    event RequestExecuted(address indexed requestor, bytes32 indexed validationHash, bytes32 documentHash, uint256 consensus, 
                        uint256 timeExecuted, string url);

    event PaymentProcessed(bytes32 validationHash, address winner, uint256 pointsPlus, uint256 pointsMinus);
    event WinnerVoted(address validator, address winner, bool isValid);
    event ValRegistered(address indexed validator, bytes32 valHash);

    function initialize (
        address _members,
        address _memberHelpers,
        address _nodeOperations,
        address _validationHelpers,
        address _queue,
        address _cFactory  ) public virtual {


        members = IMembers(_members);
        mH = IMemberHelpers(_memberHelpers);
        nodeOperations = INodeOperations(_nodeOperations);
        validationHelpers = IValidationHelpers(_validationHelpers);
        queue = IQueue(_queue);
        cohortFactory = ICohortFactory(_cFactory);
     
    }



    /**
     * @dev to be called by user to validate fin statements
     * @param docHash - hashed document
     * @param url - location of the document
     */
  function initVal(bytes32 docHash, string memory url, uint8 auditTypes, uint256 price) external  {

        require(docHash.length > 0, "VNC:initVal - Doc hash value can't be 0");
        // require(mH.checkIfRequestorHasFunds(msg.sender, price),"VNC:initVal - Deposit additional funds.");
        // require(members.userMap(msg.sender, IMembers.UserType(2)) || 
        //         members.userMap(msg.sender, IMembers.UserType(0)),"VNC:initVal - Register as data subscriber");

        bytes32 valHash = keccak256(abi.encodePacked(docHash, block.timestamp, msg.sender));

        assert(mH.increaseValNo(msg.sender));
        Validation storage newValidation = validations[valHash];

        newValidation.url = url;
        newValidation.validationTime = block.timestamp;
        newValidation.requestor = msg.sender;
        newValidation.auditTypes = AuditTypes(auditTypes);
        newValidation.price = price;

        assert(queue.addToQueue(price, valHash, docHash, url, msg.sender, block.timestamp, auditTypes));

        emit ValidationInitialized(msg.sender, valHash, block.timestamp, docHash, url, AuditTypes(auditTypes));
    }

    /**
     *@dev each validator votes who is the winner
     *@param _winners - list of candidates to vote on
     *@param _vote - list of votes for each candidate
     *@param _validationHash - val in question 
     */
    function voteWinner(address[] memory _winners, bool[] memory _vote, bytes32 _validationHash ) external nonReentrant{

        require(votes[msg.sender][_validationHash] == false, "VNC:voteWinner - voted already");
        require(members.userMap(msg.sender, IMembers.UserType(1)),"VNC:voteWinner - not registered as a validator");


        Validation storage validation = validations[_validationHash];

        for (uint8 i = 0; i < _winners.length; i++) {
            if (_vote[i])
                validation.winnerVotesPlus[_winners[i]] += 1;
            else
                validation.winnerVotesMinus[_winners[i]] +=  1;

            votes[msg.sender][_validationHash] = true;
            emit WinnerVoted(msg.sender, _winners[i], _vote[i]);
        }

        validation.winnerConfirmations++;
      
        if (validation.winnerConfirmations >= members.maxValidators() && validation.winner == address(0)) {
            address winner = validationHelpers.selectWinner(_validationHash, _winners);
            validation.winner = winner;
            processPayments(_validationHash, winner);
            assert(queue.removeFromQueue(_validationHash));
        }
    }

    /**
     * @dev validators can check if specific document has been already validated by them
     * @param validationHash - consist of hash of hashed document and timestamp
     * @return validation choices used by validator
     */
    function isValidated(bytes32 validationHash) public view returns (ValidationStatus, uint256){

        return (validations[validationHash].validatorChoice[msg.sender], validations[validationHash].validationsCompleted);
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

        Validation storage v = validations[validationHash];
        uint256 platformFee = (v.price * members.platformShareValidation()) / 100;
        uint256 winnerFee = v.price - platformFee;

        assert(mH.decreaseDeposit(v.requestor, v.price));
        assert(nodeOperations.increasePOWRewards(winner, winnerFee));
        assert(nodeOperations.increasePOWRewards(members.platformAddress(), platformFee));
        assert(mH.decreaseValNo(v.requestor));
        emit PaymentProcessed(validationHash, winner, v.winnerVotesPlus[winner], v.winnerVotesMinus[winner]);
    }

    /**
     * @dev to mark validation as executed. This happens when set number of validators have validated the request.
     * @param validationHash - consist of hash of hashed document and timestamp
     * @param documentHash hash of the document
     */
    function executeValidation(bytes32 validationHash, bytes32 documentHash)public  virtual nonReentrant{

        Validation storage validation = validations[validationHash];

        uint256 consensus = validationHelpers.returnConsensus(validationHash, address(this));
        validation.executionTime = block.timestamp;
        validation.consensus = consensus;
        assert(queue.setValidatedFlag(validationHash));
        
        emit RequestExecuted(validation.requestor, validationHash, documentHash, consensus,  block.timestamp, validation.url);
    }

    /**
     * @dev called by validator to approve or disapprove this validation
     * @param docHash - hash of validated document
     * @param valTime - time when validation has been initialized
     * @param decision - one of the ValidationStatus choices cast by validator
     */
    function validate(
        bytes32 docHash,
        uint256 valTime,
        address subscriber,
        ValidationStatus decision,
        string memory valUrl,
        bytes32 reportHash) external virtual  {

        bytes32 valHash = keccak256(abi.encodePacked(docHash, valTime, subscriber));

        Validation storage validation = validations[valHash];

        require(members.userMap(msg.sender, IMembers.UserType(1)), "VNC:validate - not authorized.");
        require(validation.validationTime == valTime,"VNC:validate - params don't match.");
        require(validation.validatorChoice[msg.sender] == ValidationStatus.Undefined, "VNC:validate - validated already.");
        require(nodeOperations.returnDelegatorLink(msg.sender) == address(0x0), "VNC:validate - delegated stake, can't validate");
        require(nodeOperations.isNodeOperator(msg.sender),"VNC:validate - not a node operator");

        validation.validatorChoice[msg.sender] = decision;
        validation.validatorTime[msg.sender] = block.timestamp;
        validation.validationUrl[msg.sender] = valUrl;
        validation.validationHash[msg.sender] = reportHash;

        validation.validationsCompleted++;
        reg[msg.sender] = 0;
        // actOpStake[validation.validationTime][valHash] += mH.returnDepositAmount(msg.sender);

        assert(nodeOperations.increaseStakeRewards(msg.sender));
        assert(nodeOperations.increaseDelegatedStakeRewards(msg.sender));
        emit ValidatorValidated(msg.sender, docHash, block.timestamp, decision, valUrl);
        executeValidation(valHash, docHash);
    }


    function registerValidation() public virtual;

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
        address[] memory validatorsList;
        Validation storage validation = validations[validationHash];

        if (validation.auditTypes == AuditTypes(0))
            validatorsList =  nodeOperations.returnNodeOperators();
        else 
            validatorsList  = cohortFactory.returnValidatorList(validation.requestor, uint8(validation.auditTypes));

        address[] memory validatorListActive = new address[](validation.validationsCompleted);
        uint256[] memory stake = new uint256[](validation.validationsCompleted);
        uint256[] memory validatorsValues = new uint256[](validation.validationsCompleted);
        uint256[] memory validationTime = new uint256[](validation.validationsCompleted);
        string[] memory validationUrl = new string[](validation.validationsCompleted);
        bytes32[] memory reportHash = new bytes32[](validation.validationsCompleted);

        for (uint256 i = 0; i < validatorsList.length; i++) {
            if (validation.validatorChoice[validatorsList[i]] != ValidationStatus.Undefined) {

                stake[j] = mH.returnDepositAmount(validatorsList[i]);
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

    function returnWinnerPoints(bytes32 validationHash, address user) external view returns (uint256 plus, uint256 minus){

        Validation storage validation = validations[validationHash];
        plus = validation.winnerVotesPlus[user];
        minus = validation.winnerVotesMinus[user];
    }
     
}
