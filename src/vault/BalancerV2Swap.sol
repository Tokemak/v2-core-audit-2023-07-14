// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import { Ownable } from "openzeppelin-contracts/access/Ownable.sol";
import "../interfaces/external/balancer/IVault.sol";
import "../interfaces/external/balancer/IAsset.sol";
import "../interfaces/external/balancer/IBasePool.sol";

import "../interfaces/swapper/ISyncSwapper.sol";

contract BalancerV2Swap is ISyncSwapper, Ownable {
    IVault public immutable vault;

    error PoolsMustMatchLPTokens();
    error PoolNotFound();
    error ApprovalFailed();

    constructor(address balancerVault) {
        if (balancerVault == address(0)) revert("VaultIsZero");
        vault = IVault(balancerVault);
    }

    /// @inheritdoc ISyncSwapper
    function swap(
        address pool,
        address sellTokenAddress,
        uint256 sellAmount,
        address buyTokenAddress,
        uint256 minBuyAmount
    ) external override returns (uint256 actualBuyAmount) {
        bytes32 poolId = IBasePool(pool).getPoolId();
        // Check if poolId is 0
        if (poolId == 0) revert("PoolIdisZero");

        IVault.SingleSwap memory singleSwap = IVault.SingleSwap(
            poolId, IVault.SwapKind.GIVEN_IN, IAsset(sellTokenAddress), IAsset(buyTokenAddress), sellAmount, ""
        );

        IVault.FundManagement memory funds = IVault.FundManagement(address(this), false, payable(address(this)), false);

        // approve vault to use sell token
        if (!IERC20(sellTokenAddress).approve(address(vault), sellAmount)) {
            revert ApprovalFailed();
        }

        // last argument is the deadline
        return vault.swap(singleSwap, funds, minBuyAmount, 999_999_999_999_999_999);
    }
}
