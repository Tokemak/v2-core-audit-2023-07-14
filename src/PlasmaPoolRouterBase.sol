// forked from https://github.com/fei-protocol/ERC4626/blob/main/src/ERC4626RouterBase.sol
// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.17;

import { IERC20, SafeERC20, Address } from "openzeppelin-contracts/token/ERC20/utils/SafeERC20.sol";
import { IPlasmaPool, IPlasmaPoolRouterBase } from "./interfaces/pool/IPlasmaPoolRouterBase.sol";

import { SelfPermit } from "./utils/SelfPermit.sol";
import { Multicall } from "./utils/Multicall.sol";
// import { PeripheryPayments, IWETH9 } from "./external/PeripheryPayments.sol";

import { IWETH9 } from "./interfaces/utils/IWETH9.sol";

/// @title PlasmaPool Router Base Contract
abstract contract PlasmaPoolRouterBase is IPlasmaPoolRouterBase, SelfPermit, Multicall /*, PeripheryPayments */ {
    using SafeERC20 for IERC20;

    IWETH9 public immutable weth9;

    error InvalidAsset();

    constructor(address _weth9) {
        weth9 = IWETH9(_weth9);
    }

    /// @inheritdoc IPlasmaPoolRouterBase
    function mint(
        IPlasmaPool pool,
        address to,
        uint256 shares,
        uint256 maxAmountIn
    ) public payable virtual override returns (uint256 amountIn) {
        // handle possible eth
        _processEthIn(pool);

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
        // handle possible eth
        _processEthIn(pool);

        if ((sharesOut = pool.deposit(amount, to)) < minSharesOut) {
            revert MinSharesError();
        }
    }

    /// @inheritdoc IPlasmaPoolRouterBase
    function withdraw(
        IPlasmaPool pool,
        address to,
        uint256 amount,
        uint256 maxSharesOut,
        bool unwrapWETH
    ) public payable virtual override returns (uint256 sharesOut) {
        address destination = unwrapWETH ? address(this) : to;

        if ((sharesOut = pool.withdraw(amount, destination, msg.sender)) > maxSharesOut) {
            revert MaxSharesError();
        }

        if (unwrapWETH) {
            _processWethOut(to);
        }
    }

    /// @inheritdoc IPlasmaPoolRouterBase
    function redeem(
        IPlasmaPool pool,
        address to,
        uint256 shares,
        uint256 minAmountOut,
        bool unwrapWETH
    ) public payable virtual override returns (uint256 amountOut) {
        address destination = unwrapWETH ? address(this) : to;

        if ((amountOut = pool.redeem(shares, destination, msg.sender)) < minAmountOut) {
            revert MinAmountError();
        }

        if (unwrapWETH) {
            _processWethOut(to);
        }
    }

    function _processEthIn(IPlasmaPool pool) internal {
        // if any eth sent, wrap it first
        if (msg.value > 0) {
            // if asset is not weth, revert
            if (address(pool.asset()) != address(weth9)) {
                revert InvalidAsset();
            }

            // wrap eth
            weth9.deposit{value: msg.value}();
        }
    }

    function _processWethOut(address to) internal {
        uint256 balanceWETH9 = weth9.balanceOf(address(this));

        if (balanceWETH9 > 0) {
            weth9.withdraw(balanceWETH9);
            Address.sendValue(payable(to), balanceWETH9);
        }
    }
}
