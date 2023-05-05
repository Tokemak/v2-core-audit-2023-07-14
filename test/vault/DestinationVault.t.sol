// SPDX-License-Identifier: MIT
pragma solidity >=0.8.7;

import { Test, StdCheats, StdUtils } from "forge-std/Test.sol";
import { DestinationVault } from "src/vault/DestinationVault.sol";
import { ISystemRegistry } from "src/interfaces/ISystemRegistry.sol";
import { ERC20 } from "openzeppelin-contracts/token/ERC20/ERC20.sol";
import { IERC20Metadata as IERC20 } from "openzeppelin-contracts/token/ERC20/extensions/IERC20Metadata.sol";

contract DestinationVaultBaseTests is Test {
    address private testUser1;
    address private testUser2;
    TestERC20 private token;
    TestDestinationVault private testVault;

    event Donated(address sender, uint256 amount);
    event Withdraw(
        uint256 target, uint256 actual, uint256 debtLoss, uint256 claimLoss, uint256 fromIdle, uint256 fromDebt
    );

    function setUp() public {
        testUser1 = vm.addr(1);
        testUser2 = vm.addr(2);
        token = new TestERC20("ABC", "ABC");
        testVault = new TestDestinationVault(address(token));

        // TestUser1 starts with 100 ABC
        token.mint(testUser1, 100);

        // Token deployer gets 1000 ABC
        token.mint(address(this), 1000);
    }

    function testDonateIncreasesIdle() public {
        uint256 donation = 10;
        vm.startPrank(testUser1);
        token.increaseAllowance(address(testVault), donation);
        testVault.donate(donation);
        vm.stopPrank();

        uint256 idle = testVault.idle();

        assertEq(idle, 10, "idle");
    }

    function testDonateTransfersAssetToVault() public {
        uint256 donation = 10;
        vm.startPrank(testUser1);
        token.increaseAllowance(address(testVault), donation);
        testVault.donate(donation);
        vm.stopPrank();

        uint256 userBalance = token.balanceOf(testUser1);
        uint256 vaultBalance = token.balanceOf(address(testVault));

        assertEq(userBalance, 90, "userBalance");
        assertEq(vaultBalance, 10, "vaultBalance");
    }

    function testDonateEmitsEvent() public {
        uint256 donation = 10;
        vm.startPrank(testUser1);
        token.increaseAllowance(address(testVault), donation);

        vm.expectEmit(true, true, true, true);
        emit Donated(testUser1, donation);

        testVault.donate(donation);
        vm.stopPrank();
    }

    function testIdleDoesntIncreaseOnDirectAssetTransfer() public {
        uint256 donation = 10;
        uint256 direct = 50;
        vm.startPrank(testUser1);
        token.increaseAllowance(address(testVault), donation);

        vm.expectEmit(true, true, true, true);
        emit Donated(testUser1, donation);

        testVault.donate(donation);

        token.transfer(address(testVault), direct);
        vm.stopPrank();

        uint256 idle = testVault.idle();
        uint256 userBalance = token.balanceOf(testUser1);
        uint256 vaultBalance = token.balanceOf(address(testVault));

        assertEq(idle, donation, "idle");
        assertEq(userBalance, 100 - donation - direct, "userBalance");
        assertEq(vaultBalance, donation + direct, "vaultBalance");
    }

    function testIdleInitializesToZeroRegardlessOfContractBalance() public {
        address nextAddress = computeCreateAddress(address(this), 3);
        token.mint(nextAddress, 100);

        TestDestinationVault vault = new TestDestinationVault(address(token));
        uint256 vaultIdle = vault.idle();
        uint256 vaultBalance = token.balanceOf(address(vault));
        assertEq(nextAddress, address(vault));
        assertEq(vaultIdle, 0);
        assertEq(vaultBalance, 100);
    }

    /* ******************************** */
    /* Profit    
    /* ******************************** */

    function testWithdrawBaseAssetGivesPortionOfProfitFromIdle() public {
        // We have 100 idle funds, and 50 previously deployed.
        // That 50 deployment is now worth 60, putting us 10 in profit
        // That puts nav at 160
        // User 1, an LMPVault in this case, owns 50% of the pool
        // User 1 should expect 80 back, and since idle has enough
        // to cover, all 80 should come from there leaving
        // 20 in idle and not touching the debt

        withdrawBaseAssetTest(
            WithdrawBaseAssetTest({
                initialIdle: 100,
                initialDebt: 50,
                initialDebtValue: 60,
                reclaimDebtAmount: 0,
                reclaimDebtLoss: 0,
                rewardValue: 0,
                claimedVested: 0,
                userOwnershipPct: 500,
                requestedAmount: 10_000,
                expectedAmount: 80,
                expectedDebtLoss: 0,
                expectedClaimLoss: 0,
                expectedFromIdle: 80,
                expectedFromDebt: 0,
                resultingIdle: 20,
                resultingDebt: 50
            })
        );
    }

    function testWithdrawBaseAssetGivesPortionOfProfitFromDebt() public {
        // We have 0 in idle, and a previous 50 deployment
        // That deployment is now worth 60, puts us 10 in profit
        // nav is 60
        // User owns 50% of the vault, so should expect 30
        // There is no idle so we expect everything to come from debt
        // We burned half of the debt so we expect our initial debt
        // number to cut in half, down to 25

        withdrawBaseAssetTest(
            WithdrawBaseAssetTest({
                initialIdle: 0,
                initialDebt: 50,
                initialDebtValue: 60,
                reclaimDebtAmount: 30,
                reclaimDebtLoss: 0,
                rewardValue: 0,
                claimedVested: 0,
                userOwnershipPct: 500,
                requestedAmount: 10_000,
                expectedAmount: 30,
                expectedDebtLoss: 0,
                expectedClaimLoss: 0,
                expectedFromIdle: 0,
                expectedFromDebt: 30,
                resultingIdle: 0,
                resultingDebt: 25
            })
        );
    }

    function testWithdrawBaseAssetGivesPortionOfProfitFromIdleAndDebt() public {
        // We have 100 in idle, and a previous deployment of 50
        // That 50 deployment is now worth 120, NAV is at 220
        // User owns 50% of the pool so should get 110
        // We have 100 in idle so we expect to clean that out
        // and then pull the remaining 10 from debt
        // Debt had a total value of 120, so we need to burn 10/120, 8.3% of our debt
        // 8.3% of our tracked debt number, 50, is 4.16
        // This should round up though, so we should be left with 45

        withdrawBaseAssetTest(
            WithdrawBaseAssetTest({
                initialIdle: 100,
                initialDebt: 50,
                initialDebtValue: 120,
                reclaimDebtAmount: 10,
                reclaimDebtLoss: 0,
                rewardValue: 0,
                claimedVested: 0,
                userOwnershipPct: 500,
                requestedAmount: 10_000,
                expectedAmount: 110,
                expectedDebtLoss: 0,
                expectedClaimLoss: 0,
                expectedFromIdle: 100,
                expectedFromDebt: 10,
                resultingIdle: 0,
                resultingDebt: 45
            })
        );
    }

    /* ******************************** */
    /* Loss
    /* ******************************** */

    function testWithdrawBaseAssetGivesPortionOfValueLossFromIdle() public {
        // We have 100 in idle, 50 deployment, with that deployment now worth 40
        // nav is then 140. User would originally be entitled to 75, but having
        // to take their portion of the loss, 50% of 10, they now only expect 70
        // realizing a loss of 5. All 70 can come from idle, leaving debt untouched
        withdrawBaseAssetTest(
            WithdrawBaseAssetTest({
                initialIdle: 100,
                initialDebt: 50,
                initialDebtValue: 40,
                reclaimDebtAmount: 0,
                reclaimDebtLoss: 0,
                rewardValue: 0,
                claimedVested: 0,
                userOwnershipPct: 500,
                requestedAmount: 10_000,
                expectedAmount: 70,
                expectedDebtLoss: 5,
                expectedClaimLoss: 0,
                expectedFromIdle: 70,
                expectedFromDebt: 0,
                resultingIdle: 30,
                resultingDebt: 50
            })
        );
    }

    function testWithdrawBaseAssetGivesPortionOfValueLossFromDebt() public {
        // We have none in idle and 50 deployment is now worth 40
        // User owns 50% of the vault, so should only expect 20
        // They need to take 50% of the loss, so 5
        // This should leave 25 in debt since we had to burn half

        withdrawBaseAssetTest(
            WithdrawBaseAssetTest({
                initialIdle: 0,
                initialDebt: 50,
                initialDebtValue: 40,
                reclaimDebtAmount: 20,
                reclaimDebtLoss: 0,
                rewardValue: 0,
                claimedVested: 0,
                userOwnershipPct: 500,
                requestedAmount: 10_000,
                expectedAmount: 20,
                expectedDebtLoss: 5,
                expectedClaimLoss: 0,
                expectedFromIdle: 0,
                expectedFromDebt: 20,
                resultingIdle: 0,
                resultingDebt: 25
            })
        );
    }

    function testWithdrawBaseAssetGivesPortionOfValueLossFromIdleAndDebt() public {
        // 100 in idle, and our 200 deployment is now only worth 120
        // puts nav at 220 and losses at 80. User would originally be
        // entitled to 150, but with the total loss at 80, their portion being 40
        // the expected return amount is 110. Idle can cover 100 of that
        // with the rest, 10, needing to come from debt
        // Debt had a total value of 120, so we need to burn 10/120, 8.3% of our debt
        // 8.3% of our tracked debt number, 200, is 16.67
        // This should round up though, so we should be left with 200 - 17 = 183

        withdrawBaseAssetTest(
            WithdrawBaseAssetTest({
                initialIdle: 100,
                initialDebt: 200,
                initialDebtValue: 120,
                reclaimDebtAmount: 10,
                reclaimDebtLoss: 0,
                rewardValue: 0,
                claimedVested: 0,
                userOwnershipPct: 500,
                requestedAmount: 10_000,
                expectedAmount: 110,
                expectedDebtLoss: 40,
                expectedClaimLoss: 0,
                expectedFromIdle: 100,
                expectedFromDebt: 10,
                resultingIdle: 0,
                resultingDebt: 183
            })
        );
    }

    /* ******************************** */
    /* Profit + Reward Value
    /* ******************************** */

    function testWithdrawBaseAssetGivesPortionOfProfitFromIdleWithReward() public {
        // We have 100 idle funds, and 50 previously deployed.
        // We have 10 in claimable rewards
        // That 50 deployment is now worth 60, putting us 10 in profit
        // That puts nav at 170
        // User 1, an LMPVault in this case, owns 50% of the pool
        // User 1 should expect 85 back, and since idle has enough
        // to cover, all 85 should come from there leaving
        // 15 in idle and not touching the debt

        withdrawBaseAssetTest(
            WithdrawBaseAssetTest({
                initialIdle: 100,
                initialDebt: 50,
                initialDebtValue: 60,
                reclaimDebtAmount: 0,
                reclaimDebtLoss: 0,
                rewardValue: 10,
                claimedVested: 10,
                userOwnershipPct: 500,
                requestedAmount: 10_000,
                expectedAmount: 85,
                expectedDebtLoss: 0,
                expectedClaimLoss: 0,
                expectedFromIdle: 85,
                expectedFromDebt: 0,
                resultingIdle: 15,
                resultingDebt: 50
            })
        );
    }

    function testWithdrawBaseAssetGivesPortionOfProfitFromDebtWithReward() public {
        // We have 0 in idle, and a previous 50 deployment
        // That deployment is now worth 60, puts us 10 in profit
        // We have 10 in rewards, nav is 70
        // User owns 50% of the vault, so should expect 35
        // We can get 10 from rewards, putting our debt component at 25
        // Debt is worth 60 now, so we need to burn 25/60, 41.67% of our debt to get it
        // That's 20.83 shares of the original 50, we round up so 21
        // Leaves us with 29 in debt

        withdrawBaseAssetTest(
            WithdrawBaseAssetTest({
                initialIdle: 0,
                initialDebt: 50,
                initialDebtValue: 60,
                reclaimDebtAmount: 25,
                reclaimDebtLoss: 0,
                rewardValue: 10,
                claimedVested: 10,
                userOwnershipPct: 500,
                requestedAmount: 10_000,
                expectedAmount: 35,
                expectedDebtLoss: 0,
                expectedClaimLoss: 0,
                expectedFromIdle: 10,
                expectedFromDebt: 25,
                resultingIdle: 0,
                resultingDebt: 29
            })
        );
    }

    function testWithdrawBaseAssetGivesPortionOfProfitFromIdleAndDebtWithReward() public {
        // We have 100 in idle, and a previous deployment of 50
        // We have 10 in rewards
        // That 50 deployment is now worth 120, NAV is at 230
        // User owns 50% of the pool so should get 115
        // We have 100, and will get 10 from reward, in idle so we expect to clean that out
        // and then pull the remaining 5 from debt
        // Debt had a total value of 120, so we need to burn 5/120, 4.16% of our debt
        // 4.16% of our tracked debt number, 50, is 2.083
        // This should round up though, so we should be left with 47

        withdrawBaseAssetTest(
            WithdrawBaseAssetTest({
                initialIdle: 100,
                initialDebt: 50,
                initialDebtValue: 120,
                reclaimDebtAmount: 5,
                reclaimDebtLoss: 0,
                rewardValue: 10,
                claimedVested: 10,
                userOwnershipPct: 500,
                requestedAmount: 10_000,
                expectedAmount: 115,
                expectedDebtLoss: 0,
                expectedClaimLoss: 0,
                expectedFromIdle: 110,
                expectedFromDebt: 5,
                resultingIdle: 0,
                resultingDebt: 47
            })
        );
    }

    /* ******************************** */
    /* Loss + Reward Value
    /* ******************************** */

    function testWithdrawBaseAssetGivesPortionOfValueLossFromIdleWithReward() public {
        // We have 100 in idle, 50 deployment, with that deployment now worth 40
        // We have 10 in reward so nav is then 150.
        // User would originally be entitled to 80 ((100 + 50 + 10) * 50%), but having
        // to take their portion of the loss, 50% of 10, they now only expect 75
        // realizing a loss of 5. All 75 can come from idle, leaving debt untouched
        // and not requiring an actual claim of rewards
        withdrawBaseAssetTest(
            WithdrawBaseAssetTest({
                initialIdle: 100,
                initialDebt: 50,
                initialDebtValue: 40,
                reclaimDebtAmount: 0,
                reclaimDebtLoss: 0,
                rewardValue: 10,
                claimedVested: 0,
                userOwnershipPct: 500,
                requestedAmount: 10_000,
                expectedAmount: 75,
                expectedDebtLoss: 5,
                expectedClaimLoss: 0,
                expectedFromIdle: 75,
                expectedFromDebt: 0,
                resultingIdle: 25,
                resultingDebt: 50
            })
        );
    }

    function testWithdrawBaseAssetGivesPortionOfValueLossFromIdleWithRewardClaimed() public {
        // We have 50 in idle, 50 deployment, with that deployment now worth 40
        // We have 100 in reward so nav is then 190.
        // User would originally be entitled to 100 ((50 + 50 + 100) * 50%), but having
        // to take their portion of the loss, 50% of 10, they now only expect 95
        // realizing a loss of 5. We clean out the original idle of 50,
        // requiring us to claim rewards. That will put idle at 150
        // We only need to take 95 of that, leaving idle with 55

        withdrawBaseAssetTest(
            WithdrawBaseAssetTest({
                initialIdle: 50,
                initialDebt: 50,
                initialDebtValue: 40,
                reclaimDebtAmount: 0,
                reclaimDebtLoss: 0,
                rewardValue: 100,
                claimedVested: 100,
                userOwnershipPct: 500,
                requestedAmount: 10_000,
                expectedAmount: 95,
                expectedDebtLoss: 5,
                expectedClaimLoss: 0,
                expectedFromIdle: 95,
                expectedFromDebt: 0,
                resultingIdle: 55,
                resultingDebt: 50
            })
        );
    }

    function testWithdrawBaseAssetGivesPortionOfValueLossFromDebtWithReward() public {
        // We have none in idle, 10 in rewards, and 50 deployment is now worth 40
        // User owns 50% of the vault, so should only expect 25 ((40+10)/2)
        // They need to take 50% of the loss, so 5
        // We'll claim rewards and get 10 from idle. Leaves us getting 15 from debt
        // Deployment is only worth 40 now, so 15/40, we need to burn 37.5% of our shares
        // So 37.5% of our original 50 debt gets burnt also, rounded up, 19, leaving 31 debt

        withdrawBaseAssetTest(
            WithdrawBaseAssetTest({
                initialIdle: 0,
                initialDebt: 50,
                initialDebtValue: 40,
                reclaimDebtAmount: 15,
                reclaimDebtLoss: 0,
                rewardValue: 10,
                claimedVested: 10,
                userOwnershipPct: 500,
                requestedAmount: 10_000,
                expectedAmount: 25,
                expectedDebtLoss: 5,
                expectedClaimLoss: 0,
                expectedFromIdle: 10,
                expectedFromDebt: 15,
                resultingIdle: 0,
                resultingDebt: 31
            })
        );
    }

    function testWithdrawBaseAssetGivesPortionOfValueLossFromIdleAndDebtWithReward() public {
        // 100 in idle, and our 200 deployment is now only worth 140
        // have a reward of 20
        // puts nav at 260 and losses at 60. User would originally be
        // entitled to 160, but with the total loss at 60, their portion being 30
        // the expected return amount is 130. Idle can cover 100 of that
        // we're claim rewards can get 20 there
        // with the rest, 10, needing to come from debt
        // Debt had a total value of 140, so we need to burn 10/140, 7.1% of our debt
        // 7.1% of our tracked debt number, 200, is 14.29
        // This should round up though, so we should be left with 200 - 15 = 185

        withdrawBaseAssetTest(
            WithdrawBaseAssetTest({
                initialIdle: 100,
                initialDebt: 200,
                initialDebtValue: 140,
                reclaimDebtAmount: 10,
                reclaimDebtLoss: 0,
                rewardValue: 20,
                claimedVested: 20,
                userOwnershipPct: 500,
                requestedAmount: 10_000,
                expectedAmount: 130,
                expectedDebtLoss: 30,
                expectedClaimLoss: 0,
                expectedFromIdle: 120,
                expectedFromDebt: 10,
                resultingIdle: 0,
                resultingDebt: 185
            })
        );
    }

    /* ******************************** */
    /* Profit + Claim Loss
    /* ******************************** */

    function testWithdrawBaseAssetGivesPortionOfProfitFromDebtWithClaimLoss() public {
        // We have 0 in idle, and a previous 50 deployment
        // That deployment is now worth 60, puts us 10 in profit
        // nav is 60
        // User owns 50% of the vault, so should expect 30
        // Claiming will result in 2 slippage loss
        // So of the 30 we'd expect, 2 to slippage, we expect 28
        // There is no idle so we expect everything to come from debt
        // We burned half of the debt so we expect our initial debt
        // number to cut in half, down to 25

        withdrawBaseAssetTest(
            WithdrawBaseAssetTest({
                initialIdle: 0,
                initialDebt: 50,
                initialDebtValue: 60,
                reclaimDebtAmount: 28,
                reclaimDebtLoss: 2,
                rewardValue: 0,
                claimedVested: 0,
                userOwnershipPct: 500,
                requestedAmount: 10_000,
                expectedAmount: 28,
                expectedDebtLoss: 0,
                expectedClaimLoss: 2,
                expectedFromIdle: 0,
                expectedFromDebt: 28,
                resultingIdle: 0,
                resultingDebt: 25
            })
        );
    }

    function testWithdrawBaseAssetGivesPortionOfProfitFromIdleAndDebtWithClaimLoss() public {
        // We have 100 in idle, and a previous deployment of 50
        // That 50 deployment is now worth 120, NAV is at 220
        // User owns 50% of the pool so should get 110
        // We have 100 in idle so we expect to clean that out
        // and then pull the remaining 8 from debt, with a claim loss of 2
        // Debt had a total value of 120, so we need to burn 10/120, 8.3% of our debt
        // 8.3% of our tracked debt number, 50, is 4.16
        // This should round up though, so we should be left with 45

        withdrawBaseAssetTest(
            WithdrawBaseAssetTest({
                initialIdle: 100,
                initialDebt: 50,
                initialDebtValue: 120,
                reclaimDebtAmount: 8,
                reclaimDebtLoss: 2,
                rewardValue: 0,
                claimedVested: 0,
                userOwnershipPct: 500,
                requestedAmount: 10_000,
                expectedAmount: 108,
                expectedDebtLoss: 0,
                expectedClaimLoss: 2,
                expectedFromIdle: 100,
                expectedFromDebt: 8,
                resultingIdle: 0,
                resultingDebt: 45
            })
        );
    }

    /* ******************************** */
    /* Loss + Claim Loss
    /* ******************************** */

    function testWithdrawBaseAssetGivesPortionOfValueLossFromDebtWithClaimLoss() public {
        // We have none in idle and 50 deployment is now worth 40
        // User owns 50% of the vault, so should only expect 20
        // We'll lose 2 when claiming
        // They need to take 50% of the loss, so 5
        // This should leave 25 in debt since we had to burn half

        withdrawBaseAssetTest(
            WithdrawBaseAssetTest({
                initialIdle: 0,
                initialDebt: 50,
                initialDebtValue: 40,
                reclaimDebtAmount: 18,
                reclaimDebtLoss: 2,
                rewardValue: 0,
                claimedVested: 0,
                userOwnershipPct: 500,
                requestedAmount: 10_000,
                expectedAmount: 18,
                expectedDebtLoss: 5,
                expectedClaimLoss: 2,
                expectedFromIdle: 0,
                expectedFromDebt: 18,
                resultingIdle: 0,
                resultingDebt: 25
            })
        );
    }

    function testWithdrawBaseAssetGivesPortionOfValueLossFromIdleAndDebtWithClaimLoss() public {
        // 100 in idle, and our 200 deployment is now only worth 120
        // puts nav at 220 and losses at 80. User would originally be
        // entitled to 150, but with the total loss at 80, their portion being 40
        // the expected return amount is 110. Idle can cover 100 of that
        // with the rest, 10, needing to come from debt, but we'll lose 3 in slippage
        // Debt had a total value of 120, so we need to burn 10/120, 8.3% of our debt
        // 8.3% of our tracked debt number, 200, is 16.67
        // This should round up though, so we should be left with 200 - 17 = 183

        withdrawBaseAssetTest(
            WithdrawBaseAssetTest({
                initialIdle: 100,
                initialDebt: 200,
                initialDebtValue: 120,
                reclaimDebtAmount: 7,
                reclaimDebtLoss: 3,
                rewardValue: 0,
                claimedVested: 0,
                userOwnershipPct: 500,
                requestedAmount: 10_000,
                expectedAmount: 107,
                expectedDebtLoss: 40,
                expectedClaimLoss: 3,
                expectedFromIdle: 100,
                expectedFromDebt: 7,
                resultingIdle: 0,
                resultingDebt: 183
            })
        );
    }

    /* ******************************** */
    /* Loss + Partial Ownership
    /* ******************************** */

    function testWithdrawBaseAssetGivesPortionOfValueLossFromIdlePartialOwner() public {
        // We have 100 in idle, 50 deployment, with that deployment now worth 40
        // nav is then 140. With the vault sitting at a loss, we can only burn the
        // tx.origin lmp ownership portion.
        // So the LMPVault itself is owed 70, but we have to take our portion of
        // the current loss. For the LPVault as a whole that's 5, 50% of 50-40,
        // the tx.origin portion being 40% of that or 2.
        // We can also only burn our portion of the LMPVault shares which would
        // leave us with 70 * 40% or 28
        // That entire 28 can come from idle, leaving 72 there

        withdrawBaseAssetTestMinorOwnership(
            WithdrawBaseAssetTest({
                initialIdle: 100,
                initialDebt: 50,
                initialDebtValue: 40,
                reclaimDebtAmount: 0,
                reclaimDebtLoss: 0,
                rewardValue: 0,
                claimedVested: 0,
                userOwnershipPct: 500,
                requestedAmount: 10_000,
                expectedAmount: 28,
                expectedDebtLoss: 2,
                expectedClaimLoss: 0,
                expectedFromIdle: 28,
                expectedFromDebt: 0,
                resultingIdle: 72,
                resultingDebt: 50
            }),
            40,
            100
        );
    }

    function testWithdrawBaseAssetGivesPortionOfValueLossFromDebtPartialOwner() public {
        // We have none in idle and 50 deployment is now worth 40
        // LMP owns 50% of the vault, tx.origin 40% of the vault,
        // so should only expect 8.
        // They need to take 50% + 40% of the loss, so 2
        // To get 8 we need to burn, 8/40, or 20% of our shares, so 20% of the debt
        // is wiped too
        // This should leave 40 in debt

        withdrawBaseAssetTestMinorOwnership(
            WithdrawBaseAssetTest({
                initialIdle: 0,
                initialDebt: 50,
                initialDebtValue: 40,
                reclaimDebtAmount: 8,
                reclaimDebtLoss: 0,
                rewardValue: 0,
                claimedVested: 0,
                userOwnershipPct: 500,
                requestedAmount: 10_000,
                expectedAmount: 8,
                expectedDebtLoss: 2,
                expectedClaimLoss: 0,
                expectedFromIdle: 0,
                expectedFromDebt: 8,
                resultingIdle: 0,
                resultingDebt: 40
            }),
            40,
            100
        );
    }

    function testWithdrawBaseAssetGivesPortionOfValueLossFromIdleAndDebtPartialOwner() public {
        // 100 in idle, and our 200 deployment is now only worth 120
        // puts nav at 220 and losses at 80. User would originally be
        // entitled to 150, but with the total loss at 80, their portion being 40
        // the expected return amount is 110. tx.origin only owns 98% of
        // the lmp vault so they can only take 107.8, Rounded down to 107.
        // Idle can cover 100 of that
        // with the rest, 7, needing to come from debt
        // Debt had a total value of 120, so we need to burn 7/120, 5.83% of our debt
        // 5.83% of our tracked debt number, 200, is 11.67
        // This should round up though, so we should be left with 200 - 12 = 183

        withdrawBaseAssetTestMinorOwnership(
            WithdrawBaseAssetTest({
                initialIdle: 100,
                initialDebt: 200,
                initialDebtValue: 120,
                reclaimDebtAmount: 7,
                reclaimDebtLoss: 0,
                rewardValue: 0,
                claimedVested: 0,
                userOwnershipPct: 500,
                requestedAmount: 10_000,
                expectedAmount: 107,
                expectedDebtLoss: 40,
                expectedClaimLoss: 0,
                expectedFromIdle: 100,
                expectedFromDebt: 7,
                resultingIdle: 0,
                resultingDebt: 188
            }),
            98,
            100
        );
    }

    function withdrawBaseAssetTestMinorOwnership(
        WithdrawBaseAssetTest memory settings,
        uint256 ownerNumerator,
        uint256 ownerDenominator
    ) internal {
        // Arrange

        // Do we have any idle assets?
        if (settings.initialIdle > 0) {
            deployerDonate(settings.initialIdle);
        }

        // If we've done a deployment before, we have debt
        if (settings.initialDebt > 0) {
            testVault.setDebt(settings.initialDebt);
        }

        // What is the value of that deployment?
        if (settings.initialDebt > 0 && settings.initialDebtValue > 0) {
            testVault.setDebtValue(settings.initialDebtValue);
            setupReclaimDebtAmount(settings.reclaimDebtAmount);
        }

        if (settings.rewardValue > 0) {
            testVault.setRewardValue(settings.rewardValue);
        }

        if (settings.claimedVested > 0) {
            token.mint(address(testVault), settings.claimedVested);
            testVault.setClaimVested(settings.claimedVested);
        }

        // Are we going to lose anything when doing an actual withdrawal?
        // This would be due to slippage most likely
        if (settings.reclaimDebtLoss > 0) {
            testVault.setReclaimDebtLoss(settings.reclaimDebtLoss);
        }

        testVault.mint(testUser1, settings.userOwnershipPct);
        testVault.mint(testUser2, 1000 - settings.userOwnershipPct);

        // Act

        // User1 performs the withdraw, withdrawing everything
        vm.prank(testUser1);

        vm.expectEmit(true, true, true, true);
        emit Withdraw(
            settings.requestedAmount,
            settings.expectedAmount,
            settings.expectedDebtLoss,
            settings.expectedClaimLoss,
            settings.expectedFromIdle,
            settings.expectedFromDebt
            );

        (uint256 amount, uint256 loss) =
            testVault.withdrawBaseAsset(settings.requestedAmount, ownerNumerator, ownerDenominator);

        // Assert

        assertEq(loss, settings.expectedDebtLoss + settings.expectedClaimLoss, "loss");
        assertEq(amount, settings.expectedAmount, "expectedAmount");

        assertEq(testVault.idle(), settings.resultingIdle, "resultingIdle");
        assertEq(testVault.debt(), settings.resultingDebt, "resultingDebt");
    }

    function withdrawBaseAssetTest(WithdrawBaseAssetTest memory settings) internal {
        withdrawBaseAssetTestMinorOwnership(settings, 1, 1);
    }

    // Factor in Rewards

    function deployerDonate(uint256 amount) public {
        token.increaseAllowance(address(testVault), amount);
        testVault.donate(amount);
    }

    function setupReclaimDebtAmount(uint256 amount) public {
        token.mint(address(testVault), amount);
        testVault.setReclaimDebtAmount(amount);
    }
}

struct WithdrawBaseAssetTest {
    uint256 initialIdle;
    uint256 initialDebt;
    uint256 initialDebtValue;
    uint256 reclaimDebtAmount;
    uint256 reclaimDebtLoss;
    uint256 rewardValue;
    uint256 claimedVested;
    uint256 userOwnershipPct;
    /// 1000 = 100%, 550 = 55%
    uint256 requestedAmount;
    uint256 expectedAmount;
    uint256 expectedDebtLoss;
    uint256 expectedClaimLoss;
    uint256 expectedFromIdle;
    uint256 expectedFromDebt;
    uint256 resultingIdle;
    uint256 resultingDebt;
}

contract TestERC20 is ERC20 {
    constructor(string memory name_, string memory symbol_) ERC20(name_, symbol_) { }

    function mint(address account, uint256 amount) external {
        _mint(account, amount);
    }
}

/// @notice TODO: Set these tests up to run on every implementation
contract BaseDestinationVaultTests is Test {
    function setUp() public { }

    function testBaseAssetDecimalsMatchVault() public { }

    function testDebtValueDoesNotIncreaseOnDirectAssetTransfer() public { }

    function testRewardValueDoesNotIncreaseOnDirectAssetTransfer() public { }

    function testClaimVestedDoesNotChangeDebt() public { }

    function testClaimVestedIncreasesIdle() public { }

    function testClaimVestedMovesRewardValueToIdle() public { }

    function testReclaimDebtRevertsOnZeroPercent() public { }

    function testReclaimDebtDecreasesUnderlyerHoldingsByPct() public { }

    function testReclaimDebtReportsAmountAndLoss() public { }

    function testReclaimDebtReportsAmount() public { }
}

contract TestDestinationVault is DestinationVault {
    uint256 private _debtVault;
    uint256 private _rewardValue;
    uint256 private _claimVested;
    uint256 private _reclaimDebtAmount;
    uint256 private _reclaimDebtLoss;

    constructor(address token) {
        initialize(ISystemRegistry(address(0)), IERC20(token), "ABC", abi.encode(""));
    }

    function mint(address to, uint256 amount) public {
        _mint(to, amount);
    }

    function debtValue() public view override returns (uint256 value) {
        return _debtVault;
    }

    function rewardValue() public view override returns (uint256 value) {
        return _rewardValue;
    }

    function claimVested_() internal view override returns (uint256 amount) {
        return _claimVested;
    }

    function reclaimDebt_(uint256, uint256) internal view override returns (uint256 amount, uint256 loss) {
        return (_reclaimDebtAmount, _reclaimDebtLoss);
    }

    function setDebtValue(uint256 val) public {
        _debtVault = val;
    }

    function setRewardValue(uint256 val) public {
        _rewardValue = val;
    }

    function setClaimVested(uint256 val) public {
        _claimVested = val;
    }

    function setReclaimDebtAmount(uint256 val) public {
        _reclaimDebtAmount = val;
    }

    function setReclaimDebtLoss(uint256 val) public {
        _reclaimDebtLoss = val;
    }

    function setDebt(uint256 val) public {
        debt = val;
    }

    function recover(address[] calldata tokens, address[] calldata amounts, address[] calldata destination) external { }

    function reset() external { }
}
