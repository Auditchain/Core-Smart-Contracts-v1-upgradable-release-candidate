import { assert } from 'chai';



const MEMBERS = artifacts.require('../Members');
const TOKEN = artifacts.require('../AuditToken');
const MEMBER_HELPERS = artifacts.require('../MemberHelpers');
const NODE_OPERATIONS = artifacts.require('../NodeOperations');
const VALIDATION = artifacts.require('../ValidationsNoCohort');
const VALIDATION_HELPERS = artifacts.require('../ValidationHelpers');
const QUEUE = artifacts.require("../Queue");

let BN = require("big-number");

contract("Queue", (accounts) => {

    const admin = accounts[0];

    let members;
    let token;
    let nodeOperations
    let validationHelpers;
    let validation;
    let queue;
    let memberHelpers;

    let auditTokenPrice = "5000000000000000000000";
    let auditTokenHalf = "2500000000000000000000";
    let trxHash = "0x44bd3e22479f8fab2aa3e9d55617f012a4cb13beb0bca204a070f41b04a4cdc5";
    let trxHash2 = "0x72bb7d6665d72c32432d2accd4f1f8391a548575d211e78c0615b2e3aaeb3cfb";
    let zeroTransaction = "0x0000000000000000000000000000000000000000000000000000000000000000";


    before(async () => {

        token = await TOKEN.deployed();
        members = await MEMBERS.deployed();
        memberHelpers = await MEMBER_HELPERS.deployed();
        nodeOperations = await NODE_OPERATIONS.deployed();
        queue = await QUEUE.deployed();
        validationHelpers = await VALIDATION_HELPERS.deployed();
        validation = await VALIDATION.deployed();

        let CONTROLLER_ROLE = web3.utils.keccak256("CONTROLLER_ROLE");
        await queue.grantRole(CONTROLLER_ROLE, admin, { from: admin });

    })


    describe("Initialize", async () => {

        it("Should succeed. Queue deployed and initialized", async () => {

            let head = await queue.head();
            let idCounter = await queue.idCounter();
            assert.strictEqual(Number(head), 0);
            assert.strictEqual(Number(idCounter), 1);

        })
    })


    describe("Use queue", async () => {

        it("Should succeed. Add new element to queue", async () => {

            let queueSize = await queue.queueCount();
            assert.strictEqual(queueSize.toString(), "0");

            await queue.addToQueue(auditTokenPrice, trxHash);
            queueSize = await queue.queueCount();
            assert.strictEqual(queueSize.toString(), "1");

        })

        it("Should succeed. Remove first element from queue", async () => {

            let queueSize = await queue.queueCount();
            assert.strictEqual(queueSize.toString(), "1");

            await queue.removeFromQueue(trxHash);
            queueSize = await queue.queueCount();
            assert.strictEqual(queueSize.toString(), "0");

        })


        it("Should succeed. Replace transaction with new price", async () => {


            await queue.addToQueue(auditTokenPrice, trxHash);
            let queueSize = await queue.queueCount();
            assert.strictEqual(queueSize.toString(), "1");

            let elementData = await queue.findIdForValidationHash(trxHash);
            let object = await queue.get(elementData.toString());

            assert.strictEqual(object[2].toString(), auditTokenPrice);

            await queue.replaceValidation(auditTokenHalf, trxHash)
            elementData = await queue.findIdForValidationHash(trxHash);
            object = await queue.get(elementData.toString());
            assert.strictEqual(object[2].toString(), auditTokenHalf);
            await queue.removeFromQueue(trxHash);

        })

        it("Should succeed. Find an item for lesser price", async () => {


            await queue.addToQueue(auditTokenPrice, trxHash);
            await queue.addToQueue(auditTokenHalf, trxHash2);

            let id = await queue.findIdForLesserPrice(auditTokenPrice);
            let object = await queue.get(id.toString());
            assert.strictEqual(object[2].toString(), auditTokenHalf);

            await queue.removeFromQueue(trxHash);
            await queue.removeFromQueue(trxHash2);

        })


        it("Should succeed. Retrieve item based on hash value", async () => {


            await queue.addToQueue(auditTokenPrice, trxHash);
            await queue.addToQueue(auditTokenHalf, trxHash2);


            let id = await queue.findIdForValidationHash(trxHash2);
            let object = await queue.get(id.toString());
            assert.strictEqual(object[2].toString(), auditTokenHalf);
            await queue.removeFromQueue(trxHash);
            await queue.removeFromQueue(trxHash2);

        })


        it("Should succeed. Setting validation flag", async () => {

            await queue.addToQueue(auditTokenPrice, trxHash);
            let id = await queue.findIdForValidationHash(trxHash);
            let object = await queue.get(id.toString());
            assert.strictEqual(object.executed, false);

            await queue.setValidatedFlag(trxHash);

            id = await queue.findIdForValidationHash(trxHash);
            object = await queue.get(id.toString());
            assert.strictEqual(object.executed, true);
            await queue.removeFromQueue(trxHash);
        })


        it("Should succeed. It gets next record for validation", async () => {

            await queue.addToQueue(auditTokenPrice, trxHash);
            await queue.addToQueue(auditTokenHalf, trxHash2);

            let nextValidation = await queue.getNextValidation();
            assert.strictEqual(nextValidation, trxHash);
            await queue.removeFromQueue(trxHash);
            await queue.removeFromQueue(trxHash2);

        })

        it("Should succeed. It gets empty validation hash if no transaction exist for validation", async () => {

            let nextValidation = await queue.getNextValidation();
            assert.strictEqual(nextValidation, zeroTransaction);

        })

        it("Should succeed. It gets next record for validation after one provided", async () => {


            await queue.addToQueue(auditTokenPrice, trxHash);
            await queue.addToQueue(auditTokenHalf, trxHash2);

            let nextValidation = await queue.getNextValidation();
            assert.strictEqual(nextValidation, trxHash);
            nextValidation = await queue.getValidationToProcess(trxHash);
            assert.strictEqual(nextValidation, trxHash2);
            await queue.removeFromQueue(trxHash);
            await queue.removeFromQueue(trxHash2);

        })

        it("Should succeed. It gets empty validation hash for validation after one provided if none exists", async () => {

            await queue.addToQueue(auditTokenPrice, trxHash);
            let nextValidation = await queue.getNextValidation();
            assert.strictEqual(nextValidation, trxHash);
            nextValidation = await queue.getValidationToProcess(trxHash);

            assert.strictEqual(nextValidation, zeroTransaction);
            await queue.removeFromQueue(trxHash);
        })


        it("Should succeed. It gets next record for vote", async () => {

            await queue.addToQueue(auditTokenPrice, trxHash);
            await queue.addToQueue(auditTokenHalf, trxHash2);
            await queue.setValidatedFlag(trxHash);

            let nextValidation = await queue.getNextValidationToVote();
            assert.strictEqual(nextValidation, trxHash);

            await queue.removeFromQueue(trxHash);
            await queue.removeFromQueue(trxHash2);

        })

        it("Should succeed. It gets next record for validation after one provided if there is none in the queue", async () => {

            await queue.addToQueue(auditTokenPrice, trxHash);
            await queue.addToQueue(auditTokenHalf, trxHash2);
            await queue.setValidatedFlag(trxHash);
            await queue.setValidatedFlag(trxHash2);

            let validationToVote = await queue.getNextValidationToVote();
            let nextValidationToVote = await queue.getValidationToVote(validationToVote);
            assert.strictEqual(nextValidationToVote, trxHash2);

            await queue.removeFromQueue(trxHash);
            await queue.removeFromQueue(trxHash2);

        })

        it("Should succeed. It gets empty validation hash record for validation after one provided if there is none in the queue", async () => {

            await queue.addToQueue(auditTokenPrice, trxHash);
            await queue.addToQueue(auditTokenHalf, trxHash2);
            await queue.setValidatedFlag(trxHash);

            let validationToVote = await queue.getNextValidationToVote();
            let nextValidationToVote = await queue.getValidationToVote(validationToVote);
            assert.strictEqual(nextValidationToVote, zeroTransaction);

            await queue.removeFromQueue(trxHash);
            await queue.removeFromQueue(trxHash2);

        })


        it("Should succeed. It should replace price of the submitted request in the queue", async () => {

            await queue.addToQueue(auditTokenPrice, trxHash);

            let elementData = await queue.findIdForValidationHash(trxHash);
            let object = await queue.get(elementData.toString());

            assert.strictEqual(object.price.toString(), auditTokenPrice);
            await queue.replaceValidation(auditTokenHalf, trxHash, {from:admin})

            elementData = await queue.findIdForValidationHash(trxHash);
            object = await queue.get(elementData.toString());
            assert.strictEqual(object.price.toString(), auditTokenHalf);
            await queue.removeFromQueue(trxHash);

        })
    })
})