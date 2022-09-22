// SPDX-License-Identifier: MIT
pragma solidity =0.8.0;

import "./Validations.sol";


/**
 * @title Validations
 * Data subscriber can request financial document validation,
 * which will be validated by group of node operators. 
 */
contract ValNoCohort is Validations {


       function initialize (
        address _members,
        address _memberHelpers,
        address _nodeOperations,
        address _validationHelpers,
        address _queue  ) public override {

            super.initialize(_members, _memberHelpers,_nodeOperations,_validationHelpers, _queue);
     
    }


     function registerValidation() public nonReentrant override returns(bytes32 valHash){

        bool done;
        uint256 prevVal = queue.head();

        if ( queue.returnQueueSize() > 0 && reg[msg.sender] == 0 ){

            (,,,valHash,,,,,) =  queue.get(prevVal);

            while(!done){
                Validation storage val = validations[valHash];

                if (val.regNum > members.maxValidators()  ){

                    (,prevVal ,,,,,,,) = queue.get(prevVal); 
                    (,,,valHash,,,,,) =  queue.get(prevVal);
                } else if (val.regNum <= members.maxValidators() && valHash != 0x0 && regP[msg.sender] != prevVal) {

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
            
            (,,,valHash,,,,,) =  queue.get(reg[msg.sender]);
            if( votes[msg.sender][valHash])
                valHash == 0x0;

            if (valHash == 0x0)
                reg[msg.sender]= 0;
        } 
        emit ValRegistered(msg.sender, valHash);
    }




}