// forked from https://github.com/fei-protocol/ERC4626/blob/main/src/ERC4626Router.sol
// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.17;

import "./PlasmaPoolRouterBase.sol";

// import {ENSReverseRecord} from "./utils/ENSReverseRecord.sol";
import "./interfaces/pool/IPlasmaPoolRouter.sol";

import "openzeppelin-contracts/token/ERC20/IERC20.sol";
import "openzeppelin-contracts/token/ERC20/utils/SafeERC20.sol";

/// @title ERC4626Router contract
contract PlasmaPoolRouter is IPlasmaPoolRouter, PlasmaPoolRouterBase /*, ENSReverseRecord */ {
    using SafeERC20 for IERC20;

    constructor( /* string memory name, IWETH9 weth, ENSReverseRecord(name) PeripheryPayments(weth) */ ) { }

    // For the below, no approval needed, assumes pool is already max approved

    /// @inheritdoc IPlasmaPoolRouter
    function depositToPool(
        IPlasmaPool pool,
        address to,
        uint256 amount,
        uint256 minSharesOut
    ) external payable override returns (uint256 sharesOut) {
        _pullToken(IERC20(pool.asset()), amount, address(this));
        return deposit(pool, to, amount, minSharesOut);
    }

    /// @inheritdoc IPlasmaPoolRouter
    function withdrawToDeposit(
        IPlasmaPool fromPool,
        IPlasmaPool toPool,
        address to,
        uint256 amount,
        uint256 maxSharesIn,
        uint256 minSharesOut
    ) external payable override returns (uint256 sharesOut) {
        withdraw(fromPool, address(this), amount, maxSharesIn);
        return deposit(toPool, to, amount, minSharesOut);
    }

    /// @inheritdoc IPlasmaPoolRouter
    function redeemToDeposit(
        IPlasmaPool fromPool,
        IPlasmaPool toPool,
        address to,
        uint256 shares,
        uint256 minSharesOut
    ) external payable override returns (uint256 sharesOut) {
        // amount out passes through so only one slippage check is needed
        uint256 amount = redeem(fromPool, address(this), shares, 0);
        return deposit(toPool, to, amount, minSharesOut);
    }

    /// @inheritdoc IPlasmaPoolRouter
    function depositMax(
        IPlasmaPool pool,
        address to,
        uint256 minSharesOut
    ) public payable override returns (uint256 sharesOut) {
        IERC20 asset = IERC20(pool.asset());
        uint256 assetBalance = asset.balanceOf(msg.sender);
        uint256 maxDeposit = pool.maxDeposit(to);
        uint256 amount = maxDeposit < assetBalance ? maxDeposit : assetBalance;
        _pullToken(asset, amount, address(this));
        return deposit(pool, to, amount, minSharesOut);
    }

    /// @inheritdoc IPlasmaPoolRouter
    function redeemMax(
        IPlasmaPool pool,
        address to,
        uint256 minAmountOut
    ) public payable override returns (uint256 amountOut) {
        uint256 shareBalance = pool.balanceOf(msg.sender);
        uint256 maxRedeem = pool.maxRedeem(msg.sender);
        uint256 amountShares = maxRedeem < shareBalance ? maxRedeem : shareBalance;
        return redeem(pool, to, amountShares, minAmountOut);
    }

    function _pullToken(IERC20 token, uint256 amount, address recipient) public payable {
        token.safeTransferFrom(msg.sender, recipient, amount);
    }
}
