// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import { ISyncSwapper } from "./ISyncSwapper.sol";

interface ISwapRouter {
    struct SwapData {
        address token;
        address pool;
        ISyncSwapper swapper;
        bytes data;
    }

    error SwapFailedDuetoInsufficientBuy();
    error SwapRouteLookupFailed();

    function swapForQuote(
        address assetToken,
        uint256 sellAmount,
        address quoteToken,
        uint256 minBuyAmount
    ) external returns (uint256);
}
