// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import { Test } from "forge-std/Test.sol";

import { IERC20 } from "openzeppelin-contracts/token/ERC20/IERC20.sol";

import { IBaseRewardPool } from "../../../../src/interfaces/external/convex/IBaseRewardPool.sol";
import { IConvexBooster } from "../../../../src/interfaces/external/convex/IConvexBooster.sol";
import { AuraRewardsAdapter } from "../../../../src/destinations/adapters/rewards/AuraRewardsAdapter.sol";
import { IClaimableRewardsAdapter } from "../../../../src/interfaces/destinations/IClaimableRewardsAdapter.sol";
import { AURA_BOOSTER, BAL_MAINNET } from "../../../utils/Addresses.sol";

// solhint-disable func-name-mixedcase
contract AuraRewardsAdapterTest is Test {
    AuraRewardsAdapter private adapter;

    IConvexBooster private convexBooster = IConvexBooster(AURA_BOOSTER);

    function setUp() public {
        string memory endpoint = vm.envString("MAINNET_RPC_URL");
        uint256 forkId = vm.createFork(endpoint, 16_731_638);
        vm.selectFork(forkId);

        adapter = new AuraRewardsAdapter();
    }

    function transferCurveLpTokenAndDepositToConvex(
        address curveLp,
        address convexPool,
        address from,
        address to
    ) private {
        uint256 balance = IERC20(curveLp).balanceOf(from);
        vm.prank(from);
        IERC20(curveLp).transfer(to, balance);

        uint256 pid = IBaseRewardPool(convexPool).pid();

        vm.startPrank(to);
        IERC20(curveLp).approve(address(convexBooster), balance);
        convexBooster.deposit(pid, balance, true);
        vm.stopPrank();

        // Move 7 days later
        vm.roll(block.number + 7200 * 7);
        // solhint-disable-next-line not-rely-on-time
        vm.warp(block.timestamp + 7 days);
    }

    function test_Revert_IfAddressZero() public {
        vm.expectRevert(IClaimableRewardsAdapter.TokenAddressZero.selector);
        adapter.claimRewards(address(0));
    }

    //Pool rETH-WETH
    function test_claimRewards_PoolrETHWETH() public {
        address gauge = 0x001B78CEC62DcFdc660E06A91Eb1bC966541d758;

        address curveLp = 0x1E19CF2D73a72Ef1332C882F20534B6519Be0276;
        address curveLpWhale = 0x5f98718e4e0EFcb7B5551E2B2584E6781ceAd867;

        transferCurveLpTokenAndDepositToConvex(curveLp, gauge, curveLpWhale, address(adapter));

        vm.prank(address(adapter));
        (uint256[] memory amountsClaimed, IERC20[] memory rewardsToken) = adapter.claimRewards(gauge);

        assertEq(amountsClaimed.length, rewardsToken.length);
        assertEq(rewardsToken.length, 1);
        assertEq(address(rewardsToken[0]), BAL_MAINNET);
        assertTrue(amountsClaimed[0] > 0);
    }

    // Pool wstETH-cbETH
    function test_claimRewards_PoolwstETHcbETH() public {
        address gauge = 0xe35ae62Ff773D518172d4B0b1af293704790B670;

        address curveLp = 0x9c6d47Ff73e0F5E51BE5FD53236e3F595C5793F2;
        address curveLpWhale = 0x854B004700885A61107B458f11eCC169A019b764;

        transferCurveLpTokenAndDepositToConvex(curveLp, gauge, curveLpWhale, address(adapter));

        vm.prank(address(adapter));
        (uint256[] memory amountsClaimed, IERC20[] memory rewardsToken) = adapter.claimRewards(gauge);

        assertEq(amountsClaimed.length, rewardsToken.length);
        assertEq(rewardsToken.length, 1);
        assertEq(address(rewardsToken[0]), BAL_MAINNET);
        assertTrue(amountsClaimed[0] > 0);
    }

    // Pool wstETH-srfxETH-rETH
    function test_claimRewards_PoolwstETHsrfxETHrETH() public {
        address gauge = 0xd26948E7a0223700e3C3cdEA21cA2471abCb8d47;

        address curveLp = 0x5aEe1e99fE86960377DE9f88689616916D5DcaBe;
        address curveLpWhale = 0x854B004700885A61107B458f11eCC169A019b764;

        transferCurveLpTokenAndDepositToConvex(curveLp, gauge, curveLpWhale, address(adapter));

        vm.prank(address(adapter));
        (uint256[] memory amountsClaimed, IERC20[] memory rewardsToken) = adapter.claimRewards(gauge);

        assertEq(amountsClaimed.length, rewardsToken.length);
        assertEq(rewardsToken.length, 1);
        assertEq(address(rewardsToken[0]), BAL_MAINNET);
        assertTrue(amountsClaimed[0] > 0);
    }
}
