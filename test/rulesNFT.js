require('source-map-support').install();
import { assert } from 'chai';
import { en } from 'ethers/wordlists';




const NFT = artifacts.require('./RulesERC721Token.sol');
const MEMBERS = artifacts.require('../Members');
const TOKEN = artifacts.require('../AuditToken');
const MEMBER_HELPERS = artifacts.require('../MemberHelpers');
const NODE_OPERATIONS = artifacts.require('../NodeOperations');
const VALIDATION = artifacts.require('../ValidationsNoCohort');
const VALIDATION_HELPERS = artifacts.require('../ValidationHelpers');
const QUEUE = artifacts.require("../Queue");





// const Cohort = artifacts.require('../ValidationsCohort');
// const CREATECOHORT = artifacts.require('../CreateCohort');

var BigNumber = require('big-number');
let SETTER_ROLE = web3.utils.keccak256("SETTER_ROLE");
let CONTROLLER_ROLE = web3.utils.keccak256("CONTROLLER_ROLE");
const documentURL = "http://xbrlsite.azurewebsites.net/2021/reporting-scheme/proof/reference-implementation/instance.xml"


import {
    ensureException,
    duration
} from './helpers/utils.js';




contract("NFT rules contract", (accounts) => {

    const owner = accounts[0];
    const enterprise1 = accounts[1];
    const validator1 = accounts[2];
    const validator2 = accounts[3];
    const validator3 = accounts[4];
    const validator4 = accounts[5];
    const platformAccount = accounts[6];
    const dataSubscriber = accounts[7];

    
    const addressZero = "0x0000000000000000000000000000000000000000"


    let auditTokenMin = "5000000000000000000000";
    let auditTokenLesMin = "1";
    let auditTokenMorMax = "25100000000000000000000";
    let auditTokenMax = "25000000000000000000000";
    let tokenName = "Auditchain Rules";
    let tokenSymbol = "ARN"
    let rules;
    let initialToken = "250000000000000000000000000";
    let price = "1000000000000000000";
    let documentHash;


    let members;
    let token;
    let memberHelpers;
    let nodeOperations;
    let validation;
    let queue;
    let validationHelpers;
    // let createCohort;
    let cohortAddress;
    let cohortContract;
    const documentURL = "http://xbrlsite.azurewebsites.net/2021/reporting-scheme/proof/reference-implementation/instance.xml";
    let MINTER_ROLE = web3.utils.keccak256("MINTER_ROLE");




    before(async () => {
        // await rules.grantRole(CONTROLLER_ROLE, owner, { from: owner });


        token = await TOKEN.deployed();
        members = await MEMBERS.deployed();
        memberHelpers = await MEMBER_HELPERS.deployed();
        nodeOperations = await NODE_OPERATIONS.deployed();
        queue = await QUEUE.deployed();
        validationHelpers = await VALIDATION_HELPERS.deployed();
        validation = await VALIDATION.deployed();
        rules = await NFT.deployed();

        await token.grantRole(MINTER_ROLE, owner, { from: owner });
        await token.mint(owner, initialToken, { from: owner });


        await members.grantRole(CONTROLLER_ROLE, owner, { from: owner });
        await nodeOperations.grantRole(CONTROLLER_ROLE, validation.address, { from: owner });
        await token.grantRole(CONTROLLER_ROLE, nodeOperations.address, { from: owner });

        await memberHelpers.grantRole(CONTROLLER_ROLE, validation.address, { from: owner });
        await memberHelpers.grantRole(CONTROLLER_ROLE, nodeOperations.address, { from: owner });

        await queue.grantRole(CONTROLLER_ROLE, validation.address, { from: owner });

        await members.addUser(enterprise1, "Enterprise 1", 0, { from: owner });
        await members.addUser(validator1, "Validators 1", 1, { from: owner });
        await members.addUser(validator2, "Validators 2", 1, { from: owner });
        await members.addUser(validator3, "Validators 3", 1, { from: owner });
        await members.addUser(dataSubscriber, "DataSubscriberr 1", 2, { from: owner });

        await token.transfer(validator1, auditTokenMin, { from: owner });
        await token.transfer(validator2, auditTokenMin, { from: owner });
        await token.transfer(validator3, auditTokenMin, { from: owner });
        await token.transfer(enterprise1, auditTokenMin, { from: owner });
        await token.transfer(dataSubscriber, auditTokenMin, { from: owner });


        await token.approve(memberHelpers.address, auditTokenMin, { from: validator1 });
        await token.approve(memberHelpers.address, auditTokenMin, { from: validator2 });
        await token.approve(memberHelpers.address, auditTokenMin, { from: validator3 });
        await token.approve(memberHelpers.address, auditTokenMin, { from: dataSubscriber });


        await memberHelpers.stake(auditTokenMin, { from: validator1 });
        await memberHelpers.stake(auditTokenMin, { from: validator2 });
        await memberHelpers.stake(auditTokenMin, { from: validator3 });
        await memberHelpers.stake(auditTokenMin, { from: dataSubscriber });


        await nodeOperations.toggleNodeOperator({ from: validator1 });
        await nodeOperations.toggleNodeOperator({ from: validator2 });
        await nodeOperations.toggleNodeOperator({ from: validator3 });

        documentHash = web3.utils.soliditySha3(documentURL);



    })


    describe("Constructor", async () => {
        it("Verify constructors", async () => {

            let tokenName = await rules.name();
            console.log("token name:", JSON.stringify(tokenName));
            assert.equal(tokenName.toString(), tokenName);

            let tokenSymbol = await rules.symbol();
            assert.equal(tokenSymbol.toString(), tokenSymbol);

            let totalSupply = await rules.totalSupply();
            assert.equal(totalSupply.toString(), "0");
        });
    });

    describe("mintTo", async () => {
        let validationHash;
        let validationInitTime;
        let count = 0;


        beforeEach(async () => {


            count++;
            documentHash = web3.utils.soliditySha3(documentURL + count);

            await token.transfer(enterprise1, auditTokenMin, { from: owner });
            await token.approve(memberHelpers.address, auditTokenMin, { from: enterprise1 });
            await memberHelpers.stake(auditTokenMin, { from: enterprise1 });
            let result = await validation.initValNoCohort(documentHash, documentURL, 1, price, { from: dataSubscriber });

            let event = result.logs[0];
            validationHash = event.args.validationHash;
            validationInitTime = event.args.initTime;

        })

        it('It should fail minting of  1 token to enterprise1 with valid hash id but before validation has been done ', async () => {

            try {
                result = await rules.mintTo(validationHash, { from: enterprise1 })
                expectRevert();
            }
            catch (error) {
                ensureException(error);
            }
        })


        it('It should succeed minting of 1 token to enterprise1 with valid hash id and successful verification ', async () => {

            // await validation.validate(documentHash, validationInitTime, dataSubscriber, 1, documentURL, documentHash, { from: validator1, gas: 900000 });


            await validation.validate(documentHash, validationInitTime, dataSubscriber, 1, documentURL, documentHash, { from: validator1, gas: 900000 });
            await validation.validate(documentHash, validationInitTime, dataSubscriber, 1, documentURL, documentHash, { from: validator2, gas: 900000 });
            await validation.validate(documentHash, validationInitTime, dataSubscriber, 1, documentURL, documentHash, { from: validator3, gas: 900000 });


            let result = await rules.mintTo(validationHash, { from: dataSubscriber });
            let event = result.logs[1];
            assert.equal(event.event, 'Mint');
            let tokenId = event.args.tokenId;
            let recipient = event.args.recipient;

            assert.strictEqual(tokenId.toString(), "1");
            assert.strictEqual(recipient, dataSubscriber);
        })


        it('It should fail minting the same token twice for one rule ', async () => {

            await validation.validate(documentHash, validationInitTime, dataSubscriber, 1, documentURL, documentHash, { from: validator1, gas: 900000 });
            await validation.validate(documentHash, validationInitTime, dataSubscriber, 1, documentURL, documentHash, { from: validator2, gas: 900000 });
            await validation.validate(documentHash, validationInitTime, dataSubscriber, 1, documentURL, documentHash, { from: validator3, gas: 900000 });


            let result = await rules.mintTo(validationHash, { from: dataSubscriber });

            try {
                result = await rules.mintTo(validationHash, { from: dataSubscriber });
                expectRevert();
            }
            catch (error) {
                ensureException(error);
            }

        })


        it('It should fail minting of 1 token to dataSubscriber with valid hash id but unsuccessful verification ', async () => {

            await validation.validate(documentHash, validationInitTime, dataSubscriber, 2, documentURL, documentHash, { from: validator1, gas: 900000 });
            await validation.validate(documentHash, validationInitTime, dataSubscriber, 2, documentURL, documentHash, { from: validator2, gas: 900000 });
            await validation.validate(documentHash, validationInitTime, dataSubscriber, 2, documentURL, documentHash, { from: validator3, gas: 900000 });2


            try {
                await rules.mintTo(validationHash, { from: dataSubscriber });
                expectRevert();
            }
            catch (error) {
                ensureException(error);
            }

        })

    })
})
