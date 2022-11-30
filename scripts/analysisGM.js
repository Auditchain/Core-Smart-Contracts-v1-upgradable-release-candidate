
let axios = require("axios");
const pako = require('pako');
let HDWalletProvider = require('@truffle/hdwallet-provider');
let dotenv = require('dotenv').config({ path: './.env' });
let Web3 = require('web3');
let ipfsBasePrivate = 'https://auditchain.infura-ipfs.io/ipfs/';
var DomParser = require('dom-parser');

parser = new DomParser();





const VALIDATIONS_HELPERS = require('../build/contracts/ValidationHelpers.json');
const NO_COHORT = require('../build/contracts/ValNoCohort.json');


const mnemonic = process.env.MNEMONIC;
const mumbai_server = process.env.MUMBAI_SERVER;
const validationHelpersAddress = process.env.VALIDATIONS_HELPERS_ADDRESS;
const validationsNoCohortAddress = process.env.VALIDATIONS_NO_COHORT_ADDRESS;


const provider = new HDWalletProvider(mnemonic, mumbai_server); // change to main_infura_server or another testnet. 
const web3 = new Web3(provider);
const owner = provider.addresses[0];

let validationHelpersContract = new web3.eth.Contract(VALIDATIONS_HELPERS["abi"], validationHelpersAddress);
let validationsNoCohortContract = new web3.eth.Contract(NO_COHORT["abi"], validationsNoCohortAddress);

let facFalse = 0, facTrue = 0;
let subTypesFalse = 0, subTypesTrue = 0;


function convertTimestamp(timestamp) {
    const d = new Date(timestamp * 1000);
    let yyyy = d.getFullYear();
    const mm = `0${d.getMonth() + 1}`.slice(-2);
    const dd = `0${d.getDate()}`.slice(-2);
    const hh = d.getHours();
    let h = hh;
    const min = `0${d.getMinutes()}`.slice(-2);
    const sec = d.getSeconds();
    let ampm = 'AM';
    let time;
    yyyy = `${yyyy}`.slice(-2);
    if (hh > 12) {
        h = hh - 12;
        ampm = 'PM';
    } else if (hh === 12) {
        h = 12;
        ampm = 'PM';
    } else if (hh === 0) {
        h = 12;
    }
    time = `${yyyy}-${mm}-${dd}, ${h}:${min} ${ampm}`;
    time = `${mm}/${dd}/${yyyy}  ${h}:${min}:${sec} ${ampm}`;
    return time;
};





async function getPacioliTrace(analysisId) {
    try {
        //console.log('analysisId - getPacioliTrace', analysisId)
        //const result = await axios(`https://ipfs.infura.io/ipfs/${analysisId}/PacioliTrace.json.gzip`, { responseType: 'arraybuffer' });
        // const result = await axios(`https://auditchain.infura-ipfs.io/ipfs/${analysisId}/PacioliTrace.json.gzip`, { responseType: 'arraybuffer' });
        const result = await axios(`${analysisId}/PacioliTrace.json.gzip`, { responseType: 'arraybuffer' });

        var unzippedFile = pako.inflate(result.data, { to: 'string' });
        return JSON.parse(unzippedFile.replace("var pacioliModel =", ''));
    } catch (error) {
        console.log(error);
        return JSON.stringify(error);
    }
}





async function getValidationHistory(ethAddress) {
    // const { validationHelpersContract } = context;

    try {
        const validations = [];
        let validationExecutedEvent;
        //   if (mode == "all")
        validationExecutedEvent = await validationsNoCohortContract.getPastEvents("RequestExecuted",
            { filter: { requestor: ethAddress }, fromBlock: 0, toBlock: "latest", })




        //   else
        //     validationExecutedEvent = await UseLogsEndpoint('RequestExecutedRequestor', ethAddress); // const validationExecutedEvent = await noCohortContractWeb3.getPastEvents("RequestExecuted",{filter: { audits: 1, requestor: ethAddress },fromBlock: startingBlockNumber,toBlock: "latest",})
        for (let k = 0; k < validationExecutedEvent.length; k++) {
            const values = validationExecutedEvent[k].returnValues;

            const winnerRecord = await validationHelpersContract.methods.returnWinnerStruct(
                values.validationHash,
                validationsNoCohortAddress
            ).call();

            // const quorum = await validationHelpersContract.calculateVoteQuorum(
            //     values.validationHash,
            //     validationsNoCohortAddress, ethAddress, 0
            // );

            let pacioliReport = winnerRecord[0].replace('/AuditchainMetadataReport.json', '');

            console.log("url:", ipfsBasePrivate + winnerRecord[0]);

            const reportContent1 = (await axios.get(ipfsBasePrivate + winnerRecord[0])).data;
            const reportUrl = JSON.parse(JSON.stringify(reportContent1))["reportPacioli"];
            // console.log("reportUrl:", reportUrl);

            // let url = reportUrl.replace("Pacioli.json", '')
            console.log("pacioli url", reportUrl)

            if (reportUrl != "https://auditchain.infura-ipfs.io/ipfs/Pacioli-failed")

                await verifyCat(reportUrl);


            // if (!valid)
            //     validations.push({
            //         txId: values.transactionHash,
            //         client: ethAddress,
            //         cohort: undefined,
            //         consensus: values.consensus,
            //         validationHash: values.validationHash,
            //         timeExecuted: convertTimestamp(values.timeExecuted),
            //         // quorum: parseInt(quorum._hex, 16),
            //         validated: values.timeExecuted === '0' ? 'in progress' : 'executed',
            //         url: values.url.replace('/AuditchainMetadataReport.json', ''),
            //         documentHash: values.documentHash
            //     });
        }
        // validations.sort((a, b) => new Date(b.timeExecuted) - new Date(a.timeExecuted));
        // return [validations, true];
    } catch (err) {
        console.log(`Error:${err}`);
    }
}

async function getIpfsUrl(reportPacioli) {
    let result = null
    try {
        //console.log('reportPacioli - getIpfsUrl', reportPacioli)
        result = await axios(reportPacioli);

        // console.log("errorContext", result.data);
        return result.data.ipfs;
    } catch (error) {
        console.log('Error - getIpfsUrl', error);
        return null;
    }
}


async function verifyCat(url) {



    let urlTrace = await getIpfsUrl(url);
    console.log("urlTrace:", urlTrace);

    let pacioliTrace = await getPacioliTrace(urlTrace);
    console.log(pacioliTrace.friendlyName);
    console.log("url", pacioliTrace.report);
    console.log(pacioliTrace.isValid);



    let report = await axios.get(pacioliTrace.report);
    // console.log(report.data);

    xmlDoc = parser.parseFromString(report.data, "xml");


    let node1 = xmlDoc.getElementsByTagName("identifier")[0];

    y = node1.childNodes;
    z = y.nodeValue;

    // let att = node1[0].getAttribute('scheme');

    console.log("cik",y[0].text);

    let entityData = await axios.get("https://dev.auditchain.finance/api/list_reporting_styles?cik=" + y[0].text);

    console.log(entityData.data.address);


    // const pathArray = pacioliTrace.report.split("/");
    // const ACanalysisId = pathArray[6];
    // console.log("cik", ACanalysisId);



    const { dashboard } = pacioliTrace;


    const { calculations, disclosureChecks, fac, modelStructure, noOtherErrors, nonFACassertions, subTypes, xbrl, disclosureMecanics } = dashboard;
    console.log("fac:", fac);

    if (fac)
        facTrue++;
    else
        facFalse++;

    if (subTypes)
        subTypesTrue++;
    else
        subTypesFalse++;

    console.log("subTypes true total:", subTypesTrue);
    console.log("SubTypes false total:", subTypesFalse);

    console.log("fac true total:", facTrue);
    console.log("fac false total:", facFalse);

    return fac

    // console.log(dashboard.fac);
}

async function start() {


    let val = await getValidationHistory("0x4afd87F1f8141D7D35C8c4d04695cf5A5eC62A56");
    // console.log(val);
    process.exit();


}

start();