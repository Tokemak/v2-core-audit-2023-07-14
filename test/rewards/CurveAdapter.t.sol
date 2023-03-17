// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import { Test } from "forge-std/Test.sol";

import { IERC20 } from "openzeppelin-contracts/token/ERC20/IERC20.sol";

import { ICurveStableSwap } from "../../src/interfaces/external/curve/ICurveStableSwap.sol";
import { ILiquidityGaugeV2 } from "../../src/interfaces/external/curve/ILiquidityGaugeV2.sol";
import { CurveAdapter } from "../../src/rewards/CurveAdapter.sol";
import { IClaimableRewards } from "../../src/interfaces/rewards/IClaimableRewards.sol";
import { LDO_MAINNET, RETH_MAINNET, WSTETH_MAINNET, STETH_MAINNET } from "../utils/Addresses.sol";

// solhint-disable func-name-mixedcase
contract CurveAdapterTest is Test {
    CurveAdapter private adapter;

    function setUp() public {
        string memory endpoint = vm.envString("MAINNET_RPC_URL");
        uint256 forkId = vm.createFork(endpoint, 16_699_085);
        vm.selectFork(forkId);

        adapter = new CurveAdapter();
    }

    function addLiquidityETH(address curvePool, uint256 amountEth, address tokenAddress, uint256 tokenAmount) private {
        IERC20(tokenAddress).approve(curvePool, tokenAmount);
        ICurveStableSwap(curvePool).add_liquidity{value: amountEth}([amountEth, tokenAmount], 1);
    }

    function addLiquidity(
        address curvePool,
        address tokenAAddress,
        uint256 tokenAAmount,
        address tokenBAddress,
        uint256 tokenBAmount
    ) private {
        IERC20(tokenAAddress).approve(curvePool, tokenAAmount);
        IERC20(tokenBAddress).approve(curvePool, tokenBAmount);
        ICurveStableSwap(curvePool).add_liquidity([tokenAAmount, tokenBAmount], 1);
    }

    function deposit(address curveGauge, address curveLpToken) private {
        uint256 curveLpTokenBalance = IERC20(curveLpToken).balanceOf(address(adapter));
        IERC20(curveLpToken).approve(curveGauge, curveLpTokenBalance);
        ILiquidityGaugeV2(curveGauge).deposit(curveLpTokenBalance, address(adapter));
    }

    function increaseTime() private {
        // Move 7 days later
        vm.roll(block.number + 7200 * 7);
        // solhint-disable-next-line not-rely-on-time
        vm.warp(block.timestamp + 7 days);
    }

    function transferToken(address token, address from, address to) private returns (uint256) {
        uint256 balance = IERC20(token).balanceOf(from);
        vm.prank(from);
        IERC20(token).transfer(to, balance);

        return balance;
    }

    function test_Revert_IfAddressZero() public {
        vm.expectRevert(IClaimableRewards.TokenAddressZero.selector);
        adapter.claimRewards(address(0));
    }

    // Pool stETH + ETH
    function test_claimRewards_PoolETHstETH() public {
        address curvePool = 0xDC24316b9AE028F1497c275EB9192a3Ea0f67022;
        address curveGauge = 0x182B723a58739a9c974cFDB385ceaDb237453c28;
        address curveLp = 0x06325440D014e39736583c165C2963BA99fAf14E;

        address stEthWhale = 0x41318419CFa25396b47A94896FfA2C77c6434040;

        uint256 stETHBalance = transferToken(STETH_MAINNET, stEthWhale, address(adapter));

        vm.deal(address(adapter), stETHBalance);

        vm.startPrank(address(adapter));

        addLiquidityETH(curvePool, stETHBalance, STETH_MAINNET, stETHBalance);
        deposit(curveGauge, curveLp);
        increaseTime();
        (uint256[] memory amountsClaimed, IERC20[] memory rewardsToken) = adapter.claimRewards(curveGauge);

        vm.stopPrank();

        assertEq(amountsClaimed.length, rewardsToken.length);
        assertTrue(amountsClaimed.length > 0);

        assertEq(rewardsToken.length, 1);
        assertEq(address(rewardsToken[0]), LDO_MAINNET);
        assertTrue(amountsClaimed[0] > 0);
    }

    // Pool rETH + wstETH
    function test_claimRewards_PoolrETHwstETH() public {
        address curvePool = 0x447Ddd4960d9fdBF6af9a790560d0AF76795CB08;
        address curveGauge = 0x8aD7e0e6EDc61bC48ca0DD07f9021c249044eD30;
        address curveLp = 0x447Ddd4960d9fdBF6af9a790560d0AF76795CB08;

        address rEthWhale = 0xEADB3840596cabF312F2bC88A4Bb0b93A4E1FF5F;
        address wstEthWhale = 0x5fEC2f34D80ED82370F733043B6A536d7e9D7f8d;

        uint256 rEthBalance = transferToken(RETH_MAINNET, rEthWhale, address(adapter));
        uint256 wstETHBalance = transferToken(WSTETH_MAINNET, wstEthWhale, address(adapter));

        vm.startPrank(address(adapter));

        addLiquidity(curvePool, RETH_MAINNET, rEthBalance, WSTETH_MAINNET, wstETHBalance);
        deposit(curveGauge, curveLp);
        increaseTime();
        (uint256[] memory amountsClaimed, IERC20[] memory rewardsToken) = adapter.claimRewards(curveGauge);

        vm.stopPrank();

        assertEq(amountsClaimed.length, rewardsToken.length);
        assertEq(rewardsToken.length, 0);
    }
}
