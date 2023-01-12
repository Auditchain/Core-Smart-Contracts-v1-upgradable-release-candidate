
const BN = require ("bn.js");

const IERC20 = artifacts.require("IERC20");
const TestUniswap = artifacts.require("TestUniswap");


contract ("TestUniswap", (accounts) => {

    const USDC = "0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174";
    const USDC_WHALE = "0xf977814e90da44bfa03b6295a0616a897441acec";
    const AUDT = "0xB90cb79B72EB10c39CbDF86e50B1C89F6a235f2e";


    const WHALE = USDC_WHALE;
    const AMOUNT_IN = new BN(10).pow(new BN(18)).mul(new BN(1));
    // const AMOUNT_IN =  "10000000000"
    const AMOUNT_OUT_MIN = 1;
    const TOKEN_IN = USDC;
    const TOKEN_OUT = AUDT;
    const TO = accounts[0];

    it("should swap", async () => {

        const tokenIn = await IERC20.at(TOKEN_IN);

        const tokenOut = await IERC20.at(TOKEN_OUT);
        const testUniswap = await TestUniswap.new();

        await tokenIn.approve(testUniswap.address, AMOUNT_IN, {from: WHALE});
        await testUniswap.swap(
            tokenIn.address,
            tokenOut.address,
            AMOUNT_IN,
            AMOUNT_OUT_MIN,
            TO,
            {from:WHALE}

        );

        console.log(`out ${await tokenOut.balanceOf(TO)}`);
    })

})

