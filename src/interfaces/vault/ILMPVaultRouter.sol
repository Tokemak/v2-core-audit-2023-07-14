// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.17;

import { ILMPVault } from "./ILMPVault.sol";

/**
 * @title ILMPVaultRouter Interface
 * @notice Extends the ILMPVaultRouterBase with specific flows to save gas
 */
interface ILMPVaultRouter {
    /**
     * ***************************   Deposit ********************************
     */

    /**
     * @notice deposit `amount` to a LMPVault.
     * @param vault The LMPVault to deposit assets to.
     * @param to The destination of ownership shares.
     * @param amount The amount of assets to deposit to `vault`.
     * @param minSharesOut The min amount of `vault` shares received by `to`.
     * @return sharesOut the amount of shares received by `to`.
     * @dev throws MinSharesError
     */
    function depositToVault(
        ILMPVault vault,
        address to,
        uint256 amount,
        uint256 minSharesOut
    ) external returns (uint256 sharesOut);

    /**
     * @notice deposit max assets to a LMPVault.
     * @param vault The LMPVault to deposit assets to.
     * @param to The destination of ownership shares.
     * @param minSharesOut The min amount of `vault` shares received by `to`.
     * @return sharesOut the amount of shares received by `to`.
     * @dev throws MinSharesError
     */
    function depositMax(ILMPVault vault, address to, uint256 minSharesOut) external returns (uint256 sharesOut);

    /**
     * *************************   Withdraw   **********************************
     */

    /**
     * @notice withdraw `amount` to a LMPVault.
     * @param fromVault The LMPVault to withdraw assets from.
     * @param toVault The LMPVault to deposit assets to.
     * @param to The destination of ownership shares.
     * @param amount The amount of assets to withdraw from fromVault.
     * @param maxSharesIn The max amount of fromVault shares withdrawn by caller.
     * @param minSharesOut The min amount of toVault shares received by `to`.
     * @return sharesOut the amount of shares received by `to`.
     * @dev throws MaxSharesError, MinSharesError
     */
    function withdrawToDeposit(
        ILMPVault fromVault,
        ILMPVault toVault,
        address to,
        uint256 amount,
        uint256 maxSharesIn,
        uint256 minSharesOut
    ) external returns (uint256 sharesOut);

    /**
     * *************************   Redeem    ********************************
     */

    /**
     * @notice redeem `shares` to a LMPVault.
     * @param fromVault The LMPVault to redeem shares from.
     * @param toVault The LMPVault to deposit assets to.
     * @param to The destination of ownership shares.
     * @param shares The amount of shares to redeem from fromVault.
     * @param minSharesOut The min amount of toVault shares received by `to`.
     * @return sharesOut the amount of shares received by `to`.
     * @dev throws MinAmountError, MinSharesError
     */
    function redeemToDeposit(
        ILMPVault fromVault,
        ILMPVault toVault,
        address to,
        uint256 shares,
        uint256 minSharesOut
    ) external returns (uint256 sharesOut);

    /**
     * @notice redeem max shares to a LMPVault.
     * @param vault The LMPVault to redeem shares from.
     * @param to The destination of assets.
     * @param minAmountOut The min amount of assets received by `to`.
     * @return amountOut the amount of assets received by `to`.
     * @dev throws MinAmountError
     */
    function redeemMax(ILMPVault vault, address to, uint256 minAmountOut) external returns (uint256 amountOut);
}
