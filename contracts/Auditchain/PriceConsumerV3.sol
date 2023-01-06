pragma solidity =0.8.0;
// SPDX-License-Identifier: MIT

import "./AggregatorV3Interface.sol";



contract PriceConsumerV3 {

    AggregatorV3Interface internal priceFeed;

    /**
     * Network: Mumbai Testnet 
     * Aggregator: MATIC/USD
     * Address: 0xd0D5e3DB44DE05E9F294BB0a3bEEaF030DE24Ada
     * Network: Polygon
     * Address main: 0xAB594600376Ec9fD91F8e885dADF0CE036862dE0
     */
    constructor(){
        // replace address for Mumbai or Main Polygon
        priceFeed = AggregatorV3Interface(0xd0D5e3DB44DE05E9F294BB0a3bEEaF030DE24Ada);
    }

    /**
     * Returns the latest price
     */
    function getLatestPrice() public view returns (int) {

        // TODO: uncomment this for deployment 
        // (
        //     , 
        //     int price,
        //     ,
        //     ,
            
        // ) = priceFeed.latestRoundData();
        // return price;

    // TODO: comment this for deployment. Use this only for running tests.     
    return 134225467;
    }

}