// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2023 Tokemak Foundation. All rights reserved.
pragma solidity 0.8.17;

import { Test } from "forge-std/Test.sol";

import { IERC20 } from "openzeppelin-contracts/token/ERC20/IERC20.sol";

import { IBaseRewardPool } from "src/interfaces/external/convex/IBaseRewardPool.sol";
import { IConvexBooster } from "src/interfaces/external/convex/IConvexBooster.sol";
import { AuraRewards } from "src/destinations/adapters/rewards/AuraRewardsAdapter.sol";
import { AURA_BOOSTER, BAL_MAINNET, AURA_MAINNET } from "test/utils/Addresses.sol";
import { RewardAdapter } from "src/destinations/adapters/rewards/RewardAdapter.sol";
import { Errors } from "src/utils/Errors.sol";

// solhint-disable func-name-mixedcase
contract AuraRewardsAdapterTest is Test {
    IConvexBooster private convexBooster = IConvexBooster(AURA_BOOSTER);

    function setUp() public {
        string memory endpoint = vm.envString("MAINNET_RPC_URL");
        uint256 forkId = vm.createFork(endpoint, 16_731_638);
        vm.selectFork(forkId);
    }

    function transferCurveLpTokenAndDepositToConvex(address curveLp, address convexPool, address from) private {
        uint256 balance = IERC20(curveLp).balanceOf(from);
        vm.prank(from);
        IERC20(curveLp).transfer(address(this), balance);

        uint256 pid = IBaseRewardPool(convexPool).pid();

        IERC20(curveLp).approve(address(convexBooster), balance);
        convexBooster.deposit(pid, balance, true);

        // Move 7 days later
        vm.roll(block.number + 7200 * 7);
        // solhint-disable-next-line not-rely-on-time
        vm.warp(block.timestamp + 7 days);
    }

    function test_claimRewards_Revert_If() public {
        address gauge = 0xbD5445402B0a287cbC77cb67B2a52e2FC635dce4;

        bytes4 selector = bytes4(keccak256(bytes("getReward(address,bool)")));
        vm.mockCall(gauge, abi.encodeWithSelector(selector, address(this), true), abi.encode(false));
        vm.expectRevert(RewardAdapter.ClaimRewardsFailed.selector);
        AuraRewards.claimRewards(gauge, AURA_MAINNET);
    }

    function test_Revert_IfAddressZero() public {
        vm.expectRevert(abi.encodeWithSelector(Errors.ZeroAddress.selector, "gauge"));
        AuraRewards.claimRewards(address(0), AURA_MAINNET);
    }

    //Pool rETH-WETH
    function test_claimRewards_PoolrETHWETH() public {
        address gauge = 0x001B78CEC62DcFdc660E06A91Eb1bC966541d758;
        address curveLp = 0x1E19CF2D73a72Ef1332C882F20534B6519Be0276;
        address curveLpWhale = 0x5f98718e4e0EFcb7B5551E2B2584E6781ceAd867;

        transferCurveLpTokenAndDepositToConvex(curveLp, gauge, curveLpWhale);

        (uint256[] memory claimed, address[] memory tokens) = AuraRewards.claimRewards(gauge, AURA_MAINNET);

        assertEq(claimed.length, tokens.length);
        assertEq(tokens.length, 2);
        assertEq(address(tokens[0]), BAL_MAINNET);
        assertTrue(claimed[0] > 0);
        assertEq(address(tokens[1]), AURA_MAINNET);
        assertTrue(claimed[1] > 0);
    }

    // Pool wstETH-cbETH
    function test_claimRewards_PoolwstETHcbETH() public {
        address gauge = 0xe35ae62Ff773D518172d4B0b1af293704790B670;

        address curveLp = 0x9c6d47Ff73e0F5E51BE5FD53236e3F595C5793F2;
        address curveLpWhale = 0x854B004700885A61107B458f11eCC169A019b764;

        transferCurveLpTokenAndDepositToConvex(curveLp, gauge, curveLpWhale);

        (uint256[] memory claimed, address[] memory tokens) = AuraRewards.claimRewards(gauge, AURA_MAINNET);

        assertEq(claimed.length, tokens.length);
        assertEq(tokens.length, 2);
        assertEq(address(tokens[0]), BAL_MAINNET);
        assertTrue(claimed[0] > 0);
        assertEq(address(tokens[1]), AURA_MAINNET);
        assertTrue(claimed[1] > 0);
    }

    // Pool wstETH-srfxETH-rETH
    function test_claimRewards_PoolwstETHsrfxETHrETH() public {
        address gauge = 0xd26948E7a0223700e3C3cdEA21cA2471abCb8d47;

        address curveLp = 0x5aEe1e99fE86960377DE9f88689616916D5DcaBe;
        address curveLpWhale = 0x854B004700885A61107B458f11eCC169A019b764;

        transferCurveLpTokenAndDepositToConvex(curveLp, gauge, curveLpWhale);

        (uint256[] memory claimed, address[] memory tokens) = AuraRewards.claimRewards(gauge, AURA_MAINNET);

        assertEq(claimed.length, tokens.length);
        assertEq(tokens.length, 2);
        assertEq(address(tokens[0]), BAL_MAINNET);
        assertTrue(claimed[0] > 0);
        assertEq(address(tokens[1]), AURA_MAINNET);
        assertTrue(claimed[1] > 0);
    }
}
