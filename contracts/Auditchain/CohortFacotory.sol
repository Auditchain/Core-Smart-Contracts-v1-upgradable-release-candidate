// SPDX-License-Identifier: MIT
pragma solidity =0.8.0;
import "./Members.sol";
import "./MemberHelpers.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlEnumerableUpgradeable.sol";


/**
 * @title CohortFactory
 * Allows on creation of invitations by Enterprise and acceptance of Validators of those 
 * invitations. Finally Enterprise can create cohort consisting of invited Validators
 * and Enterprise. 
 */

contract CohortFactory is  AccessControlEnumerableUpgradeable {

 // Audit types to be used. Two types added for future expansion 
    enum AuditTypes {
        Unknown, Financial, System, NFT, Type4, Type5
    }

    uint256[] public minValidatorPerCohort;
    bytes32 public constant SETTER_ROLE =  keccak256("SETTER_ROLE");


    // Invitation structure to hold info about its status
    struct Invitation {
        // address enterprise;
        address validator;
        uint256 invitationDate;      
        uint256 acceptanceDate;
        AuditTypes audits;
        // address cohort;
        bool deleted;
    }

    // struct Cohorts {
    //     AuditTypes audits;
    // }

    mapping(address => uint256[]) public cohortList;
    mapping(address => mapping(uint256=>bool)) public cohortMap;
    mapping (address => mapping(address=> AuditTypes[])) public validatorCohortList;  // list of validators
    

    Members public members;                                            // pointer to Members contract1 
    MemberHelpers public memberHelpers;                                       
    mapping (address =>  Invitation[]) public invitations;      // invitations list


    event ValidatorInvited(address  inviting, address indexed invitee, AuditTypes indexed audits, uint256 invitationNumber);
    event InvitationAccepted(address indexed validator, uint256 invitationNumber);
    event CohortCreated(address indexed enterprise, uint256 audits);
    event UpdateMinValidatorsPerCohort(uint256 minValidatorPerCohort, AuditTypes audits);
    event ValidatorCleared(address validator, AuditTypes audit, address enterprise);


     /// @dev check if caller is a setter     
    modifier isSetter {
        require(hasRole(SETTER_ROLE, msg.sender), "Members:isSetter - Caller is not a setter");

        _;
    }   


    function initialize(address _members, address _memberHelpers) external  {
        members = Members(_members);
        memberHelpers = MemberHelpers(_memberHelpers);
        minValidatorPerCohort = [3,3,3,3,3,3];
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender); // 
    }


   /**
    * @dev to be called by Governance contract to update new value for min validators per cohort
    * @param _minValidatorPerCohort new value 
    * @param audits type of validations
    */
    function updateMinValidatorsPerCohort(uint256 _minValidatorPerCohort, uint8 audits) external  isSetter()  {

        require(_minValidatorPerCohort != 0, "CF:updateMinValidatorsPerCohort - Min validator per cohort can't be 0");
        require(audits <= 5 , "Cohort Factory:updateMinValidatorsPerCohort - Audit type is out of range");
        minValidatorPerCohort[audits] = _minValidatorPerCohort;
        emit UpdateMinValidatorsPerCohort(_minValidatorPerCohort, AuditTypes(audits));
    }

    /**
    * @dev Used by Enterprise to invite validator
    * @param validator address of the validator to invite
    * @param audit type of the audit
    */
    function inviteValidator(address validator, uint256 audit) public {

        bool isValidator = members.userMap(validator, Members.UserType(1));
        bool isEnterprise = members.userMap(msg.sender, Members.UserType(0));
        (bool invited, ) = isValidatorInvited(msg.sender, validator, audit);
        require( !invited , "CF:inviteValidator - Validator has been already invited" );
        require( isEnterprise, "CF:inviteValidator - Only Enterprise user can invite.");
        require( isValidator, "CF:inviteValidator - Only Approved Validators can be invited.");
        require( memberHelpers.deposits(validator) > 0,"CF:inviteValidator - Validator has not staked.");
        
        Invitation memory newInvitation;
        newInvitation.validator = validator;
        newInvitation.invitationDate = block.timestamp;     
        newInvitation.audits = AuditTypes(audit);   
        invitations[msg.sender].push(newInvitation);
       
         emit ValidatorInvited(msg.sender, validator, AuditTypes(audit), invitations[msg.sender].length - 1);
    }
    

    /**
    * @dev Used by Enterprise to invite multiple validators in one call 
    * @param validator address of the validator to invite
    * @param audit type of the audit
    */
    function inviteValidatorMultiple(address[] memory validator, AuditTypes audit) external{

        uint256 length = validator.length;
        require(length <= 256, "CF-inviteValidatorMultiple: List too long");
        for (uint256 i = 0; i < length; i++) {
            inviteValidator(validator[i], uint256(audit));
        }
    }

    /**
    * @dev Used by Validator to accept Enterprise invitation
    * @param enterprise address of the Enterprise who created invitation
    * @param invitationNumber invitation number
    */
    function acceptInvitation(address enterprise, uint256 invitationNumber) public {

        require( invitations[enterprise].length > invitationNumber, "CF:acceptInvitation - Invitation doesn't exist");
        require( invitations[enterprise][invitationNumber].acceptanceDate == 0, "CF:acceptInvitation- Accepted already .");
        require( invitations[enterprise][invitationNumber].validator == msg.sender, "CF:acceptInvitation - You were not invited.");
        invitations[enterprise][invitationNumber].acceptanceDate = block.timestamp;
          
        emit InvitationAccepted(msg.sender, invitationNumber);
    }


    function clearInvitationRemoveValidator(address validator, AuditTypes audit) external  returns (bool) {

        for (uint256 i = 0; i < invitations[msg.sender].length; i++){
            if (invitations[msg.sender][i].audits == audit && invitations[msg.sender][i].validator ==  validator){
                invitations[msg.sender][i].deleted = true;                
                emit ValidatorCleared(validator, audit, msg.sender);
                return true;
            }
        }


        revert("This invitation doesn't exist");
    }

    /**
    * @dev Used by Validator to accept multiple Enterprise invitation
    * @param enterprise address of the Enterprise who created invitation
    * @param invitationNumber invitation number
    */
    function acceptInvitationMultiple(address[] memory enterprise, uint256[] memory invitationNumber) external{

        uint256 length = enterprise.length;
        for (uint256 i = 0; i < length; i++) {
            acceptInvitation(enterprise[i], invitationNumber[i]);
        }
    }

    /**
    * @dev To return invitation count
    * @param enterprise address of the Enterprise who created invitation
    * @param audit type
    * @return count of invitations
    */
    function returnInvitationCount(address enterprise, AuditTypes audit) public view returns(uint256) {

        uint256 count;

        for (uint i=0; i < invitations[enterprise].length; ++i ){
            if (invitations[enterprise][i].audits == audit && 
                invitations[enterprise][i].acceptanceDate != 0 &&
                !invitations[enterprise][i].deleted)
                count ++;
        }
        return count;
    }

    /**
    * @dev Used to determine if validator has been invited and/or if validation has been accepted
    * @param enterprise inviting party
    * @param validator address of the validator
    * @param audits types
    * @return true if invited
    * @return true if accepted invitation
    */
    function isValidatorInvited(address enterprise, address validator, uint256 audits) public view returns (bool, bool) {

        for (uint i=0; i < invitations[enterprise].length; ++i ){
            if (invitations[enterprise][i].audits == AuditTypes(audits) && 
                invitations[enterprise][i].validator == validator &&
                !invitations[enterprise][i].deleted){
                if (invitations[enterprise][i].acceptanceDate > 0)
                    return (true, true);
                return (true, false);
            }
        }
        return (false, false);
    }

     /**
    * @dev Used to determine if validator has been invited and/or if validation has been accepted
    * @param enterprise inviting party
    * @param validator address of the validator
    * @param audits types
    * @param invitNumber invitation number
    * @return true if invited
    * @return true if accepted invitation
    */
    function isValidatorInvitedNumber(address enterprise, address validator, uint256 audits, uint256 invitNumber) external view returns (bool, bool) {

        require(enterprise != address(0), "CF:isValidatorInvitedNumber - enterprise can't be 0");
        require(validator != address(0), "CF:isValidatorInvitedNumber - validtor can't be 0");
        require(audits <= 5, "CF:isValidatorInvitedNumber - audit not in range");

        if (invitations[enterprise][invitNumber].audits == AuditTypes(audits) && 
            invitations[enterprise][invitNumber].validator == validator &&
            !invitations[enterprise][invitNumber].deleted){
            if (invitations[enterprise][invitNumber].acceptanceDate > 0)
                return (true, true);
            return (true, false);
        }
        return (false, false);
    }

    /**
    * @dev Returns true for audit types for which enterprise has created cohorts.
    * @param enterprise inviting party
    * @return list of boolean variables with value true for audit types enterprise has initiated cohort, 
    */
    function returnCohorts(address enterprise) external view returns (bool[] memory){

        uint8 auditCount = 6;
        bool[] memory audits = new bool[](auditCount);

        for (uint8 i; i < auditCount; i++){
            if (cohortMap[enterprise][i])
               audits[i] = true;
        }
        return (audits);
    }


    /**
    * @dev Returns list of validators 
    * @param enterprise to get list for
    * @param audit type of audits
    * @return list of boolean variables with value true for audit types enterprise has initiated cohort, 
    */
    function returnValidatorList(address enterprise, uint8 audit)public view returns(address[] memory){

        require(enterprise != address(0), "CF:returnValidatorList - address can't be 0");
        require(audit <= 5, "CF:returnValidatorList - audit not in range");

        address[] memory validatorsList = new address[](returnInvitationCount(enterprise, AuditTypes(audit)));
        uint k;
        for (uint i=0; i < invitations[enterprise].length; ++i ){
            if (uint(invitations[enterprise][i].audits) == audit && invitations[enterprise][i].acceptanceDate > 0){
                validatorsList[k] = invitations[enterprise][i].validator;
                k++;
            }
        }
        return validatorsList;
    }

     /**
    * @dev create a list of validators to be initialized in new cohort   
    * @param validators any array of address of the validators
    * @param enterprise who created cohort
    * @param audit  type of audit
    */
    function createValidatorCohortList(address[] memory validators, address enterprise, AuditTypes audit) internal {

        for (uint256 i=0; i< validators.length; i++){
            validatorCohortList[validators[i]][enterprise].push(audit);
        }
    }


   /**
    * @dev Used to determine cohorts count for given validator
    * @param validator address of the validator
    * @return number of cohorts
    */ 
    function returnValidatorCohortsCount(address validator, address enterprise) external view returns (uint256){

        return validatorCohortList[validator][enterprise].length;
    }

    /**
    * @dev Initiate creation of a new cohort 
    * @param audit type
    */
    function createCohort(uint8 audit) external {
        require(!cohortMap[msg.sender][uint8(audit)] , "CF:createCohort - This cohort already exists.");
        address[] memory validators =  returnValidatorList(msg.sender, audit);
        require(validators.length >= minValidatorPerCohort[uint8(audit)], "CF:createCohort - Validator num below minimum.");
        cohortMap[msg.sender][uint8(audit)] = true;   
        createValidatorCohortList(validators, msg.sender, AuditTypes(audit));
        emit CohortCreated(msg.sender, audit);
        
    }

    
}
