// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import { IERC20, SafeERC20 } from "openzeppelin-contracts/token/ERC20/utils/SafeERC20.sol";

import { ICurveStableSwap } from "src/interfaces/external/curve/ICurveStableSwap.sol";
import { ISyncSwapper } from "src/interfaces/swapper/ISyncSwapper.sol";

// TODO: access control??
contract CurveV2Swap is ISyncSwapper {
    using SafeERC20 for IERC20;

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
