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
