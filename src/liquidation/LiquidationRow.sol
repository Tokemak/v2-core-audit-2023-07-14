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

contract LiquidationRow is ILiquidationRow, ReentrancyGuard {
    using Address for address;
    using SafeERC20 for IERC20;
    using EnumerableSet for EnumerableSet.AddressSet;

    struct LiquidationData {
        uint256 totalBalanceToLiquidate;
        uint256 balanceBefore;
        uint256 balanceDiff;
        uint256 pct;
        uint256 amount;
        uint256[] vaultsBalances;
    }

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
    function getAllowedSwappers() public view returns (address[] memory) {
        return allowedSwappers.values();
    }

    /// @inheritdoc ILiquidationRow
    function addAllowedSwapper(address swapper) public {
        bool success = allowedSwappers.add(swapper);
        if (!success) {
            revert SwapperAlreadyAdded();
        }
        emit SwapperAdded(swapper);
    }

    /// @inheritdoc ILiquidationRow
    function removeAllowedSwapper(address swapper) public {
        bool success = allowedSwappers.remove(swapper);
        if (!success) {
            revert SwapperNotFound();
        }
        emit SwapperRemoved(swapper);
    }

    /// @inheritdoc ILiquidationRow
    function isAllowedSwapper(address swapper) public view returns (bool) {
        return allowedSwappers.contains(swapper);
    }

    /// @inheritdoc ILiquidationRow
    function updateBalances(
        address[] memory vaultAddresses,
        address[][] memory rewardsTokensList,
        uint256[][] memory rewardsTokensAmounts
    ) public {
        for (uint256 i = 0; i < vaultAddresses.length; i++) {
            address vaultAddress = vaultAddresses[i];
            address[] memory rewardsTokens = rewardsTokensList[i];
            uint256[] memory rewardsTokensAmount = rewardsTokensAmounts[i];

            if (rewardsTokens.length != rewardsTokensAmount.length) {
                revert LengthsMismatch();
            }

            for (uint256 j = 0; j < rewardsTokens.length; j++) {
                address tokenAddress = rewardsTokens[j];
                uint256 tokenAmount = rewardsTokensAmount[j];

                if (tokenAmount > 0) {
                    _updateBalance(tokenAddress, vaultAddress, tokenAmount);
                }
            }
        }
    }

    /// @inheritdoc ILiquidationRow
    function balanceOf(address tokenAddress, address vaultAddress) public view returns (uint256) {
        return balances[tokenAddress][vaultAddress];
    }

    /// @inheritdoc ILiquidationRow
    function totalBalanceOf(address tokenAddress) public view returns (uint256) {
        return totalTokenBalances[tokenAddress];
    }

    /// @inheritdoc ILiquidationRow
    function getTokens() public view returns (address[] memory) {
        return rewardTokens.values();
    }

    /// @inheritdoc ILiquidationRow
    function getVaultsForToken(address tokenAddress) public view returns (address[] memory) {
        return tokenVaults[tokenAddress].values();
    }

    /// @inheritdoc ILiquidationRow
    function liquidateVaultsForToken(
        address fromToken,
        address asyncSwapper,
        address[] memory vaultsToLiquidate,
        SwapParams memory params
    ) public nonReentrant {
        uint256 vaultsToLiquidateLength = vaultsToLiquidate.length;
        LiquidationData memory data = LiquidationData(0, 0, 0, 0, 0, new uint256[](vaultsToLiquidateLength));

        data.totalBalanceToLiquidate = _getVaultsTotalBalance(fromToken, vaultsToLiquidate);

        if (data.totalBalanceToLiquidate == 0) {
            revert NothingToLiquidate();
        }

        if (data.totalBalanceToLiquidate != params.sellAmount) {
            revert SellAmountMismatch();
        }

        for (uint256 i = 0; i < vaultsToLiquidateLength; i++) {
            address vaultAddress = vaultsToLiquidate[i];
            uint256 vaultBalance = balances[fromToken][vaultAddress];
            data.vaultsBalances[i] = vaultBalance;
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

        // Check if the token still has any other vaults
        if (tokenVaults[fromToken].length() == 0) {
            delete tokenVaults[fromToken];
            bool success = rewardTokens.remove(fromToken);
            if (!success) {
                revert TokenNotFound();
            }
        }

        data.balanceBefore = IERC20(params.buyTokenAddress).balanceOf(address(this));

        _swapTokens(asyncSwapper, params);

        data.balanceDiff = IERC20(params.buyTokenAddress).balanceOf(address(this)) - data.balanceBefore;

        if (data.balanceDiff < params.buyAmount) {
            revert InsufficientSellAmount();
        }

        for (uint256 i = 0; i < vaultsToLiquidateLength; i++) {
            address vaultAddress = vaultsToLiquidate[i];

            uint256 vaultBalance = data.vaultsBalances[i];

            data.pct = vaultBalance * 1e18 / data.totalBalanceToLiquidate;
            data.amount = data.balanceDiff * data.pct / 1e18;

            IERC20(params.buyTokenAddress).safeTransfer(vaultAddress, data.amount);
        }

        emit VaultLiquidated(fromToken, params.buyTokenAddress, data.balanceDiff);
    }

    /**
     * @notice Get the total balance for the vaults
     * @param tokenAddress The address of the token
     * @param vaultsToLiquidate The list of vaults to liquidate
     */

    function _getVaultsTotalBalance(
        address tokenAddress,
        address[] memory vaultsToLiquidate
    ) private view returns (uint256) {
        uint256 vaultsToLiquidateLength = vaultsToLiquidate.length;
        uint256 totalBalanceToLiquidate = 0;

        for (uint256 i = 0; i < vaultsToLiquidateLength; i++) {
            address vaultAddress = vaultsToLiquidate[i];
            uint256 vaultBalance = balances[tokenAddress][vaultAddress];
            totalBalanceToLiquidate += vaultBalance;
        }

        return totalBalanceToLiquidate;
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
    function _updateBalance(address tokenAddress, address vaultAddress, uint256 balance) private {
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
