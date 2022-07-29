// SPDX-License-Identifier: Unlicensed
pragma solidity ^0.8.7;

import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

library RateConverter {
    function getPrice(AggregatorV3Interface priceFeed) internal view returns (uint256) {
        (, int256 answer, , ,) = priceFeed.latestRoundData();
        return uint256(answer);
    }

    /* Return value in cents */
    function getConversionRate(uint256 croAmount, AggregatorV3Interface priceFeed) internal view returns (uint256 croAmountInUSD) {
        uint256 ethPrice = getPrice(priceFeed);
        croAmountInUSD = (ethPrice * croAmount) / 1e24;
        return croAmountInUSD;
    }
}
