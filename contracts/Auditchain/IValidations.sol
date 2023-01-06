// SPDX-License-Identifier: MIT
pragma solidity =0.8.0;    
    
interface IValidations {

    enum ValidationStatus {Undefined, Yes, No}        


    function returnValidationUrl(bytes32 validationHash, address user) external  view returns(string memory url);
    function returnWinnerPoints(bytes32 validationHash, address user) external  view returns(uint256 plus, uint256 minus);
    function selectWinner(bytes32 validationHash, address[] memory winners) external view returns (address);
    function validations(bytes32 valHash) external view returns( uint8 auditTypes,
                                                                address requestor,
                                                                uint256 validationTime,
                                                                uint256 executionTime,
                                                                string memory url,
                                                                uint256 consensus,
                                                                uint256 validationsCompleted,
                                                                uint64 winnerConfirmations,
                                                                address winner,
                                                                uint256 price,
                                                                uint64 regNum);



     function collectValidationResults(bytes32 validationHash)
        external
        view
        returns (
            address[] memory,
            uint256[] memory,
            uint8[] memory,
            uint256[] memory,
            string[] memory,
            bytes32[] memory
        );

    function returnValidationRecord(bytes32 validationHash) external  view
        returns(bool isCohort,
                address requestor,
                uint256 validationTime,
                uint256 executionTime,
                string memory url,
                uint256 consensus,
                uint256 validationsCompleted,
                uint64 winnerConfirmations,
                bool paymentSent,
                address winner);

    function cohort() external view returns (bool);
    function returnRegVal(bytes32 valHash) external view returns (address[] memory);


}
