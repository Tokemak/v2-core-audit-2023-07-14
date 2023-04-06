// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import { Test } from "forge-std/Test.sol";

import { IERC20 } from "openzeppelin-contracts/token/ERC20/IERC20.sol";

import { IVoter } from "../../src/interfaces/external/velodrome/IVoter.sol";
import { IGauge } from "../../src/interfaces/external/velodrome/IGauge.sol";
import { IRouter } from "../../src/interfaces/external/velodrome/IRouter.sol";
import { VelodromeAdapter } from "../../src/rewards/VelodromeAdapter.sol";
import { IClaimableRewards } from "../../src/interfaces/rewards/IClaimableRewards.sol";
import { IChildChainGaugeRewardHelper } from "../../src/interfaces/external/beethoven/IChildChainGaugeRewardHelper.sol";
import {
    USDC_OPTIMISM,
    SUSDC_OPTIMISM,
    VELO_OPTIMISM,
    OP_OPTIMISM,
    OPTI_DOGE_OPTIMISM,
    WSTETH_OPTIMISM,
    USDT_OPTIMISM,
    SONNE_OPTIMISM,
    WETH9_OPTIMISM,
    RETH_OPTIMISM,
    SETH_OPTIMISM,
    FRXETH_OPTIMISM
} from "../utils/Addresses.sol";

struct VelodromeExtraParams {
    address pool;
    uint256[] tokensIds;
    address tokenA;
    address tokenB;
    bool stable;
    uint256 amountAMin;
    uint256 amountBMin;
    uint256 deadline;
}

contract VelodromeAdapterWrapper is VelodromeAdapter, Test {
    address private sender;

    constructor(
        address _router,
        address _voter,
        address _wrappedBribeFactory,
        address _votingEscrow,
        address _account
    ) VelodromeAdapter(_router, _voter, _wrappedBribeFactory, _votingEscrow, _account) { }

    function setSender(address _sender) public {
        sender = _sender;
    }

    function claimRewardsWrapper(address pool) public returns (uint256[] memory, IERC20[] memory) {
        vm.startPrank(sender);

        (uint256[] memory amountsEmissions, IERC20[] memory emissionsTokens) = super.claimRewards(pool);

        vm.stopPrank();

        return (amountsEmissions, emissionsTokens);
    }
}

// solhint-disable func-name-mixedcase
contract VelodromeAdapterTest is Test {
    IChildChainGaugeRewardHelper private gaugeRewardHelper =
        IChildChainGaugeRewardHelper(0x299dcDF14350999496204c141A0c20A29d71AF3E);

    VelodromeAdapterWrapper private adapter;
    IRouter private router;
    IVoter private voter;

    function setUp() public {
        string memory endpoint = vm.envString("OPTIMISM_MAINNET_RPC_URL");
        uint256 forkId = vm.createFork(endpoint, 86_937_163);
        vm.selectFork(forkId);

        router = IRouter(0x9c12939390052919aF3155f41Bf4160Fd3666A6f);
        voter = IVoter(0x09236cfF45047DBee6B921e00704bed6D6B8Cf7e);

        adapter = new VelodromeAdapterWrapper(
            address(router),
            address(voter), 
            0xFC1AA395EBd27664B11fC093C07E10FF00f0122C, 
            0x9c7305eb78a432ced5C4D14Cac27E8Ed569A2e26, 
            0x5d5Bea9f0Fc13d967511668a60a3369fD53F784F
        );
    }

    function test_Revert_IfAddressZero() public {
        vm.expectRevert(IClaimableRewards.TokenAddressZero.selector);
        new VelodromeAdapter(
            address(0),
            0x09236cfF45047DBee6B921e00704bed6D6B8Cf7e, 
            0xFC1AA395EBd27664B11fC093C07E10FF00f0122C, 
            0x9c7305eb78a432ced5C4D14Cac27E8Ed569A2e26, 
            0x5d5Bea9f0Fc13d967511668a60a3369fD53F784F
        );

        vm.expectRevert(IClaimableRewards.TokenAddressZero.selector);
        new VelodromeAdapter(
            address(router),
            address(0), 
            0xFC1AA395EBd27664B11fC093C07E10FF00f0122C, 
            0x9c7305eb78a432ced5C4D14Cac27E8Ed569A2e26, 
            0x5d5Bea9f0Fc13d967511668a60a3369fD53F784F
        );

        vm.expectRevert(IClaimableRewards.TokenAddressZero.selector);
        new VelodromeAdapter(
            address(router),
            0x09236cfF45047DBee6B921e00704bed6D6B8Cf7e,
            address(0),
            0x9c7305eb78a432ced5C4D14Cac27E8Ed569A2e26, 
            0x5d5Bea9f0Fc13d967511668a60a3369fD53F784F
        );

        vm.expectRevert(IClaimableRewards.TokenAddressZero.selector);
        new VelodromeAdapter(
            address(router),
            0x09236cfF45047DBee6B921e00704bed6D6B8Cf7e,
            0xFC1AA395EBd27664B11fC093C07E10FF00f0122C, 
            address(0), 
            0x5d5Bea9f0Fc13d967511668a60a3369fD53F784F
        );

        vm.expectRevert(IClaimableRewards.TokenAddressZero.selector);
        new VelodromeAdapter(
            address(router),
            0x09236cfF45047DBee6B921e00704bed6D6B8Cf7e,
            0xFC1AA395EBd27664B11fC093C07E10FF00f0122C, 
            0x9c7305eb78a432ced5C4D14Cac27E8Ed569A2e26,
            address(0)
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
        address pool = 0xFd7FddFc0A729eCF45fB6B12fA3B71A575E1966F;
        bytes memory extraParams = abi.encode(
            VelodromeExtraParams(
                pool, tokenIds, WETH9_OPTIMISM, SETH_OPTIMISM, isStablePool, 1, 1, block.timestamp + 10_000
            )
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

        // Stake LPs

        IGauge gauge = IGauge(voter.gauges(pool));
        uint256 preStakeLpBalance = gauge.balanceOf(address(adapter));

        uint256[] memory stakeAmounts = new uint256[](1);
        stakeAmounts[0] = aftrerLpBalance;
        adapter.stakeLPs(stakeAmounts, 1, extraParams);

        uint256 afterStakeLpBalance = gauge.balanceOf(address(adapter));

        assertTrue(afterStakeLpBalance > 0 && afterStakeLpBalance > preStakeLpBalance);

        // Unstake LPs

        adapter.unstakeLPs(stakeAmounts, afterStakeLpBalance, extraParams);

        uint256 afterUnstakeLpBalance = gauge.balanceOf(address(adapter));

        assertTrue(afterUnstakeLpBalance == preStakeLpBalance);
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
        address pool = 0xFd7FddFc0A729eCF45fB6B12fA3B71A575E1966F;
        bytes memory extraParams = abi.encode(
            VelodromeExtraParams(
                pool, tokenIds, WETH9_OPTIMISM, SETH_OPTIMISM, isStablePool, 1, 1, block.timestamp + 10_000
            )
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
        address pool = 0xB343dae0E7fe28c16EC5dCa64cB0C1ac5F4690AC;
        bytes memory extraParams = abi.encode(
            VelodromeExtraParams(
                pool, tokenIds, WSTETH_OPTIMISM, SETH_OPTIMISM, isStablePool, 1, 1, block.timestamp + 10_000
            )
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

        // Stake LPs

        IGauge gauge = IGauge(voter.gauges(pool));
        uint256 preStakeLpBalance = gauge.balanceOf(address(adapter));

        uint256[] memory stakeAmounts = new uint256[](1);
        stakeAmounts[0] = aftrerLpBalance;
        adapter.stakeLPs(stakeAmounts, 1, extraParams);

        uint256 afterStakeLpBalance = gauge.balanceOf(address(adapter));

        assertTrue(afterStakeLpBalance > 0 && afterStakeLpBalance > preStakeLpBalance);

        // Unstake LPs

        adapter.unstakeLPs(stakeAmounts, afterStakeLpBalance, extraParams);

        uint256 afterUnstakeLpBalance = gauge.balanceOf(address(adapter));

        assertTrue(afterUnstakeLpBalance == preStakeLpBalance);
    }

    // wstETH/sETH
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
        address pool = 0xB343dae0E7fe28c16EC5dCa64cB0C1ac5F4690AC;
        bytes memory extraParams = abi.encode(
            VelodromeExtraParams(
                pool, tokenIds, WSTETH_OPTIMISM, SETH_OPTIMISM, isStablePool, 1, 1, block.timestamp + 10_000
            )
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
        address pool = 0xBf205335De602ac38244F112d712ab04CB59A498;
        bytes memory extraParams = abi.encode(
            VelodromeExtraParams(
                pool, tokenIds, WSTETH_OPTIMISM, WETH9_OPTIMISM, isStablePool, 1, 1, block.timestamp + 10_000
            )
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

        // Stake LPs

        IGauge gauge = IGauge(voter.gauges(pool));
        uint256 preStakeLpBalance = gauge.balanceOf(address(adapter));

        uint256[] memory stakeAmounts = new uint256[](1);
        stakeAmounts[0] = aftrerLpBalance;
        adapter.stakeLPs(stakeAmounts, 1, extraParams);

        uint256 afterStakeLpBalance = gauge.balanceOf(address(adapter));

        assertTrue(afterStakeLpBalance > 0 && afterStakeLpBalance > preStakeLpBalance);

        // Unstake LPs

        adapter.unstakeLPs(stakeAmounts, afterStakeLpBalance, extraParams);

        uint256 afterUnstakeLpBalance = gauge.balanceOf(address(adapter));

        assertTrue(afterUnstakeLpBalance == preStakeLpBalance);
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

        uint256[] memory tokenIds = new uint256[](1);
        tokenIds[0] = 0;
        address pool = 0xBf205335De602ac38244F112d712ab04CB59A498;
        bytes memory extraParams = abi.encode(
            VelodromeExtraParams(
                pool, tokenIds, WSTETH_OPTIMISM, WETH9_OPTIMISM, isStablePool, 1, 1, block.timestamp + 10_000
            )
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

        uint256[] memory tokenIds = new uint256[](1);
        tokenIds[0] = 0;
        address pool = 0x63642a192BAb08B09A70a997bb35B36b9286B01e;
        bytes memory extraParams = abi.encode(
            VelodromeExtraParams(
                pool, tokenIds, FRXETH_OPTIMISM, WETH9_OPTIMISM, isStablePool, 1, 1, block.timestamp + 10_000
            )
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

        // Stake LPs

        IGauge gauge = IGauge(voter.gauges(pool));
        uint256 preStakeLpBalance = gauge.balanceOf(address(adapter));

        uint256[] memory stakeAmounts = new uint256[](1);
        stakeAmounts[0] = aftrerLpBalance;
        adapter.stakeLPs(stakeAmounts, 1, extraParams);

        uint256 afterStakeLpBalance = gauge.balanceOf(address(adapter));

        assertTrue(afterStakeLpBalance > 0 && afterStakeLpBalance > preStakeLpBalance);

        // Unstake LPs

        adapter.unstakeLPs(stakeAmounts, afterStakeLpBalance, extraParams);

        uint256 afterUnstakeLpBalance = gauge.balanceOf(address(adapter));

        assertTrue(afterUnstakeLpBalance == preStakeLpBalance);
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

        uint256[] memory tokenIds = new uint256[](1);
        tokenIds[0] = 0;
        address pool = 0x63642a192BAb08B09A70a997bb35B36b9286B01e;
        bytes memory extraParams = abi.encode(
            VelodromeExtraParams(
                pool, tokenIds, FRXETH_OPTIMISM, WETH9_OPTIMISM, isStablePool, 1, 1, block.timestamp + 10_000
            )
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

        uint256[] memory tokenIds = new uint256[](1);
        tokenIds[0] = 0;
        address pool = 0x69F795e2d9249021798645d784229e5bec2a5a25;
        bytes memory extraParams = abi.encode(
            VelodromeExtraParams(
                pool, tokenIds, RETH_OPTIMISM, WETH9_OPTIMISM, isStablePool, 1, 1, block.timestamp + 10_000
            )
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

        // Stake LPs

        IGauge gauge = IGauge(voter.gauges(pool));
        uint256 preStakeLpBalance = gauge.balanceOf(address(adapter));

        uint256[] memory stakeAmounts = new uint256[](1);
        stakeAmounts[0] = aftrerLpBalance;
        adapter.stakeLPs(stakeAmounts, 1, extraParams);

        uint256 afterStakeLpBalance = gauge.balanceOf(address(adapter));

        assertTrue(afterStakeLpBalance > 0 && afterStakeLpBalance > preStakeLpBalance);

        // Unstake LPs

        adapter.unstakeLPs(stakeAmounts, afterStakeLpBalance, extraParams);

        uint256 afterUnstakeLpBalance = gauge.balanceOf(address(adapter));

        assertTrue(afterUnstakeLpBalance == preStakeLpBalance);
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

        uint256[] memory tokenIds = new uint256[](1);
        tokenIds[0] = 0;
        address pool = 0x69F795e2d9249021798645d784229e5bec2a5a25;
        bytes memory extraParams = abi.encode(
            VelodromeExtraParams(
                pool, tokenIds, RETH_OPTIMISM, WETH9_OPTIMISM, isStablePool, 1, 1, block.timestamp + 10_000
            )
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

    // USDC/sUSD
    function test_claimRewards_PoolUSDCSUSD() public {
        address whale = 0xC6602A0eE4e10d22C01144747B91365FCE19a59a;
        address pool = 0xd16232ad60188B68076a235c65d692090caba155;

        adapter.setSender(whale);

        vm.mockCall(
            address(adapter), abi.encodeWithSelector(VelodromeAdapter.getContractAddress.selector), abi.encode(whale)
        );

        (uint256[] memory amountsClaimed, IERC20[] memory rewardsToken) = adapter.claimRewardsWrapper(pool);

        assertEq(amountsClaimed.length, rewardsToken.length);
        assertEq(rewardsToken.length, 8);

        assertEq(address(rewardsToken[0]), USDC_OPTIMISM);
        assertEq(address(rewardsToken[1]), SUSDC_OPTIMISM);
        assertEq(address(rewardsToken[2]), VELO_OPTIMISM);
        assertEq(address(rewardsToken[3]), OP_OPTIMISM);
        assertEq(address(rewardsToken[4]), OPTI_DOGE_OPTIMISM);
        assertEq(address(rewardsToken[5]), WSTETH_OPTIMISM);
        assertEq(address(rewardsToken[6]), USDT_OPTIMISM);
        assertEq(address(rewardsToken[7]), SONNE_OPTIMISM);

        assertTrue(amountsClaimed[0] > 0);
        assertTrue(amountsClaimed[1] > 0);
        assertTrue(amountsClaimed[2] > 0);
        assertTrue(amountsClaimed[3] > 0);
        assertEq(amountsClaimed[4], 0);
        assertEq(amountsClaimed[5], 0);
        assertEq(amountsClaimed[6], 0);
        assertEq(amountsClaimed[7], 0);
    }

    // WETH/rETH
    function test_claimRewards_PoolWETHRETH() public {
        address whale = 0x43ccfb70ca135cd213FBAF2020B9cCa05F4482E5;
        address pool = 0x985612ff2C9409174FedcFf23d4F4761AF124F88;

        adapter.setSender(whale);

        vm.mockCall(
            address(adapter), abi.encodeWithSelector(VelodromeAdapter.getContractAddress.selector), abi.encode(whale)
        );

        (uint256[] memory amountsClaimed, IERC20[] memory rewardsToken) = adapter.claimRewardsWrapper(pool);

        assertEq(amountsClaimed.length, rewardsToken.length);
        assertEq(rewardsToken.length, 5);

        assertEq(address(rewardsToken[0]), WETH9_OPTIMISM);
        assertEq(address(rewardsToken[1]), RETH_OPTIMISM);
        assertEq(address(rewardsToken[2]), VELO_OPTIMISM);
        assertEq(address(rewardsToken[3]), OP_OPTIMISM);
        assertEq(address(rewardsToken[4]), OPTI_DOGE_OPTIMISM);

        assertEq(amountsClaimed[0], 0);
        assertEq(amountsClaimed[1], 0);
        assertTrue(amountsClaimed[2] > 0);
        assertEq(amountsClaimed[3], 0);
        assertEq(amountsClaimed[4], 0);
    }
}
