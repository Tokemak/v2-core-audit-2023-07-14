// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.17;

import "./IPlasmaPool.sol";

/**
 * @title IPlasmaPoolRouter Interface
 * @notice Extends the IPlasmaPoolRouterBase with specific flows to save gas
 */
interface IPlasmaPoolRouter {
    /**
     * ***************************   Deposit ********************************
     */

    /**
     * @notice deposit `amount` to a PlasmaPool.
     * @param pool The PlasmaPool to deposit assets to.
     * @param to The destination of ownership shares.
     * @param amount The amount of assets to deposit to `pool`.
     * @param minSharesOut The min amount of `pool` shares received by `to`.
     * @return sharesOut the amount of shares received by `to`.
     * @dev throws MinSharesError
     */
    function depositToPool(
        IPlasmaPool pool,
        address to,
        uint256 amount,
        uint256 minSharesOut
    ) external returns (uint256 sharesOut);

    /**
     * @notice deposit max assets to a PlasmaPool.
     * @param pool The PlasmaPool to deposit assets to.
     * @param to The destination of ownership shares.
     * @param minSharesOut The min amount of `pool` shares received by `to`.
     * @return sharesOut the amount of shares received by `to`.
     * @dev throws MinSharesError
     */
    function depositMax(IPlasmaPool pool, address to, uint256 minSharesOut) external returns (uint256 sharesOut);

    /**
     * *************************   Withdraw   **********************************
     */

    /**
     * @notice withdraw `amount` to a PlasmaPool.
     * @param fromPool The PlasmaPool to withdraw assets from.
     * @param toPool The PlasmaPool to deposit assets to.
     * @param to The destination of ownership shares.
     * @param amount The amount of assets to withdraw from fromPool.
     * @param maxSharesIn The max amount of fromPool shares withdrawn by caller.
     * @param minSharesOut The min amount of toPool shares received by `to`.
     * @return sharesOut the amount of shares received by `to`.
     * @dev throws MaxSharesError, MinSharesError
     */
    function withdrawToDeposit(
        IPlasmaPool fromPool,
        IPlasmaPool toPool,
        address to,
        uint256 amount,
        uint256 maxSharesIn,
        uint256 minSharesOut
    ) external returns (uint256 sharesOut);

    /**
     * *************************   Redeem    ********************************
     */

    /**
     * @notice redeem `shares` to a PlasmaPool.
     * @param fromPool The PlasmaPool to redeem shares from.
     * @param toPool The PlasmaPool to deposit assets to.
     * @param to The destination of ownership shares.
     * @param shares The amount of shares to redeem from fromPool.
     * @param minSharesOut The min amount of toPool shares received by `to`.
     * @return sharesOut the amount of shares received by `to`.
     * @dev throws MinAmountError, MinSharesError
     */
    function redeemToDeposit(
        IPlasmaPool fromPool,
        IPlasmaPool toPool,
        address to,
        uint256 shares,
        uint256 minSharesOut
    ) external returns (uint256 sharesOut);

    /**
     * @notice redeem max shares to a PlasmaPool.
     * @param pool The PlasmaPool to redeem shares from.
     * @param to The destination of assets.
     * @param minAmountOut The min amount of assets received by `to`.
     * @return amountOut the amount of assets received by `to`.
     * @dev throws MinAmountError
     */
    function redeemMax(IPlasmaPool pool, address to, uint256 minAmountOut) external returns (uint256 amountOut);
}
