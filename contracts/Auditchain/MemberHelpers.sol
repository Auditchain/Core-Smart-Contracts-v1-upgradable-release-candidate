// SPDX-License-Identifier: MIT
pragma solidity =0.8.0;
import "./Members.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlEnumerableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "./../IAuditToken.sol";
import "./IValidations.sol";

/**
 * @title MemberHelpers
 * Additional function for Members
 */
contract MemberHelpers is AccessControlEnumerableUpgradeable, ReentrancyGuardUpgradeable {
    using SafeERC20Upgradeable for IERC20Upgradeable;

        bytes32 public constant CONTROLLER_ROLE = keccak256("CONTROLLER_ROLE");

    address public auditToken; //AUDT token
    Members public members; // Members contract
    IValidations public validations; // Validation interface
    mapping(address => uint256) public deposits; //track deposits per user
    uint256 public totalStaked;
    mapping(address => uint256) public outstandingValidations;

    struct USER {
        address user;
        string name;
        uint256 deposit;
    }

    

    event LogDepositReceived(address indexed from, uint256 amount);
    event LogDepositRedeemed(address indexed from, uint256 amount);
    event LogIncreaseDeposit(address user, uint256 amount);
    event LogDecreaseDeposit(address user, uint256 amount);
    event LogIncreaseVal(address user, uint256 val);
    event LogDecreaseVal(address user, uint256 val);


    function initialize(address _members, address _auditToken) external {
        require(_members != address(0),"MemberHelpers:constructor - Member address can't be 0");
        require(_auditToken != address(0), "MemberHelpers:setCohort - Token address can't be 0");
        members = Members(_members);
        auditToken = _auditToken;
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

   /// @dev check if caller is a controller
    modifier isController(string memory source) {
        string memory msgError = string(abi.encodePacked("MemberHelpers(isController - Modifier):", source, "- Caller is not a controller"));
        require(hasRole(CONTROLLER_ROLE, msg.sender),msgError);

        _;
    }


     /// @dev check if user is validator
    modifier isValidator(string memory source) {

        string memory msgError = string(abi.encodePacked("NodeOperations(Modifier):", source, "- You are not a validator"));
        require( members.userMap(msg.sender, Members.UserType(1)), msgError);

        _;
    }

    function returnDepositAmount(address user) public view returns (uint256) {
        return deposits[user];
    }

   

    function increaseDeposit(address user, uint256 amount) external isController("increaseDeposit") returns(bool){
        deposits[user] += amount;
        emit LogIncreaseDeposit(user, amount);
        return true;
    }

    function decreaseDeposit(address user, uint256 amount) external isController("decreaseDeposit") returns (bool){
        deposits[user] -= amount;
        emit LogDecreaseDeposit(user, amount);
        return true;
    }


     function increaseValNo(address user) external isController("increaseValNo") returns(bool){
        outstandingValidations[user]++;
        emit LogIncreaseVal(user, outstandingValidations[user]);
        return true;
    }

    function decreaseValNo(address user) external isController("decreaseValNo") returns (bool){
        outstandingValidations[user]--;
        emit LogDecreaseVal(user, outstandingValidations[user]);
        return true;
    }

    /**
     * @dev Function to accept contribution to staking
     * @param amount number of AUDT tokens sent to contract for staking
     */
    function stake(uint256 amount) external nonReentrant {
        require(amount > 0, "MH:stake - Amount can't be 0");

        if (members.userMap(msg.sender, Members.UserType(1))) {
            require(amount + deposits[msg.sender] >= members.minContribution(), "MH:stake - Minimum contribution amount is 5000 AUDT");
           
        }
        require(members.userMap(msg.sender, Members.UserType(0)) ||
                members.userMap(msg.sender, Members.UserType(1)) ||
                members.userMap(msg.sender, Members.UserType(2)),
                                            "MH:stake - User is not validator or enterprise.");

        IERC20Upgradeable(auditToken).safeTransferFrom(msg.sender, address(this), amount);
        deposits[msg.sender] += amount;
        totalStaked += amount;
        emit LogDepositReceived(msg.sender, amount);
    }


    /**
     * @dev Function to redeem contribution.
     * @param amount number of tokens being redeemed
     */
    function redeem(uint256 amount) external nonReentrant {
        if (members.userMap(msg.sender, Members.UserType(0))) {
            require(outstandingValidations[msg.sender] == 0, "MH:redeem - still processing outstanding validations");
        }

        deposits[msg.sender] -= amount;
        totalStaked -= amount;
        IERC20Upgradeable(auditToken).safeTransfer(msg.sender, amount);
        emit LogDepositRedeemed(msg.sender, amount);
    }
    

    /**
     * @dev to be called by administrator to set Validation address
     * @param _validations validation contract address
     */
    function setValidation(address _validations) external isController("setValidation") {
        require( _validations != address(0), "MH:setValidation - Validation address can't be 0");
        validations = IValidations(_validations);
    }


        /**
     * @dev verify if requesting party has sufficient funds
     * @param requestor a user whose funds are checked
     * @return true or false
     */
    function checkIfRequestorHasFunds(address requestor, uint256 price) public view returns (bool)
    { 
        require(requestor != address(0), "VNC:checkIfRequestorHasFunds - address can't be 0)");


        if (outstandingValidations[requestor] == 0)
            return (returnDepositAmount(requestor) > price );

        return (returnDepositAmount(requestor) > price * (outstandingValidations[requestor] ));
    }


    function returnMembers(uint8 userType) external view  returns (USER[] memory){

        address[] memory user;
        string[] memory name;
        USER[] memory newUser;

        if (userType == 0)
            (user, name) = members.returnEnterprises();
        else if (userType == 1)
            (user, name) = members.returnValidators();
         else if (userType == 2)
            (user, name) = members.returnDS();

        for (uint256 i; i< user.length; i++ ){
            newUser[i].user = user[i];
            newUser[i].name = name[i];
            newUser[i].deposit = deposits[user[i]];
        }

        return newUser;
    }




}
