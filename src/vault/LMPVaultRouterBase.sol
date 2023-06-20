// forked from https://github.com/fei-protocol/ERC4626/blob/main/src/ERC4626RouterBase.sol
// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.17;

import { IERC20, SafeERC20, Address } from "openzeppelin-contracts/token/ERC20/utils/SafeERC20.sol";
import { ILMPVault, ILMPVaultRouterBase } from "src/interfaces/vault/ILMPVaultRouterBase.sol";

import { SelfPermit } from "src/utils/SelfPermit.sol";
import { Multicall } from "src/utils/Multicall.sol";

import { IWETH9 } from "src/interfaces/utils/IWETH9.sol";

/// @title LMPVault Router Base Contract
abstract contract LMPVaultRouterBase is ILMPVaultRouterBase, SelfPermit, Multicall /*, PeripheryPayments */ {
    using SafeERC20 for IERC20;

    IWETH9 public immutable weth9;

    error InvalidAsset();

    constructor(address _weth9) {
        weth9 = IWETH9(_weth9);
    }

    /// @inheritdoc ILMPVaultRouterBase
    function mint(
        ILMPVault vault,
        address to,
        uint256 shares,
        uint256 maxAmountIn
    ) public payable virtual override returns (uint256 amountIn) {
        // handle possible eth
        _processEthIn(vault);

        if ((amountIn = vault.mint(shares, to)) > maxAmountIn) {
            revert MaxAmountError();
        }
    }

    /// @inheritdoc ILMPVaultRouterBase
    function deposit(
        ILMPVault vault,
        address to,
        uint256 amount,
        uint256 minSharesOut
    ) public payable virtual override returns (uint256 sharesOut) {
        // handle possible eth
        _processEthIn(vault);
        IERC20(vault.asset()).safeApprove(address(vault), amount);
        if ((sharesOut = vault.deposit(amount, to)) < minSharesOut) {
            revert MinSharesError();
        }
    }

    /// @inheritdoc ILMPVaultRouterBase
    function withdraw(
        ILMPVault vault,
        address to,
        uint256 amount,
        uint256 maxSharesOut,
        bool unwrapWETH
    ) public virtual override returns (uint256 sharesOut) {
        address destination = unwrapWETH ? address(this) : to;

        if ((sharesOut = vault.withdraw(amount, destination, msg.sender)) > maxSharesOut) {
            revert MaxSharesError();
        }

        if (unwrapWETH) {
            _processWethOut(to);
        }
    }

    /// @inheritdoc ILMPVaultRouterBase
    function redeem(
        ILMPVault vault,
        address to,
        uint256 shares,
        uint256 minAmountOut,
        bool unwrapWETH
    ) public virtual override returns (uint256 amountOut) {
        address destination = unwrapWETH ? address(this) : to;

        if ((amountOut = vault.redeem(shares, destination, msg.sender)) < minAmountOut) {
            revert MinAmountError();
        }

        if (unwrapWETH) {
            _processWethOut(to);
        }
    }

    function _processEthIn(ILMPVault vault) internal {
        // if any eth sent, wrap it first
        if (msg.value > 0) {
            // if asset is not weth, revert
            if (address(vault.asset()) != address(weth9)) {
                revert InvalidAsset();
            }

            // wrap eth
            weth9.deposit{ value: msg.value }();
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
