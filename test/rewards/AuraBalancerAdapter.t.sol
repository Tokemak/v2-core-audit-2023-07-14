// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import { Test } from "forge-std/Test.sol";

import { IERC20 } from "openzeppelin-contracts/token/ERC20/IERC20.sol";

import { IBaseRewardPool } from "../../src/interfaces/external/convex/IBaseRewardPool.sol";
import { IConvexBooster } from "../../src/interfaces/external/convex/IConvexBooster.sol";
import { ConvexAdapter } from "../../src/rewards/ConvexAdapter.sol";
import { IClaimableRewards } from "../../src/rewards/IClaimableRewards.sol";
import { AURA_BOOSTER, BAL_MAINNET, LDO_MAINNET } from "../utils/Addresses.sol";

// solhint-disable func-name-mixedcase
contract AuraBalancerAdapterTest is Test {
    ConvexAdapter private adapter;

    IConvexBooster private convexBooster = IConvexBooster(AURA_BOOSTER);

    function setUp() public {
        string memory endpoint = vm.envString("TEST_ALCHEMY_MAINNET_RPC_URL");
        uint256 forkId = vm.createFork(endpoint, 16_731_638);
        vm.selectFork(forkId);

        adapter = new ConvexAdapter();
    }

    function transferCurveLpTokenAndDepositToConvex(
        address curveLp,
        address convexPool,
        uint256 balance,
        address from,
        address to
    ) private {
        vm.prank(from);
        IERC20(curveLp).transfer(to, balance);

        uint256 pid = IBaseRewardPool(convexPool).pid();

        adapter.depositAndStakeConvex(convexBooster, curveLp, convexPool, pid, balance);

        // Move 7 days later
        vm.roll(block.number + 7200 * 7);
        // solhint-disable-next-line not-rely-on-time
        vm.warp(block.timestamp + 7 days);
    }

    function test_Revert_IfAddressZero() public {
        vm.expectRevert(IClaimableRewards.TokenAddressZero.selector);
        adapter.claimRewards(address(0));
    }

    // Pool rETH-WETH
    function test_rETHWETH_pool() public {
        address gauge = 0x001B78CEC62DcFdc660E06A91Eb1bC966541d758;
        address curveLp = 0x1E19CF2D73a72Ef1332C882F20534B6519Be0276;
        address curveLpWhale = 0x5f98718e4e0EFcb7B5551E2B2584E6781ceAd867;

        // Deposit
        uint256 balance = IERC20(curveLp).balanceOf(curveLpWhale);
        transferCurveLpTokenAndDepositToConvex(curveLp, gauge, balance, curveLpWhale, address(adapter));

        // Claim rewards
        vm.prank(address(adapter));
        (uint256[] memory amountsClaimed, IERC20[] memory rewardsToken) = adapter.claimRewards(gauge);

        assertEq(amountsClaimed.length, rewardsToken.length);
        assertEq(rewardsToken.length, 1);
        assertEq(address(rewardsToken[0]), BAL_MAINNET);
        assertEq(amountsClaimed[0] > 0, true);

        // Withdraw
        adapter.withdrawStakeConvex(curveLp, gauge, balance);
        assertEq(balance, IERC20(curveLp).balanceOf(address(adapter)));
    }

    // Pool wstETH-cbETH
    function test_wstETHcbETH_pool() public {
        address gauge = 0xe35ae62Ff773D518172d4B0b1af293704790B670;
        address curveLp = 0x9c6d47Ff73e0F5E51BE5FD53236e3F595C5793F2;
        address curveLpWhale = 0x854B004700885A61107B458f11eCC169A019b764;

        // Deposit
        uint256 balance = IERC20(curveLp).balanceOf(curveLpWhale);
        transferCurveLpTokenAndDepositToConvex(curveLp, gauge, balance, curveLpWhale, address(adapter));

        // Claim rewards
        vm.prank(address(adapter));
        (uint256[] memory amountsClaimed, IERC20[] memory rewardsToken) = adapter.claimRewards(gauge);

        assertEq(amountsClaimed.length, rewardsToken.length);
        assertEq(rewardsToken.length, 1);
        assertEq(address(rewardsToken[0]), BAL_MAINNET);
        assertEq(amountsClaimed[0] > 0, true);

        // Withdraw
        adapter.withdrawStakeConvex(curveLp, gauge, balance);
        assertEq(balance, IERC20(curveLp).balanceOf(address(adapter)));
    }

    // Pool wstETH-srfxETH-rETH
    function test_wstETHsrfxETHrETH_pool() public {
        address gauge = 0xd26948E7a0223700e3C3cdEA21cA2471abCb8d47;
        address curveLp = 0x5aEe1e99fE86960377DE9f88689616916D5DcaBe;
        address curveLpWhale = 0x854B004700885A61107B458f11eCC169A019b764;

        // Deposit
        uint256 balance = IERC20(curveLp).balanceOf(curveLpWhale);
        transferCurveLpTokenAndDepositToConvex(curveLp, gauge, balance, curveLpWhale, address(adapter));

        // Claim rewards
        vm.prank(address(adapter));
        (uint256[] memory amountsClaimed, IERC20[] memory rewardsToken) = adapter.claimRewards(gauge);

        assertEq(amountsClaimed.length, rewardsToken.length);
        assertEq(rewardsToken.length, 1);
        assertEq(address(rewardsToken[0]), BAL_MAINNET);
        assertEq(amountsClaimed[0] > 0, true);

        // Withdraw
        adapter.withdrawStakeConvex(curveLp, gauge, balance);
        assertEq(balance, IERC20(curveLp).balanceOf(address(adapter)));
    }

    // Pool wstETH-wETH
    function test_wstETHwETH_pool() public {
        address gauge = 0xe4683Fe8F53da14cA5DAc4251EaDFb3aa614d528;
        address curveLp = 0x32296969Ef14EB0c6d29669C550D4a0449130230;
        address curveLpWhale = 0x21ac89788d52070D23B8EaCEcBD3Dc544178DC60;

        // Deposit
        uint256 balance = IERC20(curveLp).balanceOf(curveLpWhale);
        transferCurveLpTokenAndDepositToConvex(curveLp, gauge, balance, curveLpWhale, address(adapter));

        // Claim rewards
        vm.prank(address(adapter));
        (uint256[] memory amountsClaimed, IERC20[] memory rewardsToken) = adapter.claimRewards(gauge);

        assertEq(amountsClaimed.length, rewardsToken.length);
        assertEq(rewardsToken.length, 2);
        assertEq(address(rewardsToken[0]), LDO_MAINNET);
        // assert(amountsClaimed[0] > 0);
        assertEq(address(rewardsToken[1]), BAL_MAINNET);
        assert(amountsClaimed[1] > 0);

        // Withdraw
        adapter.withdrawStakeConvex(curveLp, gauge, balance);
        assertEq(balance, IERC20(curveLp).balanceOf(address(adapter)));
    }
}
