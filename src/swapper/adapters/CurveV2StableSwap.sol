// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2023 Tokemak Foundation. All rights reserved.
pragma solidity 0.8.17;

import { IERC20, SafeERC20 } from "openzeppelin-contracts/token/ERC20/utils/SafeERC20.sol";

import { Errors } from "src/utils/Errors.sol";
import { ICurveV2StableSwap } from "src/interfaces/external/curve/ICurveV2StableSwap.sol";
import { ISyncSwapper } from "src/interfaces/swapper/ISyncSwapper.sol";
import { ISwapRouter } from "src/interfaces/swapper/ISwapRouter.sol";
import { BaseAdapter } from "src/swapper/adapters/BaseAdapter.sol";

contract CurveV2StableSwap is BaseAdapter, ISyncSwapper {
    using SafeERC20 for IERC20;

    constructor(address _router) BaseAdapter(_router) { }

    /// @inheritdoc ISyncSwapper
    function validate(address fromAddress, ISwapRouter.SwapData memory swapData) external view override {
        (uint256 sellIndex, uint256 buyIndex) = abi.decode(swapData.data, (uint256, uint256));

        ICurveV2StableSwap pool = ICurveV2StableSwap(swapData.pool);

        address sellAddress = pool.coins(sellIndex);
        address buyAddress = pool.coins(buyIndex);

        // verify that the fromAddress and toAddress are in the pool
        if (fromAddress != sellAddress) revert DataMismatch("fromAddress");
        if (swapData.token != buyAddress) revert DataMismatch("toAddress");
    }

    /// @inheritdoc ISyncSwapper
    function swap(
        address poolAddress,
        address sellTokenAddress,
        uint256 sellAmount,
        address,
        uint256 minBuyAmount,
        bytes memory data
    ) external override onlyRouter returns (uint256 actualBuyAmount) {
        (uint256 sellIndex, uint256 buyIndex) = abi.decode(data, (uint256, uint256));
        ICurveV2StableSwap pool = ICurveV2StableSwap(poolAddress);

        IERC20(sellTokenAddress).safeApprove(poolAddress, sellAmount);

        return pool.exchange(sellIndex, buyIndex, sellAmount, minBuyAmount);
    }
}
