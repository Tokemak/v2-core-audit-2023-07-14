/* solhint-disable func-name-mixedcase */
// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import { Test } from "forge-std/Test.sol";

import { ERC20Mock } from "openzeppelin-contracts/mocks/ERC20Mock.sol";
import { IERC20 } from "openzeppelin-contracts/token/ERC20/IERC20.sol";

import { MainRewarder } from "src/rewarders/MainRewarder.sol";
import { ExtraRewarder } from "src/rewarders/ExtraRewarder.sol";
import { StakeTrackingMock } from "test/mocks/StakeTrackingMock.sol";
import { IStakeTracking } from "src/interfaces/rewarders/IStakeTracking.sol";

import { Roles } from "src/libs/Roles.sol";
import { BaseTest } from "test/BaseTest.t.sol";

import { Errors } from "src/utils/Errors.sol";

import { PRANK_ADDRESS, RANDOM } from "test/utils/Addresses.sol";

import { console2 as console } from "forge-std/console2.sol";

contract MainRewarderTest is BaseTest {
    address private operator;

    StakeTrackingMock private stakeTracker;
    address private liquidator;

    MainRewarder private mainRewardVault;
    ExtraRewarder private extraReward1Vault;
    ExtraRewarder private extraReward2Vault;
    MainRewarder private tokeRewardVault;

    ERC20Mock private mainReward;
    ERC20Mock private extraReward1;
    ERC20Mock private extraReward2;

    uint256 private amount = 100_000;
    uint256 private newRewardRatio = 800;
    uint256 private durationInBlock = 100;

    function setUp() public virtual override(BaseTest) {
        BaseTest.setUp();

        operator = vm.addr(1);
        liquidator = vm.addr(2);
        mainReward = new ERC20Mock("MAIN_REWARD", "MAIN_REWARD", address(this), 0);
        extraReward1 = new ERC20Mock("EXTRA_REWARD_1", "EXTRA_REWARD_1", address(this), 0);
        extraReward2 = new ERC20Mock("EXTRA_REWARD_2", "EXTRA_REWARD_2", address(this), 0);

        // grant new roles
        accessController.grantRole(Roles.DV_REWARD_MANAGER_ROLE, operator);
        accessController.grantRole(Roles.LIQUIDATOR_ROLE, liquidator);

        deployGpToke();
        deal(address(toke), RANDOM, 1 ether);

        stakeTracker = new StakeTrackingMock();
        mainRewardVault = new MainRewarder(
            systemRegistry,
            address(stakeTracker),
            operator,
            address(mainReward),
            newRewardRatio,
            durationInBlock
        );

        extraReward1Vault = new ExtraRewarder(
            systemRegistry,
            address(stakeTracker),
            operator,
            address(extraReward1),
            address(mainRewardVault),
            newRewardRatio,
            durationInBlock
        );

        extraReward2Vault = new ExtraRewarder(
            systemRegistry,
            address(stakeTracker),
            operator,
            address(extraReward2),
            address(mainRewardVault),
            newRewardRatio,
            durationInBlock
        );

        tokeRewardVault = new MainRewarder(
            systemRegistry,
            address(stakeTracker),
            operator,
            address(toke),
            newRewardRatio,
            durationInBlock
        );

        mainReward.mint(address(mainRewardVault), amount);
        extraReward1.mint(address(extraReward1Vault), amount);
        extraReward2.mint(address(extraReward2Vault), amount);

        // make sure only liquidator has access to `queueNewRewards`
        vm.startPrank(operator);
        vm.expectRevert(abi.encodeWithSelector(Errors.AccessDenied.selector));
        mainRewardVault.queueNewRewards(amount);

        vm.startPrank(liquidator);
        mainRewardVault.queueNewRewards(amount);
        extraReward1Vault.queueNewRewards(amount);
        extraReward2Vault.queueNewRewards(amount);

        vm.startPrank(operator);
        mainRewardVault.addExtraReward(address(extraReward1Vault));
        mainRewardVault.addExtraReward(address(extraReward2Vault));

        vm.stopPrank();
    }

    function test_getAllRewards() public {
        vm.prank(address(stakeTracker));
        mainRewardVault.stake(RANDOM, amount);

        vm.roll(block.number + 100);

        uint256 earned = mainRewardVault.earned(RANDOM);
        assertEq(earned, amount);

        uint256 rewardBalanceBefore = mainReward.balanceOf(RANDOM);
        uint256 extraReward1BalanceBefore = extraReward1.balanceOf(RANDOM);
        uint256 extraReward2BalanceBefore = extraReward2.balanceOf(RANDOM);

        vm.prank(RANDOM);
        mainRewardVault.getReward();

        uint256 rewardBalanceAfter = mainReward.balanceOf(RANDOM);
        uint256 extraReward1BalanceAfter = extraReward1.balanceOf(RANDOM);
        uint256 extraReward2BalanceAfter = extraReward2.balanceOf(RANDOM);

        assertEq(rewardBalanceAfter - rewardBalanceBefore, amount);
        assertEq(extraReward1BalanceAfter - extraReward1BalanceBefore, amount);
        assertEq(extraReward2BalanceAfter - extraReward2BalanceBefore, amount);
    }

    // TODO: add a set of failure tests! @adrienbarreau

    function test_toke_autoStakeRewards() public {
        vm.prank(address(stakeTracker));
        tokeRewardVault.stake(RANDOM, amount);

        vm.roll(block.number + 100);

        uint256 earned = tokeRewardVault.earned(RANDOM);
        assertEq(earned, amount);

        uint256 rewardBalanceBefore = tokeRewardVault.balanceOf(RANDOM);
        uint256 tokeBalanceBefore = toke.balanceOf(RANDOM);
        uint256 gpTokeBalanceBefore = gpToke.balanceOf(RANDOM);

        // set duration

        vm.prank(address(operator));
        tokeRewardVault.setTokeLockDuration(30 days);

        // claim rewards

        vm.prank(RANDOM);
        mainRewardVault.getReward();

        uint256 rewardBalanceAfter = mainReward.balanceOf(RANDOM);
        uint256 tokeBalanceAfter = toke.balanceOf(RANDOM);
        uint256 gpTokeBalanceAfter = gpToke.balanceOf(RANDOM);

        console.log("rewardBalanceBefore", rewardBalanceBefore);
        console.log("rewardBalanceAfter", rewardBalanceAfter);
        console.log("tokeBalanceBefore", tokeBalanceBefore);
        console.log("tokeBalanceAfter", tokeBalanceAfter);
        console.log("gpTokeBalanceBefore", gpTokeBalanceBefore);
        console.log("gpTokeBalanceAfter", gpTokeBalanceAfter);

        assertEq(rewardBalanceAfter - rewardBalanceBefore, amount, "reward not fully claimed");
        assertEq(tokeBalanceAfter - tokeBalanceBefore, 0, "toke balance shouldn't change"); // shouldn't change
        assertEq(gpTokeBalanceAfter - gpTokeBalanceBefore, amount, "gpToke not staked"); // now fully staked
    }
}
