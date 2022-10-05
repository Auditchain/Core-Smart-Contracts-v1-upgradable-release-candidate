// SPDX-License-Identifier: MIT
pragma solidity =0.8.0;    
    
interface IMembers {

    enum UserType {Enterprise, Validator, DataSubscriber}  
    function userMap(address user, UserType userType) external returns (bool);
    function maxValidators() external returns (uint256);
    function minContribution() external returns (uint256);
    function platformShare() external returns (uint256);
    function platformAddress() external returns (address);

}
