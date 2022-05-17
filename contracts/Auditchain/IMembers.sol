// SPDX-License-Identifier: MIT
pragma solidity =0.8.0;    
    
interface IMembers {

    enum UserType {Enterprise, Validator, DataSubscriber}  
    function userMap(address user, UserType userType) external returns (bool);
    function requiredQuorum() external returns (uint256);
    function enterpriseMatch() external returns (uint256);
    function amountTokensPerValidation() external returns (uint256);
    // function UserType(uint256 type) external returns 

}
