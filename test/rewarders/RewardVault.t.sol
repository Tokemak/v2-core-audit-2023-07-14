/* solhint-disable func-name-mixedcase */
// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import { Test } from "forge-std/Test.sol";
import "forge-std/console2.sol";

import { ERC20Mock } from "openzeppelin-contracts/mocks/ERC20Mock.sol";
import { IERC20 } from "openzeppelin-contracts/token/ERC20/IERC20.sol";

import { MainRewarder } from "../../src/rewarders/MainRewarder.sol";
import { ExtraRewarder } from "../../src/rewarders/ExtraRewarder.sol";
import { IStakeTracking } from "../../src/interfaces/rewarders/IStakeTracking.sol";

import { PRANK_ADDRESS, RANDOM } from "../utils/Addresses.sol";

contract StakeTrackingMock is IStakeTracking {
    function totalSupply() external pure returns (uint256) {
        return 100_000_000_000_000_000;
    }

    function balanceOf(address) external pure returns (uint256) {
        return 100_000_000_000_000_000;
    }
}

contract MainRewarderTest is Test {
    address private operator;

    StakeTrackingMock private stakeTracker;

    MainRewarder private mainRewardVault;
    ExtraRewarder private extraReward1Vault;
    ExtraRewarder private extraReward2Vault;

    ERC20Mock private mainReward;
    ERC20Mock private extraReward1;
    ERC20Mock private extraReward2;

    uint256 private newRewardRatio = 800;
    uint256 private durationInBlock = 100;

    function setUp() public {
        operator = vm.addr(1);
        mainReward = new ERC20Mock("MAIN_REWARD", "MAIN_REWARD", address(this), 0);
        extraReward1 = new ERC20Mock("EXTRA_REWARD_1", "EXTRA_REWARD_1", address(this), 0);
        extraReward2 = new ERC20Mock("EXTRA_REWARD_2", "EXTRA_REWARD_2", address(this), 0);

        stakeTracker = new StakeTrackingMock();
        mainRewardVault = new MainRewarder(
            address(stakeTracker),
            operator,
            address(mainReward),
            operator,   
            newRewardRatio,
            durationInBlock
        );

        extraReward1Vault = new ExtraRewarder(
            address(stakeTracker),
            operator,
            address(extraReward1),
            address(mainRewardVault),
            newRewardRatio,
            durationInBlock
        );

        extraReward2Vault = new ExtraRewarder(
            address(stakeTracker),
            operator,
            address(extraReward2),
            address(mainRewardVault),
            newRewardRatio,
            durationInBlock
        );

        uint256 amount = 100_000;

        mainReward.mint(address(mainRewardVault), amount);
        extraReward1.mint(address(extraReward1Vault), amount);
        extraReward2.mint(address(extraReward2Vault), amount);

        vm.startPrank(operator);

        mainRewardVault.queueNewRewards(amount);
        extraReward1Vault.queueNewRewards(amount);
        extraReward2Vault.queueNewRewards(amount);

        mainRewardVault.addExtraReward(address(extraReward1Vault));
        mainRewardVault.addExtraReward(address(extraReward2Vault));

        vm.stopPrank();
    }

    function test_getAllRewards() public {
        uint256 amount = 100_000;

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
}
