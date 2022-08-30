// src/index.js
const Web3 = require('web3');
const { setupLoader } = require('@openzeppelin/contract-loader');

async function main() {
    // Set up web3 object, connected to the local development network, and a contract loader
    const web3 = new Web3('https://polygon-mumbai.g.alchemy.com/v2/H2g1siLIwqCBQMIY052r_vJAejQ_A_V3');
    // const web3 = new Web3('https://polygon-mumbai.infura.io/v3/5250187d69d747f392fcf1d32bbbc64a');
    // const web3 = new Web3('https://speedy-nodes-nyc.moralis.io/19733f9d7aae891cd574576e/polygon/mumbai');
    

    
    const loader = setupLoader({ provider: web3 }).web3;

    // Set up a web3 contract, representing our deployed Box instance, using the contract loader
    // const address = '0x1a3F8606745B25f5e5f78a250f1f2DbAEEa41B97';
    // const box = loader.fromArtifact('Box', address);

    // box.getPastEvents('ValueChanged', {
    //     fromBlock: 0,
    //     toBlock: 'latest'
    // }, function(error, events){ console.log("events 123", events); });



    // const memberAddress = "0x79cBbaAC67d7F5565a707685B49544Fd8cd29E0D";
    // const member = loader.fromArtifact("Members", memberAddress);


    // member.getPastEvents('UserAdded', {
    //     fromBlock: 0,
    //     toBlock: 'latest'
    // }, function (error, events) { console.log("events user", events); });


    const noCohortAddress = "0xfD39AB42e94c88fb8432FfEEeDE72672DC4a8104";
    const noCohort = loader.fromArtifact("ValidationsNoCohort", noCohortAddress);


    // noCohort.getPastEvents('ValidationInitialized', {
    //     filter: { validationHash: "0x976228ce0905f1f7c5eb6e0b6dc9574a7774112fa038b0094c46bd210110f928" },
    //     fromBlock: 0,
    //     toBlock: 'latest'
    // }, function (error, events) { console.log("events no cohort", events); });

    let filter = "0xd431134b507d3B6F2742687e14cD9CbA5b6BE0F4"

    let result = await noCohort.getPastEvents('RequestExecuted', {
        filter: { audits: 1, requestor: filter },
        fromBlock: 0,
        toBlock: 'latest'})
    // }, function (error, events) { console.log("events no cohort", events); });

    console.log(result);

}

main();