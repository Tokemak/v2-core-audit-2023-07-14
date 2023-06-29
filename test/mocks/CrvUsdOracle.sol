// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2023 Tokemak Foundation. All rights reserved.

pragma solidity 0.8.17;

// solhint-disable func-name-mixedcase
// solhint-disable const-name-snakecase

import { IAggregatorV3Interface } from "src/interfaces/external/chainlink/IAggregatorV3Interface.sol";
import { ICurveStableSwapNG } from "src/interfaces/external/curve/ICurveStableSwapNG.sol";

import { ISystemRegistry } from "src/interfaces/ISystemRegistry.sol";
import { SystemComponent } from "src/SystemComponent.sol";

/**
 * @notice Chainlink does not have a price feed for crvUSD, which is needed in order to price
 *      the majority of Curve ng Stableswap pools.  This contract takes the oracle price from two
 *      of the crvUSD pools and averages it to get a price for crvUSD.
 *
 * @dev Do not use this contract in production.
 */
contract CrvUsdOracle is SystemComponent {
    ICurveStableSwapNG public constant crvUsdUsdcPool = ICurveStableSwapNG(0x4DEcE678ceceb27446b35C672dC7d61F30bAD69E);
    ICurveStableSwapNG public constant crvUsdUsdtPool = ICurveStableSwapNG(0x390f3595bCa2Df7d23783dFd126427CCeb997BF4);

    IAggregatorV3Interface public immutable usdcUsdPriceFeed;
    IAggregatorV3Interface public immutable usdtUsdPriceFeed;
    IAggregatorV3Interface public immutable ethInUsdPriceFeed;

    constructor(
        ISystemRegistry _systemRegistry,
        IAggregatorV3Interface _usdcUsdPriceFeed,
        IAggregatorV3Interface _usdtUsdPriceFeed,
        IAggregatorV3Interface _ethInUsdPriceFeed
    ) SystemComponent(_systemRegistry) {
        usdcUsdPriceFeed = _usdcUsdPriceFeed;
        usdtUsdPriceFeed = _usdtUsdPriceFeed;
        ethInUsdPriceFeed = _ethInUsdPriceFeed;
    }

    function getPriceInEth(address) external view returns (uint256) {
        // Use Curve pool price oracles to get pricing for pool.
        uint256 crvUsdInUsdc = crvUsdUsdcPool.price_oracle();
        uint256 crvUsdInUsdt = crvUsdUsdtPool.price_oracle();

        // Get price of usdc, usdt, eth in usd.
        (, int256 usdcInUsd,,,) = usdcUsdPriceFeed.latestRoundData();
        (, int256 usdtInUsd,,,) = usdtUsdPriceFeed.latestRoundData();
        (, int256 ethInUsd,,,) = ethInUsdPriceFeed.latestRoundData();

        // Get price of eth in usdc and usdt.
        uint256 ethInUsdc = (uint256(ethInUsd) * 10 ** 18) / uint256(usdcInUsd);
        uint256 ethInUsdt = (uint256(ethInUsd) * 10 ** 18) / uint256(usdtInUsd);

        // Get price of crvUsd in eth by pool.
        uint256 crvUsdUsdcPoolInEth = (crvUsdInUsdc * 10 ** 18) / ethInUsdc;
        uint256 crvUsdUsdtPoolInEth = (crvUsdInUsdt * 10 ** 18) / ethInUsdt;

        // Return average of price in Eth from each pool
        return (crvUsdUsdcPoolInEth + crvUsdUsdtPoolInEth) / 2;
    }
}
