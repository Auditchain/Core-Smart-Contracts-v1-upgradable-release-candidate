import { assert } from 'chai';
import {
    ensureException,
} from './helpers/utils.js';

const MEMBERS = artifacts.require('../Members');
const MEMBER_HELPERS = artifacts.require('../MemberHelpers')
const TOKEN = artifacts.require('../AuditToken');
const VALIDATION = artifacts.require('../ValNoCohort');
const NODE_OPERATIONS = artifacts.require('../NodeOperations');
const VALIDATION_HELPERS = artifacts.require('../ValidationHelpers');
const QUEUE = artifacts.require("../Queue");

import expectRevert from './helpers/expectRevert';

contract("Member Helper contract", (accounts) => {

    const admin = accounts[0];
    const enterprise1 = accounts[1];
    const validator1 = accounts[3];
    const validator2 = accounts[4];

    let members;
    let token;
    let memberHelpers;
    let validation;
    let nodeOperations;
    let validationHelpers;
    let queue;
    let CONTROLLER_ROLE;

    let auditTokenMin = "5000000000000000000000";
    let auditTokenLesMin = "1";
    let initialToken = "2500000000000000000000000000";

    CONTROLLER_ROLE = web3.utils.keccak256("CONTROLLER_ROLE");
    let MINTER_ROLE = web3.utils.keccak256("MINTER_ROLE");

    before(async () => {

        token = await TOKEN.deployed();
        members = await MEMBERS.deployed();
        memberHelpers = await MEMBER_HELPERS.deployed();
        nodeOperations = await NODE_OPERATIONS.deployed();
        queue = await QUEUE.deployed();
        validationHelpers = await VALIDATION_HELPERS.deployed();
        validation = await VALIDATION.deployed();

        await token.grantRole(MINTER_ROLE, admin, { from: admin });
        await token.mint(admin, initialToken, { from: admin });

        await token.grantRole(MINTER_ROLE, memberHelpers.address, { from: admin });

        await token.grantRole(MINTER_ROLE, admin, { from: admin });
        await token.mint(admin, initialToken, { from: admin });
        await queue.grantRole(CONTROLLER_ROLE, validation.address, { from: admin });

    })

    describe("Deploy", async () => {

        it("Should succeed. Initialize members with Audit token", async () => {
            let tokenAddress = await memberHelpers.auditToken();
            assert.strictEqual(tokenAddress, token.address);

        })
    })

    describe("Set Validation ", async () => {

        it("Should succeed. Validation address has been set", async () => {

            await memberHelpers.setValidation(validation.address);
            let validationAddress = await memberHelpers.validations();
            assert.strictEqual(validationAddress, validation.address);
        })

        it("Should fail. Validation address has been set by not authorized user", async () => {

            try {
                await memberHelpers.setValidation(validation.address, { from: validator2 });

                expectRevert()
            } catch (error) {
                ensureException(error);
            }
        })

        it("Should fail. Validation address has been set by authorized user, but with address 0", async () => {

            try {
                await memberHelpers.setValidation("0x0000000000000000000000000000000000000000", { from: admin });

                expectRevert()
            } catch (error) {
                ensureException(error);
            }
        })
    })


    describe("Stake by validators", async () => {

        before(async () => {

            await members.addUser(validator1, "Validator 1", 1, { from: admin });
            await token.transfer(validator1, auditTokenMin, { from: admin });
            await token.approve(memberHelpers.address, auditTokenMin, { from: validator1 });
        })

        it("Should succeed. Validator stakes tokens.", async () => {

            let result = await memberHelpers.stake(auditTokenMin, { from: validator1 });
            assert.lengthOf(result.logs, 1);

            let event = result.logs[0];
            assert.equal(event.event, 'LogDepositReceived');
            assert.strictEqual(event.args.from, validator1);
            assert.strictEqual(event.args.amount.toString(), auditTokenMin);
        })

        it("Should fail. User hasn't been registered as validator.", async () => {
            try {
                await memberHelpers.stake(auditTokenMin, { from: validator2 });
                expectRevert()
            } catch (error) {
                ensureException(error);
            }
        })

        it("Should fail. User contributed less than required amount.", async () => {

            try {
                await memberHelpers.stake(auditTokenLesMin, { from: validator1 });
                expectRevert()
            } catch (error) {
                ensureException(error);
            }

        })
    })

    describe("Deposit by Enterprise", async () => {

        before(async () => {

            await members.addUser(enterprise1, "Enterprise 1", 0, { from: admin });
            await token.transfer(enterprise1, auditTokenMin, { from: admin });
            await token.approve(memberHelpers.address, auditTokenMin, { from: enterprise1 });
        })

        it("Should succeed. Enterprise deposits tokens.", async () => {

            let result = await memberHelpers.stake(auditTokenMin, { from: enterprise1 });
            assert.lengthOf(result.logs, 1);

            let event = result.logs[0];
            assert.equal(event.event, 'LogDepositReceived');
            assert.strictEqual(event.args.from, enterprise1);
            assert.strictEqual(event.args.amount.toString(), auditTokenMin);
        })

        it("Should fail. User hasn't been registered as enterprise.", async () => {
            try {
                result = await memberHelpers.stake(auditTokenMin, { from: admin });
                expectRevert()
            } catch (error) {
                ensureException(error);
            }
        })
    })


    describe("Redeem", async () => {

        it("Should succeed. Data subscriber redeems their deposit", async () => {

            let result = await memberHelpers.redeem(auditTokenLesMin, { from: validator1 });
            assert.lengthOf(result.logs, 1);

            let event = result.logs[0];
            assert.equal(event.event, 'LogDepositRedeemed');
            assert.strictEqual(event.args.from, validator1);
            assert.strictEqual(event.args.amount.toString(), auditTokenLesMin);
        })

        it("Should fail. Data subscriber tried to withdraw more than available.", async () => {
            try {
                result = await memberHelpers.redeem(auditTokenMin, { from: validator1 });
                expectRevert()
            } catch (error) {
                ensureException(error);
            }
        })
    })

})