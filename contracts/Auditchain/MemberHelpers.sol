// SPDX-License-Identifier: MIT
pragma solidity =0.8.0;
import "./Members.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlEnumerableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "./../IAuditToken.sol";
import "./IValidations.sol";
import "./PriceConsumerV3.sol";


/**
 * @title MemberHelpers
 * Additional function for Members
 */
contract MemberHelpers is AccessControlEnumerableUpgradeable, ReentrancyGuardUpgradeable {
    using SafeERC20Upgradeable for IERC20Upgradeable;

    bytes32 public constant CONTROLLER_ROLE = keccak256("CONTROLLER_ROLE");
    PriceConsumerV3 private _priceConsumerV3;   // Smart contract checking fof price of USD/ETH


    address public auditToken; //AUDT token
    address public USDC;

    Members public members; // Members contract
    IValidations public validations; // Validation interface
    mapping(address => uint256) public depositsAUDT; //track deposits per user
    mapping(address => uint256) public depositsUSDC; //track deposits per user

    uint256 public totalStaked;
    mapping(address => uint256) public outstandingValidations;

    uint256 public AUDTDeposited;
    uint256 public USDCDeposited;

    struct USER {
        address user;
        string name;
        uint256 depositAUDT;
        uint256 depositUSDC;

    }

    enum Coin {NONE, USDC, AUDT}

    

    event LogDepositReceived(address indexed from, uint256 amount, Coin coin);
    event LogDepositRedeemed(address indexed from, uint256 amount);
    event LogIncreaseDeposit(address user, uint256 amount, uint256 audtAmount);
    event LogDecreaseDeposit(address user, uint256 amount, uint256 audtAmount);
    event LogIncreaseVal(address user, uint256 val);
    event LogDecreaseVal(address user, uint256 val);
    event FundsForwarded(uint256 amount, Coin coin);



    function initialize(address _members, address _auditToken, address _USDC) external {
        require(_members != address(0),"MemberHelpers:constructor - Member address can't be 0");
        require(_auditToken != address(0), "MemberHelpers:setCohort - Token address can't be 0");
        members = Members(_members);
        auditToken = _auditToken;
        USDC = _USDC;
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

    function returnDepositAmount(address user) public view returns (uint256 amount) {
        uint256 audtAmount =  calculateUSDForAUDT(depositsAUDT[user]);
        return (audtAmount + depositsUSDC[user]);
    }

   

    function increaseDeposit(address user, uint256 amount) external isController("increaseDeposit") returns(bool){

        uint256 audtAmount = calculateAUDTForUSD(amount);
        depositsAUDT[user] += audtAmount;
        emit LogIncreaseDeposit(user, amount, audtAmount);
        return true;
    }

    function decreaseDeposit(address user, uint256 amount) external isController("decreaseDeposit") returns (bool){

        uint256 audtAmount = calculateAUDTForUSD(amount);

        if  (depositsUSDC[user] >= amount)
            depositsUSDC[user] -= amount;

        else if(depositsUSDC[user] > 0 &&  depositsUSDC[user] < amount){
            depositsUSDC[user] = 0;
            audtAmount = calculateAUDTForUSD(amount - depositsUSDC[user] );
            depositsAUDT[user] -= audtAmount;

        }else
            depositsAUDT[user] -= audtAmount;
        
        IAuditToken(auditToken).mint(address(validations), audtAmount );
        emit LogDecreaseDeposit(user, amount, audtAmount);
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
     * @dev find out ETH/USD price
     * @param amount - amount of crypto to be checked against USD
     * @return amount of stable coin
     */
    function calculateUSDForAUDT(uint256 amount) public view returns (uint256) {

       int256 price = _priceConsumerV3.getLatestPrice();
       return (amount / uint256(price));
    }


    function calculateAUDTForUSD(uint256 amount) public view returns (uint256) {

       int256 price = _priceConsumerV3.getLatestPrice();
       return (amount / uint256(price)) / 1e8;  
    }

    /**
     * @dev Function to accept contribution for staking
     * @param amount number of AUDT or USDC tokens sent to contract for staking
     */
    function stake(uint256 amount, Coin coin) external nonReentrant {

        uint256 valueInSC;


         _preValidateDeposit(amount, coin);

        if (coin == Coin.AUDT) {
            valueInSC =  calculateUSDForAUDT(amount);
            AUDTDeposited +=  amount;
            depositsAUDT[msg.sender] += amount; 
        } else if (coin == Coin.USDC) {
            valueInSC = amount;
            USDCDeposited += amount;
            depositsUSDC[msg.sender] += amount; 
        }

        _forwardFunds(amount, coin);

        emit LogDepositReceived(msg.sender, amount, coin);
    }


     /**
     * @dev Forward funds to wallet. 
     * @param amount - amount of stable coin to be transferred to this contract
     * @param coin - type of coin contributed
     */
    function _forwardFunds(uint256 amount, Coin coin) internal {

        if (coin == Coin.AUDT)
            IERC20Upgradeable(auditToken).safeTransferFrom(msg.sender, address(this), amount);
        else if (coin == Coin.USDC)
            IERC20Upgradeable(USDC).safeTransferFrom(msg.sender, address(this), amount);

        emit FundsForwarded(amount, coin);

    }


    /**
     * @dev Validation of an incoming deposit.
     * @param amount Amount to deposit
     * @param coin coin deposited
     */
    function _preValidateDeposit(uint256 amount, Coin coin) internal view {
        require(msg.sender != address(0), "MH:_preValidatePurchase  sender is the zero address");
        require(amount != 0, "NH:_preValidatePurchase amount can't be  0");
        require(members.userMap(msg.sender, Members.UserType(0)) ||
                members.userMap(msg.sender, Members.UserType(1)) ||
                members.userMap(msg.sender, Members.UserType(2)),
                                            "MH:_preValidatePurchase - User is not validator or enterprise.");
        require(coin == Coin.USDC || coin == Coin.AUDT, "MH:_preValidatePurchase - Invalid coin");

        //TOD: deal with two coins
        if (members.userMap(msg.sender, Members.UserType(1))) 
            require(amount + returnDepositAmount(msg.sender)  >= members.minContribution(), "MH:stake - You are below minimum contribution.");

           
        
    }

    /**
     * @dev Function to redeem contribution.
     * @param amount number of tokens being redeemed
     */
    function redeem(uint256 amount) external nonReentrant {
        if (members.userMap(msg.sender, Members.UserType(0))) {
            require(outstandingValidations[msg.sender] == 0, "MH:redeem - still processing outstanding validations");
        }

        // deposits[msg.sender] -= amount;
        // totalStaked -= amount;
        // IERC20Upgradeable(auditToken).safeTransfer(msg.sender, amount);
        // emit LogDepositRedeemed(msg.sender, amount);
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
            newUser[i].depositAUDT = depositsAUDT[user[i]];
            newUser[i].depositUSDC = depositsUSDC[user[i]];
        }

        return newUser;
    }


    function verifyInit(bool docSize, uint256 price, address caller) public view returns (bool) {

        require(docSize, "VNC:initVal - Doc hash value can't be 0");
        require(checkIfRequestorHasFunds(caller, price),"VNC:initVal - Deposit additional funds.");
        require(members.userMap(caller, Members.UserType(2)) || 
                members.userMap(caller, Members.UserType(0)),"VNC:initVal - Register as data subscriber");
        return true;

    }

}
