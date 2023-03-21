// forked from https://github.com/fei-protocol/ERC4626/blob/main/src/ERC4626Router.sol
// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.17;

import { IPlasmaVaultRouterBase, PlasmaVaultRouterBase } from "./PlasmaVaultRouterBase.sol";

import { IPlasmaVault, IPlasmaVaultRouter } from "src/interfaces/vault/IPlasmaVaultRouter.sol";

import { IERC20, SafeERC20 } from "openzeppelin-contracts/token/ERC20/utils/SafeERC20.sol";

import { IWETH9 } from "src/interfaces/utils/IWETH9.sol";

/// @title ERC4626Router contract
contract PlasmaVaultRouter is IPlasmaVaultRouter, PlasmaVaultRouterBase {
    using SafeERC20 for IERC20;

    constructor(address _weth9) PlasmaVaultRouterBase(_weth9) { }

    // For the below, no approval needed, assumes vault is already max approved

    /// @inheritdoc IPlasmaVaultRouter
    function depositToPool(
        IPlasmaVault vault,
        address to,
        uint256 amount,
        uint256 minSharesOut
    ) external override returns (uint256 sharesOut) {
        _pullToken(IERC20(vault.asset()), amount, address(this));
        return deposit(vault, to, amount, minSharesOut);
    }

    /// @inheritdoc IPlasmaVaultRouter
    function withdrawToDeposit(
        IPlasmaVault fromPool,
        IPlasmaVault toPool,
        address to,
        uint256 amount,
        uint256 maxSharesIn,
        uint256 minSharesOut
    ) external override returns (uint256 sharesOut) {
        withdraw(fromPool, address(this), amount, maxSharesIn, false);
        return deposit(toPool, to, amount, minSharesOut);
    }

    /// @inheritdoc IPlasmaVaultRouter
    function redeemToDeposit(
        IPlasmaVault fromPool,
        IPlasmaVault toPool,
        address to,
        uint256 shares,
        uint256 minSharesOut
    ) external override returns (uint256 sharesOut) {
        // amount out passes through so only one slippage check is needed
        uint256 amount = redeem(fromPool, address(this), shares, 0, false);
        return deposit(toPool, to, amount, minSharesOut);
    }

    /// @inheritdoc IPlasmaVaultRouter
    function depositMax(
        IPlasmaVault vault,
        address to,
        uint256 minSharesOut
    ) public override returns (uint256 sharesOut) {
        IERC20 asset = IERC20(vault.asset());
        uint256 assetBalance = asset.balanceOf(msg.sender);
        uint256 maxDeposit = vault.maxDeposit(to);
        uint256 amount = maxDeposit < assetBalance ? maxDeposit : assetBalance;
        _pullToken(asset, amount, address(this));
        return deposit(vault, to, amount, minSharesOut);
    }

    /// @inheritdoc IPlasmaVaultRouter
    function redeemMax(
        IPlasmaVault vault,
        address to,
        uint256 minAmountOut
    ) public override returns (uint256 amountOut) {
        uint256 shareBalance = vault.balanceOf(msg.sender);
        uint256 maxRedeem = vault.maxRedeem(msg.sender);
        uint256 amountShares = maxRedeem < shareBalance ? maxRedeem : shareBalance;
        return redeem(vault, to, amountShares, minAmountOut, false);
    }

    function _pullToken(IERC20 token, uint256 amount, address recipient) public payable {
        token.safeTransferFrom(msg.sender, recipient, amount);
    }
}
