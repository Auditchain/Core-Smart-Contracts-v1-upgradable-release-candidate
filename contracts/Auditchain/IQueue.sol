// SPDX-License-Identifier: MIT
pragma solidity =0.8.0;    
    
interface IQueue {

    function addToQueue(uint256 price, bytes32 validationHash, bytes32 documentHash, string memory url, address user,  uint256 initTime) external returns(bool);
    function removeFromQueue(bytes32 valHash) external returns (bool);
    function setValidatedFlag(bytes32 valHash)  external returns(bool);
    function replaceValidation(uint256 newPrice, bytes32 valHash) external returns(bool);

}