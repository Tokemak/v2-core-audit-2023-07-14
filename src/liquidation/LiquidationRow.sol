/**
 * @todo: Role management is yet to be implemented, as we are currently waiting for the role management project to be
 * completed.
 * Once the role management project is ready, appropriate access control and role-based permissions will be added to
 * this contract.
 */

// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import { IERC20 } from "openzeppelin-contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "openzeppelin-contracts/token/ERC20/utils/SafeERC20.sol";
import { ReentrancyGuard } from "openzeppelin-contracts/security/ReentrancyGuard.sol";
import { EnumerableSet } from "openzeppelin-contracts/utils/structs/EnumerableSet.sol";
import { Address } from "openzeppelin-contracts/utils/Address.sol";
import { IAsyncSwapper, SwapParams } from "../interfaces/liquidation/IAsyncSwapper.sol";
import { ILiquidationRow } from "../interfaces/liquidation/ILiquidationRow.sol";
import { IVaultClaimableRewards } from "../interfaces/rewards/IVaultClaimableRewards.sol";

contract LiquidationRow is ILiquidationRow, ReentrancyGuard {
    using Address for address;
    using SafeERC20 for IERC20;
    using EnumerableSet for EnumerableSet.AddressSet;

    EnumerableSet.AddressSet private allowedSwappers;

    EnumerableSet.AddressSet private rewardTokens;

    /**
     * @notice Mapping to store the balance amount for each vault for each token
     */
    mapping(address => mapping(address => uint256)) private balances;

    /**
     * @notice Mapping to store the total balance for each token
     */
    mapping(address => uint256) private totalTokenBalances;

    /**
     * @notice Mapping to store the list of vaults for each token
     */
    mapping(address => EnumerableSet.AddressSet) private tokenVaults;

    /// @inheritdoc ILiquidationRow
    function getAllowedSwappers() external view returns (address[] memory) {
        return allowedSwappers.values();
    }

    /// @inheritdoc ILiquidationRow
    function addAllowedSwapper(address swapper) external {
        bool success = allowedSwappers.add(swapper);
        if (!success) {
            revert SwapperAlreadyAdded();
        }
        emit SwapperAdded(swapper);
    }

    /// @inheritdoc ILiquidationRow
    function removeAllowedSwapper(address swapper) external {
        bool success = allowedSwappers.remove(swapper);
        if (!success) {
            revert SwapperNotFound();
        }
        emit SwapperRemoved(swapper);
    }

    /// @inheritdoc ILiquidationRow
    function isAllowedSwapper(address swapper) external view returns (bool) {
        return allowedSwappers.contains(swapper);
    }

    /// @inheritdoc ILiquidationRow
    function claimsVaultRewards(IVaultClaimableRewards[] memory vaults) external nonReentrant {
        for (uint256 i = 0; i < vaults.length; ++i) {
            if (address(vaults[i]) == address(0)) revert ZeroAddress();
            // @todo: Check if the vault is in our registry
            IVaultClaimableRewards vault = vaults[i];
            // slither-disable-next-line calls-loop
            (uint256[] memory amounts, IERC20[] memory tokens) = vault.claimRewards();

            uint256 tokensLength = tokens.length;
            for (uint256 j = 0; j < tokensLength; ++j) {
                IERC20 token = tokens[j];
                uint256 amount = amounts[j];
                if (amount > 0) {
                    // slither-disable-next-line reentrancy-no-eth
                    _increaseBalance(address(token), address(vault), amount);
                }
            }
        }
    }

    /// @inheritdoc ILiquidationRow
    function balanceOf(address tokenAddress, address vaultAddress) external view returns (uint256) {
        return balances[tokenAddress][vaultAddress];
    }

    /// @inheritdoc ILiquidationRow
    function totalBalanceOf(address tokenAddress) external view returns (uint256) {
        return totalTokenBalances[tokenAddress];
    }

    /// @inheritdoc ILiquidationRow
    function getTokens() external view returns (address[] memory) {
        return rewardTokens.values();
    }

    /// @inheritdoc ILiquidationRow
    function getVaultsForToken(address tokenAddress) external view returns (address[] memory) {
        return tokenVaults[tokenAddress].values();
    }

    /// @inheritdoc ILiquidationRow
    function liquidateVaultsForToken(
        address fromToken,
        address asyncSwapper,
        address[] memory vaultsToLiquidate,
        SwapParams memory params
    ) external nonReentrant {
        uint256 vaultsToLiquidateLength = vaultsToLiquidate.length;
        uint256[] memory vaultsBalances = new uint256[](vaultsToLiquidateLength);

        uint256 totalBalanceToLiquidate = 0;

        for (uint256 i = 0; i < vaultsToLiquidateLength; ++i) {
            address vaultAddress = vaultsToLiquidate[i];
            uint256 vaultBalance = balances[fromToken][vaultAddress];
            totalBalanceToLiquidate += vaultBalance;
            vaultsBalances[i] = vaultBalance;
            // Update the total balance for the token
            totalTokenBalances[fromToken] -= vaultBalance;
            // Update the balance for the vault and token
            balances[fromToken][vaultAddress] = 0;
            // Remove the vault from the token vaults list
            bool success = tokenVaults[fromToken].remove(vaultAddress);
            if (!success) {
                revert VaultNotFound();
            }
        }

        if (totalBalanceToLiquidate == 0) {
            revert NothingToLiquidate();
        }

        if (totalBalanceToLiquidate != params.sellAmount) {
            revert SellAmountMismatch();
        }

        // Check if the token still has any other vaults
        if (tokenVaults[fromToken].length() == 0) {
            bool success = rewardTokens.remove(fromToken);
            if (!success) {
                revert TokenNotFound();
            }
        }

        uint256 balanceBefore = IERC20(params.buyTokenAddress).balanceOf(address(this));

        _swapTokens(asyncSwapper, params);

        /// @todo integrate pricing to confirm that our specified minimum token is within a reasonable price
        uint256 balanceDiff = IERC20(params.buyTokenAddress).balanceOf(address(this)) - balanceBefore;

        if (balanceDiff < params.buyAmount) {
            revert InsufficientSellAmount();
        }

        for (uint256 i = 0; i < vaultsToLiquidateLength; ++i) {
            address vaultAddress = vaultsToLiquidate[i];
            uint256 vaultBalance = vaultsBalances[i];

            uint256 amount = balanceDiff * vaultBalance / totalBalanceToLiquidate;

            IERC20(params.buyTokenAddress).safeTransfer(vaultAddress, amount);
        }

        emit VaultLiquidated(fromToken, params.buyTokenAddress, balanceDiff);
    }

    /**
     * @notice Perform the token swap
     * @param asyncSwapper The address of the async swapper
     * @param params Swap parameters for the async swapper
     */
    function _swapTokens(address asyncSwapper, SwapParams memory params) private {
        if (!allowedSwappers.contains(asyncSwapper)) {
            revert AsyncSwapperNotAllowed();
        }
        IAsyncSwapper(asyncSwapper).swap(params);
    }

    /**
     * @notice Update the balance of a specific token and vault
     * @param tokenAddress The address of the token
     * @param vaultAddress The address of the vault
     * @param balance The amount of the token to be updated
     */
    function _increaseBalance(address tokenAddress, address vaultAddress, uint256 balance) internal {
        if(balance == 0) {
            revert ZeroBalance();
        }

        uint256 currentBalance = balances[tokenAddress][vaultAddress];
        uint256 totalBalance = totalTokenBalances[tokenAddress];
        uint256 newTotalBalance = totalBalance + balance;

        //slither-disable-next-line calls-loop
        uint256 balanceOfToken = IERC20(tokenAddress).balanceOf(address(this));
        if (newTotalBalance > balanceOfToken) {
            /**
             * @dev This should never happen, but just in case. The error is raised if the updated total balance of a
             * specific token in the contract is greater than the actual balance of that token held by the
             * contract.
             * The calling contract should transfer the funds first before updating the balance.
             */
            revert InsufficientBalance();
        }

        if (currentBalance == 0) {
            bool success = tokenVaults[tokenAddress].add(vaultAddress);
            if (!success) {
                revert VaultAlreadyAdded();
            }

            if (totalBalance == 0) {
                success = rewardTokens.add(tokenAddress);
                if (!success) {
                    revert TokenAlreadyAdded();
                }
            }
        }

        // Update the total balance for the token
        totalTokenBalances[tokenAddress] = newTotalBalance;
        // Update the balance for the vault and token
        balances[tokenAddress][vaultAddress] = currentBalance + balance;

        emit BalanceUpdated(tokenAddress, vaultAddress, currentBalance + balance);
    }
}
