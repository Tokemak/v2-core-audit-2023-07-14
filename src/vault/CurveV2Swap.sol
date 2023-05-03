// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import { Ownable } from "openzeppelin-contracts/access/Ownable.sol";
import "openzeppelin-contracts/access/AccessControl.sol";
import "openzeppelin-contracts/token/ERC20/IERC20.sol";
import "openzeppelin-contracts/security/ReentrancyGuard.sol";

import { ICurveStableSwap, IPool } from "../interfaces/external/curve/ICurveStableSwap.sol";
import "../interfaces/swapper/ISyncSwapper.sol";

import { console2 as console } from "forge-std/console2.sol";

contract CurveV2Swap is ISyncSwapper, Ownable {
    constructor() { }

    error PoolTokensMismatch();
    error ApprovalFailed();

    /// @inheritdoc ISyncSwapper
    function swap(
        address poolAddress,
        address sellTokenAddress,
        uint256 sellAmount,
        address buyTokenAddress,
        uint256 minBuyAmount
    ) external override returns (uint256 actualBuyAmount) {
        ICurveStableSwap pool = ICurveStableSwap(poolAddress);
        int128 sellIndex;
        int128 buyIndex;

        if (sellTokenAddress == pool.coins(0)) {
            if (buyTokenAddress != pool.coins(1)) revert PoolTokensMismatch();
            sellIndex = 0;
            buyIndex = 1;
        } else {
            if (buyTokenAddress != pool.coins(0)) revert PoolTokensMismatch();
            if (sellTokenAddress != pool.coins(1)) revert PoolTokensMismatch();
            sellIndex = 1;
            buyIndex = 0;
        }

        // approval for the pool to sell token
        if (!IERC20(sellTokenAddress).approve(poolAddress, sellAmount)) {
            revert ApprovalFailed();
        }

        return pool.exchange(sellIndex, buyIndex, sellAmount, minBuyAmount);
    }
}
