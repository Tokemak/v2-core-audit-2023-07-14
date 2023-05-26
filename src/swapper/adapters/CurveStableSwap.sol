// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import { IERC20, SafeERC20 } from "openzeppelin-contracts/token/ERC20/utils/SafeERC20.sol";

import { ICurveStableSwap } from "src/interfaces/external/curve/ICurveStableSwap.sol";
import { ISyncSwapper } from "src/interfaces/swapper/ISyncSwapper.sol";
import { ISwapRouter } from "src/interfaces/swapper/ISwapRouter.sol";
import { BaseAdapter } from "src/swapper/adapters/BaseAdapter.sol";

// TODO: access control??
contract CurveV2Swap is BaseAdapter, ISyncSwapper {
    using SafeERC20 for IERC20;

    constructor(address router) BaseAdapter(router) { }

    /// @inheritdoc ISyncSwapper
    function validate(ISwapRouter.SwapData memory swapData) external view override {
        (uint256 sellIndex, uint256 buyIndex) = abi.decode(swapData.data, (uint256, uint256));
        ICurveStableSwap pool = ICurveStableSwap(swapData.pool);
        address sellAddress = pool.coins(sellIndex);
        address buyAddress = pool.coins(buyIndex);
        if (sellAddress != swapData.token && buyAddress != swapData.token) revert DataMismatch();
    }

    /// @inheritdoc ISyncSwapper
    function swap(
        address poolAddress,
        address sellTokenAddress,
        uint256 sellAmount,
        address,
        uint256 minBuyAmount,
        bytes memory data
    ) external override returns (uint256 actualBuyAmount) {
        (int128 sellIndex, int128 buyIndex) = abi.decode(data, (int128, int128));
        ICurveStableSwap pool = ICurveStableSwap(poolAddress);

        IERC20(sellTokenAddress).safeApprove(poolAddress, sellAmount);

        return pool.exchange(sellIndex, buyIndex, sellAmount, minBuyAmount);
    }
}
