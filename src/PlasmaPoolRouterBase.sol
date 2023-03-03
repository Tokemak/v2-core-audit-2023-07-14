// forked from https://github.com/fei-protocol/ERC4626/blob/main/src/ERC4626RouterBase.sol
// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.17;

import "openzeppelin-contracts/token/ERC20/IERC20.sol";
import "openzeppelin-contracts/token/ERC20/utils/SafeERC20.sol";
import "./interfaces/pool/IPlasmaPool.sol";
import "./interfaces/pool/IPlasmaPoolRouterBase.sol";

import { SelfPermit } from "./utils/SelfPermit.sol";
import { Multicall } from "./utils/Multicall.sol";
// import { PeripheryPayments, IWETH9 } from "./external/PeripheryPayments.sol";

/// @title PlasmaPool Router Base Contract
abstract contract PlasmaPoolRouterBase is IPlasmaPoolRouterBase, SelfPermit, Multicall /*, PeripheryPayments */ {
    using SafeERC20 for IERC20;

    /// @inheritdoc IPlasmaPoolRouterBase
    function mint(
        IPlasmaPool pool,
        address to,
        uint256 shares,
        uint256 maxAmountIn
    ) public payable virtual override returns (uint256 amountIn) {
        if ((amountIn = pool.mint(shares, to)) > maxAmountIn) {
            revert MaxAmountError();
        }
    }

    /// @inheritdoc IPlasmaPoolRouterBase
    function deposit(
        IPlasmaPool pool,
        address to,
        uint256 amount,
        uint256 minSharesOut
    ) public payable virtual override returns (uint256 sharesOut) {
        if ((sharesOut = pool.deposit(amount, to)) < minSharesOut) {
            revert MinSharesError();
        }
    }

    /// @inheritdoc IPlasmaPoolRouterBase
    function withdraw(
        IPlasmaPool pool,
        address to,
        uint256 amount,
        uint256 maxSharesOut
    ) public payable virtual override returns (uint256 sharesOut) {
        if ((sharesOut = pool.withdraw(amount, to, msg.sender)) > maxSharesOut) {
            revert MaxSharesError();
        }
    }

    /// @inheritdoc IPlasmaPoolRouterBase
    function redeem(
        IPlasmaPool pool,
        address to,
        uint256 shares,
        uint256 minAmountOut
    ) public payable virtual override returns (uint256 amountOut) {
        if ((amountOut = pool.redeem(shares, to, msg.sender)) < minAmountOut) {
            revert MinAmountError();
        }
    }
}
