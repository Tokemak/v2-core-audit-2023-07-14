// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.17;

import "./IPlasmaVault.sol";

/**
 * @title IPlasmaVaultRouter Interface
 * @notice Extends the IPlasmaVaultRouterBase with specific flows to save gas
 */
interface IPlasmaVaultRouter {
    /**
     * ***************************   Deposit ********************************
     */

    /**
     * @notice deposit `amount` to a PlasmaVault.
     * @param vault The PlasmaVault to deposit assets to.
     * @param to The destination of ownership shares.
     * @param amount The amount of assets to deposit to `vault`.
     * @param minSharesOut The min amount of `vault` shares received by `to`.
     * @return sharesOut the amount of shares received by `to`.
     * @dev throws MinSharesError
     */
    function depositToPool(
        IPlasmaVault vault,
        address to,
        uint256 amount,
        uint256 minSharesOut
    ) external returns (uint256 sharesOut);

    /**
     * @notice deposit max assets to a PlasmaVault.
     * @param vault The PlasmaVault to deposit assets to.
     * @param to The destination of ownership shares.
     * @param minSharesOut The min amount of `vault` shares received by `to`.
     * @return sharesOut the amount of shares received by `to`.
     * @dev throws MinSharesError
     */
    function depositMax(IPlasmaVault vault, address to, uint256 minSharesOut) external returns (uint256 sharesOut);

    /**
     * *************************   Withdraw   **********************************
     */

    /**
     * @notice withdraw `amount` to a PlasmaVault.
     * @param fromPool The PlasmaVault to withdraw assets from.
     * @param toPool The PlasmaVault to deposit assets to.
     * @param to The destination of ownership shares.
     * @param amount The amount of assets to withdraw from fromPool.
     * @param maxSharesIn The max amount of fromPool shares withdrawn by caller.
     * @param minSharesOut The min amount of toPool shares received by `to`.
     * @return sharesOut the amount of shares received by `to`.
     * @dev throws MaxSharesError, MinSharesError
     */
    function withdrawToDeposit(
        IPlasmaVault fromPool,
        IPlasmaVault toPool,
        address to,
        uint256 amount,
        uint256 maxSharesIn,
        uint256 minSharesOut
    ) external returns (uint256 sharesOut);

    /**
     * *************************   Redeem    ********************************
     */

    /**
     * @notice redeem `shares` to a PlasmaVault.
     * @param fromPool The PlasmaVault to redeem shares from.
     * @param toPool The PlasmaVault to deposit assets to.
     * @param to The destination of ownership shares.
     * @param shares The amount of shares to redeem from fromPool.
     * @param minSharesOut The min amount of toPool shares received by `to`.
     * @return sharesOut the amount of shares received by `to`.
     * @dev throws MinAmountError, MinSharesError
     */
    function redeemToDeposit(
        IPlasmaVault fromPool,
        IPlasmaVault toPool,
        address to,
        uint256 shares,
        uint256 minSharesOut
    ) external returns (uint256 sharesOut);

    /**
     * @notice redeem max shares to a PlasmaVault.
     * @param vault The PlasmaVault to redeem shares from.
     * @param to The destination of assets.
     * @param minAmountOut The min amount of assets received by `to`.
     * @return amountOut the amount of assets received by `to`.
     * @dev throws MinAmountError
     */
    function redeemMax(IPlasmaVault vault, address to, uint256 minAmountOut) external returns (uint256 amountOut);
}
