// SPDX-License-Identifier: MIT
pragma solidity =0.8.0;
import "@openzeppelin/contracts/access/AccessControl.sol";
import "./../IAuditToken.sol";
import "./MemberHelpers.sol";



/**
 * @title NodeOperations
 * Functions for Node Operators
 */
contract NodeOperations is AccessControl {


    MemberHelpers public memberHelpers;
    address public auditToken;          
    Members public members;

    address[] public nodeOperators;
    address[] public CPAs;

    uint256 public stakeRatio;
    uint256 public stakeRatioDelegating;
    uint256 public stakingRatioReferral;


    struct nodeOperator {

        bool isNodeOperator;
        address[] delegations;
        mapping(address => bool) isDelegating;
        uint256 stakeAmount;
        uint256 delegateAmount;
        uint256 referralAmount;
        uint256 POWAmount;
        address delegatorLink;
        bool noDelegations;
        bool isCPA;
    }


    mapping(address => nodeOperator) public nodeOpStruct;

    bytes32 public constant CONTROLLER_ROLE = keccak256("CONTROLLER_ROLE");
    bytes32 public constant SETTER_ROLE =  keccak256("SETTER_ROLE");

    event LogNodeOperatorToggled(address indexed user, string action);
    event LogCPAToggled(address indexed user, string action);
    event LogNoDelegateToggled(address indexed user, string action);
    event LogRemoveDelegation(address indexed delegating, address indexed delegatee);
    event LogDelegation(address indexed delegating, address indexed newDelegatee);
    event LogDelegatedStakeRewardsIncreased(address indexed delegating, uint256 amount);
    event LogReferralStakeRewardsIncreased(address indexed delegating, uint256 amount);
    event LogStakingRewardsTransferredOut(address indexed user, uint256 amount);
    event LogStakingRewardsClaimed(address indexed user, uint256 amount);
    event LogStakeRewardsIncreased(address indexed validator, uint256 amount);
    event LogGovernanceUpdate(uint256 params, string indexed action);
    event IncreasePOW(uint256 amount, address validator);

    function initialize(address _memberHelpers, address _auditToken, address _members) external  { 
        require(_memberHelpers != address(0), "NO:constructor - MemberHelpers address can't be 0");
        require( _auditToken != address(0), "NO:setCohort - Cohort address can't be 0");
        memberHelpers = MemberHelpers(_memberHelpers);
        auditToken = _auditToken;
        members = Members(_members);    
        stakeRatio = 100000;
        stakeRatioDelegating = 110000;
        stakingRatioReferral = 910000;
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

     /// @dev check if caller is a controller
    modifier isController(string memory source) {
        string memory msgError = string(abi.encodePacked("NO(isController):", source, "- Caller is not a controller"));
        require(hasRole(CONTROLLER_ROLE, msg.sender), msgError);

        _;
    }

    /// @dev check if caller is a setter     
    modifier isSetter {
        require(hasRole(SETTER_ROLE, msg.sender), "NO - isSetter - Caller is not a setter");

        _;
    }


    /// @dev check if user is validator
    modifier isValidator(string memory source) {

        string memory msgError = string(abi.encodePacked("NO(isValidator):", source, "- You are not a validator"));
        require( members.userMap(msg.sender, Members.UserType(1)), msgError);

        _;
    }


    function updateStakeRatioDelegating(uint256 _newRatio) external isSetter() {

        require(_newRatio != 0, "NO:updateStakeRatioDelegating - New ratio can't be 0");
        stakeRatioDelegating = _newRatio;

        emit LogGovernanceUpdate(_newRatio, "updateStakeRatioDelegating");
    }


    function updateStakingRatioReferral(uint256 _newRatio) external isSetter() {

        require(_newRatio != 0, "NO:updateStakingRatioReferral - New ratio can't be 0");
        stakingRatioReferral = _newRatio;
        emit LogGovernanceUpdate(_newRatio, "updateStakingRatioReferral");
    }


    function updateStakeRatio(uint256 _newRatio) external isSetter() {

        require(_newRatio != 0, "NO:updateStakeRatio - New ratio can't be 0");
        stakeRatio = _newRatio;
        emit LogGovernanceUpdate(_newRatio, "UpdateStakeRatio");
    }


    function returnDelegatorLink(address operator) external view returns (address){

        return nodeOpStruct[operator].delegatorLink;
    }

    function isNodeOperator(address operator) external view returns (bool) {

        return nodeOpStruct[operator].isNodeOperator;

    }


    /*** 
    * @dev return members of the staking pool
    * @param poolOperator - owner of the pool
    * @param name name of the user
    * @return array of users with their deposit values
    */

    function returnPoolList(address poolOperator)external view returns (address[] memory, uint256[] memory) {

        address[] memory poolUsers = new address[](nodeOpStruct[poolOperator].delegations.length  );
        uint256[] memory poolUsersStakes = new uint256[](nodeOpStruct[poolOperator].delegations.length );

        for (uint256 i = 0; i< nodeOpStruct[poolOperator].delegations.length ;i++) {
            poolUsers[i]= nodeOpStruct[poolOperator].delegations[i];
            poolUsersStakes[i] = memberHelpers.returnDepositAmount(poolUsers[i]);

        }
        return (poolUsers, poolUsersStakes);
    }


    /// remove all delegations for specific pool operator
    function removeAllDelegations() public {

        for (uint256 i = nodeOpStruct[msg.sender].delegations.length  ; i > 0; i--) {
            address delegating = nodeOpStruct[msg.sender].delegations[i-1];
            nodeOpStruct[msg.sender].delegations.pop();   
            nodeOpStruct[msg.sender].isDelegating[delegating] = false;
            nodeOpStruct[delegating].delegatorLink = address(0x0);
        }
    }

    
    /// @dev change Node operator status from on to off or the vice versa 
    function toggleNodeOperator( ) external isValidator("toggleNodeOperator") {


        if (nodeOpStruct[msg.sender].isNodeOperator){
            nodeOpStruct[msg.sender].isNodeOperator = false;
            removeNodeOperator();
            removeAllDelegations();
            emit LogNodeOperatorToggled(msg.sender, "OFF");
        }
        else{
            require(memberHelpers.returnDepositAmount(msg.sender) >= members.minContribution(), 
                                                                    "NO:toggleNodeOperator - Minimum stake amount not met.");
            nodeOpStruct[msg.sender].isNodeOperator = true;
            nodeOperators.push(msg.sender);
            emit LogNodeOperatorToggled(msg.sender, "ON");
        }
    }


    /// @dev change CPA status from on to off or vice versa
    function toggleCPA( ) external isValidator("toggleCPA") {

        if (nodeOpStruct[msg.sender].isCPA){
            nodeOpStruct[msg.sender].isCPA = false;
            removeCPA();
            emit LogCPAToggled(msg.sender,"OFF");
        }
        else{
            nodeOpStruct[msg.sender].isCPA = true;
            CPAs.push(msg.sender);
            emit LogCPAToggled(msg.sender,"ON");
        }
    }


    /// @dev change no delegate flag from on to off or vice versa
    function toggleNoDelegate( ) isValidator("toggleNoDelegate") external {

        if (nodeOpStruct[msg.sender].noDelegations){
            nodeOpStruct[msg.sender].noDelegations = false;
            emit LogNoDelegateToggled(msg.sender, "OFF");
        }
        else{
            removeAllDelegations();
            nodeOpStruct[msg.sender].noDelegations = true;
            emit LogNoDelegateToggled(msg.sender, "ON");
        }
    }


    /// @dev remove CPA status
    function removeCPA() internal {

        for (uint256 i= 0; i < CPAs.length; i++) {

            if (CPAs[i] == msg.sender){

                CPAs[i] = CPAs[CPAs.length - 1];
                CPAs.pop();
                i = CPAs.length;
            }
        }
    }


    /// @dev remove Node operator status 
    function removeNodeOperator() internal {

        for (uint256 i= 0; i < nodeOperators.length; i++) {

            if (nodeOperators[i] == msg.sender){

                nodeOperators[i] = nodeOperators[nodeOperators.length - 1];
                nodeOperators.pop();
                i = nodeOperators.length;
            }
        }
    }


    /// return all node operators
    function returnNodeOperators() external view returns (address[] memory) {

        return nodeOperators;
    }


    function returnNodeOperatorsCount() external view returns(uint256){

        return nodeOperators.length;
    }


    /// return all CPAs
    function returnCPAs() external view returns (address[] memory) {

        return CPAs;
    }
    
    
    /// remove delegation for pool member 
    function removeDelegation() public isValidator("removeDelegation") {

        address oldDelegatee = nodeOpStruct[msg.sender].delegatorLink;

        require(oldDelegatee != address(0x0), "NO:removeDelegation Not delegating yet.");


        for (uint256 i = 0; i < nodeOpStruct[oldDelegatee].delegations.length; i++) {
            if (nodeOpStruct[oldDelegatee].delegations[i] == msg.sender) {
                nodeOpStruct[oldDelegatee].delegations[i] = nodeOpStruct[oldDelegatee].delegations[nodeOpStruct[oldDelegatee].delegations.length - 1];
                nodeOpStruct[oldDelegatee].delegations.pop();
                nodeOpStruct[oldDelegatee].isDelegating[msg.sender] = false;
                nodeOpStruct[msg.sender].delegatorLink = address(0x0);
                i= nodeOpStruct[oldDelegatee].delegations.length;
            }
        }

        emit LogRemoveDelegation(msg.sender, oldDelegatee);
    }


    /*** 
    * @dev delegate stake to the pool 
    * @param delegatee - owner of the pool 
    */

     function delegate(address delegatee) external isValidator("Delegate") {

        require(!nodeOpStruct[msg.sender].isNodeOperator, "NO:delegagte - Can't delegate while a node operator. ");
        require(!nodeOpStruct[delegatee].isDelegating[msg.sender], "NO:delegate - You are already delegating to this user");

        if (nodeOpStruct[msg.sender].delegatorLink != address(0x0)) 
            removeDelegation();

        nodeOpStruct[delegatee].delegations.push(msg.sender);
        nodeOpStruct[msg.sender].delegatorLink = delegatee;
        nodeOpStruct[delegatee].isDelegating[msg.sender] = true;

        emit LogDelegation(msg.sender, delegatee);
    }


    /*** 
    * @dev called by the Validations contract to increase POW amount of winning validator
    * @param validator - winner of the validation task
    * @param amount to aword to validator
    */
    function increasePOWRewards(address validator, uint256 amount) external isController("increasePOWRewards") returns(bool) {
            nodeOpStruct[validator].POWAmount += amount;
            emit IncreasePOW(amount, validator);
            return true;
    }


    /*** 
    * @dev called by the Validations contract to increase delegated stake rewards and referral rewards
    * @param validator - validator for whom values are increased
    */
    function increaseDSRewards(address validator) external isController("increaseDSRewards") returns(bool) {
        uint256 referringReward;

        for (uint256 i = 0; i < nodeOpStruct[validator].delegations.length ; i++) {
            address delegating = nodeOpStruct[validator].delegations[i];
            uint256 amount = memberHelpers.returnDepositAmount(delegating) / stakeRatioDelegating;
            nodeOpStruct[delegating].delegateAmount = nodeOpStruct[delegating].delegateAmount + amount;
            referringReward += memberHelpers.returnDepositAmount(delegating) / stakingRatioReferral;
            emit LogDelegatedStakeRewardsIncreased(delegating, amount);

        }
        if (referringReward > 0) {
            nodeOpStruct[validator].referralAmount += referringReward;
            emit LogReferralStakeRewardsIncreased(validator, referringReward);
        }
        return true;
    }
    

    /*** 
    * @dev called by the Validations contract to increase pool operator stake reward amount
    * @param validator - validator for whom values are increased
    */
    function increaseStakeRewards(address validator) external isController("increaseStakeRewards") returns(bool) {
        uint256 amount = memberHelpers.returnDepositAmount(validator)/ stakeRatio;
        nodeOpStruct[validator].stakeAmount += amount;
        emit LogStakeRewardsIncreased(validator, amount);
        return true;
    }


    /*** 
    * @dev called by the Validator to claim their reward
    * @param deliver - true if amount should be delivered into the wallet or stake deposit
    */
    function claimStakeRewards(bool deliver) external {
        uint256 stakeRewards = nodeOpStruct[msg.sender].stakeAmount;
        uint256 delegateRewards = nodeOpStruct[msg.sender].delegateAmount;
        uint256 powRewards = nodeOpStruct[msg.sender].POWAmount;
        uint256 refRewards = nodeOpStruct[msg.sender].referralAmount;


        uint256 payment = stakeRewards + powRewards + refRewards + delegateRewards;
        nodeOpStruct[msg.sender].stakeAmount= 0;
        nodeOpStruct[msg.sender].delegateAmount = 0;
        nodeOpStruct[msg.sender].POWAmount = 0;
        nodeOpStruct[msg.sender].referralAmount = 0;

        if (payment > 0)
            if (deliver) {
                emit LogStakingRewardsTransferredOut(msg.sender, payment);
                assert(IAuditToken(auditToken).mint(msg.sender, payment));
            } else {
                emit LogStakingRewardsClaimed(msg.sender, payment);
                assert(memberHelpers.increaseDeposit(msg.sender, payment));
                assert(IAuditToken(auditToken).mint(address(this), payment));
            }
    }
}