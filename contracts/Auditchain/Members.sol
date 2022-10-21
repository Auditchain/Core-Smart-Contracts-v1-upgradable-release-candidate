// SPDX-License-Identifier: MIT
pragma solidity =0.8.0;
pragma experimental ABIEncoderV2;
import "@openzeppelin/contracts-upgradeable/access/AccessControlEnumerableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "./../IAuditToken.sol";

/**
 * @title Members
 * Allows on creation of Enterprise and Validator accounts.
 * Contract also contains several update functions controlled by the Governance contracts
 */

contract Members is  AccessControlEnumerableUpgradeable {


    bytes32 public constant CONTROLLER_ROLE = keccak256("CONTROLLER_ROLE");
    bytes32 public constant SETTER_ROLE =  keccak256("SETTER_ROLE");

    IAuditToken public auditToken;                       //AUDT token 
    mapping(address => uint256) public deposits;        //track deposits per user
    mapping(address => mapping(address => bool)) public dataSubscriberCohortMap;

    uint256 public accessFee;
    uint256 public enterpriseShareSubscriber;
    uint256 public validatorShareSubscriber;
    address public platformAddress;
    uint256 public platformShare;    
    uint256 public enterpriseMatch;         
    uint256 public minDepositDays;
    uint256 public requiredQuorum;             // quorum required to consider validation valid
    uint256 public maxValidators;
    uint256 public minContribution;

    struct USER {

        address user;
        string name;
    }   


     // Audit types to be used. Two types added for future expansion 
    mapping(address => mapping(UserType => string)) public user;
    mapping(address => mapping(UserType => bool)) public userMap;
    USER[] public enterprises;
    USER[] public validators;
    USER[] public dataSubscribers;

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
        accessFee = 1000e18;
        enterpriseShareSubscriber = 40;
        validatorShareSubscriber = 40;
        platformShare = 15;    
        enterpriseMatch = 200;       
        minDepositDays = 30;
        requiredQuorum = 80;
        maxValidators = 2;
        minContribution = 5e21;
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

   
       /**
     * @dev to be called by governance to update new amount for min contribution/stake
     * @param _minContribution new value of required min contribution
     */
    function updateMinContribution(uint256 _minContribution) external isSetter() {
        require(_minContribution != 0, "Members:updateMinContribution - Min contribution can't be 0");
        minContribution = _minContribution;
        LogGovernanceUpdate(maxValidators, "updateMinContribution");
    }
     

     /**
     * @dev to be called by governance to update new amount for max validators
     * @param _maxValidator new value of required quorum
     */
    function updateMaxValidator(uint256 _maxValidator) external isSetter() {
        require(_maxValidator != 0, "Members:updateMaxValidator - Max validator value can't be 0");
        maxValidators = _maxValidator;
        LogGovernanceUpdate(maxValidators, "updateMaxValidator");
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
        platformShare = _newFee;
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
    * @param _newUser to add
    * @param _name name of the user
    * @param _userType  type of the user, enterprise, validator or data subscriber
    */
    function addUser(address _newUser, string memory _name, UserType _userType) external isController() {
        

        require(!userMap[_newUser][_userType], "Members:addUser - This user already exist.");
        user[_newUser][_userType] = _name;
        userMap[_newUser][_userType] = true;

        USER memory newUser;

        newUser.user = _newUser;
        newUser.name = _name;

        if (_userType == UserType.DataSubscriber) 
            dataSubscribers.push(newUser);
        else if (_userType == UserType.Validator)
            validators.push(newUser);
        else if (_userType == UserType.Enterprise)
            enterprises.push(newUser);
     
        emit UserAdded(_newUser, _name, _userType);
    }

    function returnValidators() external view returns(address[] memory, string[] memory) {

        address[] memory u = new address[](validators.length);
        string[] memory name = new string[](validators.length);

        for (uint256 i; i < validators.length; i++){
            u[i] = validators[i].user;
            name[i] = validators[i].name;
        }

        return (u, name);
    }

     function returnEnterprises() external view returns(address[] memory, string[] memory) {

        address[] memory u = new address[](enterprises.length);
        string[] memory name = new string[](enterprises.length);

        for (uint256 i; i < enterprises.length; i++){
            u[i] = enterprises[i].user;
            name[i] = enterprises[i].name;
        }

        return (u, name);

    }

     function returnDS() external view returns(address[] memory, string[] memory) {

        address[] memory u = new address[](dataSubscribers.length);
        string[] memory name = new string[](dataSubscribers.length);

        for (uint256 i; i < dataSubscribers.length; i++){
            u[i] = dataSubscribers[i].user;
            name[i] = dataSubscribers[i].name;
        }

        return (u, name);
    }

}
