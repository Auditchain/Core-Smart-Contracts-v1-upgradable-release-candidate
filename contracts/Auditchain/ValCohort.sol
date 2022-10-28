// SPDX-License-Identifier: MIT
pragma solidity =0.8.0;

import "./Validations.sol";

/**
 * @title Validations
 * Data subscriber can request financial document validation,
 * which will be validated by group of node operators. 
 */
contract ValCohort is Validations {

    function initialize (
        address _members,
        address _memberHelpers,
        address _nodeOperations,
        address _validationHelpers,
        address _queue,
        address _cohortFact  ) public override {

        super.initialize(_members, _memberHelpers,_nodeOperations,_validationHelpers, _queue, _cohortFact);
    
    }

     function registerValidation() public nonReentrant override{

        bool done;
        bytes32 valHash;
        address user;
        uint8 auditType;
        uint256 prevVal = queue.head();

        if ( queue.returnQueueSize() > 0 && reg[msg.sender] == 0 ){


            (,,,valHash,,,user,,,auditType) =  queue.get(prevVal);
            while(!done){
                Validation storage val = validations[valHash];

               (,bool isInvited) = cohortFactory.isValidatorInvited(user, msg.sender, auditType);

                if ((!isInvited || regP[msg.sender] == prevVal) && prevVal != 0 ){
                    (,prevVal ,,,,,,,,) = queue.get(prevVal); 
                    (,,,valHash,,,user,,,auditType) =  queue.get(prevVal);
                } else if (valHash != 0x0 && regP[msg.sender] != prevVal) {

                    val.regNum ++;
                    reg[msg.sender] = prevVal;
                    regP[msg.sender] = prevVal;
                    done = true;
                } else{
                    valHash = 0x0;
                    done = true;
                }
            } 

        }else if (reg[msg.sender] > 0){
            
            (,,,valHash,,,,,,) =  queue.get(reg[msg.sender]);
            if( votes[msg.sender][valHash])
                valHash == 0x0;

            if (valHash == 0x0)
                reg[msg.sender]= 0;
        } 
        emit ValRegistered(msg.sender, valHash);
    }

 

  function executeValidation(bytes32 validationHash, bytes32 documentHash) public override {

        Validation storage validation = validations[validationHash];

        address[] memory vList = cohortFactory.returnValidatorList(validation.requestor, uint8(validation.auditTypes));

        if (validation.executionTime == 0 && validation.validationsCompleted >= vList.length- 1 )
            super.executeValidation(validationHash, documentHash);
    }


    function voteWinner(address[] memory _winners, bool[] memory _vote, bytes32 _validationHash ) public override nonReentrant{

        super.voteWinner(_winners, _vote, _validationHash);

        Validation storage validation = validations[_validationHash];
        address[] memory vList = cohortFactory.returnValidatorList(validation.requestor, uint8(validation.auditTypes));

         if (validation.validationsCompleted >= vList.length- 1 && validation.winner == address(0)) {
            address winner = validationHelpers.selectWinner(_validationHash, _winners);
            validation.winner = winner;
            processPayments(_validationHash, winner);
            assert(queue.removeFromQueue(_validationHash));
        }
    }

}