// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >=0.8.7;

import { IPlasmaVault } from "./IPlasmaVault.sol";

/**
 * @title PlasmaVault Router Base Interface
 * @notice A canonical router between PlasmaVaults
 *
 * The base router is a multicall style router inspired by Uniswap v3 with built-in features for permit,
 * WETH9 wrap/unwrap, and ERC20 token pulling/sweeping/approving. It includes methods for the four mutable
 * ERC4626 functions deposit/mint/withdraw/redeem as well.
 *
 * These can all be arbitrarily composed using the multicall functionality of the router.
 *
 * NOTE the router is capable of pulling any approved token from your wallet. This is only possible when
 * your address is msg.sender, but regardless be careful when interacting with the router or ERC4626 Vaults.
 * The router makes no special considerations for unique ERC20 implementations such as fee on transfer.
 * There are no built in protections for unexpected behavior beyond enforcing the minSharesOut is received.
 */
interface IPlasmaVaultRouterBase {
    /// @notice thrown when amount of assets received is below the min set by caller
    error MinAmountError();

    /// @notice thrown when amount of shares received is below the min set by caller
    error MinSharesError();

    /// @notice thrown when amount of assets received is above the max set by caller
    error MaxAmountError();

    /// @notice thrown when amount of shares received is above the max set by caller
    error MaxSharesError();

    /**
     * @notice mint `shares` from an ERC4626 vault.
     * @param vault The PlasmaVault to mint shares from.
     * @param to The destination of ownership shares.
     * @param shares The amount of shares to mint from `vault`.
     * @param maxAmountIn The max amount of assets used to mint.
     * @return amountIn the amount of assets used to mint by `to`.
     * @dev throws MaxAmountError
     */
    function mint(
        IPlasmaVault vault,
        address to,
        uint256 shares,
        uint256 maxAmountIn
    ) external payable returns (uint256 amountIn);

    /**
     * @notice deposit `amount` to an ERC4626 vault.
     * @param vault The PlasmaVaultt to deposit assets to.
     * @param to The destination of ownership shares.
     * @param amount The amount of assets to deposit to `vault`.
     * @param minSharesOut The min amount of `vault` shares received by `to`.
     * @return sharesOut the amount of shares received by `to`.
     * @dev throws MinSharesError
     */
    function deposit(
        IPlasmaVault vault,
        address to,
        uint256 amount,
        uint256 minSharesOut
    ) external payable returns (uint256 sharesOut);

    /**
     * @notice withdraw `amount` from an ERC4626 vault.
     * @param vault The PlasmaVault to withdraw assets from.
     * @param to The destination of assets.
     * @param amount The amount of assets to withdraw from vault.
     * @param minSharesOut The min amount of shares received by `to`.
     * @param unwrapWETH If true, unwrap WETH9 to ETH before sending to `to`.
     * @return sharesOut the amount of shares received by `to`.
     * @dev throws MaxSharesError
     */
    function withdraw(
        IPlasmaVault vault,
        address to,
        uint256 amount,
        uint256 minSharesOut,
        bool unwrapWETH
    ) external returns (uint256 sharesOut);

    /**
     * @notice redeem `shares` shares from a PlasmaVault
     * @param vault The PlasmaVault to redeem shares from.
     * @param to The destination of assets.
     * @param shares The amount of shares to redeem from vault.
     * @param minAmountOut The min amount of assets received by `to`.
     * @param unwrapWETH If true, unwrap WETH9 to ETH before sending to `to`.
     * @return amountOut the amount of assets received by `to`.
     * @dev throws MinAmountError
     */
    function redeem(
        IPlasmaVault vault,
        address to,
        uint256 shares,
        uint256 minAmountOut,
        bool unwrapWETH
    ) external returns (uint256 amountOut);
}
