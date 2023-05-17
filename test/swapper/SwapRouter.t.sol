// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import { Test } from "forge-std/Test.sol";

import { IERC20 } from "openzeppelin-contracts/token/ERC20/IERC20.sol";

import { SwapRouter } from "src/swapper/SwapRouter.sol";
import { BalancerV2Swap } from "src/swapper/adapters/BalancerV2Swap.sol";
import { CurveV2Swap } from "src/swapper/adapters/CurveStableSwap.sol";
import { ISyncSwapper } from "src/interfaces/swapper/ISyncSwapper.sol";
import { ISwapRouter } from "src/interfaces/swapper/ISwapRouter.sol";
import {
    WSTETH_MAINNET, RETH_MAINNET, STETH_MAINNET, WETH_MAINNET, FRXETH_MAINNET, RANDOM
} from "../utils/Addresses.sol";

contract SwapRouterTest is Test {
    address private constant BALANCER_VAULT = 0xBA12222222228d8Ba445958a75a0704d566BF2C8;

    SwapRouter private swapRouter;
    BalancerV2Swap private balSwapper;
    CurveV2Swap private curveSwapper;

    error ApprovalFailed();

    function setUp() public {
        string memory endpoint = vm.envString("MAINNET_RPC_URL");
        uint256 forkId = vm.createFork(endpoint, 16_728_070);
        vm.selectFork(forkId);

        swapRouter = new SwapRouter();

        balSwapper = new BalancerV2Swap(BALANCER_VAULT);
        curveSwapper = new CurveV2Swap();

        // setup input for Balancer 1-hop WETH -> WSTETH
        ISwapRouter.SwapData[] memory balSwapRoute = new ISwapRouter.SwapData[](1);
        balSwapRoute[0] = ISwapRouter.SwapData({
            token: WSTETH_MAINNET,
            pool: 0x32296969Ef14EB0c6d29669C550D4a0449130230,
            swapper: balSwapper,
            data: abi.encode(0x32296969ef14eb0c6d29669c550d4a0449130230000200000000000000000080)
        });
        swapRouter.setSwapRoute(WETH_MAINNET, balSwapRoute);

        // setup input for Curve 1-hop WETH -> STETH
        ISwapRouter.SwapData[] memory curveOneHopRoute = new ISwapRouter.SwapData[](1);
        curveOneHopRoute[0] = ISwapRouter.SwapData({
            token: STETH_MAINNET,
            pool: 0x828b154032950C8ff7CF8085D841723Db2696056,
            swapper: curveSwapper,
            data: abi.encode(0, 1)
        });
        swapRouter.setSwapRoute(WETH_MAINNET, curveOneHopRoute);

        // setup input for Curve 2-hop WETH -> STETH -> FRXETH
        ISwapRouter.SwapData[] memory curveTwoHopRoute = new ISwapRouter.SwapData[](2);
        curveTwoHopRoute[0] = curveOneHopRoute[0];
        curveTwoHopRoute[1] = ISwapRouter.SwapData({
            token: FRXETH_MAINNET,
            pool: 0x4d9f9D15101EEC665F77210cB999639f760F831E,
            swapper: curveSwapper,
            data: abi.encode(0, 1)
        });
        swapRouter.setSwapRoute(WETH_MAINNET, curveTwoHopRoute);
    }

    function testSwapRouter() public {
        uint256 sellAmount = 1e18;
        // swap STETH with Curve pool
        address asset1 = WETH_MAINNET;
        address quoteT1 = STETH_MAINNET;
        uint256 val1;
        deal(WETH_MAINNET, address(this), 10 * 1e18);
        if (!IERC20(WETH_MAINNET).approve(address(swapRouter), 10 * 1e18)) {
            revert ApprovalFailed();
        }

        // sellAmount = 0 should return 0
        val1 = swapRouter.swapForQuote(asset1, 0, quoteT1, 0);
        assert(val1 == 0);

        // revert test - min buy amount > sell amount for 1:1 tokens
        vm.expectRevert(ISwapRouter.SwapFailedDuetoInsufficientBuy.selector);
        val1 = swapRouter.swapForQuote(asset1, sellAmount, quoteT1, 2 * sellAmount);

        // revert test - incorrect entry in mapping
        ISyncSwapper[] memory swappers;
        swappers = new ISyncSwapper[](1);
        address[] memory tPath;
        tPath = new address[](1);
        address[] memory pPath;
        pPath = new address[](2);

        // revert test - incorrect sell token
        vm.expectRevert(ISwapRouter.SwapRouteLookupFailed.selector);
        val1 = swapRouter.swapForQuote(RANDOM, sellAmount, quoteT1, 0);

        // revert test - incorrect quote token
        vm.expectRevert(ISwapRouter.SwapRouteLookupFailed.selector);
        val1 = swapRouter.swapForQuote(asset1, sellAmount, RANDOM, 0);
    }

    function testSwapCurveOneHop() public {
        uint256 sellAmount = 1e18;
        // swap STETH with Curve pool
        address asset1 = WETH_MAINNET;
        address quoteT1 = STETH_MAINNET;
        uint256 val1;
        deal(WETH_MAINNET, address(this), 10 * 1e18);
        if (!IERC20(WETH_MAINNET).approve(address(swapRouter), 4 * 1e18)) {
            revert ApprovalFailed();
        }
        // 1-hop swap: WETH -> STETH
        val1 = swapRouter.swapForQuote(asset1, sellAmount, quoteT1, 0);
        assertGe(val1, 0);
    }

    function testSwapCurveTwoHop() public {
        uint256 sellAmount = 1e18;
        // swap STETH with Curve pool
        address asset1 = WETH_MAINNET;
        address quoteT1 = STETH_MAINNET;
        uint256 val1;
        deal(WETH_MAINNET, address(this), 10 * 1e18);
        if (!IERC20(WETH_MAINNET).approve(address(swapRouter), 4 * 1e18)) {
            revert ApprovalFailed();
        }

        // 2-hop swap: WETH -> STETH -> FRXETH
        quoteT1 = FRXETH_MAINNET;
        val1 = swapRouter.swapForQuote(asset1, sellAmount, quoteT1, 0);
        assertGe(val1, 0);
    }

    function testSwapBalancer() public {
        uint256 sellAmount = 1e18;
        // swap WSTETH with Balancer pool
        address asset2 = WETH_MAINNET;
        address quoteT2 = WSTETH_MAINNET;

        uint256 val2;
        deal(WETH_MAINNET, address(this), 10 * 1e18);
        if (!IERC20(WETH_MAINNET).approve(address(swapRouter), 2 * 1e18)) {
            revert ApprovalFailed();
        }
        val2 = swapRouter.swapForQuote(asset2, sellAmount, quoteT2, 0);
        assertGe(val2, 0);
    }
}
