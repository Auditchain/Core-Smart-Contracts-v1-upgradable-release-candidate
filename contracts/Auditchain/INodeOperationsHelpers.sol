// SPDX-License-Identifier: MIT
pragma solidity =0.8.0;    
    
interface INodeOperationsHelpers {

    function stakeRatioDelegating() external view returns (uint256) ;
    function POWFee() external view returns (uint256);
    function stakeRatio() external view returns (uint256);
    function stakingRatioReferral() external view returns (uint256);

  

}