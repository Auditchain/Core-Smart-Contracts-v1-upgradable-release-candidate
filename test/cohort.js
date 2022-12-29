import {
    ensureException,
    duration
} from './helpers/utils.js';


const MEMBERS = artifacts.require('../Members');
const TOKEN = artifacts.require('../AuditToken');
const COHORTFACTORY = artifacts.require('../CohortFactory');
const MEMBER_HELPERS = artifacts.require('../MemberHelpers');
const NODE_OPERATIONS = artifacts.require('../NodeOperations');
const DEPOSIT_MODIFIERS = artifacts.require('../DepositModifiers');
const VALIDATION = artifacts.require('../ValCohort');
const VALIDATION_HELPERS = artifacts.require('../ValidationHelpers')
const QUEUE = artifacts.require("../Queue");

import expectRevert from './helpers/expectRevert';
import { assert } from 'chai';
let BN = require("big-number");
const timeMachine = require('ganache-time-traveler');





contract("Cohort validation contract", (accounts) => {

    const admin = accounts[0];
    const enterprise1 = accounts[1];
    const validator1 = accounts[2];
    const validator2 = accounts[3];
    const validator3 = accounts[4];
    const validator4 = accounts[5];
    const validator5 = accounts[6];

    const platformAccount = accounts[6];
    const dataSubscriber = accounts[7];
    const documentURL = "http://xbrlsite.azurewebsites.net/2021/reporting-scheme/proof/reference-implementation/instance.xml"


    let members;
    let token;
    let memberHelpers;
    let cohortFactory;
    let nodeOperations;
    let depositModifiers;
    let validation;
    let documentHash;

    let auditTokenMin = "5000000000000000000000";
    let initialToken = "250000000000000000000000000";
    let replacementPrice = "2000000000000000000";


    let price = "1000000000000000000";


    let validationInitTime;
    let validationHash;
    let validationHelpers;
    let queue;



    const tokenAmount1 = "9000000000000000000000000";
    const tokenAmount2 = "8500000000000000000000000";
    const tokenAmount3 = "10000000000000000000000000";
    const tokenAmount4 = "44443332220000000000000000";
    const tokenAmount5 = "14443332220000000000000000";
    const zeroTransaction = "0x0000000000000000000000000000000000000000000000000000000000000000";


    before(async () => {


        token = await TOKEN.deployed();
        members = await MEMBERS.deployed();
        memberHelpers = await MEMBER_HELPERS.deployed();
        nodeOperations = await NODE_OPERATIONS.deployed();
        queue = await QUEUE.deployed();
        validationHelpers = await VALIDATION_HELPERS.deployed();
        validation = await VALIDATION.deployed();
        cohortFactory = await COHORTFACTORY.deployed();
        depositModifiers = await DEPOSIT_MODIFIERS.deployed();


        let CONTROLLER_ROLE = web3.utils.keccak256("CONTROLLER_ROLE");
        let MINTER_ROLE = web3.utils.keccak256("MINTER_ROLE");

        await members.grantRole(CONTROLLER_ROLE, admin, { from: admin });

        await nodeOperations.grantRole(CONTROLLER_ROLE, validation.address, { from: admin });
        await token.grantRole(CONTROLLER_ROLE, nodeOperations.address, { from: admin });
        await depositModifiers.grantRole(CONTROLLER_ROLE, validation.address, { from: admin });

        await memberHelpers.grantRole(CONTROLLER_ROLE, validation.address, { from: admin });
        await memberHelpers.grantRole(CONTROLLER_ROLE, admin, { from: admin });

        await memberHelpers.grantRole(CONTROLLER_ROLE, nodeOperations.address, { from: admin });
        await memberHelpers.grantRole(CONTROLLER_ROLE, depositModifiers.address, { from: admin });

        await token.grantRole(CONTROLLER_ROLE, depositModifiers.address, { from: admin });
        await token.grantRole(CONTROLLER_ROLE, memberHelpers.address, { from: admin });
        await token.grantRole(MINTER_ROLE, admin, { from: admin });


        await token.mint(admin, initialToken, { from: admin });

        await memberHelpers.setValidation(validation.address, { from: admin });


        await members.addUser(validator2, "Validators 2", 1, { from: admin });
        await members.addUser(validator1, "Validators 1", 1, { from: admin });
        await members.addUser(validator3, "Validators 3", 1, { from: admin });
        await members.addUser(validator4, "Validators 4", 1, { from: admin });
        await members.addUser(enterprise1, "Enterprise 1", 0, { from: admin });
        await members.addUser(validator5, "Validators 5", 1, { from: admin });


        await token.transfer(validator1, auditTokenMin);
        await token.transfer(validator2, auditTokenMin);
        await token.transfer(validator3, auditTokenMin);
        await token.transfer(validator4, auditTokenMin);
        await token.transfer(enterprise1, auditTokenMin);
        await token.transfer(validator5, auditTokenMin);


        await token.approve(memberHelpers.address, auditTokenMin, { from: validator1 });
        await token.approve(memberHelpers.address, auditTokenMin, { from: validator2 });
        await token.approve(memberHelpers.address, auditTokenMin, { from: validator3 });
        await token.approve(memberHelpers.address, auditTokenMin, { from: validator4 });
        await token.approve(memberHelpers.address, auditTokenMin, { from: validator5 });
        await token.approve(memberHelpers.address, auditTokenMin, { from: enterprise1 });




        await memberHelpers.stake(auditTokenMin, { from: validator1 });
        await memberHelpers.stake(auditTokenMin, { from: validator2 });
        await memberHelpers.stake(auditTokenMin, { from: validator3 });
        await memberHelpers.stake(auditTokenMin, { from: validator4 });
        await memberHelpers.stake(auditTokenMin, { from: validator5 });
        await memberHelpers.stake(auditTokenMin, { from: enterprise1 });

        await nodeOperations.toggleNodeOperator({ from: validator1 });
        await nodeOperations.toggleNodeOperator({ from: validator2 });
        await nodeOperations.toggleNodeOperator({ from: validator3 });


        await cohortFactory.inviteValidator(validator1, 1, { from: enterprise1 });
        await cohortFactory.inviteValidator(validator2, 1, { from: enterprise1 });
        await cohortFactory.inviteValidator(validator3, 1, { from: enterprise1 });

        await cohortFactory.acceptInvitation(enterprise1, 0, { from: validator1 });
        await cohortFactory.acceptInvitation(enterprise1, 1, { from: validator2 });
        await cohortFactory.acceptInvitation(enterprise1, 2, { from: validator3 });

        await cohortFactory.createCohort(1, { from: enterprise1 });
        documentHash = web3.utils.soliditySha3(documentURL);
        await queue.grantRole(CONTROLLER_ROLE, admin, { from: admin });

    })


    describe("Deploy", async () => {

        it("Should succeed. validation deployed and initialized", async () => {

            let memberAddress = await validation.members();
            let memberHelperAddress = await validation.mH();
            assert.strictEqual(memberAddress, members.address);
            assert.strictEqual(memberHelperAddress, memberHelpers.address);

        })
    })


    describe("Initialize validation", async () => {

        it("Should succeed. Validation initialized by registered user who has sufficient funds", async () => {


            let result = await validation.initVal(documentHash, documentURL, 1, price, { from: enterprise1 });
            let event = result.logs[0];
            assert.equal(event.event, 'ValidationInitialized');

            let validationTime = event.args.initTime;
            let validationHash = web3.utils.soliditySha3(documentHash, validationTime, enterprise1);

            assert.strictEqual(event.args.validationHash, validationHash);
            assert.strictEqual(event.args.user, enterprise1);
            await queue.removeFromQueue(event.args.validationHash, { from: admin }); //clean up queue
        })

        it("Should fail. Validation initialized by not registered user.", async () => {

            try {
                let result = await validation.initVal(documentHash, documentURL, 1, price, { from: admin });
                expectRevert();
            }
            catch (error) {
                ensureException(error);
            }
        })

        it("Should fail. Validation initialized by registered user for amount higher than available funds", async () => {

            try {
                await validation.initVal(documentHash, documentURL, 1, auditTokenMin, { from: enterprise1 });
                expectRevert();
            }
            catch (error) {
                ensureException(error);
            }
        })
    })

    describe("Validate document", async () => {

        let validationInitTime;
        let valHash;
        let count = 1000;
        let documentHash;

        beforeEach(async () => {

            documentHash = web3.utils.soliditySha3(documentURL + count);
            let result = await validation.initVal(documentHash, documentURL, 1, price, { from: enterprise1 });
            let event = result.logs[0]
            assert.equal(event.event, 'ValidationInitialized');
            validationInitTime = event.args.initTime;
            validationHash = event.args.validationHash;
            count++;

        })

        afterEach(async () => {
            await queue.removeFromQueue(validationHash, { from: admin }); //clean up queue
        })

        it("Should succeed. Validation executed by proper validator and proper values are passed", async () => {

            let result = await validation.validate(documentHash, validationInitTime, enterprise1, 1, documentURL, documentHash, { from: validator1, gas: 900000 });
            let event = result.logs[0];
            assert.equal(event.event, 'ValidatorValidated');
            assert.strictEqual(event.args.decision.toString(), "1");
            assert.strictEqual(event.args.documentHash, documentHash);
        })

        it("Should fail. Validation attested by proper validator but improper document hash is sent.", async () => {


            documentHash = web3.utils.soliditySha3("2+1=4");
            try {
                await validation.validate(documentHash, validationInitTime, enterprise1, 1, documentURL, documentHash, { from: validator1, gas: 900000 });

                expectRevert();
            } catch (error) {
                ensureException(error);
            }
        })

        it("Should fail. Validation attested by proper validator but improper validation time is sent.", async () => {

            try {
                await validation.validate(documentHash, 1, enterprise1, 1, documentURL, documentHash, { from: validator1, gas: 900000 });

                expectRevert();
            } catch (error) {
                ensureException(error);
            }
        })

        it("Should fail. Validation attested by improper validator while all params are correct.", async () => {

            try {
                await validation.validate(documentHash, validationInitTime, enterprise1, 1, documentURL, documentHash, { from: admin, gas: 900000 });
                expectRevert();
            } catch (error) {
                ensureException(error);
            }

        })


    })

    describe("Check if validator has validated specific document", async () => {

        let validationInitTime;
        let valHash;
        let count = 1000;
        let documentHash;

        beforeEach(async () => {
            count++;
            documentHash = web3.utils.soliditySha3(documentURL + count);
            let result = await validation.initVal(documentHash, documentURL, 1, price, { from: enterprise1 });
            let event = result.logs[0];
            assert.equal(event.event, 'ValidationInitialized');
            validationInitTime = event.args.initTime;
            validationHash = web3.utils.soliditySha3(documentHash, validationInitTime, enterprise1);
        })

        afterEach(async () => {
            await queue.removeFromQueue(validationHash, { from: admin }); //clean up queue
        })


        it("It should succeed. The return value should be true.", async () => {

            await validation.validate(documentHash, validationInitTime, enterprise1, 1, "", documentHash, { from: validator1, gas: 900000 });
            let isValidated = await validation.isValidated(validationHash, { from: validator1 });
            assert.strictEqual(isValidated[0].toString(), "1");
        })

        it("It should succeed. The return value should be false.", async () => {
            let isValidated = await validation.isValidated(validationHash, { from: validator1 });
            assert.strictEqual(isValidated[0].toString(), "0");
        })
    })



    describe("Calculate Vote Quorum", async () => {

        let validationInitTime;
        let validationHash

        beforeEach(async () => {

            let result = await validation.initVal(documentHash, documentURL, 1, price, { from: enterprise1 });
            let event = result.logs[0];
            assert.equal(event.event, 'ValidationInitialized');
            validationInitTime = event.args.initTime;
            validationHash = web3.utils.soliditySha3(documentHash, validationInitTime, enterprise1);

        })

        afterEach(async () => {
            await queue.removeFromQueue(validationHash, { from: admin }); //clean up queue
        })

        it("Should succeed. Calculation is done against valid validation.", async () => {

            await validation.validate(documentHash, validationInitTime, enterprise1, 1, "", documentHash, { from: validator1, gas: 900000 });
            let quorum = await validationHelpers.calculateVoteQuorum(validationHash, validation.address, enterprise1, 1);

            assert.strictEqual(quorum.toString(), "33");
        })

        it("Should fail. Calculation is done against valid validation with wrong time. ", async () => {

            try {
                await validation.validate(documentHash, 1, enterprise1, 1, "", documentHash, { from: validator1, gas: 900000 });
                expectRevert();
            } catch (error) {
                ensureException(error);
            }
        })
    })

    describe("Collect Validation Results", async () => {

        let validationInitTime;
        let valHash;
        let count = 1001;
        let documentHash;

        beforeEach(async () => {
            count++;
            documentHash = web3.utils.soliditySha3(documentURL + count);
            let result = await validation.initVal(documentHash, documentURL, 1, price, { from: enterprise1 });
            let event = result.logs[0];
            assert.equal(event.event, 'ValidationInitialized');
            validationInitTime = event.args.initTime;
            validationHash = web3.utils.soliditySha3(documentHash, validationInitTime, enterprise1);
        })

        afterEach(async () => {
            await queue.removeFromQueue(validationHash, { from: admin }); //clean up queue
        })

        it("Should succeed. CollectValidationResults properly returns results", async () => {

            let val = await validation.validate(documentHash, validationInitTime, enterprise1, 2, "", documentHash, { from: validator1, gas: 900000 });
            let event = val.logs[0];
            assert.equal(event.event, 'ValidatorValidated');
            let validationTime = event.args.validationTime;

            let status = await validation.collectValidationResults(validationHash);

            assert.strictEqual(status[0][0], validator1);
            assert.strictEqual(status[1][0].toString(), auditTokenMin);
            assert.strictEqual(status[2][0].toString(), "2");
            assert.strictEqual(status[3][0].toString(), validationTime.toString());
        })

        it("Should succeed. determineConsensus properly determines consensus", async () => {

            let result = await validationHelpers.determineConsensus([1, 1, 1, 2]);
            assert.strictEqual(result.toString(), "1");
        })
    })

    describe("Change price cancel request", async () => {

        it("Should succeed. it should update price of requested validation", async () => {

            let result = await validation.initVal(documentHash, documentURL, 1, price, { from: enterprise1 });
            let event = result.logs[0];

            result = await validationHelpers.replaceCancelValidation(replacementPrice, event.args.validationHash, validation.address, queue.address, { from: enterprise1 });
            event = result.logs[0];

            assert.strictEqual(event.args.price.toString(), replacementPrice);
            await queue.removeFromQueue(event.args.validationHash, { from: admin }); //clean up queue
        })

        it("Should fail. it shouldn't update price of requested validation by different requestor", async () => {

            let result = await validation.initVal(documentHash, documentURL, 1, price, { from: enterprise1 });
            let event = result.logs[0];

            try {
                await validationHelpers.replaceCancelValidation(replacementPrice, event.args.validationHash, validation.address, queue.address, { from: dataSubscriber });

                expectRevert();
            } catch (error) {
                ensureException(error);
            }

            await queue.removeFromQueue(event.args.validationHash, { from: admin }); //clean up queue


        })


        it("Should succeed. it should remove validation from queue requested by proper requestor", async () => {

            let result = await validation.initVal(documentHash, documentURL, 1, price, { from: enterprise1 });
            let event = result.logs[0];

            result = await validationHelpers.replaceCancelValidation(0, event.args.validationHash, validation.address, queue.address, { from: enterprise1 });
            event = result.logs[0];
            assert.strictEqual(event.args.price.toString(), "0");
        })

        it("Should fail. it shouldn't remove request from the queue requested by different requestor", async () => {

            let result = await validation.initVal(documentHash, documentURL, 1, price, { from: enterprise1 });
            let event = result.logs[0];

            try {
                await validationHelpers.replaceCancelValidation(0, event.args.validationHash, validation.address, queue.address, { from: dataSubscriber });

                expectRevert();
            } catch (error) {
                ensureException(error);
            }

            await queue.removeFromQueue(event.args.validationHash, { from: admin }); //clean up queue

        })
    })


    describe("Register for validation", async () => {
        let count = 2000;
        let validationInitTime;
        let validationHash;

        beforeEach(async () => {
            count++;
            documentHash = web3.utils.soliditySha3(documentURL + count);
            let result = await validation.initVal(documentHash, documentURL, 1, price, { from: enterprise1 });
            let event = result.logs[0];
            assert.equal(event.event, 'ValidationInitialized');
            validationInitTime = event.args.initTime;
            validationHash = event.args.validationHash;

        })

        afterEach(async () => {
            await queue.removeFromQueue(validationHash, { from: admin }); //clean up queue
        })

        it("It should succeed. The return value should be non zero hash", async () => {

            let result = await validation.registerValidation({ from: validator1 });
            let event = result.logs[0];
            assert.equal(event.event, 'ValRegistered');

            assert.strictEqual(event.args.valHash, validationHash);
            assert.strictEqual(event.args.validator, validator1);
        })


        it("It should succeed. The return value should be zero hash", async () => {

            await validation.registerValidation({ from: validator1 });
            await validation.registerValidation({ from: validator2 });
            await validation.registerValidation({ from: validator3 });
            await validation.registerValidation({ from: validator4 });

            let result = await validation.registerValidation({ from: validator5 });

            let event = result.logs[0];
            assert.equal(event.event, 'ValRegistered');

            assert.strictEqual(event.args.valHash, zeroTransaction);
            assert.strictEqual(event.args.validator, validator5);

            await validation.registerValidation({ from: validator1 });
            await validation.registerValidation({ from: validator2 });
            await validation.registerValidation({ from: validator3 });
            await validation.registerValidation({ from: validator4 });
            await validation.registerValidation({ from: validator5 });
        })
    })
})