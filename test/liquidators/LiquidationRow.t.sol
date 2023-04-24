// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import { Test } from "forge-std/Test.sol";

import { IERC20 } from "openzeppelin-contracts/token/ERC20/IERC20.sol";
import { EnumerableSet } from "openzeppelin-contracts/utils/structs/EnumerableSet.sol";

import { LiquidationRow } from "../../src/liquidation/LiquidationRow.sol";
import { IAsyncSwapper, SwapParams } from "../../src/interfaces/liquidation/IAsyncSwapper.sol";
import { ILiquidationRow } from "../../src/interfaces/liquidation/ILiquidationRow.sol";
import { BaseAsyncSwapper } from "../../src/liquidation/BaseAsyncSwapper.sol";
import { IVaultClaimableRewards } from "../../src/interfaces/rewards/IVaultClaimableRewards.sol";
import { ZERO_EX_MAINNET, PRANK_ADDRESS, CVX_MAINNET, WETH_MAINNET } from "../utils/Addresses.sol";
import { MockERC20 } from "../mocks/MockERC20.sol";

contract AsyncSwapperMock is BaseAsyncSwapper {
    MockERC20 private immutable targetToken;
    address private immutable liquidationRow;

    constructor(address _aggregator, MockERC20 _targetToken, address _liquidationRow) BaseAsyncSwapper(_aggregator) {
        targetToken = _targetToken;
        liquidationRow = _liquidationRow;
    }

    function swap(SwapParams memory params) public override {
        /// @dev This is a mock function that will mint the target token to the liquidation row assuming that the swap
        /// was successful
        targetToken.mint(liquidationRow, params.sellAmount);
    }
}

contract MockVault is IVaultClaimableRewards {
    function claimRewards() external override returns (uint256[] memory, IERC20[] memory) {
        // delegatecall the Reward Adapater associated to it
    }
}

/**
 * @notice This contract is used to test the LiquidationRow contract and specifically the _updateBalance private
 * function
 */
contract LiquidationRowWrapper is LiquidationRow {
    /**
     * @notice Update the balances of the vaults
     * @param vaultAddresses An array of vault addresses
     * @param rewardsTokensList An array of arrays containing the reward tokens for each vault
     * @param rewardsTokensAmounts An array of arrays containing the reward token amounts for each vault
     */
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
}

// solhint-disable func-name-mixedcase
contract LiquidationRowTest is Test {
    LiquidationRowWrapper private liquidationRow;
    AsyncSwapperMock private asyncSwapper;
    MockERC20 private targetToken;
    MockERC20 private rewardToken;
    MockERC20 private rewardToken2;
    MockERC20 private rewardToken3;

    address private vault1 = vm.addr(1);
    address private vault2 = vm.addr(2);

    function setUp() public {
        liquidationRow = new LiquidationRowWrapper();
        targetToken = new MockERC20();
        rewardToken = new MockERC20();
        rewardToken2 = new MockERC20();
        rewardToken3 = new MockERC20();
        asyncSwapper = new AsyncSwapperMock(vm.addr(100), targetToken, address(liquidationRow));

        liquidationRow.addAllowedSwapper(address(asyncSwapper));
    }

    /*  
        ----------------------------------------------------------------------
        test_Revert_claimRewards_IfAVaultHasZeroAddress and test_claimRewards
        only tests the claimRewards function but only checks if the vault.claimRewards() function is being called.
        The _updateBalance function is tested in other parts of the contract.
        ----------------------------------------------------------------------
    */

    function test_Revert_claimRewards_IfAVaultHasZeroAddress() public {
        IVaultClaimableRewards[] memory vaults = new IVaultClaimableRewards[](1);
        vaults[0] = IVaultClaimableRewards(address(0));

        vm.expectRevert(ILiquidationRow.ZeroAddress.selector);
        liquidationRow.claimsVaultRewards(vaults);
    }

    /**
     * @notice Test the claimRewards function.
     * @dev This test checks if the vault.claimRewards() function is being called.
     * The _updateBalance function is tested in other parts of the contract.
     */
    function test_claimRewards() public {
        IVaultClaimableRewards[] memory vaults = new IVaultClaimableRewards[](2);
        vaults[0] = IVaultClaimableRewards(new MockVault());
        vaults[1] = IVaultClaimableRewards(new MockVault());

        vm.expectCall(address(vaults[0]), abi.encodeCall(vaults[0].claimRewards, ()));
        vm.expectCall(address(vaults[1]), abi.encodeCall(vaults[0].claimRewards, ()));

        liquidationRow.claimsVaultRewards(vaults);
    }

    /*  
        ----------------------------------------------------------------------
        Following tests only focuses on the _updateBalance function.
        ----------------------------------------------------------------------
    */

    /**
     * @notice Test if a revert occurs when there's a mismatch in the lengths of input arrays.
     */
    function test_Revert_IfLengthsMismatch() public {
        uint256 nbVaults = 2;
        address[] memory vaultAddresses = new address[](nbVaults);
        address[][] memory rewardsTokensList = new address[][](nbVaults);
        uint256[][] memory rewardsTokensAmounts = new uint256[][](nbVaults);

        // set vault1 rewards and amounts
        vaultAddresses[0] = vault1;
        rewardsTokensList[0] = new address[](2);
        rewardsTokensAmounts[0] = new uint256[](1);
        rewardsTokensList[0][0] = address(rewardToken);
        rewardsTokensAmounts[0][0] = 100;
        rewardsTokensList[0][1] = address(rewardToken2);

        vm.expectRevert(ILiquidationRow.LengthsMismatch.selector);
        liquidationRow.updateBalances(vaultAddresses, rewardsTokensList, rewardsTokensAmounts);
    }

    /**
     * @notice Test if a revert occurs when there's an insufficient balance for liquidation.
     */
    function test_Revert_IfInsufficientBalance() public {
        uint256 nbVaults = 1;
        address[] memory vaultAddresses = new address[](nbVaults);
        address[][] memory rewardsTokensList = new address[][](nbVaults);
        uint256[][] memory rewardsTokensAmounts = new uint256[][](nbVaults);

        // set vault1 rewards and amounts
        vaultAddresses[0] = vault1;
        rewardsTokensList[0] = new address[](1);
        rewardsTokensAmounts[0] = new uint256[](1);
        rewardsTokensList[0][0] = address(rewardToken);
        rewardsTokensAmounts[0][0] = 100;

        vm.expectRevert(ILiquidationRow.InsufficientBalance.selector);
        liquidationRow.updateBalances(vaultAddresses, rewardsTokensList, rewardsTokensAmounts);
    }

    /**
     * @notice Test if a revert occurs when there's nothing to liquidate.
     */
    function test_Revert_IfNothingToLiquidate() public {
        address[] memory vaults = liquidationRow.getVaultsForToken(address(rewardToken));

        vm.expectRevert(ILiquidationRow.NothingToLiquidate.selector);
        liquidationRow.liquidateVaultsForToken(
            address(rewardToken),
            address(asyncSwapper),
            vaults,
            SwapParams(address(rewardToken), 200, address(targetToken), 200, new bytes(0), new bytes(0))
        );
    }

    /**
     * @notice Test if a revert occurs when an unallowed async swapper tries to perform liquidation.
     */
    function test_Revert_IfAsyncSwapperNotAllowed() public {
        (address[] memory vaultAddresses, address[][] memory rewardsTokensList, uint256[][] memory rewardsTokensAmounts)
        = get_update_balance_multiple_vaults();

        liquidationRow.updateBalances(vaultAddresses, rewardsTokensList, rewardsTokensAmounts);

        address[] memory vaults = liquidationRow.getVaultsForToken(address(rewardToken));

        vm.expectRevert(ILiquidationRow.AsyncSwapperNotAllowed.selector);

        liquidationRow.liquidateVaultsForToken(
            address(rewardToken),
            address(10_000),
            vaults,
            SwapParams(address(rewardToken), 200, address(targetToken), 200, new bytes(0), new bytes(0))
        );
    }

    /**
     * @notice Test if a revert occurs when there's a mismatch in the sell amount during liquidation.
     */
    function test_Revert_IfSellAmountMismatch() public {
        (address[] memory vaultAddresses, address[][] memory rewardsTokensList, uint256[][] memory rewardsTokensAmounts)
        = get_update_balance_multiple_vaults();

        liquidationRow.updateBalances(vaultAddresses, rewardsTokensList, rewardsTokensAmounts);

        address[] memory vaults = liquidationRow.getVaultsForToken(address(rewardToken));

        vm.expectRevert(ILiquidationRow.SellAmountMismatch.selector);

        liquidationRow.liquidateVaultsForToken(
            address(rewardToken),
            address(10_000),
            vaults,
            SwapParams(address(rewardToken), 10_000, address(targetToken), 200, new bytes(0), new bytes(0))
        );
    }

    /**
     * @notice Test the functionality of adding an allowed swapper.
     */
    function test_addAllowedSwapper() public {
        // Add a new swapper
        AsyncSwapperMock newSwapper = new AsyncSwapperMock(vm.addr(200), targetToken, address(liquidationRow));
        liquidationRow.addAllowedSwapper(address(newSwapper));

        // Check if the swapper is allowed
        bool isSwapperAllowed = liquidationRow.isAllowedSwapper(address(newSwapper));
        assertTrue(isSwapperAllowed);
    }

    /**
     * @notice Test the functionality of adding and then removing an allowed swapper.
     */
    function test_removeAllowedSwapper() public {
        // Add a new swapper
        AsyncSwapperMock newSwapper = new AsyncSwapperMock(vm.addr(200), targetToken, address(liquidationRow));
        liquidationRow.addAllowedSwapper(address(newSwapper));

        // Check if the swapper is allowed
        bool isSwapperAllowed = liquidationRow.isAllowedSwapper(address(newSwapper));
        assertTrue(isSwapperAllowed);

        // Remove the swapper
        liquidationRow.removeAllowedSwapper(address(newSwapper));

        // Check if the swapper is no longer allowed
        isSwapperAllowed = liquidationRow.isAllowedSwapper(address(newSwapper));
        assertFalse(isSwapperAllowed);
    }

    /**
     * @notice Test the updateBalances function with multiple vaults.
     */
    function test_updateBalancesForMultipleVaults() public {
        (address[] memory vaultAddresses, address[][] memory rewardsTokensList, uint256[][] memory rewardsTokensAmounts)
        = get_update_balance_multiple_vaults();

        // Call the updateBalances function in the Liquidation contract with the test data
        liquidationRow.updateBalances(vaultAddresses, rewardsTokensList, rewardsTokensAmounts);

        // Check if the balances are correctly updated in the Liquidation contract
        // Vault 1
        uint256 vault1RewardToken1Balance = liquidationRow.balanceOf(rewardsTokensList[0][0], vaultAddresses[0]);
        uint256 vault1RewardToken2Balance = liquidationRow.balanceOf(rewardsTokensList[0][1], vaultAddresses[0]);

        // Vault 2
        uint256 vault2RewardToken1Balance = liquidationRow.balanceOf(rewardsTokensList[1][0], vaultAddresses[1]);
        uint256 vault2RewardToken2Balance = liquidationRow.balanceOf(rewardsTokensList[1][1], vaultAddresses[1]);

        // Compare balances with expected values
        assertTrue(vault1RewardToken1Balance == 100);
        assertTrue(vault1RewardToken2Balance == 200);
        assertTrue(vault2RewardToken1Balance == 100);
        assertTrue(vault2RewardToken2Balance == 200);

        // Check totalBalanceOf for each reward token
        uint256 totalRewardToken1Balance = liquidationRow.totalBalanceOf(rewardsTokensList[0][0]);
        uint256 totalRewardToken2Balance = liquidationRow.totalBalanceOf(rewardsTokensList[0][1]);

        // Compare total balances with expected values
        assertTrue(totalRewardToken1Balance == 200); // 100 (vault1) + 100 (vault2)
        assertTrue(totalRewardToken2Balance == 400); // 200 (vault1) + 200 (vault2)
    }

    /**
     * @notice Test the liquidateVaultsForToken function by liquidating all vaults for a single reward token.
     */
    function test_liquidateVaultsForToken_Success() public {
        (address[] memory vaultAddresses, address[][] memory rewardsTokensList, uint256[][] memory rewardsTokensAmounts)
        = get_update_balance_multiple_vaults();

        // update balances
        liquidationRow.updateBalances(vaultAddresses, rewardsTokensList, rewardsTokensAmounts);

        address[] memory vaults = liquidationRow.getVaultsForToken(address(rewardToken));

        uint256 vault1RewardTokenBalanceBefore = liquidationRow.balanceOf(address(rewardToken), vault1);
        uint256 vault1RewardToken2BalanceBefore = liquidationRow.balanceOf(address(rewardToken2), vault1);
        uint256 vault2RewardTokenBalanceBefore = liquidationRow.balanceOf(address(rewardToken), vault2);
        uint256 vault2RewardToken2BalanceBefore = liquidationRow.balanceOf(address(rewardToken2), vault2);

        address[] memory tokensBefore = liquidationRow.getTokens();

        // liquidate all vaults for rewardToken
        liquidationRow.liquidateVaultsForToken(
            address(rewardToken),
            address(asyncSwapper),
            vaults,
            SwapParams(address(rewardToken), 200, address(targetToken), 200, new bytes(0), new bytes(0))
        );

        address[] memory tokensAfter = liquidationRow.getTokens();

        uint256 vault1RewardTokenBalanceAfter = liquidationRow.balanceOf(address(rewardToken), vault1);
        uint256 vault1RewardToken2BalanceAfter = liquidationRow.balanceOf(address(rewardToken2), vault1);
        uint256 vault2RewardTokenBalanceAfter = liquidationRow.balanceOf(address(rewardToken), vault2);
        uint256 vault2RewardToken2BalanceAfter = liquidationRow.balanceOf(address(rewardToken2), vault2);

        // check that rewardToken has been liquidated
        assertTrue(vault1RewardTokenBalanceBefore == 100);
        assertTrue(vault1RewardTokenBalanceAfter == 0);
        assertTrue(vault2RewardTokenBalanceBefore == 100);
        assertTrue(vault2RewardTokenBalanceAfter == 0);

        // check that rewardToken2 has not been liquidated
        assertTrue(vault1RewardToken2BalanceBefore == vault1RewardToken2BalanceAfter);
        assertTrue(vault2RewardToken2BalanceBefore == vault2RewardToken2BalanceAfter);

        uint256 vault1TargetTokenBalanceAfter = targetToken.balanceOf(vault1);
        uint256 vault2TargetTokenBalanceAfter = targetToken.balanceOf(vault2);

        // check that targetToken has been received by vaults
        assertTrue(vault1TargetTokenBalanceAfter == 100);
        assertTrue(vault2TargetTokenBalanceAfter == 100);

        assertTrue(tokensAfter.length == tokensBefore.length - 1);
    }

    /**
     * @notice Test the liquidateVaultsForToken function by liquidating only one vault for a single reward token.
     */
    function test_liquidateVault1ForToken_Success() public {
        (address[] memory vaultAddresses, address[][] memory rewardsTokensList, uint256[][] memory rewardsTokensAmounts)
        = get_update_balance_multiple_vaults();

        // update balances
        liquidationRow.updateBalances(vaultAddresses, rewardsTokensList, rewardsTokensAmounts);

        uint256 vault1RewardTokenBalanceBefore = liquidationRow.balanceOf(address(rewardToken), vault1);
        uint256 vault1RewardToken2BalanceBefore = liquidationRow.balanceOf(address(rewardToken2), vault1);
        uint256 vault2RewardTokenBalanceBefore = liquidationRow.balanceOf(address(rewardToken), vault2);
        uint256 vault2RewardToken2BalanceBefore = liquidationRow.balanceOf(address(rewardToken2), vault2);

        address[] memory tokensBefore = liquidationRow.getTokens();

        // Create an array with only vault1 address
        address[] memory vaultsToLiquidate = new address[](1);
        vaultsToLiquidate[0] = vault1;

        // liquidate only vault1 for rewardToken
        liquidationRow.liquidateVaultsForToken(
            address(rewardToken),
            address(asyncSwapper),
            vaultsToLiquidate,
            SwapParams(address(rewardToken), 100, address(targetToken), 100, new bytes(0), new bytes(0))
        );

        address[] memory tokensAfter = liquidationRow.getTokens();

        uint256 vault1RewardTokenBalanceAfter = liquidationRow.balanceOf(address(rewardToken), vault1);
        uint256 vault1RewardToken2BalanceAfter = liquidationRow.balanceOf(address(rewardToken2), vault1);
        uint256 vault2RewardTokenBalanceAfter = liquidationRow.balanceOf(address(rewardToken), vault2);
        uint256 vault2RewardToken2BalanceAfter = liquidationRow.balanceOf(address(rewardToken2), vault2);

        // check that rewardToken has been liquidated in vault1
        assertTrue(vault1RewardTokenBalanceBefore == 100);
        assertTrue(vault1RewardTokenBalanceAfter == 0);

        // check that rewardToken2 has not been liquidated in vault1
        assertTrue(vault1RewardToken2BalanceBefore == vault1RewardToken2BalanceAfter);

        // check that rewardToken and rewardToken2 have not been liquidated in vault2
        assertTrue(vault2RewardTokenBalanceBefore == vault2RewardTokenBalanceAfter);
        assertTrue(vault2RewardToken2BalanceBefore == vault2RewardToken2BalanceAfter);

        uint256 vault1TargetTokenBalanceAfter = targetToken.balanceOf(vault1);
        uint256 vault2TargetTokenBalanceBefore = targetToken.balanceOf(vault2);

        // check that targetToken has been received by vault1
        assertTrue(vault1TargetTokenBalanceAfter == 100);

        // check that targetToken hasn't been received by vault2
        assertTrue(vault2TargetTokenBalanceBefore == 0);

        assertTrue(tokensAfter.length == tokensBefore.length);
    }

    /**
     * @notice Test the updateBalances function when merging balances for a single vault.
     */
    function test_updateBalances_MergeSuccessful() public {
        (address[] memory vaultAddresses, address[][] memory rewardsTokensList, uint256[][] memory rewardsTokensAmounts)
        = get_update_balance_merge_data();

        // update balances
        liquidationRow.updateBalances(vaultAddresses, rewardsTokensList, rewardsTokensAmounts);

        address[] memory tokens = liquidationRow.getTokens();
        assertTrue(tokens.length == 3);
        assertTrue(tokens[0] == address(rewardToken));
        assertTrue(tokens[1] == address(rewardToken2));
        assertTrue(tokens[2] == address(rewardToken3));

        uint256 rewardTokenBalance = liquidationRow.balanceOf(address(rewardToken), vault1);
        uint256 rewardToken2Balance = liquidationRow.balanceOf(address(rewardToken2), vault1);
        uint256 rewardToken3Balance = liquidationRow.balanceOf(address(rewardToken3), vault1);

        assertTrue(rewardTokenBalance == rewardsTokensAmounts[0][0] + rewardsTokensAmounts[1][0]);
        assertTrue(rewardToken2Balance == 100);
        assertTrue(rewardToken3Balance == 40);

        uint256 rewardTokenTotalBalance = liquidationRow.totalBalanceOf(address(rewardToken));
        assertTrue(rewardTokenTotalBalance == rewardsTokensAmounts[0][0] + rewardsTokensAmounts[1][0]);
    }

    /**
     * @notice Returns test data for the updateBalances function.
     * @dev This function creates test data with two vaults containing different sets of tokens and amounts.
     * It is intended to simulate a scenario where a single vault has multiple types of reward tokens
     * with different amounts. The resulting data can be used to test the updateBalances function
     * when merging balances for a single vault.
     *
     * Data values:
     * - vault1 has 400 rewardToken and 100 rewardToken2 initially
     * - vault1 receives an additional 1300 rewardToken and 40 rewardToken3
     *
     * @return vaultAddresses An array containing the addresses of the vaults ([vault1, vault1]).
     * @return rewardsTokensList A 2D array containing the addresses of the reward tokens for each vault
     *                           ([[rewardToken, rewardToken2], [rewardToken, rewardToken3]]).
     * @return rewardsTokensAmounts A 2D array containing the amounts of the reward tokens for each vault
     *                              ([[400, 100], [1300, 40]]).
     */
    function get_update_balance_merge_data()
        private
        returns (
            address[] memory vaultAddresses,
            address[][] memory rewardsTokensList,
            uint256[][] memory rewardsTokensAmounts
        )
    {
        uint256 nbVaults = 2;
        vaultAddresses = new address[](nbVaults);
        rewardsTokensList = new address[][](nbVaults);
        rewardsTokensAmounts = new uint256[][](nbVaults);

        // set vault1 rewards and amounts
        vaultAddresses[0] = vault1;
        rewardsTokensList[0] = new address[](2);
        rewardsTokensAmounts[0] = new uint256[](2);

        rewardsTokensList[0][0] = address(rewardToken);
        rewardToken.mint(address(liquidationRow), 400);
        rewardsTokensAmounts[0][0] = 400;

        rewardsTokensList[0][1] = address(rewardToken2);
        rewardToken2.mint(address(liquidationRow), 100);
        rewardsTokensAmounts[0][1] = 100;

        // add more rewards for vault1
        vaultAddresses[1] = vault1;
        rewardsTokensList[1] = new address[](2);
        rewardsTokensAmounts[1] = new uint256[](2);

        rewardsTokensList[1][0] = address(rewardToken);
        rewardToken.mint(address(liquidationRow), 1300);
        rewardsTokensAmounts[1][0] = 1300;

        rewardsTokensList[1][1] = address(rewardToken3);
        rewardToken3.mint(address(liquidationRow), 40);
        rewardsTokensAmounts[1][1] = 40;
    }

    /**
     * @notice Returns test data for the updateBalances function.
     * @dev This function creates test data with two vaults containing different sets of tokens and amounts.
     * It is intended to simulate a scenario where multiple vaults have different types of reward tokens
     * with varying amounts. The resulting data can be used to test the updateBalances function
     * when updating balances for multiple vaults.
     *
     * Data values:
     * - vault1 has 100 rewardToken and 200 rewardToken2
     * - vault2 has 100 rewardToken and 200 rewardToken2
     *
     * @return vaultAddresses An array containing the addresses of the vaults ([vault1, vault2]).
     * @return rewardsTokensList A 2D array containing the addresses of the reward tokens for each vault
     *                           ([[rewardToken, rewardToken2], [rewardToken, rewardToken2]]).
     * @return rewardsTokensAmounts A 2D array containing the amounts of the reward tokens for each vault
     *                              ([[100, 200], [100, 200]]).
     */
    function get_update_balance_multiple_vaults()
        private
        returns (
            address[] memory vaultAddresses,
            address[][] memory rewardsTokensList,
            uint256[][] memory rewardsTokensAmounts
        )
    {
        uint256 nbVaults = 2;
        vaultAddresses = new address[](nbVaults);
        rewardsTokensList = new address[][](nbVaults);
        rewardsTokensAmounts = new uint256[][](nbVaults);

        // set vault1 rewards and amounts
        vaultAddresses[0] = vault1;
        rewardsTokensList[0] = new address[](2);
        rewardsTokensAmounts[0] = new uint256[](2);

        rewardsTokensList[0][0] = address(rewardToken);
        rewardToken.mint(address(liquidationRow), 100);
        rewardsTokensAmounts[0][0] = 100;

        rewardsTokensList[0][1] = address(rewardToken2);
        rewardToken2.mint(address(liquidationRow), 200);
        rewardsTokensAmounts[0][1] = 200;

        // set vault2 rewards and amounts
        vaultAddresses[1] = vault2;
        rewardsTokensList[1] = new address[](2);
        rewardsTokensAmounts[1] = new uint256[](2);

        rewardsTokensList[1][0] = address(rewardToken);
        rewardToken.mint(address(liquidationRow), 100);
        rewardsTokensAmounts[1][0] = 100;

        rewardsTokensList[1][1] = address(rewardToken2);
        rewardToken2.mint(address(liquidationRow), 200);
        rewardsTokensAmounts[1][1] = 200;
    }
}
