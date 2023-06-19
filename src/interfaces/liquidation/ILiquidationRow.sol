// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import { SwapParams } from "./IAsyncSwapper.sol";
import { IVaultClaimableRewards } from "../rewards/IVaultClaimableRewards.sol";

interface ILiquidationRow {
    event SwapperAdded(address indexed swapper);
    event SwapperRemoved(address indexed swapper);
    event BalanceUpdated(address indexed token, address indexed vault, uint256 balance);
    event VaultLiquidated(address indexed vault, address indexed fromToken, address indexed toToken, uint256 amount);
    event GasUsedForVault(address indexed vault, uint256 gasAmount, bytes32 action);

    error ZeroAddress();
    error ZeroBalance();
    error NoVaults();
    error LengthsMismatch();
    error InsufficientSellAmount();
    error SellAmountMismatch();
    error InsufficientBalance();
    error NothingToLiquidate();
    error AsyncSwapperNotAllowed();
    error SwapperAlreadyAdded();
    error SwapperNotFound();
    error VaultAlreadyAdded();
    error VaultNotFound();
    error TokenAlreadyAdded();
    error TokenNotFound();

    /**
     * @notice Claim rewards from a list of vaults
     * @param vaults The list of vaults to claim rewards from
     */
    function claimsVaultRewards(IVaultClaimableRewards[] memory vaults) external;

    /**
     * @notice Get the list of allowed swappers
     * @return An array of allowed swapper addresses
     */
    function getAllowedSwappers() external view returns (address[] memory);

    /**
     * @notice Add a new swapper to the list of allowed swappers
     * @param swapper The address of the swapper to be added
     */
    function addAllowedSwapper(address swapper) external;

    /**
     * @notice Remove a swapper from the list of allowed swappers
     * @param swapper The address of the swapper to be removed
     */
    function removeAllowedSwapper(address swapper) external;

    /**
     * @notice Check if a swapper is allowed
     * @param swapper The address of the swapper to be checked
     * @return A boolean indicating if the swapper is allowed
     */
    function isAllowedSwapper(address swapper) external view returns (bool);

    /**
     * @notice Get the balance of a specific token and vault
     * @param tokenAddress The address of the token
     * @param vaultAddress The address of the vault
     * @return The balance of the specific token and vault
     */
    function balanceOf(address tokenAddress, address vaultAddress) external view returns (uint256);

    /**
     * @notice Get the total balance of a specific token across all vaults
     * @param tokenAddress The address of the token
     * @return The total balance of the specific token across all vaults
     */
    function totalBalanceOf(address tokenAddress) external view returns (uint256);

    /**
     * @notice Get the list of reward tokens
     * @return An array containing the addresses of reward tokens
     */
    function getTokens() external view returns (address[] memory);

    /**
     * @notice Get the list of vaults associated with a specific token
     * @param tokenAddress The address of the token
     * @return An array of vault addresses associated with the given token
     */
    function getVaultsForToken(address tokenAddress) external view returns (address[] memory);

    /*
    @notice Liquidate the specified vaults' balances for a specific token
    @param fromToken The address of the token to be liquidated
    @param asyncSwapper The address of the async swapper
    @param params Swap parameters for the async swapper
    @param vaultsToLiquidate An array of vault addresses to liquidate
    */
    function liquidateVaultsForToken(
        address fromToken,
        address asyncSwapper,
        address[] memory vaultsToLiquidate,
        SwapParams memory params
    ) external;
}
