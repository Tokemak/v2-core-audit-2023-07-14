// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "forge-std/Test.sol";

import "openzeppelin-contracts/token/ERC20/IERC20.sol";

import "../../../../src/interfaces/external/velodrome/IGauge.sol";
import "../../../../src/interfaces/external/velodrome/IVoter.sol";
import "../../../../src/interfaces/external/velodrome/IRouter.sol";
import "../../../../src/destinations/adapters/staking/VelodromeStakingAdapter.sol";
import {
    WSTETH_OPTIMISM,
    WETH9_OPTIMISM,
    RETH_OPTIMISM,
    SETH_OPTIMISM,
    FRXETH_OPTIMISM
} from "../../../utils/Addresses.sol";

contract VelodromeStakingAdapterTest is Test {
    VelodromeStakingAdapter private adapter;

    IVoter private voter;
    IRouter private router;

    function setUp() public {
        string memory endpoint = vm.envString("OPTIMISM_MAINNET_RPC_URL");
        uint256 forkId = vm.createFork(endpoint, 86_937_163);
        vm.selectFork(forkId);

        router = IRouter(0x9c12939390052919aF3155f41Bf4160Fd3666A6f);
        voter = IVoter(0x09236cfF45047DBee6B921e00704bed6D6B8Cf7e);

        adapter = new VelodromeStakingAdapter(
            address(voter)
        );
    }

    // WETH/sETH
    function testAddLiquidityWethSeth() public {
        bool isStablePool = true;

        IERC20 lpToken = IERC20(router.pairFor(WETH9_OPTIMISM, SETH_OPTIMISM, isStablePool));

        deal(address(lpToken), address(adapter), 10 * 1e18);

        uint256[] memory tokenIds = new uint256[](1);
        tokenIds[0] = 0;
        address pool = 0xFd7FddFc0A729eCF45fB6B12fA3B71A575E1966F;

        // Stake LPs
        uint256 minLpMintAmount = 1;

        IGauge gauge = IGauge(voter.gauges(pool));
        uint256 preStakeLpBalance = gauge.balanceOf(address(adapter));

        uint256[] memory stakeAmounts = new uint256[](1);
        stakeAmounts[0] = lpToken.balanceOf(address(adapter));
        adapter.stakeLPs(stakeAmounts, tokenIds, minLpMintAmount, pool);

        uint256 afterStakeLpBalance = gauge.balanceOf(address(adapter));

        assertTrue(afterStakeLpBalance > 0 && afterStakeLpBalance > preStakeLpBalance);

        // Unstake LPs
        adapter.unstakeLPs(stakeAmounts, tokenIds, afterStakeLpBalance, pool);

        uint256 afterUnstakeLpBalance = gauge.balanceOf(address(adapter));

        assertTrue(afterUnstakeLpBalance == preStakeLpBalance);
    }

    // wstETH/sETH
    function testWstEthSethStaking() public {
        bool isStablePool = true;

        IERC20 lpToken = IERC20(router.pairFor(WSTETH_OPTIMISM, SETH_OPTIMISM, isStablePool));

        deal(address(lpToken), address(adapter), 10 * 1e18);

        uint256[] memory tokenIds = new uint256[](1);
        tokenIds[0] = 0;
        address pool = 0xB343dae0E7fe28c16EC5dCa64cB0C1ac5F4690AC;

        // Stake LPs
        uint256 minLpMintAmount = 1;

        IGauge gauge = IGauge(voter.gauges(pool));
        uint256 preStakeLpBalance = gauge.balanceOf(address(adapter));

        uint256[] memory stakeAmounts = new uint256[](1);
        stakeAmounts[0] = lpToken.balanceOf(address(adapter));
        adapter.stakeLPs(stakeAmounts, tokenIds, minLpMintAmount, pool);

        uint256 afterStakeLpBalance = gauge.balanceOf(address(adapter));

        assertTrue(afterStakeLpBalance > 0 && afterStakeLpBalance > preStakeLpBalance);

        // Unstake LPs
        adapter.unstakeLPs(stakeAmounts, tokenIds, afterStakeLpBalance, pool);

        uint256 afterUnstakeLpBalance = gauge.balanceOf(address(adapter));

        assertTrue(afterUnstakeLpBalance == preStakeLpBalance);
    }

    // wstETH/WETH
    function testWstEthWethStaking() public {
        bool isStablePool = true;

        IERC20 lpToken = IERC20(router.pairFor(WSTETH_OPTIMISM, WETH9_OPTIMISM, isStablePool));

        deal(address(lpToken), address(adapter), 10 * 1e18);

        uint256[] memory tokenIds = new uint256[](1);
        tokenIds[0] = 0;
        address pool = 0xBf205335De602ac38244F112d712ab04CB59A498;

        // Stake LPs
        uint256 minLpMintAmount = 1;

        IGauge gauge = IGauge(voter.gauges(pool));
        uint256 preStakeLpBalance = gauge.balanceOf(address(adapter));

        uint256[] memory stakeAmounts = new uint256[](1);
        stakeAmounts[0] = lpToken.balanceOf(address(adapter));
        adapter.stakeLPs(stakeAmounts, tokenIds, minLpMintAmount, pool);

        uint256 afterStakeLpBalance = gauge.balanceOf(address(adapter));

        assertTrue(afterStakeLpBalance > 0 && afterStakeLpBalance > preStakeLpBalance);

        // Unstake LPs
        adapter.unstakeLPs(stakeAmounts, tokenIds, afterStakeLpBalance, pool);

        uint256 afterUnstakeLpBalance = gauge.balanceOf(address(adapter));

        assertTrue(afterUnstakeLpBalance == preStakeLpBalance);
    }

    // frxETH/WETH
    function testFrxEthWethStaking() public {
        bool isStablePool = true;

        IERC20 lpToken = IERC20(router.pairFor(FRXETH_OPTIMISM, WETH9_OPTIMISM, isStablePool));

        deal(address(lpToken), address(adapter), 10 * 1e18);

        uint256[] memory tokenIds = new uint256[](1);
        tokenIds[0] = 0;
        address pool = 0x63642a192BAb08B09A70a997bb35B36b9286B01e;

        // Stake LPs
        uint256 minLpMintAmount = 1;

        IGauge gauge = IGauge(voter.gauges(pool));
        uint256 preStakeLpBalance = gauge.balanceOf(address(adapter));

        uint256[] memory stakeAmounts = new uint256[](1);
        stakeAmounts[0] = lpToken.balanceOf(address(adapter));
        adapter.stakeLPs(stakeAmounts, tokenIds, minLpMintAmount, pool);

        uint256 afterStakeLpBalance = gauge.balanceOf(address(adapter));

        assertTrue(afterStakeLpBalance > 0 && afterStakeLpBalance > preStakeLpBalance);

        // Unstake LPs
        adapter.unstakeLPs(stakeAmounts, tokenIds, afterStakeLpBalance, pool);

        uint256 afterUnstakeLpBalance = gauge.balanceOf(address(adapter));

        assertTrue(afterUnstakeLpBalance == preStakeLpBalance);
    }

    // WETH/rETH
    function testWethRethStaking() public {
        bool isStablePool = true;

        IERC20 lpToken = IERC20(router.pairFor(RETH_OPTIMISM, WETH9_OPTIMISM, isStablePool));

        deal(address(lpToken), address(adapter), 10 * 1e18);

        uint256[] memory tokenIds = new uint256[](1);
        tokenIds[0] = 0;
        address pool = 0x69F795e2d9249021798645d784229e5bec2a5a25;

        // Stake LPs
        uint256 minLpMintAmount = 1;

        IGauge gauge = IGauge(voter.gauges(pool));
        uint256 preStakeLpBalance = gauge.balanceOf(address(adapter));

        uint256[] memory stakeAmounts = new uint256[](1);
        stakeAmounts[0] = lpToken.balanceOf(address(adapter));
        adapter.stakeLPs(stakeAmounts, tokenIds, minLpMintAmount, pool);

        uint256 afterStakeLpBalance = gauge.balanceOf(address(adapter));

        assertTrue(afterStakeLpBalance > 0 && afterStakeLpBalance > preStakeLpBalance);

        // Unstake LPs
        adapter.unstakeLPs(stakeAmounts, tokenIds, afterStakeLpBalance, pool);

        uint256 afterUnstakeLpBalance = gauge.balanceOf(address(adapter));

        assertTrue(afterUnstakeLpBalance == preStakeLpBalance);
    }
}
