// SPDX-License-Identifier: MIT
pragma solidity =0.8.0;    
    
interface ICohortFactory {

    function returnValidatorList(address enterprise, uint8 audit)external view returns(address[] memory);
    function returnValidatorCohortsList(address validator, address enterprise) external view returns (uint256[] memory);
    function isValidatorInvited(address enterprise, address validator, uint256 audits) external view returns (bool invited, bool accepted);


}
