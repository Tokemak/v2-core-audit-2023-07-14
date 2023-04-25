// SPDX-License-Identifier: MIT
// solhint-disable not-rely-on-time
pragma solidity 0.8.17;

import { Test } from "forge-std/Test.sol";

import { IERC20 } from "openzeppelin-contracts/token/ERC20/IERC20.sol";

import { IGauge } from "../../../src/interfaces/external/velodrome/IGauge.sol";
import { IRouter } from "../../../src/interfaces/external/velodrome/IRouter.sol";
import { VelodromeAdapter } from "../../../src/destinations/adapters/VelodromeAdapter.sol";
import {
    WSTETH_OPTIMISM, WETH9_OPTIMISM, RETH_OPTIMISM, SETH_OPTIMISM, FRXETH_OPTIMISM
} from "../../utils/Addresses.sol";

struct VelodromeExtraParams {
    address tokenA;
    address tokenB;
    bool stable;
    uint256 amountAMin;
    uint256 amountBMin;
    uint256 deadline;
}

contract VelodromeAdapterTest is Test {
    VelodromeAdapter private adapter;
    IRouter private router;

    function setUp() public {
        string memory endpoint = vm.envString("OPTIMISM_MAINNET_RPC_URL");
        uint256 forkId = vm.createFork(endpoint, 86_937_163);
        vm.selectFork(forkId);

        router = IRouter(0x9c12939390052919aF3155f41Bf4160Fd3666A6f);

        adapter = new VelodromeAdapter(
            address(router)
        );
    }

    // WETH/sETH
    function testAddLiquidityWethSeth() public {
        bool isStablePool = true;

        IERC20 lpToken = IERC20(router.pairFor(WETH9_OPTIMISM, SETH_OPTIMISM, isStablePool));

        uint256[] memory amounts = new uint256[](2);
        amounts[0] = 1.5 * 1e18;
        amounts[1] = 1.5 * 1e18;

        deal(address(WETH9_OPTIMISM), address(adapter), 3 * 1e18);

        // Using whale for funding since storage slot overwrite is not working for proxy ERC-20s
        address sethWhale = 0x9912a94725271600590BeB0815Ca96fA0065eA27;
        vm.startPrank(sethWhale);
        IERC20(SETH_OPTIMISM).approve(address(adapter), 3 * 1e18);
        IERC20(SETH_OPTIMISM).transfer(address(adapter), 3 * 1e18);
        vm.stopPrank();

        uint256 preBalance1 = IERC20(WETH9_OPTIMISM).balanceOf(address(adapter));
        uint256 preBalance2 = IERC20(SETH_OPTIMISM).balanceOf(address(adapter));
        uint256 preLpBalance = lpToken.balanceOf(address(adapter));

        uint256 minLpMintAmount = 1;

        IERC20[] memory tokens = new IERC20[](2);
        tokens[0] = IERC20(WETH9_OPTIMISM);
        tokens[1] = IERC20(SETH_OPTIMISM);

        uint256[] memory tokenIds = new uint256[](1);
        tokenIds[0] = 0;
        bytes memory extraParams = abi.encode(
            VelodromeExtraParams(WETH9_OPTIMISM, SETH_OPTIMISM, isStablePool, 1, 1, block.timestamp + 10_000)
        );
        adapter.addLiquidity(amounts, minLpMintAmount, extraParams);

        uint256 afterBalance1 = IERC20(WETH9_OPTIMISM).balanceOf(address(adapter));
        uint256 afterBalance2 = IERC20(SETH_OPTIMISM).balanceOf(address(adapter));
        uint256 aftrerLpBalance = lpToken.balanceOf(address(adapter));

        uint256 balanceDiff1 = preBalance1 - afterBalance1;
        assertTrue(balanceDiff1 > 0 && balanceDiff1 <= amounts[0]);

        uint256 balanceDiff2 = preBalance2 - afterBalance2;
        assertTrue(balanceDiff2 > 0 && balanceDiff2 <= amounts[1]);
        assertTrue(aftrerLpBalance > preLpBalance);
    }

    // WETH/sETH
    function testRemoveLiquidityWethSeth() public {
        bool isStablePool = true;

        IERC20 lpToken = IERC20(router.pairFor(WETH9_OPTIMISM, SETH_OPTIMISM, isStablePool));

        uint256[] memory amounts = new uint256[](2);
        amounts[0] = 1.5 * 1e18;
        amounts[1] = 1.5 * 1e18;

        deal(address(WETH9_OPTIMISM), address(adapter), 3 * 1e18);
        // Using whale for funding since storage slot overwrite is not working for proxy ERC-20s
        address sethWhale = 0x9912a94725271600590BeB0815Ca96fA0065eA27;
        vm.prank(sethWhale);
        IERC20(SETH_OPTIMISM).approve(address(adapter), 3 * 1e18);
        vm.prank(sethWhale);
        IERC20(SETH_OPTIMISM).transfer(address(adapter), 3 * 1e18);

        uint256 minLpMintAmount = 1;

        IERC20[] memory tokens = new IERC20[](2);
        tokens[0] = IERC20(WETH9_OPTIMISM);
        tokens[1] = IERC20(SETH_OPTIMISM);

        uint256[] memory tokenIds = new uint256[](1);
        tokenIds[0] = 0;
        bytes memory extraParams = abi.encode(
            VelodromeExtraParams(WETH9_OPTIMISM, SETH_OPTIMISM, isStablePool, 1, 1, block.timestamp + 10_000)
        );
        adapter.addLiquidity(amounts, minLpMintAmount, extraParams);

        uint256 preBalance1 = IERC20(WETH9_OPTIMISM).balanceOf(address(adapter));
        uint256 preBalance2 = IERC20(SETH_OPTIMISM).balanceOf(address(adapter));
        uint256 preLpBalance = lpToken.balanceOf(address(adapter));

        uint256[] memory withdrawAmounts = new uint256[](2);
        withdrawAmounts[0] = 1 * 1e18;
        withdrawAmounts[1] = 1 * 1e18;
        adapter.removeLiquidity(withdrawAmounts, preLpBalance, extraParams);

        uint256 afterBalance1 = IERC20(WETH9_OPTIMISM).balanceOf(address(adapter));
        uint256 afterBalance2 = IERC20(SETH_OPTIMISM).balanceOf(address(adapter));
        uint256 aftrerLpBalance = lpToken.balanceOf(address(adapter));

        assert(afterBalance1 > preBalance1);
        assert(afterBalance2 > preBalance2);
        assert(aftrerLpBalance < preLpBalance);
    }

    // wstETH/sETH
    function testAddLiquidityWstEthSeth() public {
        bool isStablePool = true;

        IERC20 lpToken = IERC20(router.pairFor(WSTETH_OPTIMISM, SETH_OPTIMISM, isStablePool));

        uint256[] memory amounts = new uint256[](2);
        amounts[0] = 1.5 * 1e18;
        amounts[1] = 1.5 * 1e18;

        deal(address(WSTETH_OPTIMISM), address(adapter), 3 * 1e18);

        // Using whale for funding since storage slot overwrite is not working for proxy ERC-20s
        address sethWhale = 0x9912a94725271600590BeB0815Ca96fA0065eA27;
        vm.startPrank(sethWhale);
        IERC20(SETH_OPTIMISM).approve(address(adapter), 3 * 1e18);
        IERC20(SETH_OPTIMISM).transfer(address(adapter), 3 * 1e18);
        vm.stopPrank();

        uint256 preBalance1 = IERC20(WSTETH_OPTIMISM).balanceOf(address(adapter));
        uint256 preBalance2 = IERC20(SETH_OPTIMISM).balanceOf(address(adapter));
        uint256 preLpBalance = lpToken.balanceOf(address(adapter));

        uint256 minLpMintAmount = 1;

        IERC20[] memory tokens = new IERC20[](2);
        tokens[0] = IERC20(WSTETH_OPTIMISM);
        tokens[1] = IERC20(SETH_OPTIMISM);

        uint256[] memory tokenIds = new uint256[](1);
        tokenIds[0] = 0;
        bytes memory extraParams = abi.encode(
            VelodromeExtraParams(WSTETH_OPTIMISM, SETH_OPTIMISM, isStablePool, 1, 1, block.timestamp + 10_000)
        );
        adapter.addLiquidity(amounts, minLpMintAmount, extraParams);

        uint256 afterBalance1 = IERC20(WSTETH_OPTIMISM).balanceOf(address(adapter));
        uint256 afterBalance2 = IERC20(SETH_OPTIMISM).balanceOf(address(adapter));
        uint256 aftrerLpBalance = lpToken.balanceOf(address(adapter));

        uint256 balanceDiff1 = preBalance1 - afterBalance1;
        assertTrue(balanceDiff1 > 0 && balanceDiff1 <= amounts[0]);

        uint256 balanceDiff2 = preBalance2 - afterBalance2;
        assertTrue(balanceDiff2 > 0 && balanceDiff2 <= amounts[1]);

        assertTrue(aftrerLpBalance > preLpBalance);
    }

    // wstETH/sETH 0xB343dae0E7fe28c16EC5dCa64cB0C1ac5F4690AC
    function testRemoveLiquidityWstEthSeth() public {
        bool isStablePool = true;

        IERC20 lpToken = IERC20(router.pairFor(WSTETH_OPTIMISM, SETH_OPTIMISM, isStablePool));

        uint256[] memory amounts = new uint256[](2);
        amounts[0] = 1.5 * 1e18;
        amounts[1] = 1.5 * 1e18;

        deal(address(WSTETH_OPTIMISM), address(adapter), 3 * 1e18);
        // Using whale for funding since storage slot overwrite is not working for proxy ERC-20s
        address sethWhale = 0x9912a94725271600590BeB0815Ca96fA0065eA27;
        vm.prank(sethWhale);
        IERC20(SETH_OPTIMISM).approve(address(adapter), 3 * 1e18);
        vm.prank(sethWhale);
        IERC20(SETH_OPTIMISM).transfer(address(adapter), 3 * 1e18);

        uint256 minLpMintAmount = 1;

        IERC20[] memory tokens = new IERC20[](2);
        tokens[0] = IERC20(WSTETH_OPTIMISM);
        tokens[1] = IERC20(SETH_OPTIMISM);

        uint256[] memory tokenIds = new uint256[](1);
        tokenIds[0] = 0;

        bytes memory extraParams = abi.encode(
            VelodromeExtraParams(WSTETH_OPTIMISM, SETH_OPTIMISM, isStablePool, 1, 1, block.timestamp + 10_000)
        );
        adapter.addLiquidity(amounts, minLpMintAmount, extraParams);

        uint256 preBalance1 = IERC20(WSTETH_OPTIMISM).balanceOf(address(adapter));
        uint256 preBalance2 = IERC20(SETH_OPTIMISM).balanceOf(address(adapter));
        uint256 preLpBalance = lpToken.balanceOf(address(adapter));

        uint256[] memory withdrawAmounts = new uint256[](2);
        withdrawAmounts[0] = 0.5 * 1e18;
        withdrawAmounts[1] = 0.5 * 1e18;
        adapter.removeLiquidity(withdrawAmounts, preLpBalance, extraParams);

        uint256 afterBalance1 = IERC20(WSTETH_OPTIMISM).balanceOf(address(adapter));
        uint256 afterBalance2 = IERC20(SETH_OPTIMISM).balanceOf(address(adapter));
        uint256 aftrerLpBalance = lpToken.balanceOf(address(adapter));

        assert(afterBalance1 > preBalance1);
        assert(afterBalance2 > preBalance2);
        assert(aftrerLpBalance < preLpBalance);
    }

    // wstETH/WETH
    function testAddLiquidityWstEthWeth() public {
        bool isStablePool = true;

        IERC20 lpToken = IERC20(router.pairFor(WSTETH_OPTIMISM, WETH9_OPTIMISM, isStablePool));

        uint256[] memory amounts = new uint256[](2);
        amounts[0] = 7 * 1e18;
        amounts[1] = 7 * 1e18;

        deal(address(WSTETH_OPTIMISM), address(adapter), 10 * 1e18);
        deal(address(WETH9_OPTIMISM), address(adapter), 10 * 1e18);

        uint256 preBalance1 = IERC20(WSTETH_OPTIMISM).balanceOf(address(adapter));
        uint256 preBalance2 = IERC20(WETH9_OPTIMISM).balanceOf(address(adapter));
        uint256 preLpBalance = lpToken.balanceOf(address(adapter));

        uint256 minLpMintAmount = 1;

        IERC20[] memory tokens = new IERC20[](2);
        tokens[0] = IERC20(WSTETH_OPTIMISM);
        tokens[1] = IERC20(WETH9_OPTIMISM);

        uint256[] memory tokenIds = new uint256[](1);
        tokenIds[0] = 0;
        bytes memory extraParams = abi.encode(
            VelodromeExtraParams(WSTETH_OPTIMISM, WETH9_OPTIMISM, isStablePool, 1, 1, block.timestamp + 10_000)
        );
        adapter.addLiquidity(amounts, minLpMintAmount, extraParams);

        uint256 afterBalance1 = IERC20(WSTETH_OPTIMISM).balanceOf(address(adapter));
        uint256 afterBalance2 = IERC20(WETH9_OPTIMISM).balanceOf(address(adapter));
        uint256 aftrerLpBalance = lpToken.balanceOf(address(adapter));

        uint256 balanceDiff1 = preBalance1 - afterBalance1;
        assertTrue(balanceDiff1 > 0 && balanceDiff1 <= amounts[0]);

        uint256 balanceDiff2 = preBalance2 - afterBalance2;
        assertTrue(balanceDiff2 > 0 && balanceDiff2 <= amounts[1]);

        assertTrue(aftrerLpBalance > preLpBalance);
    }

    // wstETH/WETH
    function testRemoveLiquidityWstEthWeth() public {
        bool isStablePool = true;

        IERC20 lpToken = IERC20(router.pairFor(WSTETH_OPTIMISM, WETH9_OPTIMISM, isStablePool));

        uint256[] memory amounts = new uint256[](2);
        amounts[0] = 7 * 1e18;
        amounts[1] = 7 * 1e18;

        deal(address(WSTETH_OPTIMISM), address(adapter), 10 * 1e18);
        deal(address(WETH9_OPTIMISM), address(adapter), 10 * 1e18);

        uint256 minLpMintAmount = 1;

        IERC20[] memory tokens = new IERC20[](2);
        tokens[0] = IERC20(WSTETH_OPTIMISM);
        tokens[1] = IERC20(WETH9_OPTIMISM);

        bytes memory extraParams = abi.encode(
            VelodromeExtraParams(WSTETH_OPTIMISM, WETH9_OPTIMISM, isStablePool, 1, 1, block.timestamp + 10_000)
        );
        adapter.addLiquidity(amounts, minLpMintAmount, extraParams);

        uint256 preBalance1 = IERC20(WSTETH_OPTIMISM).balanceOf(address(adapter));
        uint256 preBalance2 = IERC20(WETH9_OPTIMISM).balanceOf(address(adapter));
        uint256 preLpBalance = lpToken.balanceOf(address(adapter));

        uint256[] memory withdrawAmounts = new uint256[](2);
        withdrawAmounts[0] = 3 * 1e18;
        withdrawAmounts[1] = 3 * 1e18;
        adapter.removeLiquidity(withdrawAmounts, preLpBalance, extraParams);

        uint256 afterBalance1 = IERC20(WSTETH_OPTIMISM).balanceOf(address(adapter));
        uint256 afterBalance2 = IERC20(WETH9_OPTIMISM).balanceOf(address(adapter));
        uint256 aftrerLpBalance = lpToken.balanceOf(address(adapter));

        assert(afterBalance1 > preBalance1);
        assert(afterBalance2 > preBalance2);
        assert(aftrerLpBalance < preLpBalance);
    }

    // frxETH/WETH
    function testAddLiquidityFrxEthWeth() public {
        bool isStablePool = true;

        IERC20 lpToken = IERC20(router.pairFor(FRXETH_OPTIMISM, WETH9_OPTIMISM, isStablePool));

        uint256[] memory amounts = new uint256[](2);
        amounts[0] = 7 * 1e18;
        amounts[1] = 7 * 1e18;

        deal(address(FRXETH_OPTIMISM), address(adapter), 10 * 1e18);
        deal(address(WETH9_OPTIMISM), address(adapter), 10 * 1e18);

        uint256 preBalance1 = IERC20(FRXETH_OPTIMISM).balanceOf(address(adapter));
        uint256 preBalance2 = IERC20(WETH9_OPTIMISM).balanceOf(address(adapter));
        uint256 preLpBalance = lpToken.balanceOf(address(adapter));

        uint256 minLpMintAmount = 1;

        IERC20[] memory tokens = new IERC20[](2);
        tokens[0] = IERC20(FRXETH_OPTIMISM);
        tokens[1] = IERC20(WETH9_OPTIMISM);

        bytes memory extraParams = abi.encode(
            VelodromeExtraParams(FRXETH_OPTIMISM, WETH9_OPTIMISM, isStablePool, 1, 1, block.timestamp + 10_000)
        );
        adapter.addLiquidity(amounts, minLpMintAmount, extraParams);

        uint256 afterBalance1 = IERC20(FRXETH_OPTIMISM).balanceOf(address(adapter));
        uint256 afterBalance2 = IERC20(WETH9_OPTIMISM).balanceOf(address(adapter));
        uint256 aftrerLpBalance = lpToken.balanceOf(address(adapter));

        uint256 balanceDiff1 = preBalance1 - afterBalance1;
        assertTrue(balanceDiff1 > 0 && balanceDiff1 <= amounts[0]);

        uint256 balanceDiff2 = preBalance2 - afterBalance2;
        assertTrue(balanceDiff2 > 0 && balanceDiff2 <= amounts[1]);

        assertTrue(aftrerLpBalance > preLpBalance);
    }

    // frxETH/WETH
    function testRemoveLiquidityFrxEthWeth() public {
        bool isStablePool = true;

        IERC20 lpToken = IERC20(router.pairFor(FRXETH_OPTIMISM, WETH9_OPTIMISM, isStablePool));

        uint256[] memory amounts = new uint256[](2);
        amounts[0] = 7 * 1e18;
        amounts[1] = 7 * 1e18;

        deal(address(FRXETH_OPTIMISM), address(adapter), 10 * 1e18);
        deal(address(WETH9_OPTIMISM), address(adapter), 10 * 1e18);

        uint256 minLpMintAmount = 1;

        IERC20[] memory tokens = new IERC20[](2);
        tokens[0] = IERC20(FRXETH_OPTIMISM);
        tokens[1] = IERC20(WETH9_OPTIMISM);

        bytes memory extraParams = abi.encode(
            VelodromeExtraParams(FRXETH_OPTIMISM, WETH9_OPTIMISM, isStablePool, 1, 1, block.timestamp + 10_000)
        );
        adapter.addLiquidity(amounts, minLpMintAmount, extraParams);

        uint256 preBalance1 = IERC20(FRXETH_OPTIMISM).balanceOf(address(adapter));
        uint256 preBalance2 = IERC20(WETH9_OPTIMISM).balanceOf(address(adapter));
        uint256 preLpBalance = lpToken.balanceOf(address(adapter));

        uint256[] memory withdrawAmounts = new uint256[](2);
        withdrawAmounts[0] = 3 * 1e18;
        withdrawAmounts[1] = 3 * 1e18;
        adapter.removeLiquidity(withdrawAmounts, preLpBalance, extraParams);

        uint256 afterBalance1 = IERC20(FRXETH_OPTIMISM).balanceOf(address(adapter));
        uint256 afterBalance2 = IERC20(WETH9_OPTIMISM).balanceOf(address(adapter));
        uint256 aftrerLpBalance = lpToken.balanceOf(address(adapter));

        assert(afterBalance1 > preBalance1);
        assert(afterBalance2 > preBalance2);
        assert(aftrerLpBalance < preLpBalance);
    }

    // WETH/rETH
    function testAddLiquidityWethReth() public {
        bool isStablePool = true;

        IERC20 lpToken = IERC20(router.pairFor(RETH_OPTIMISM, WETH9_OPTIMISM, isStablePool));

        uint256[] memory amounts = new uint256[](2);
        amounts[0] = 7 * 1e18;
        amounts[1] = 7 * 1e18;

        deal(address(RETH_OPTIMISM), address(adapter), 10 * 1e18);
        deal(address(WETH9_OPTIMISM), address(adapter), 10 * 1e18);

        uint256 preBalance1 = IERC20(RETH_OPTIMISM).balanceOf(address(adapter));
        uint256 preBalance2 = IERC20(WETH9_OPTIMISM).balanceOf(address(adapter));
        uint256 preLpBalance = lpToken.balanceOf(address(adapter));

        uint256 minLpMintAmount = 1;

        IERC20[] memory tokens = new IERC20[](2);
        tokens[0] = IERC20(RETH_OPTIMISM);
        tokens[1] = IERC20(WETH9_OPTIMISM);

        bytes memory extraParams = abi.encode(
            VelodromeExtraParams(RETH_OPTIMISM, WETH9_OPTIMISM, isStablePool, 1, 1, block.timestamp + 10_000)
        );
        adapter.addLiquidity(amounts, minLpMintAmount, extraParams);

        uint256 afterBalance1 = IERC20(RETH_OPTIMISM).balanceOf(address(adapter));
        uint256 afterBalance2 = IERC20(WETH9_OPTIMISM).balanceOf(address(adapter));
        uint256 aftrerLpBalance = lpToken.balanceOf(address(adapter));

        uint256 balanceDiff1 = preBalance1 - afterBalance1;
        assertTrue(balanceDiff1 > 0 && balanceDiff1 <= amounts[0]);

        uint256 balanceDiff2 = preBalance2 - afterBalance2;
        assertTrue(balanceDiff2 > 0 && balanceDiff2 <= amounts[1]);

        assertTrue(aftrerLpBalance > preLpBalance);
    }

    // WETH/rETH
    function testRemoveLiquidityWethReth() public {
        bool isStablePool = true;

        IERC20 lpToken = IERC20(router.pairFor(RETH_OPTIMISM, WETH9_OPTIMISM, isStablePool));

        uint256[] memory amounts = new uint256[](2);
        amounts[0] = 7 * 1e18;
        amounts[1] = 7 * 1e18;

        deal(address(RETH_OPTIMISM), address(adapter), 10 * 1e18);
        deal(address(WETH9_OPTIMISM), address(adapter), 10 * 1e18);

        uint256 minLpMintAmount = 1;

        IERC20[] memory tokens = new IERC20[](2);
        tokens[0] = IERC20(RETH_OPTIMISM);
        tokens[1] = IERC20(WETH9_OPTIMISM);

        bytes memory extraParams = abi.encode(
            VelodromeExtraParams(RETH_OPTIMISM, WETH9_OPTIMISM, isStablePool, 1, 1, block.timestamp + 10_000)
        );
        adapter.addLiquidity(amounts, minLpMintAmount, extraParams);

        uint256 preBalance1 = IERC20(RETH_OPTIMISM).balanceOf(address(adapter));
        uint256 preBalance2 = IERC20(WETH9_OPTIMISM).balanceOf(address(adapter));
        uint256 preLpBalance = lpToken.balanceOf(address(adapter));

        uint256[] memory withdrawAmounts = new uint256[](2);
        withdrawAmounts[0] = 3 * 1e18;
        withdrawAmounts[1] = 3 * 1e18;
        adapter.removeLiquidity(withdrawAmounts, preLpBalance, extraParams);

        uint256 afterBalance1 = IERC20(RETH_OPTIMISM).balanceOf(address(adapter));
        uint256 afterBalance2 = IERC20(WETH9_OPTIMISM).balanceOf(address(adapter));
        uint256 aftrerLpBalance = lpToken.balanceOf(address(adapter));

        assert(afterBalance1 > preBalance1);
        assert(afterBalance2 > preBalance2);
        assert(aftrerLpBalance < preLpBalance);
    }
}
