// SPDX-License-Identifier: MIT
pragma solidity =0.8.0;
pragma experimental ABIEncoderV2;
import "@openzeppelin/contracts-upgradeable/access/AccessControlEnumerableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "./../IAuditToken.sol";

/**
 * @title Members
 * Allows on creation of Enterprise and Validator accounts and staking of funds by validators
 * Validators and enterprises have ability to withdraw their staking and earnings 
 * Contract also contains several update functions controlled by the Governance contracts
 */

contract Members is  AccessControlEnumerableUpgradeable {

    struct DataSubscriberTypes{
        address cohort;
        uint256 audits;
    }

    bytes32 public constant CONTROLLER_ROLE = keccak256("CONTROLLER_ROLE");
    bytes32 public constant SETTER_ROLE =  keccak256("SETTER_ROLE");

    IAuditToken public auditToken;                       //AUDT token 
    mapping(address => uint256) public deposits;        //track deposits per user
    // mapping(address => DataSubscriberTypes[]) public dataSubscriberCohorts;
    mapping(address => mapping(address => bool)) public dataSubscriberCohortMap;
    uint256 public amountTokensPerValidation ;    //New minted amount per validation

    uint256 public accessFee;
    uint256 public enterpriseShareSubscriber;
    uint256 public validatorShareSubscriber;
    address public platformAddress;
    uint256 public platformShareValidation;    
    uint256 public enterpriseMatch;         
    uint256 public minDepositDays;
    uint256 public requiredQuorum;             // quorum required to consider validation valid

     // Audit types to be used. Two types added for future expansion 
    mapping(address => mapping(UserType => string)) public user;
    mapping(address => mapping(UserType => bool)) public userMap;
    address[] public enterprises;
    address[] public validators;
    address[] public dataSubscribers;

    enum UserType {Enterprise, Validator, DataSubscriber}  
    
    event UserAdded(address indexed user, string name, UserType indexed userType);
    event LogGovernanceUpdate(uint256 params, string indexed action);

    
    /// @dev check if caller is a controller     
    modifier isController {
        require(hasRole(CONTROLLER_ROLE, msg.sender), "Members:IsController - Caller is not a controller");

        _;
    }

    /// @dev check if caller is a setter     
    modifier isSetter {
        require(hasRole(SETTER_ROLE, msg.sender), "Members:isSetter - Caller is not a setter");

        _;
    }

    function initialize(address _auditToken, address _platformAddress ) initializer external {


        require(_auditToken != address(0), "Members:constructor - Audit token address can't be 0");
        require(_platformAddress != address(0), "Members:constructor - Platform address can't be 0");
        auditToken = IAuditToken(_auditToken);        
        platformAddress = _platformAddress;
        amountTokensPerValidation =  1e18;  
        accessFee = 1000e18;
        enterpriseShareSubscriber = 40;
        validatorShareSubscriber = 40;
        platformShareValidation = 15;    
        enterpriseMatch = 200;       
        minDepositDays = 30;
        requiredQuorum = 80;
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

   
     
    /**
     * @dev to be called by governance to update new amount for required quorum
     * @param _requiredQuorum new value of required quorum
     */
    function updateQuorum(uint256 _requiredQuorum) external isSetter() {
        require(_requiredQuorum != 0, "Members:updateQuorum - New quorum value can't be 0");
        requiredQuorum = _requiredQuorum;
        LogGovernanceUpdate(_requiredQuorum, "updateQuorum");
    }


    /**
    * @dev to be called by Governance contract to update new value for the validation platform fee
    * @param _newFee new value for data subscriber access fee
    */
    function updatePlatformShareValidation(uint256 _newFee) external isSetter() {

        require(_newFee != 0, "Members:updatePlatformShareValidation - New value for the platform fee can't be 0");
        platformShareValidation = _newFee;
        emit LogGovernanceUpdate(_newFee, "updatePlatformShareValidation");
    }

    /**
    * @dev to be called by Governance contract to update new value for data subscriber access fee
    * @param _accessFee new value for data subscriber access fee
    */
    function updateAccessFee(uint256 _accessFee) external isSetter() {

        require(_accessFee != 0, "Members:updateAccessFee - New value for the access fee can't be 0");
        accessFee = _accessFee;
        emit LogGovernanceUpdate(_accessFee, "updateAccessFee");
    }

     /**
    * @dev to be called by Governance contract to update new amount for validation rewards
    * @param _minDepositDays new value for minimum of days to calculate 
    */
    function updateMinDepositDays(uint256 _minDepositDays) external isSetter() {

        require(_minDepositDays != 0, "Members:updateMinDepositDays - New value for the min deposit days can't be 0");
        minDepositDays = _minDepositDays;
        emit LogGovernanceUpdate(_minDepositDays, "updateMinDepositDays");
    }

    /**
    * @dev to be called by Governance contract to update new amount for validation rewards
    * @param _amountTokensPerValidation new value of reward per validation
    */
    function updateTokensPerValidation(uint256 _amountTokensPerValidation) external isSetter() {

        require(_amountTokensPerValidation != 0, "Members:updateTokensPerValidation - New value for the reward can't be 0");
        amountTokensPerValidation = _amountTokensPerValidation;
        emit LogGovernanceUpdate(_amountTokensPerValidation, "updateRewards");

    }
    
    /**
    * @dev to be called by Governance contract
    * @param _enterpriseMatch new value of enterprise portion of enterprise value of validation cost
    */
    function updateEnterpriseMatch(uint256 _enterpriseMatch) external isSetter()  {

        require(_enterpriseMatch != 0, "Members:updateEnterpriseMatch - New value for the enterprise match can't be 0");
        enterpriseMatch = _enterpriseMatch;
        emit LogGovernanceUpdate(_enterpriseMatch, "updateEnterpriseMatch");

    }

    /**
    * @dev to be called by Governance contract to change enterprise and validators shares
    * of data subscription fees. 
    * @param _enterpriseShareSubscriber  - share of the enterprise
    * @param _validatorShareSubscriber - share of the subscribers
    */
    function updateDataSubscriberShares(uint256 _enterpriseShareSubscriber, uint256 _validatorShareSubscriber ) external isSetter()  {

        // platform share should be at least 10%
        require(_enterpriseShareSubscriber + validatorShareSubscriber <=90, "Enterprise and Validator shares can't be larger than 90");
        enterpriseShareSubscriber = _enterpriseShareSubscriber;
        validatorShareSubscriber = _validatorShareSubscriber;
        emit LogGovernanceUpdate(enterpriseShareSubscriber, "updateDataSubscriberShares:Enterprise");
    }

   
    /** 
    * @dev add new platform user
    * @param newUser to add
    * @param name name of the user
    * @param userType  type of the user, enterprise, validator or data subscriber
    */
    function addUser(address newUser, string memory name, UserType userType) external isController() {

        require(!userMap[newUser][userType], "Members:addUser - This user already exist.");
        user[newUser][userType] = name;
        userMap[newUser][userType] = true;

        if (userType == UserType.DataSubscriber) 
            dataSubscribers.push(newUser);
        else if (userType == UserType.Validator)
            validators.push(newUser);
        else if (userType == UserType.Enterprise)
            enterprises.push(newUser);
     
        emit UserAdded(newUser, name, userType);
    }

    function returnValidators() external view returns(address[] memory) {

        return validators;
    }

}
