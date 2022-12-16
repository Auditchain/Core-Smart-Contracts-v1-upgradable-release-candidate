// SPDX-License-Identifier: MIT
pragma solidity =0.8.0;    
    
interface IValidationHelpers {

    function selectWinner(bytes32 validationHash, address[] memory winners) external view returns (address);
    function returnConsensus(bytes32 validationHash, address validationContract) external view returns(uint256);
    function verifyValidate(bool valTime, bool choice, bool userType, address caller) external view returns (bool);
    // function verifyInit(bool docSize, uint256 price, bool userType, address caller) external view returns (bool);

}