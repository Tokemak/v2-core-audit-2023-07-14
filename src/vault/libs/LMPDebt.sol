// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2023 Tokemak Foundation. All rights reserved.

pragma solidity 0.8.17;

import { Errors } from "src/utils/Errors.sol";
import { IDestinationVault } from "src/interfaces/vault/IDestinationVault.sol";
import { Math } from "openzeppelin-contracts/utils/math/Math.sol";
import { EnumerableSet } from "openzeppelin-contracts/utils/structs/EnumerableSet.sol";
import { SafeERC20 } from "openzeppelin-contracts/token/ERC20/utils/SafeERC20.sol";
import { IERC20Metadata as IERC20 } from "openzeppelin-contracts/token/ERC20/extensions/IERC20Metadata.sol";
import { ISystemRegistry, IDestinationVaultRegistry } from "src/interfaces/ISystemRegistry.sol";

library LMPDebt {
    using SafeERC20 for IERC20;

    error VaultShutdown();

    struct DestinationInfo {
        /// @notice Current underlying and reward value at the destination vault
        /// @dev Used for calculating totalDebt of the LMPVault
        uint256 currentDebt;
        /// @notice Last block timestamp this info was updated
        uint256 lastReport;
        /// @notice How many shares of the destination vault we owned at last report
        uint256 ownedShares;
        /// @notice Amount of baseAsset transferred out in service of deployments
        /// @dev Used for calculating 'in profit' or not during user withdrawals
        uint256 debtBasis;
    }

    struct RebalanceOutParams {
        /// Address that will received the withdrawn underlyer
        address receiver;
        /// The "out" destination vault
        address destinationOut;
        /// The amount of tokenOut that will be withdrawn
        uint256 amountOut;
        /// The underlyer for destinationOut
        address tokenOut;
        IERC20 _baseAsset;
        bool _shutdown;
    }

    /// @notice Perform deposit and debt info update for the "in" destination during a rebalance
    /// @dev This "in" function performs less validations than its "out" version
    /// @param dvIn The "in" destination vault
    /// @param tokenIn The underlyer for dvIn
    /// @param depositAmount The amount of tokenIn that will be deposited
    /// @return debtDecrease The previous amount of debt dvIn accounted for in totalDebt
    /// @return debtIncrease The current amount of debt dvIn should account for in totalDebt
    function _handleRebalanceIn(
        DestinationInfo storage destInfo,
        IDestinationVault dvIn,
        address tokenIn,
        uint256 depositAmount
    ) external returns (uint256 debtDecrease, uint256 debtIncrease) {
        IERC20(tokenIn).safeApprove(address(dvIn), depositAmount);

        // Snapshot our current shares so we know how much to back out
        uint256 originalShareBal = dvIn.balanceOf(address(this));

        // deposit to dv
        uint256 newShares = dvIn.depositUnderlying(depositAmount);

        // Update the debt info snapshot
        (debtDecrease, debtIncrease) =
            _recalculateDestInfo(destInfo, dvIn, originalShareBal, originalShareBal + newShares, true);
    }

    /// @notice Perform withdraw and debt info update for the "out" destination during a rebalance
    /// @dev This "out" function performs more validations and handles idle as opposed to "in" which does not
    /// @param params Rebalance out params
    /// @param destOutInfo The "out" destination vault info
    /// @return debtDecrease The previous amount of debt destinationOut accounted for in totalDebt
    /// @return debtIncrease The current amount of debt destinationOut should account for in totalDebt
    /// @return idleDecrease Amount of baseAsset that was sent from the vault. > 0 only when tokenOut == baseAsset
    /// @return idleIncrease Amount of baseAsset that was claimed from Destination Vault
    function _handleRebalanceOut(
        RebalanceOutParams memory params,
        DestinationInfo storage destOutInfo
    ) external returns (uint256 debtDecrease, uint256 debtIncrease, uint256 idleDecrease, uint256 idleIncrease) {
        // Handle decrease (shares going "Out", cashing in shares and sending underlying back to swapper)
        // If the tokenOut is _asset we assume they are taking idle
        // which is already in the contract
        if (params.amountOut > 0) {
            if (params.tokenOut != address(params._baseAsset)) {
                IDestinationVault dvOut = IDestinationVault(params.destinationOut);

                // Snapshot our current shares so we know how much to back out
                uint256 originalShareBal = dvOut.balanceOf(address(this));

                // Burning our shares will claim any pending baseAsset
                // rewards and send them to us. Make sure we capture them
                // so they can end up in idle
                uint256 beforeBaseAssetBal = params._baseAsset.balanceOf(address(this));

                // withdraw underlying from dv
                // slither-disable-next-line unused-return
                dvOut.withdrawUnderlying(params.amountOut, params.receiver);

                idleIncrease = params._baseAsset.balanceOf(address(this)) - beforeBaseAssetBal;

                // Update the debt info snapshot
                (debtDecrease, debtIncrease) = _recalculateDestInfo(
                    destOutInfo, dvOut, originalShareBal, originalShareBal - params.amountOut, true
                );
            } else {
                // If we are shutdown then the only operations we should be performing are those that get
                // the base asset back to the vault. We shouldn't be sending out more
                if (params._shutdown) {
                    revert VaultShutdown();
                }
                // Working with idle baseAsset which should be in the vault already
                // Just send it out
                IERC20(params.tokenOut).safeTransfer(params.receiver, params.amountOut);
                idleDecrease = params.amountOut;
            }
        }
    }

    function recalculateDestInfo(
        DestinationInfo storage destInfo,
        IDestinationVault destVault,
        uint256 originalShares,
        uint256 currentShares,
        bool resetDebtBasis
    ) external returns (uint256 totalDebtDecrease, uint256 totalDebtIncrease) {
        (totalDebtDecrease, totalDebtIncrease) =
            _recalculateDestInfo(destInfo, destVault, originalShares, currentShares, resetDebtBasis);
    }

    function _recalculateDestInfo(
        DestinationInfo storage destInfo,
        IDestinationVault destVault,
        uint256 originalShares,
        uint256 currentShares,
        bool resetDebtBasis
    ) private returns (uint256 totalDebtDecrease, uint256 totalDebtIncrease) {
        // Figure out what to back out of our totalDebt number.
        // We could have had withdraws since the last snapshot which means our
        // cached currentDebt number should be decreased based on the remaining shares
        // totalDebt is decreased using the same proportion of shares method during withdrawals
        // so this should represent whatever is remaining.

        // Figure out how much our debt is currently worth
        uint256 dvDebtValue = destVault.debtValue(currentShares);

        // Calculate what we're backing out based on the original shares
        uint256 currentDebt = (destInfo.currentDebt * originalShares) / Math.max(destInfo.ownedShares, 1);
        destInfo.currentDebt = dvDebtValue;
        destInfo.lastReport = block.timestamp;
        destInfo.ownedShares = currentShares;
        if (resetDebtBasis) {
            destInfo.debtBasis = dvDebtValue;
        }

        totalDebtDecrease = currentDebt;
        totalDebtIncrease = dvDebtValue;
    }
}
