// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import { IERC4626 } from "openzeppelin-contracts/interfaces/IERC4626.sol";
import { IERC20Permit } from "openzeppelin-contracts/token/ERC20/extensions/draft-IERC20Permit.sol";
import { IStrategy } from "src/interfaces/strategy/IStrategy.sol";

interface ILMPVault is IERC4626, IERC20Permit {
    /* ******************************** */
    /*      Events                      */
    /* ******************************** */
    event StrategySet(address strategy);
    event TokensPulled(address[] tokens, uint256[] amounts, address[] destinations);
    event TokensRecovered(address[] tokens, uint256[] amounts, address[] destinations);
    event DebtUpdated(uint256 oldDebt, uint256 newDebt);

    /* ******************************** */
    /*      Errors                      */
    /* ******************************** */

    error StrategyNotSet();
    error ERC4626MintExceedsMax(uint256 shares, uint256 maxMint);
    error ERC4626DepositExceedsMax(uint256 assets, uint256 maxDeposit);
    error AmountExceedsAllowance(uint256 shares, uint256 allowed);

    error WithdrawalFailed();
    error DepositFailed();
    error InsufficientFundsInDestinations(uint256 deficit);
    error WithdrawalIncomplete();

    /// @notice Gets the strategy used by the rewarder for this vault to allocate assets
    function strategy() external view returns (IStrategy);

    /// @notice Placeholder for updating strategy
    /// @dev not implemented until the re-allocation math is finalized
    // function setStrategy(IStrategy _strategy) external;

    /// @notice Allow Rebalancer to move tracked assets
    function pullTokens(
        address[] calldata tokens,
        uint256[] calldata amounts,
        address[] calldata destinations
    ) external;

    /// @notice Allow token recoverer to collect dust / unintended transfers (non-tracked assets only)
    function recover(address[] calldata tokens, uint256[] calldata amounts, address[] calldata destinations) external;

    /// @notice Used by rebalancer to update pending debt total
    function updateDebt(uint256 newDebt) external;

    /// @notice Migrate user assets to a new vault
    function migrateVault(uint256 amount, address newLmpVault) external;

    /// @notice Set the order of destination vaults used for withdrawals
    // NOTE: will be done going directly to strategy (IStrategy) vault points to.
    //       How it'll delegate is still being decided
    // function setWithdrawalQueue(address[] calldata destinations) external;

    /// @notice Claim Accrued Rewards
    function claimRewards() external;
}
