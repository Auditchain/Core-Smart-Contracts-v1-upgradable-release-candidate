import {
    ensureException,
    duration
} from './helpers/utils.js';


const MEMBERS = artifacts.require('../Members');
const TOKEN = artifacts.require('../AuditToken');
const MEMBER_HELPERS = artifacts.require('../MemberHelpers');
const NODE_OPERATIONS = artifacts.require('../NodeOperations');
const VALIDATION = artifacts.require('../ValidationsNoCohort');
const VALIDATION_HELPERS = artifacts.require('../ValidationHelpers');
const QUEUE = artifacts.require("../Queue");



import expectRevert from './helpers/expectRevert';
import { assert } from 'chai';
let BN = require("big-number");




contract("NoCohort Validations contract", (accounts) => {

    const admin = accounts[0];
    const enterprise1 = accounts[1];
    const validator1 = accounts[2];
    const validator2 = accounts[3];
    const validator3 = accounts[4];
    const validator4 = accounts[5];
    const platformAccount = accounts[6];
    const dataSubscriber = accounts[7];
    const documentURL = "http://xbrlsite.azurewebsites.net/2021/reporting-scheme/proof/reference-implementation/instance.xml"


    let members;
    let token;
    let memberHelpers;
    let nodeOperations
    let validationHelpers;
    let validation;
    let documentHash;
    let validationHash;
    let queue;

    let auditTokenMin = "5000000000000000000000";
    let rewardTokensHalf = "341500000000000000000";
    let rewardTokens = "1000000000000000000";
    let price = "1000000000000000000";
    let replacementPrice = "2000000000000000000";
    let initialToken = "250000000000000000000000000";

    let cohortAddress;
    let cohortContract;
    let result;

    let CONTROLLER_ROLE = web3.utils.keccak256("CONTROLLER_ROLE");
    let MINTER_ROLE = web3.utils.keccak256("MINTER_ROLE");




    const tokenAmount1 = "9000000000000000000000000";
    const tokenAmount2 = "8500000000000000000000000";
    const tokenAmount3 = "10000000000000000000000000";
    const tokenAmount4 = "44443332220000000000000000";
    const tokenAmount5 = "14443332220000000000000000";


    before(async () => {

        token = await TOKEN.deployed();
        members = await MEMBERS.deployed();
        memberHelpers = await MEMBER_HELPERS.deployed();
        nodeOperations = await NODE_OPERATIONS.deployed();
        queue = await QUEUE.deployed();
        validationHelpers = await VALIDATION_HELPERS.deployed();
        validation = await VALIDATION.deployed();

        let CONTROLLER_ROLE = web3.utils.keccak256("CONTROLLER_ROLE");
        await members.grantRole(CONTROLLER_ROLE, admin, { from: admin });

        await token.grantRole(MINTER_ROLE, admin, { from: admin });
        await token.mint(admin, initialToken, { from: admin });

        await queue.grantRole(CONTROLLER_ROLE, validation.address, { from: admin });
        await members.addUser(validator1, "Validators 1", 1, { from: admin });
        await members.addUser(validator2, "Validators 2", 1, { from: admin });
        await members.addUser(validator3, "Validators 3", 1, { from: admin });
        await members.addUser(validator4, "Validators 4", 1, { from: admin });


        await members.addUser(dataSubscriber, "DataSubscriberr 1", 2, { from: admin });


        await token.transfer(validator1, tokenAmount1);
        await token.transfer(validator2, tokenAmount2);
        await token.transfer(validator3, tokenAmount3);
        await token.transfer(validator4, tokenAmount4);
        await token.transfer(dataSubscriber, tokenAmount5);

        await token.approve(memberHelpers.address, auditTokenMin, { from: validator1 });
        await token.approve(memberHelpers.address, auditTokenMin, { from: validator2 });
        await token.approve(memberHelpers.address, auditTokenMin, { from: validator3 });
        await token.approve(memberHelpers.address, auditTokenMin, { from: validator4 });
        await token.approve(memberHelpers.address, auditTokenMin, { from: dataSubscriber });



        await memberHelpers.stake(auditTokenMin, { from: validator1 });
        await memberHelpers.stake(auditTokenMin, { from: validator2 });
        await memberHelpers.stake(auditTokenMin, { from: validator3 });
        await memberHelpers.stake(auditTokenMin, { from: validator4 });
        await memberHelpers.stake(auditTokenMin, { from: dataSubscriber });

        await nodeOperations.toggleNodeOperator({ from: validator1 });
        await nodeOperations.toggleNodeOperator({ from: validator2 });
        await nodeOperations.toggleNodeOperator({ from: validator3 });
        await nodeOperations.toggleNodeOperator({ from: validator4 });



        documentHash = web3.utils.soliditySha3(documentURL);
        await memberHelpers.grantRole(CONTROLLER_ROLE, validation.address, { from: admin });
        await queue.grantRole(CONTROLLER_ROLE, validation.address, { from: admin });
        await queue.grantRole(CONTROLLER_ROLE, validationHelpers.address, { from: admin });

    })


    describe("Initialize", async () => {

        it("Should succeed. noCohort deployed and initialized", async () => {

            let memberAddress = await validation.members();
            let memberHelperAddress = await validation.memberHelpers();
            assert.strictEqual(memberAddress, members.address);
            assert.strictEqual(memberHelperAddress, memberHelpers.address);

        })
    })


    describe("Initialize validation", async () => {

        it("Should succeed. Validation initialized by registered user who has sufficient funds", async () => {

            let result = await validation.initValNoCohort(documentHash, documentURL, 1, price, { from: dataSubscriber });

            let event = result.logs[0];
            assert.equal(event.event, 'ValidationInitialized');

            let validationTime = event.args.initTime;
            let validationHash = web3.utils.soliditySha3(documentHash, validationTime, dataSubscriber);

            assert.strictEqual(event.args.validationHash, validationHash);
            assert.strictEqual(event.args.user, dataSubscriber);

        })

        it("Should fail. Validation initialized by not registered user.", async () => {

            try {
                let result = await validation.initValNoCohort(documentHash, documentURL, 1, price, { from: admin });
                expectRevert();
            }
            catch (error) {
                ensureException(error);
            }
        })


        it("Should fail. Validation initialized by registered user with no funds", async () => {

            await members.addUser(enterprise1, "Enterprise 1", 2, { from: admin });
            let balance = await token.balanceOf(enterprise1);
            try {
                let result = await validation.initValNoCohort(documentHash, documentURL, 0, price, { from: enterprise1 });
                expectRevert();
            }
            catch (error) {
                ensureException(error);
            }
        })
    })

    describe("Validate document", async () => {

        let validationInitTime;

        beforeEach(async () => {

            let result = await validation.initValNoCohort(documentHash, documentURL, 1, price, { from: dataSubscriber });
            let event = result.logs[0]
            assert.equal(event.event, 'ValidationInitialized');
            validationInitTime = event.args.initTime;

        })

        it("Should succeed. Validation executed by proper validator and proper values are passed", async () => {

            let result = await validation.validate(documentHash, validationInitTime, dataSubscriber, 1, documentURL, documentHash, { from: validator1, gas: 900000 });


            let event = result.logs[0];
            assert.equal(event.event, 'ValidatorValidated');

            assert.strictEqual(event.args.decision.toString(), "1");
            assert.strictEqual(event.args.documentHash, documentHash);
        })

        it("Should fail. Validation attested by proper validator but improper document hash is sent.", async () => {

            documentHash = web3.utils.soliditySha3("1");

            try {
                await validation.validate(documentHash, validationInitTime, dataSubscriber, 1, documentURL, documentHash, { from: validator1, gas: 900000 });
                expectRevert();
            } catch (error) {
                ensureException(error);
            }
        })


        it("Should fail. Validation attested by proper validator but improper validation time is sent.", async () => {

            try {
                await validation.validate(documentHash, 1, dataSubscriber, 1, documentURL, documentHash, { from: validator1, gas: 900000 });
                expectRevert();
            } catch (error) {
                ensureException(error);
            }
        })


        it("Should fail. Validation attested by improper validator while all params are correct.", async () => {

            try {
                await validation.validate(documentHash, validationInitTime, dataSubscriber, 1, documentURL, documentHash, { from: dataSubscriber, gas: 900000 });
                expectRevert();
            } catch (error) {
                ensureException(error);
            }

        })

        it("Should fail. Validation validate with wrong subscriber while all remaining params are correct.", async () => {

            try {
                await validation.validate(documentHash, validationInitTime, validator1, 1, documentURL, documentHash, { from: validator1, gas: 900000 });
                expectRevert();
            } catch (error) {
                ensureException(error);
            }

        })


        it("Should succeed. Validation executed by all validators should result in total award equal payment fee for one validation", async () => {


            let depositAmountBefore1 = (await nodeOperations.nodeOpStruct(validator1)).POWAmount;
            let depositAmountBefore2 = (await nodeOperations.nodeOpStruct(validator2)).POWAmount;
            let depositAmountBefore3 = (await nodeOperations.nodeOpStruct(validator3)).POWAmount;
            let depositAmountBefore4 = (await nodeOperations.nodeOpStruct(validator4)).POWAmount;

            let result = await validation.validate(documentHash, validationInitTime, dataSubscriber, 1, documentURL, documentHash, { from: validator1, gas: 900000 });
            await validation.validate(documentHash, validationInitTime, dataSubscriber, 1, documentURL, documentHash, { from: validator2, gas: 900000 });
            await validation.validate(documentHash, validationInitTime, dataSubscriber, 1, documentURL, documentHash, { from: validator3, gas: 900000 });
            await validation.validate(documentHash, validationInitTime, dataSubscriber, 1, documentURL, documentHash, { from: validator4, gas: 900000 });


            let event = result.logs[1];
            assert.equal(event.event, 'RequestExecuted');


            validation.voteWinner(event.args.winners, [true, true, true], event.args.validationHash, { from: validator1 });
            validation.voteWinner(event.args.winners, [true, true, true], event.args.validationHash, { from: validator2 });
            validation.voteWinner(event.args.winners, [true, true, true], event.args.validationHash, { from: validator3 });
            validation.voteWinner(event.args.winners, [true, true, true], event.args.validationHash, { from: validator4 });

            let depositAmountAfter1 = (await nodeOperations.nodeOpStruct(validator1)).POWAmount;
            let depositAmountAfter2 = (await nodeOperations.nodeOpStruct(validator2)).POWAmount;
            let depositAmountAfter3 = (await nodeOperations.nodeOpStruct(validator3)).POWAmount;
            let depositAmountAfter4 = (await nodeOperations.nodeOpStruct(validator4)).POWAmount;

            let earned1 = BN(depositAmountAfter1.toString()).minus(BN(depositAmountBefore1.toString()));
            let earned2 = BN(depositAmountAfter2.toString()).minus(BN(depositAmountBefore2.toString()));
            let earned3 = BN(depositAmountAfter3.toString()).minus(BN(depositAmountBefore3.toString()));
            let earned4 = BN(depositAmountAfter4.toString()).minus(BN(depositAmountBefore4.toString()));

            let total = BN(earned1.toString()).add(BN(earned2.toString()).add(BN(earned3.toString()).add(BN(earned4.toString()))));
            assert.strictEqual(total.toString(), price.toString());

        })

    })

    describe("Check if validator has validated specific document", async () => {

        let validationInitTime;
        let validationHash
        let count=0;
        let documentHash
        
        beforeEach(async () => {
            
            count++;
            documentHash = web3.utils.soliditySha3(documentURL + count);
            let result = await validation.initValNoCohort(documentHash, documentURL, 1, price, { from: dataSubscriber });


            let event = result.logs[0];
            assert.equal(event.event, 'ValidationInitialized');
            validationInitTime = event.args.initTime;
            validationHash = web3.utils.soliditySha3(documentHash, validationInitTime, dataSubscriber);

        })


        it("It should succeed. The return value should be true.", async () => {

            let result = await validation.validate(documentHash, validationInitTime, dataSubscriber, 1, documentURL, documentHash, { from: validator1, gas: 900000 });

            let isValidated = await validation.isValidated(validationHash, { from: validator1 });
            assert.strictEqual(isValidated.toString(), "1");
        })

        it("It should succeed. The return value should be false.", async () => {

            let isValidated = await validation.isValidated(validationHash, { from: validator1 });

            assert.strictEqual(isValidated.toString(), "0");
        })
    })



    describe("Calculate Vote Quorum", async () => {

        let validationInitTime;
        let validationHash

        beforeEach(async () => {

            let result = await validation.initValNoCohort(documentHash, documentURL, 1, price, { from: dataSubscriber });

            let event = result.logs[0];
            assert.equal(event.event, 'ValidationInitialized');
            validationInitTime = event.args.initTime;
            validationHash = web3.utils.soliditySha3(documentHash, validationInitTime, dataSubscriber);

        })


        it("Should succeed. Calculation is done against valid validation.", async () => {

            let result = await validation.validate(documentHash, validationInitTime, dataSubscriber, 1, documentURL, documentHash, { from: validator1, gas: 900000 });

            let quorum = await validationHelpers.calculateVoteQuorum(validationHash, validation.address);

            assert.strictEqual(quorum.toString(), "25");
        })

        it("Should fail. Calculation is done against valid validation with wrong time. ", async () => {
            validationHash = web3.utils.soliditySha3(documentHash, 1, dataSubscriber);

            let result = await validationHelpers.calculateVoteQuorum(validationHash, validation.address);

            assert.strictEqual(result.toString(), "0");

        })

        it("Should fail. Calculation is done against valid validation with wrong requestor. ", async () => {
            validationHash = web3.utils.soliditySha3(documentHash, validationInitTime, enterprise1);

            let result = await validationHelpers.calculateVoteQuorum(validationHash, validation.address);

            assert.strictEqual(result.toString(), "0");


        })
    })

    describe("Collect Validation Results", async () => {

        let validationInitTime;
        let validationHash

        let count=10;
        let documentHash
        
        beforeEach(async () => {
            
            count++;  
            documentHash = web3.utils.soliditySha3(documentURL + count); // prevent same hash
            let result = await validation.initValNoCohort(documentHash, documentURL, 1, price, { from: dataSubscriber });

            let event = result.logs[0];
            assert.equal(event.event, 'ValidationInitialized');
            validationInitTime = event.args.initTime;
            validationHash = web3.utils.soliditySha3(documentHash, validationInitTime, dataSubscriber);

        })



        it("Should succeed. CollectValidationResults properly returns results", async () => {

            await validation.validate(documentHash, validationInitTime, dataSubscriber, 1, documentURL, documentHash, { from: validator1, gas: 900000 });

            let status = await validation.collectValidationResults(validationHash);

            assert.strictEqual(status[0][0], validator1);
            assert.strictEqual(status[1][0].toString(), auditTokenMin);
            assert.strictEqual(status[2][0].toString(), "1");
            assert.strictEqual(status[3][0].toString(), validationInitTime.toString());
        })

        it("Should succeed. determineConsensus properly determines consensus", async () => {

            let result = await validationHelpers.determineConsensus([1, 1, 1, 2]);
            assert.strictEqual(result.toString(), "1");
        })
    })

    describe("Change price cancel request", async () => {

        it("Should succeed. it should update price of requested validation", async () => {

            let result = await validation.initValNoCohort(documentHash, documentURL, 1, price, { from: dataSubscriber });
            let event = result.logs[0];

            result = await validationHelpers.replaceCancelValidation(replacementPrice, event.args.validationHash, validation.address, { from: dataSubscriber });
            event = result.logs[0];

            assert.strictEqual(event.args.price.toString(), replacementPrice);

        })

        it("Should fail. it shouldn't update price of requested validation by different requestor", async () => {

            let result = await validation.initValNoCohort(documentHash, documentURL, 1, price, { from: dataSubscriber });
            let event = result.logs[0];

            try {
                await validationHelpers.replaceCancelValidation(replacementPrice, event.args.validationHash, validation.address, { from: validator1 });

                expectRevert();
            } catch (error) {
                ensureException(error);
            }

        })


        it("Should succeed. it should remove validation from queue requested by proper requestor", async () => {

            let result = await validation.initValNoCohort(documentHash, documentURL, 1, price, { from: dataSubscriber });
            let event = result.logs[0];

            result = await validationHelpers.replaceCancelValidation(0, event.args.validationHash, validation.address, { from: dataSubscriber });
            event = result.logs[0];

            assert.strictEqual(event.args.price.toString(), "0");

        })

        it("Should fail. it shouldn't remove request from the queue requested by different requestor", async () => {

            let result = await validation.initValNoCohort(documentHash, documentURL, 1, price, { from: dataSubscriber });
            let event = result.logs[0];

            try {
                await validationHelpers.replaceCancelValidation(0, event.args.validationHash, validation.address, { from: validator1 });

                expectRevert();
            } catch (error) {
                ensureException(error);
            }

        })


    })


})