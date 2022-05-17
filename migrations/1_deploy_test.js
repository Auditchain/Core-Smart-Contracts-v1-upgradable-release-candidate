
const Members = artifacts.require('./Members.sol');
const Token = artifacts.require('./AuditToken.sol');
const NoCohort = artifacts.require('./ValidationsNoCohort.sol');
const ValidationHelpers = artifacts.require('./ValidationHelpers.sol');
const MemberHelpers = artifacts.require('MemberHelpers.sol');
const NFT = artifacts.require('./RulesERC721Token.sol');
const NodeOperations = artifacts.require('./NodeOperations.sol');
const Queue = artifacts.require("./Queue.sol");

const { upgradeProxy, deployProxy } = require('@openzeppelin/truffle-upgrades');

module.exports = async function (deployer, network, accounts) { // eslint-disable-line..

  let admin = accounts[0];   // 0
  let platformAddress = accounts[1]; // 1
  let MINTER_ROLE = web3.utils.keccak256("MINTER_ROLE");
  let CONTROLLER_ROLE = web3.utils.keccak256("CONTROLLER_ROLE");
  let SETTER_ROLE = web3.utils.keccak256("SETTER_ROLE");

  
  await deployProxy(Token, [admin], { deployer, initializer: 'initialize' });
  let token = await Token.deployed();
  console.log("token address:", token.address);


  await deployProxy(Queue, { deployer, initializer: 'initialize' });
  let queue = await Queue.deployed();
  console.log("queue address:", queue.address);


  await deployProxy(Members, [token.address, platformAddress], { deployer, initializer: 'initialize' });
  let members = await Members.deployed();
  console.log("member address:", members.address);

  await deployProxy(MemberHelpers, [members.address,  token.address], { deployer, initializer: 'initialize' });
  let memberHelpers = await MemberHelpers.deployed();
  console.log("member helpers address:", memberHelpers.address);


  await deployProxy(NodeOperations, [memberHelpers.address, token.address, members.address], { deployer, initializer: 'initialize' });
  let nodeOperations = await NodeOperations.deployed();
  console.log("node operations address:", nodeOperations.address);


  await deployProxy(ValidationHelpers, [memberHelpers.address, queue.address], { deployer, initializer: 'initialize' });
  let validationHelpers = await ValidationHelpers.deployed();
  console.log("validation helpers address:", validationHelpers.address);


  await deployProxy(NoCohort, [members.address, memberHelpers.address, nodeOperations.address,  validationHelpers.address, queue.address], { deployer, initializer: 'initialize' } );
  let noCohort = await NoCohort.deployed();
  console.log("no cohort address:", noCohort.address);



  await deployProxy(NFT, ["AuditChain", "Rules", noCohort.address], { deployer, initializer: 'initialize' } );
  let nft = await NFT.deployed();
  console.log("NFT address:", nft.address);


  // env format
  console.log("\n\n" + ".env format" + "\n\n");


  console.log('AUDT_TOKEN_ADDRESS=' + token.address);
  console.log('MEMBER_ADDRESS=' + members.address);
  console.log('MEMBER_HELPERS_ADDRESS=' + memberHelpers.address);
  console.log('VALIDATIONS_HELPERS_ADDRESS=' + validationHelpers.address);
  console.log('VALIDATIONS_NO_COHORT_ADDRESS=' + noCohort.address);
  console.log('NODE_OPERATIONS_ADDRESS=' + nodeOperations.address);
  console.log('QUEUE_ADDRESS=' + queue.address);
  console.log('RULES_NFT_ADDRESS=' + nft.address);


  console.log("\n\n" + "React format:" + "\n\n");


  console.log("\n\n" + '"AUDT_TOKEN_ADDRESS":"' + token.address + '",');
  console.log('"MEMBER_ADDRESS":"' + members.address + '",');
  console.log('"MEMBER_HELPERS_ADDRESS":"' + memberHelpers.address + '",');
  console.log('"VALIDATIONS_HELPERS_ADDRESS":"' + validationHelpers.address + '",');
  console.log('"VALIDATIONS_NO_COHORT_ADDRESS":"' + noCohort.address + '",')
  console.log('"NODE_OPERATIONS_ADDRESS":"' + nodeOperations.address + '",');
  console.log('"QUEUE_ADDRESS":"' + queue.address + '",');
  console.log('"RULES_NFT_ADDRESS":"' + nft.address + '",' + "\n\n");


  await validationHelpers.grantRole(CONTROLLER_ROLE, admin, { from: admin });

  await validationHelpers.setValAddress(noCohort.address, { from: admin });


  await memberHelpers.grantRole(CONTROLLER_ROLE, admin, { from: admin });
  console.log("memberHelpers.grantRole(CONTROLLER_ROLE, admin, { from: admin })")

  await memberHelpers.grantRole(CONTROLLER_ROLE, noCohort.address, { from: admin });
  console.log('memberHelpers.grantRole(CONTROLLER_ROLE, noCohort.address, { from: admin })')

  await memberHelpers.grantRole(CONTROLLER_ROLE, nodeOperations.address, { from: admin });
  console.log('memberHelpers.grantRole(CONTROLLER_ROLE, nodeOperations.address, { from: admin })');

  await nodeOperations.grantRole(CONTROLLER_ROLE, noCohort.address, { from: admin });
  console.log('nodeOperations.grantRole(CONTROLLER_ROLE, noCohort.address, { from: admin });')

  await members.grantRole(CONTROLLER_ROLE, admin, { from: admin });
  console.log('members.grantRole(CONTROLLER_ROLE, admin, { from: admin });');


  await token.grantRole(CONTROLLER_ROLE, admin, { from: admin });
  console.log('token.grantRole(CONTROLLER_ROLE, admin, { from: admin });')

  await token.grantRole(CONTROLLER_ROLE, members.address, { from: admin });
  console.log('token.grantRole(CONTROLLER_ROLE, members.address, { from: admin });');

  await token.grantRole(CONTROLLER_ROLE, memberHelpers.address, { from: admin });
  console.log('token.grantRole(CONTROLLER_ROLE, memberHelpers.address, { from: admin });')


  await token.grantRole(CONTROLLER_ROLE, nodeOperations.address, { from: admin });
  console.log('token.grantRole(CONTROLLER_ROLE, nodeOperations.address, { from: admin });');

  await token.grantRole(MINTER_ROLE, nodeOperations.address, { from: admin });
  console.log('token.grantRole(MINTER_ROLE, nodeOperations.address, { from: admin })');

  await queue.grantRole(CONTROLLER_ROLE, noCohort.address, { from: admin });
  console.log('queue.grantRole(CONTROLLER_ROLE, noCohort.address, { from: admin });')

  await memberHelpers.setValidation(noCohort.address, { from: admin });
  console.log('memberHelpers.setValidation(cohort.address, { from: admin });')

  console.log("FINISHED");


};