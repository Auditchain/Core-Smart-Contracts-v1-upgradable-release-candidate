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
abstract contract Validations  is ReentrancyGuardUpgradeable {
    IMembers public members;
    IQueue public queue;
    IMemberHelpers public memberHelpers;
    INodeOperations public nodeOperations;
    IValidationHelpers public validationHelpers;

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
                        uint256 timeExecuted, string url, address[] winners);

    event PaymentProcessed(bytes32 validationHash, address winner, uint256 pointsPlus, uint256 pointsMinus);
    event WinnerVoted(address validator, address winner, bool isValid);
    event ValRegistered(address indexed validator, bytes32 valHash);

    function initialize (
        address _members,
        address _memberHelpers,
        address _nodeOperations,
        address _validationHelpers,
        address _queue  ) public virtual {


        members = IMembers(_members);
        memberHelpers = IMemberHelpers(_memberHelpers);
        nodeOperations = INodeOperations(_nodeOperations);
        validationHelpers = IValidationHelpers(_validationHelpers);
        queue = IQueue(_queue);
     
    }



    /**
     * @dev to be called by user to validate fin statements
     * @param docHash - hashed document
     * @param url - location of the document
     */
  function initValNoCohort(bytes32 docHash, string memory url, uint8 auditTypes, uint256 price) external  {

        require(docHash.length > 0, "VNC:initValNoCohort - Doc hash value can't be 0");
        require(memberHelpers.checkIfRequestorHasFunds(msg.sender, price),"VNC:initValNoCohort - Deposit additional funds.");
        require(members.userMap(msg.sender, IMembers.UserType(2)) || 
                members.userMap(msg.sender, IMembers.UserType(0)),"VNC:initValNoCohort - Register as data subscriber");

        bytes32 valHash = keccak256(abi.encodePacked(docHash, block.timestamp, msg.sender));

        assert(memberHelpers.increaseValNo(msg.sender));
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
      
        if (validation.winnerConfirmations >= members.maxValidators() && validation.winner == address(0)) {
            address winner = validationHelpers.selectWinner(validationHash, winners);
            validation.winner = winner;
            processPayments(validationHash, winner);
            assert(queue.removeFromQueue(validationHash));
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

    /**isValidated
     *@dev winner gets paid, requestor pays
     *@param validationHash - consist of hash of hashed document and timestamp
     *@param winner - address of the winner
     */
    function processPayments(bytes32 validationHash, address winner) internal {

        Validation storage validation = validations[validationHash];
        uint256 platformFee = (validation.price * members.platformShareValidation()) / 100;
        uint256 winnerFee = validation.price - platformFee;

        assert(memberHelpers.decreaseDeposit(validation.requestor, validation.price));
        assert(nodeOperations.increasePOWRewards(winner, winnerFee));
        assert(nodeOperations.increasePOWRewards(members.platformAddress(), platformFee));
        assert(memberHelpers.decreaseValNo(msg.sender));
        emit PaymentProcessed(validationHash, winner, validation.winnerVotesPlus[winner], validation.winnerVotesMinus[winner]);
    }

    /**
     * @dev to mark validation as executed. This happens when set number of validators have validated the request.
     * @param validationHash - consist of hash of hashed document and timestamp
     * @param documentHash hash of the document
     */
    function executeValidation(bytes32 validationHash, bytes32 documentHash) internal nonReentrant{

        Validation storage validation = validations[validationHash];
        validation.executionTime = block.timestamp;

        (address[] memory winners, uint256 consensus) = validationHelpers.determineWinners(validationHash);

        validation.consensus = consensus;
        // processedId = queue.findIdForValidationHash(validationHash);
        assert(queue.setValidatedFlag(validationHash));
        emit RequestExecuted(validation.requestor, validationHash, documentHash, consensus,  block.timestamp, validation.url,winners);
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


        // actOpStake[validation.validationTime][valHash] += memberHelpers.returnDepositAmount(msg.sender);

        emit ValidatorValidated(msg.sender, docHash, block.timestamp, decision, valUrl);

        if (validation.validationsCompleted >= members.maxValidators() && validation.executionTime == 0) 
            executeValidation(valHash, docHash);

        assert(nodeOperations.increaseStakeRewards(msg.sender));
        assert(nodeOperations.increaseDelegatedStakeRewards(msg.sender));
    }


    function registerValidation() public virtual  returns(bytes32 valHash);

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

        address[] memory validatorsList = validationHelpers.returnValidatorList();
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

function returnWinnerPoints(bytes32 validationHash, address user) external view returns (uint256 plus, uint256 minus){

    Validation storage validation = validations[validationHash];
    plus = validation.winnerVotesPlus[user];
    minus = validation.winnerVotesMinus[user];
}
     
}
