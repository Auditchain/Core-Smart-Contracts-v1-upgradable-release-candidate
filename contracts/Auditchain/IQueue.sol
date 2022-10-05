// SPDX-License-Identifier: MIT
pragma solidity =0.8.0;    
    
interface IQueue {

    function addToQueue(uint256 price, bytes32 validationHash, bytes32 documentHash, string memory url, address user,  uint256 initTime, uint8 auditType) external returns(bool);
    function removeFromQueue(bytes32 valHash) external returns (bool);
    function setValidatedFlag(bytes32 valHash)  external returns(bool);
    function replaceValidation(uint256 newPrice, bytes32 valHash) external returns(bool);
    function returnQueueSize() external view returns(uint256);
    function get(uint256 _id) external view returns
    (uint256 id, uint256 next, uint256 price, bytes32 validationHash, bytes32 documentHash, string memory url, address user, uint256 initTime, bool executed);
    function head() external view returns (uint256);
}