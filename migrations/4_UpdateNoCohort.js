// migrations/2_deploy_box.js
const NoCohort = artifacts.require('ValNoCohort');

 
const { upgradeProxy, deployProxy } = require('@openzeppelin/truffle-upgrades');
 
module.exports = async function (deployer, network, accounts) {
//   await deployProxy(auditToken, ["0x67794670742BA1E53FD04d8bA22a9b4487CE65B4"], { deployer, initializer: 'initialize' });
  // console.log("members address:", Members.address);

//   let token = await auditToken.deployed();

  // let admin = accounts[0];
  // let admin = "0x67794670742BA1E53FD04d8bA22a9b4487CE65B4";

  // let CONTROLLER_ROLE = web3.utils.keccak256("CONTROLLER_ROLE");
  // let SETTER_ROLE = web3.utils.keccak256("SETTER_ROLE");

//   await members.grantRole(CONTROLLER_ROLE, controller, { from: admin });
//   console.log("1. Creating new user with name [Enterprise 1] in original [Members] contract.\n");
//   let result = await token.addUser(enterprise1, "Enterprise 1", 0, { from: controller });
  
//   let event = result.logs[0];
//   console.log("2. Testing User Name in original contract: [", event.args.name + "]\n");

  console.log("1. Upgrading [ValNoCohort] .\n");

  await upgradeProxy("0x2473f86dbEEc53FCFabA78BAb0EaA1f7d54Efd0C", NoCohort);

  const noCohort = await NoCohort.deployed();
   
  // let initialized = await tokenV2.initialized();
  // console.log("4. showing initialized after upgrade", initialized);


//   await membersV2.modifyName(enterprise1, "Apple Computers Mobile", 0);

//   userName = await membersV2.user(enterprise1, 0);
//   console.log("6. Testing User name in Upgraded contract after calling new name modification function [", userName  + "]\n");

};