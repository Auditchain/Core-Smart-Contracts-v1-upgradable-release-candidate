// SPDX-License-Identifier: MIT
pragma solidity =0.8.0;
pragma experimental ABIEncoderV2;
import "@openzeppelin/contracts-upgradeable/access/AccessControlEnumerableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/math/SafeMathUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "./Members.sol";
import "./MemberHelpers.sol";
import "./ICohortFactory.sol";
import "./INodeOperations.sol";


/**
 * @title DepositModifiers
 * Collection of function which alter deposit values
 */

contract DepositModifiers is  AccessControlEnumerableUpgradeable, ReentrancyGuardUpgradeable {
    using SafeERC20Upgradeable for IERC20Upgradeable;
    using SafeMathUpgradeable for uint256;


    address public auditToken;                  
    Members public members;
    MemberHelpers public memberHelpers;
    ICohortFactory public cohortFactory;
    INodeOperations public nodeOperations;

    struct DataSubscriberTypes{
        address cohort;
        uint256 audits;
    }

    mapping(address => mapping(address => mapping(uint256 => bool))) public dataSubscriberCohortMap;
    bytes32 public constant CONTROLLER_ROLE = keccak256("CONTROLLER_ROLE");

    event LogDataSubscriberPaid(address indexed from, uint256 accessFee,  uint256 indexed audits, address enterprise, uint256 enterpriseShare);
    event LogSubscriptionCompleted(address subscriber, uint256 numberOfSubscriptions);
    event LogDataSubscriberValidatorPaid(address  from, address indexed validator, uint256 amount);
    event LogFeesReceived(address indexed validator, uint256 tokens, bytes32 validationHash);
    event LogRewardsDeposited(uint256 tokens, uint256 enterpriseAmount, address indexed enterprise, bytes32 validationHash);
    event LogNonCohortValidationPaid(address indexed requestor, address winner, bytes32 validationHash, uint256 amount);


    function initialize(address  _members, address _auditToken, address _memberHelpers, address _cohortFactory, address _nodeOperations) external  {
        require(_members != address(0), "DM:initialize - Member can't be 0");
        require(_auditToken != address(0), "DM:initialize - Audit Token can't be 0");
        require(_memberHelpers != address(0), "DM:initialize - Member Helpers can't be 0");
        require(_cohortFactory != address(0), "DM:initialize - Cohort Factory can't be 0");
        require(_nodeOperations != address(0), "DM:initialize - Node Operations can't be 0");


        members = Members(_members);
        auditToken = _auditToken;
        memberHelpers = MemberHelpers(_memberHelpers);
        cohortFactory = ICohortFactory(_cohortFactory);
        nodeOperations = INodeOperations(_nodeOperations);
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }


    /// @dev check if caller is a controller
    modifier isController(string memory source) {
        string memory msgError = string(abi.encodePacked("DM - (isController-Modifier):", source, "- Caller is not a controller"));
        require(hasRole(CONTROLLER_ROLE, msg.sender),msgError);

        _;
    }


    /**
    * @dev called when data subscriber initiates subscription 
    * @param enterpriseAddress - address of the enterprise
    * @param audits - type of audits this cohort is part of
    */
    function dataSubscriberPayment(address enterpriseAddress, uint8 audits) public nonReentrant {

        require(enterpriseAddress != address(0), "DM:dataSubscriberPayment - Enterprise address can't be 0");
        require(audits <= 5, "DM:dataSubscriberPayment - Audit type is not in the required range");
        require(!dataSubscriberCohortMap[msg.sender][enterpriseAddress][audits], "DM:dataSubscriberPayment - You are subscribed already");
        require(members.userMap(msg.sender, Members.UserType(2)), "DM:dataSubscriberPayment - Register as data subscriber first");

        dataSubscriberCohortMap[msg.sender][enterpriseAddress][audits] = true;

        uint256 accessFee = members.accessFee();

        require(memberHelpers.returnDepositAmount(msg.sender) >= accessFee, "DM:dataSubscriberPayment - You don't have enough AUDT.");
        IERC20Upgradeable(auditToken).safeTransferFrom(msg.sender, address(this), accessFee);
        uint platformShare = (uint256(100)).sub(members.enterpriseShareSubscriber()).sub(members.validatorShareSubscriber());
        IERC20Upgradeable(auditToken).safeTransfer(members.platformAddress(), accessFee.mul(platformShare).div(100));

        if (members.userMap(msg.sender, Members.UserType(2)) || members.userMap(msg.sender, Members.UserType(0))){
            assert(memberHelpers.decreaseDeposit(msg.sender, accessFee));
        }

        uint256 enterpriseShare = accessFee.mul(members.enterpriseShareSubscriber()).div(100);
        assert(memberHelpers.increaseDeposit(enterpriseAddress, enterpriseShare));

        allocateValidatorDataSubscriberFee(enterpriseAddress, audits, accessFee.mul(members.validatorShareSubscriber()).div(100));

        emit LogDataSubscriberPaid(msg.sender, accessFee, audits, enterpriseAddress, enterpriseShare);
    }

    /**
    * @dev To calculate validator share of data subscriber fee and allocate it to validator deposits
    * @param enterprise - address of cohort holding list of validators
    * @param audits - audit type
    * @param amount - total amount of tokens available for allocation
    */
    function allocateValidatorDataSubscriberFee(address enterprise, uint8 audits, uint256 amount) internal  {

        address[] memory cohortValidators = cohortFactory.returnValidatorList(enterprise, audits);
        uint256 totalDeposits;

        for (uint i=0; i < cohortValidators.length; i++){
            totalDeposits = totalDeposits.add(memberHelpers.returnDepositAmount(cohortValidators[i]));
        }

        for (uint i=0; i < cohortValidators.length; i++){
            uint256 oneValidatorPercentage = (memberHelpers.returnDepositAmount(cohortValidators[i]).mul(10e18)).div(totalDeposits);
            uint256 oneValidatorAmount = (amount.mul(oneValidatorPercentage)).div(10e18);
            assert(memberHelpers.increaseDeposit(cohortValidators[i], oneValidatorAmount));
            emit LogDataSubscriberValidatorPaid(msg.sender, cohortValidators[i], oneValidatorAmount);
        }
    }


    /**
    * @dev To automate subscription for multiple cohorts for data subscriber 
    * @param enterprise - array of enterprise addresses
    * @param audits - array of audit types for each cohort
    */
    function dataSubscriberPaymentMultiple(address[] memory enterprise, uint8[] memory audits) external {

        uint256 length = enterprise.length;
        require(length <= 50, "DM:dataSubscriberPaymentMultiple - List too long");
        for (uint256 i = 0; i < length; i++) {
            dataSubscriberPayment(enterprise[i], audits[i]);
        }

        emit LogSubscriptionCompleted(msg.sender, length);
    }

    /**
    * @dev To process payment for cohort validation
    * @param winner - winner of POW
    * @param _requestor - requesting party
    * @param validationHash -  hash identifying validation
    */
    function processPayment(address winner, address _requestor, bytes32 validationHash) external  isController("processPayment") nonReentrant {

        uint256 enterprisePortion =  members.amountTokensPerValidation().mul(members.enterpriseMatch()).div(100);
        uint256 platformFee = members.amountTokensPerValidation().mul(members.platformShareValidation()).div(100);
        uint256 winnerFee = members.amountTokensPerValidation().add(enterprisePortion).sub(platformFee);

        assert(memberHelpers.decreaseDeposit(_requestor, enterprisePortion));
        require(IAuditToken(auditToken).mint(address(this), members.amountTokensPerValidation()), "DM:processPayment -problem minting");
        assert(memberHelpers.increaseDeposit(members.platformAddress(), platformFee));

        assert(memberHelpers.increaseDeposit(winner, winnerFee));
        emit LogFeesReceived(winner, winnerFee, validationHash);
        emit LogRewardsDeposited(winnerFee, enterprisePortion, _requestor, validationHash);
    }


     /**
    * @dev To process payment for no cohort validation
    * @param _winner - winner of the POW
    * @param _requestor - requesting party
    * @param validationHash -  hash identifying validation
    */
    function processNonChortPayment(address _winner, address _requestor, bytes32 validationHash, uint256 price) external isController("processNonChortPayment") nonReentrant {

        // uint256 POWFee = nodeOperations.POWFee();
        assert(memberHelpers.decreaseDeposit(_requestor, price));
        assert(nodeOperations.increasePOWRewards(_winner, price));
        emit LogNonCohortValidationPaid(_requestor, _winner, validationHash, price);
    }

}