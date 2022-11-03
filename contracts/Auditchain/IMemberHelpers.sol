// SPDX-License-Identifier: MIT
pragma solidity =0.8.0;    
    
interface IMemberHelpers {

    function returnDepositAmount(address user) external view returns (uint256);
    function increaseDeposit(address user, uint256 amount)  external returns (bool);
    function decreaseDeposit(address user, uint256 amount)  external returns (bool);
    function increaseValNo(address user)  external returns (bool);
    function decreaseValNo(address user)  external returns (bool);
    function outstandingValidations(address enterprise) external view returns (uint256);
    function checkIfRequestorHasFunds(address user, uint256 amount) external view returns (bool);


}
