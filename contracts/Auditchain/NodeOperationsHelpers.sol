// SPDX-License-Identifier: MIT
pragma solidity =0.8.0;
import "@openzeppelin/contracts-upgradeable/access/AccessControlEnumerableUpgradeable.sol";


/**
 * @title NodeOperations
 * Additional function for Members
 */
contract NodeOperationsHelpers is AccessControlEnumerableUpgradeable {

    uint256 public stakeRatio;
    uint256 public stakeRatioDelegating;
    uint256 public stakingRatioReferral;
    uint256 public POWFee;


    bytes32 public constant SETTER_ROLE =  keccak256("SETTER_ROLE");
    event LogGovernanceUpdate(uint256 params, string indexed action);


    function initialize() external {
       
        stakeRatio = 1000;
        stakeRatioDelegating = 1100;
        stakingRatioReferral = 9100;
        POWFee = 1e18;
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

        /// @dev check if caller is a setter     
    modifier isSetter {
        require(hasRole(SETTER_ROLE, msg.sender), "NodeOperations:isSetter - Caller is not a setter");

        _;
    }

    function updateStakeRatioDelegating(uint256 _newRatio) external isSetter() {

        require(_newRatio != 0, "NodeOperations:updateStakeRatioDelegating - New value for the stake delegating ratio can't be 0");
        stakeRatioDelegating = _newRatio;

        emit LogGovernanceUpdate(_newRatio, "updateStakeRatioDelegating");
    }

    function updateStakingRatioReferral(uint256 _newRatio) external isSetter() {

        require(_newRatio != 0, "NodeOperations:updateStakingRatioReferral - New value for the stake ratio can't be 0");
        stakingRatioReferral = _newRatio;
        emit LogGovernanceUpdate(_newRatio, "updateStakingRatioReferral");
    }

    function updateStakeRatio(uint256 _newRatio) external isSetter() {

        require(_newRatio != 0, "NodeOperations:updateStakeRatio - New value for the stake ratio can't be 0");
        stakeRatio = _newRatio;
        emit LogGovernanceUpdate(_newRatio, "UpdateStakeRatio");
    }

    function updatePOWFee(uint256 _newFee) external isSetter() {

        require(_newFee != 0, "NodeOperations:updatePOWFee - New value for the POWFee can't be 0");
        POWFee = _newFee;
        emit LogGovernanceUpdate(_newFee, "updatePOWFee");
    }

}