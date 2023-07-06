// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2023 Tokemak Foundation. All rights reserved.
pragma solidity 0.8.17;

import { IERC4626 } from "openzeppelin-contracts/interfaces/IERC4626.sol";
import { IERC20Permit } from "openzeppelin-contracts/token/ERC20/extensions/draft-IERC20Permit.sol";
import { IDestinationVault } from "src/interfaces/vault/IDestinationVault.sol";
import { IStrategy } from "src/interfaces/strategy/IStrategy.sol";

interface ILMPVault is IERC4626, IERC20Permit {
    /* ******************************** */
    /*      Events                      */
    /* ******************************** */
    event TokensPulled(address[] tokens, uint256[] amounts, address[] destinations);
    event TokensRecovered(address[] tokens, uint256[] amounts, address[] destinations);
    event DebtUpdated(uint256 oldDebt, uint256 newDebt);
    event RewarderSet(address rewarder);
    event DestinationDebtReporting(address destination, uint256 debtValue, uint256 claimed, uint256 claimGasUsed);
    event FeeCollected(uint256 fees, address feeSink, uint256 mintedShares, uint256 profit);

    /* ******************************** */
    /*      Errors                      */
    /* ******************************** */

    error ERC4626MintExceedsMax(uint256 shares, uint256 maxMint);
    error ERC4626DepositExceedsMax(uint256 assets, uint256 maxDeposit);
    error AmountExceedsAllowance(uint256 shares, uint256 allowed);

    error WithdrawalFailed();
    error DepositFailed();
    error InsufficientFundsInDestinations(uint256 deficit);
    error WithdrawalIncomplete();

    /// @notice Query the type of vault
    function vaultType() external view returns (bytes32);

    /// @notice Allow Rebalancer to move tracked assets
    function pullTokens(
        address[] calldata tokens,
        uint256[] calldata amounts,
        address[] calldata destinations
    ) external;

    /// @notice Allow token recoverer to collect dust / unintended transfers (non-tracked assets only)
    function recover(address[] calldata tokens, uint256[] calldata amounts, address[] calldata destinations) external;

    /// @notice Migrate user assets to a new vault
    function migrateVault(uint256 amount, address newLmpVault) external;

    /// @notice Set the order of destination vaults used for withdrawals
    // NOTE: will be done going directly to strategy (IStrategy) vault points to.
    //       How it'll delegate is still being decided
    // function setWithdrawalQueue(address[] calldata destinations) external;

    /// @notice Claim Accrued Rewards
    function claimRewards() external;

    /// @notice Set the withdrawal queue to be used when taking out Assets
    /// @param _destinations The ordered list of destination vaults to go for withdrawals
    function setWithdrawalQueue(address[] calldata _destinations) external;

    /// @notice Get the withdrawal queue to be used when taking out Assets
    function getWithdrawalQueue() external returns (IDestinationVault[] memory _destinations);

    /// @notice Get a list of destination vaults with pending assets to clear out
    function getRemovalQueue() external returns (address[] memory);

    /// @notice Remove emptied destination vault from pending removal queue
    function removeFromRemovalQueue(address vaultToRemove) external;
}
