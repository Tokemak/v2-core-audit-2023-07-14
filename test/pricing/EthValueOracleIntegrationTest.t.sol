// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

// solhint-disable func-name-mixedcase
import { Test } from "forge-std/Test.sol";
import {
    BAL_VAULT,
    BEETHOVENX_VAULT,
    ROCKET_ETH_OVM_ORACLE,
    WSTETH_MAINNET,
    RETH_MAINNET,
    USDC_MAINNET,
    USDT_MAINNET,
    RETH_OPTIMISM,
    RETH_CL_FEED_MAINNET,
    USDC_CL_FEED_MAINNET,
    USDT_CL_FEED_MAINNET,
    FRAX_MAINNET,
    FRAX_CL_FEED_MAINNET,
    DAI_MAINNET,
    DAI_CL_FEED_MAINNET,
    SUSD_MAINNET,
    SUSD_CL_FEED_MAINNET,
    CRV_MAINNET,
    CRV_CL_FEED_MAINNET,
    CVX_MAINNET,
    CVX_CL_FEED_MAINNET,
    USDC_OPTIMISM,
    WSTETH_OPTIMISM,
    SUSDC_OPTIMISM,
    SUSD_CL_FEED_OPTIMISM,
    USDC_CL_FEED_OPTIMISM,
    WSTETH_CL_FEED_OPTIMISM,
    USDC_ARBITRUM,
    USDT_ARBITRUM,
    USDC_CL_FEED_ARBITRUM,
    USDT_CL_FEED_ARBITRUM,
    WETH9_ADDRESS,
    ETH_CL_FEED_MAINNET,
    WETH9_OPTIMISM,
    ETH_CL_FEED_OPTIMISM,
    WETH9_ARBITRUM,
    ETH_CL_FEED_ARBITRUM,
    FRXETH_MAINNET,
    SFRXETH_MAINNET,
    STETH_MAINNET,
    SETH_MAINNET,
    CBETH_MAINNET,
    CBETH_CL_FEED_MAINNET,
    STETH_CL_FEED_MAINNET,
    WSETH_WETH_BAL_POOL,
    RETH_WETH_BAL_POOL,
    CBETH_WSTETH_BAL_POOL,
    RETH_WETH_BEETHOVEN_POOL,
    WSTETH_USDC_BEETHOVEN_POOL,
    USDC_WETH_CAMELOT_POOL,
    USDC_USDT_CAMELOT_POOL,
    FRAX_CURVE_METAPOOL_LP,
    STETH_WETH_CURVE_POOL_LP,
    SETH_WETH_CURVE_POOL_LP,
    RETH_WSTETH_CURVE_POOL_LP,
    ETH_FRXETH_CURVE_POOL_LP,
    CRV_ETH_CURVE_V2_LP,
    CVX_ETH_CURVE_V2_LP,
    WETH_RETH_VELODROME_POOL,
    USDC_SUSD_VELODROME_POOL,
    THREE_CURVE_POOL_MAINNET_LP,
    LDO_ETH_CURVE_V2_LP,
    LDO_MAINNET,
    LDO_CL_FEED_MAINNET,
    WSETH_RETH_SFRXETH_BAL_POOL,
    FRAX_CURVE_METAPOOL,
    THREE_CURVE_MAINNET,
    STETH_WETH_CURVE_POOL,
    SETH_WETH_CURVE_POOL,
    RETH_WSTETH_CURVE_POOL,
    ETH_FRXETH_CURVE_POOL,
    CRV_ETH_CURVE_V2_POOL,
    CVX_ETH_CURVE_V2_POOL,
    LDO_ETH_CURVE_V2_POOL
} from "test/utils/Addresses.sol";

import { EthValueOracle } from "src/pricing/EthValueOracle.sol";
import { BalancerV2LPValueProvider } from "src/pricing/value-providers/BalancerV2LPValueProvider.sol";
import { BeethovenXValueProvider } from "src/pricing/value-providers/BeethovenXValueProvider.sol";
import { CamelotValueProvider } from "src/pricing/value-providers/CamelotValueProvider.sol";
import { ChainlinkValueProvider } from "src/pricing/value-providers/ChainlinkValueProvider.sol";
import { CurveValueProvider } from "src/pricing/value-providers/CurveValueProvider.sol";
import { VelodromeValueProvider } from "src/pricing/value-providers/VelodromeValueProvider.sol";
import { OptimismRocketPoolEthValueProvider } from "src/pricing/value-providers/OptimismRocketPoolEthValueProvider.sol";
import { EthValueProvider } from "src/pricing/value-providers/EthValueProvider.sol";
import { SfrxEthValueProvider } from "src/pricing/value-providers/SfrxEthValueProvider.sol";
import { WstEthValueProvider } from "src/pricing/value-providers/WstEthValueProvider.sol";

import { Denominations } from "src/pricing/library/Denominations.sol";
import { TokemakPricingPrecision } from "src/pricing/library/TokemakPricingPrecision.sol";

/**
 * @dev This contract should be updated for any new pool or token that will require pricing.  In order to calculate
 *      expected values, follow the operations in whatever `ValueProvider.sol` contract that is being tested. A
 *      basic overview below:
 *
 *        1) Get balances of all tokens in pool at pinned block.  This is accomplished through a registry, vault,
 *            or simply calling `balanceOf()` on the pool contract for each ERC20 token contained.
 *        2) Find the price of each token in the pool in Eth at the pinned block.  This is usually accomplished via an
 *            oracle like Chainlink or Tellor, but can also be accomplished through other mechanisms (ex:
 *            rEth has its own adapter on Optimism).  There is also the possibility that a token is priced
 *            in USD, which will require the price of Eth / USD to be retrieved as well.
 *        3) Get the total value of each token in the pool.  This is accomplished by multiplying the
 *            balance of token retrieved in step 1 by the price of the token in Eth retrieved in step 2.
 *        4) Add the total values for each token in the pool together to get the total value of the pool in eth.
 *        5) Divide the total pool value by the number of lp tokens in the pool.  This will be the price per lp
 *            token in Eth, and will be the expected price for the pool.
 *
 *      These tests use pinned blocks to give stable pricing information in relation to the calculated expected
 *      values.
 */

//solhint-disable max-states-count
contract EthValueOracleIntegrationTest is Test {
    uint256 public mainnetFork;
    uint256 public optimismFork;
    uint256 public arbitrumFork;

    // Mainnet deployments
    EthValueOracle public ethValueOracleMainnet;
    ChainlinkValueProvider public clValueProviderMainnet;
    BalancerV2LPValueProvider public balancerV2ValueProvider;
    CurveValueProvider public curveValueProvider;
    EthValueProvider public ethValueProviderMainnet;
    SfrxEthValueProvider public sfrxValueProviderMainnet;
    WstEthValueProvider public wstEthValueProviderMainnet;

    // Optimism deployments
    EthValueOracle public ethValueOracleOptimism;
    ChainlinkValueProvider public clValueProviderOptimism;
    BeethovenXValueProvider public beethovenXValueProvider;
    VelodromeValueProvider public velodromeValueProvider;
    OptimismRocketPoolEthValueProvider public rEthValueProviderOptimism;
    EthValueProvider public ethValueProviderOptimism;

    // Arbitrum deployments
    EthValueOracle public ethValueOracleArbitrum;
    ChainlinkValueProvider public clValueProviderArbitrum;
    CamelotValueProvider public camelotValueProvider;
    EthValueProvider public ethValueProviderArbitrum;

    function setUp() external {
        // __________________________ //
        // Forking set up
        // __________________________ //

        mainnetFork = vm.createFork(vm.envString("MAINNET_RPC_URL"), 17_000_000);
        optimismFork = vm.createFork(vm.envString("OPTIMISM_MAINNET_RPC_URL"), 90_000_000);
        arbitrumFork = vm.createFork(vm.envString("ARBITRUM_MAINNET_RPC_URL"), 80_000_000);

        // __________________________ //
        // Mainnet setup
        // __________________________ //

        // Deployments
        vm.selectFork(mainnetFork);
        ethValueOracleMainnet = new EthValueOracle();
        clValueProviderMainnet = new ChainlinkValueProvider(address(ethValueOracleMainnet));
        balancerV2ValueProvider = new BalancerV2LPValueProvider(BAL_VAULT, address(ethValueOracleMainnet));
        curveValueProvider = new CurveValueProvider(address(ethValueOracleMainnet));
        ethValueProviderMainnet = new EthValueProvider(address(ethValueOracleMainnet));
        sfrxValueProviderMainnet = new SfrxEthValueProvider(SFRXETH_MAINNET, address(ethValueOracleMainnet));
        wstEthValueProviderMainnet = new WstEthValueProvider(WSTETH_MAINNET, address(ethValueOracleMainnet));

        // Setting value providers for tokens
        ethValueOracleMainnet.addValueProvider(WSTETH_MAINNET, address(wstEthValueProviderMainnet));
        ethValueOracleMainnet.addValueProvider(RETH_MAINNET, address(clValueProviderMainnet));
        ethValueOracleMainnet.addValueProvider(USDC_MAINNET, address(clValueProviderMainnet));
        ethValueOracleMainnet.addValueProvider(USDT_MAINNET, address(clValueProviderMainnet));
        ethValueOracleMainnet.addValueProvider(FRAX_MAINNET, address(clValueProviderMainnet));
        ethValueOracleMainnet.addValueProvider(DAI_MAINNET, address(clValueProviderMainnet));
        ethValueOracleMainnet.addValueProvider(SUSD_MAINNET, address(clValueProviderMainnet));
        ethValueOracleMainnet.addValueProvider(CRV_MAINNET, address(clValueProviderMainnet));
        ethValueOracleMainnet.addValueProvider(CVX_MAINNET, address(clValueProviderMainnet));
        ethValueOracleMainnet.addValueProvider(WETH9_ADDRESS, address(ethValueProviderMainnet));
        ethValueOracleMainnet.addValueProvider(Denominations.ETH, address(ethValueProviderMainnet));
        ethValueOracleMainnet.addValueProvider(Denominations.ETH_IN_USD, address(clValueProviderMainnet));
        ethValueOracleMainnet.addValueProvider(STETH_MAINNET, address(clValueProviderMainnet));
        ethValueOracleMainnet.addValueProvider(SETH_MAINNET, address(ethValueProviderMainnet));
        ethValueOracleMainnet.addValueProvider(CBETH_MAINNET, address(clValueProviderMainnet));
        ethValueOracleMainnet.addValueProvider(FRXETH_MAINNET, address(ethValueProviderMainnet));
        ethValueOracleMainnet.addValueProvider(SFRXETH_MAINNET, address(sfrxValueProviderMainnet));
        ethValueOracleMainnet.addValueProvider(LDO_MAINNET, address(clValueProviderMainnet));

        // Setting denominations
        clValueProviderMainnet.addDenomination(RETH_MAINNET, Denominations.ETH);
        clValueProviderMainnet.addDenomination(USDC_MAINNET, Denominations.ETH);
        clValueProviderMainnet.addDenomination(USDT_MAINNET, Denominations.ETH);
        clValueProviderMainnet.addDenomination(FRAX_MAINNET, Denominations.ETH);
        clValueProviderMainnet.addDenomination(DAI_MAINNET, Denominations.ETH);
        clValueProviderMainnet.addDenomination(SUSD_MAINNET, Denominations.ETH);
        clValueProviderMainnet.addDenomination(CRV_MAINNET, Denominations.ETH);
        clValueProviderMainnet.addDenomination(CVX_MAINNET, Denominations.ETH);
        clValueProviderMainnet.addDenomination(Denominations.ETH_IN_USD, Denominations.USD);
        clValueProviderMainnet.addDenomination(STETH_MAINNET, Denominations.ETH);
        clValueProviderMainnet.addDenomination(CBETH_MAINNET, Denominations.ETH);
        clValueProviderMainnet.addDenomination(LDO_MAINNET, Denominations.ETH);

        // Setting AggregatorV3 contract addresses for tokens using Chainlink
        clValueProviderMainnet.addChainlinkOracle(RETH_MAINNET, RETH_CL_FEED_MAINNET);
        clValueProviderMainnet.addChainlinkOracle(USDC_MAINNET, USDC_CL_FEED_MAINNET);
        clValueProviderMainnet.addChainlinkOracle(USDT_MAINNET, USDT_CL_FEED_MAINNET);
        clValueProviderMainnet.addChainlinkOracle(FRAX_MAINNET, FRAX_CL_FEED_MAINNET);
        clValueProviderMainnet.addChainlinkOracle(DAI_MAINNET, DAI_CL_FEED_MAINNET);
        clValueProviderMainnet.addChainlinkOracle(SUSD_MAINNET, SUSD_CL_FEED_MAINNET);
        clValueProviderMainnet.addChainlinkOracle(CRV_MAINNET, CRV_CL_FEED_MAINNET);
        clValueProviderMainnet.addChainlinkOracle(CVX_MAINNET, CVX_CL_FEED_MAINNET);
        clValueProviderMainnet.addChainlinkOracle(Denominations.ETH_IN_USD, ETH_CL_FEED_MAINNET);
        clValueProviderMainnet.addChainlinkOracle(STETH_MAINNET, STETH_CL_FEED_MAINNET);
        clValueProviderMainnet.addChainlinkOracle(CBETH_MAINNET, CBETH_CL_FEED_MAINNET);
        clValueProviderMainnet.addChainlinkOracle(LDO_MAINNET, LDO_CL_FEED_MAINNET);

        // __________________________ //
        // Optimism setup
        // __________________________ //

        // Deployments
        vm.selectFork(optimismFork);
        ethValueOracleOptimism = new EthValueOracle();
        clValueProviderOptimism = new ChainlinkValueProvider(address(ethValueOracleOptimism));
        beethovenXValueProvider = new BeethovenXValueProvider(BEETHOVENX_VAULT, address(ethValueOracleOptimism));
        velodromeValueProvider = new VelodromeValueProvider(address(ethValueOracleOptimism));
        rEthValueProviderOptimism =
            new OptimismRocketPoolEthValueProvider(ROCKET_ETH_OVM_ORACLE, address(ethValueOracleOptimism));
        ethValueProviderOptimism = new EthValueProvider(address(ethValueOracleOptimism));

        // Setting value providers for tokens
        ethValueOracleOptimism.addValueProvider(RETH_OPTIMISM, address(rEthValueProviderOptimism));
        ethValueOracleOptimism.addValueProvider(USDC_OPTIMISM, address(clValueProviderOptimism));
        ethValueOracleOptimism.addValueProvider(WSTETH_OPTIMISM, address(clValueProviderOptimism));
        ethValueOracleOptimism.addValueProvider(SUSDC_OPTIMISM, address(clValueProviderOptimism));
        ethValueOracleOptimism.addValueProvider(WETH9_OPTIMISM, address(ethValueProviderOptimism));
        ethValueOracleOptimism.addValueProvider(Denominations.ETH, address(ethValueProviderOptimism));
        ethValueOracleOptimism.addValueProvider(Denominations.ETH_IN_USD, address(clValueProviderOptimism));

        // Setting denominations
        clValueProviderOptimism.addDenomination(USDC_OPTIMISM, Denominations.USD);
        clValueProviderOptimism.addDenomination(WSTETH_OPTIMISM, Denominations.USD);
        clValueProviderOptimism.addDenomination(SUSDC_OPTIMISM, Denominations.USD);
        clValueProviderOptimism.addDenomination(Denominations.ETH_IN_USD, Denominations.USD);

        // Setting AggregatorV3 contract addresses for tokens using Chainlink
        clValueProviderOptimism.addChainlinkOracle(USDC_OPTIMISM, USDC_CL_FEED_OPTIMISM);
        clValueProviderOptimism.addChainlinkOracle(WSTETH_OPTIMISM, WSTETH_CL_FEED_OPTIMISM);
        clValueProviderOptimism.addChainlinkOracle(SUSDC_OPTIMISM, SUSD_CL_FEED_OPTIMISM);
        clValueProviderOptimism.addChainlinkOracle(Denominations.ETH_IN_USD, ETH_CL_FEED_OPTIMISM);

        // __________________________ //
        // Arbitrum setup
        // __________________________ //

        // Deployments
        vm.selectFork(arbitrumFork);
        ethValueOracleArbitrum = new EthValueOracle();
        clValueProviderArbitrum = new ChainlinkValueProvider(address(ethValueOracleArbitrum));
        camelotValueProvider = new CamelotValueProvider(address(ethValueOracleArbitrum));
        ethValueProviderArbitrum = new EthValueProvider(address(ethValueOracleArbitrum));

        // Setting value providers for tokens
        ethValueOracleArbitrum.addValueProvider(USDC_ARBITRUM, address(clValueProviderArbitrum));
        ethValueOracleArbitrum.addValueProvider(USDT_ARBITRUM, address(clValueProviderArbitrum));
        ethValueOracleArbitrum.addValueProvider(WETH9_ARBITRUM, address(ethValueProviderArbitrum));
        ethValueOracleArbitrum.addValueProvider(Denominations.ETH, address(ethValueProviderArbitrum));
        ethValueOracleArbitrum.addValueProvider(Denominations.ETH_IN_USD, address(clValueProviderArbitrum));

        // Setting denominations
        clValueProviderArbitrum.addDenomination(USDC_ARBITRUM, Denominations.USD);
        clValueProviderArbitrum.addDenomination(USDT_ARBITRUM, Denominations.USD);
        clValueProviderArbitrum.addDenomination(Denominations.ETH_IN_USD, Denominations.USD);

        // Setting AggregatorV3 contract addresses for tokens using Chainlink
        clValueProviderArbitrum.addChainlinkOracle(USDC_ARBITRUM, USDC_CL_FEED_ARBITRUM);
        clValueProviderArbitrum.addChainlinkOracle(USDT_ARBITRUM, USDT_CL_FEED_ARBITRUM);
        clValueProviderArbitrum.addChainlinkOracle(Denominations.ETH_IN_USD, ETH_CL_FEED_ARBITRUM);
    }

    // __________________________ //
    // Test lp token pricing
    // __________________________ //
    function test_BalancerV2ValueProviderViaEthValueOracle() external {
        vm.selectFork(mainnetFork);

        address[4] memory lpTokensToTest =
            [WSETH_WETH_BAL_POOL, RETH_WETH_BAL_POOL, CBETH_WSTETH_BAL_POOL, WSETH_RETH_SFRXETH_BAL_POOL];
        uint256[4] memory expectedValues = [
            uint256(922_087_924_000_000_000),
            uint256(1_021_931_860_000_000_000),
            uint256(920_332_090_000_000_000),
            uint256(931_582_611_000_000_000)
        ];

        for (uint256 i = 0; i < lpTokensToTest.length; ++i) {
            ethValueOracleMainnet.addValueProvider(lpTokensToTest[i], address(balancerV2ValueProvider));

            uint256 contractCalculatedPrice =
                ethValueOracleMainnet.getPrice(lpTokensToTest[i], TokemakPricingPrecision.STANDARD_PRECISION, false);

            (uint256 upperBound, uint256 lowerBound) = _getOnePercentTolerance(expectedValues[i]);

            assertGt(upperBound, contractCalculatedPrice);
            assertLt(lowerBound, contractCalculatedPrice);
        }
    }

    function test_BeethovenXValueProviderViaEthValueOracle() external {
        vm.selectFork(optimismFork);

        address[2] memory lpTokensToTest = [RETH_WETH_BEETHOVEN_POOL, WSTETH_USDC_BEETHOVEN_POOL];
        uint256[2] memory expectedValues = [uint256(1_010_783_670_000_000_000), uint256(23_546_546_100_000_000)];

        for (uint256 i = 0; i < lpTokensToTest.length; ++i) {
            ethValueOracleOptimism.addValueProvider(lpTokensToTest[i], address(beethovenXValueProvider));

            uint256 contractCalculatedPrice = ethValueOracleOptimism.getPrice(
                RETH_WETH_BEETHOVEN_POOL, TokemakPricingPrecision.STANDARD_PRECISION, false
            );

            (uint256 upperBound, uint256 lowerBound) = _getOnePercentTolerance(expectedValues[0]);

            assertGt(upperBound, contractCalculatedPrice);
            assertLt(lowerBound, contractCalculatedPrice);
        }
    }

    function test_CamelotValueProviderViaEthValueOracle() external {
        vm.selectFork(arbitrumFork);

        address[2] memory lpTokensToTest = [USDC_WETH_CAMELOT_POOL, USDC_USDT_CAMELOT_POOL];
        uint256[2] memory expectedValues =
            [uint256(47_568_846_200_000_000_000_000), uint256(1_015_994_110_000_000_000_000_000_000)];

        for (uint256 i = 0; i < lpTokensToTest.length; ++i) {
            ethValueOracleArbitrum.addValueProvider(lpTokensToTest[i], address(camelotValueProvider));

            uint256 contractCalculatedPrice =
                ethValueOracleArbitrum.getPrice(lpTokensToTest[i], TokemakPricingPrecision.STANDARD_PRECISION, false);

            (uint256 upperBound, uint256 lowerBound) = _getOnePercentTolerance(expectedValues[i]);

            assertGt(upperBound, contractCalculatedPrice);
            assertLt(lowerBound, contractCalculatedPrice);
        }
    }

    // Tests meta, stable, v2 pools
    function test_CurveValueProviderViaEthValueOracle() external {
        vm.selectFork(mainnetFork);

        // Register base pools needed for metapool tests.
        address[1] memory basePoolLpsToRegister = [THREE_CURVE_POOL_MAINNET_LP];
        address[1] memory basePoolsToRegister = [THREE_CURVE_MAINNET];
        uint8[1] memory numTokensBasePools = [2];
        for (uint256 i = 0; i < basePoolLpsToRegister.length; ++i) {
            ethValueOracleMainnet.addValueProvider(basePoolLpsToRegister[i], address(curveValueProvider));
            curveValueProvider.registerCurveLPToken(
                basePoolLpsToRegister[i], basePoolsToRegister[i], numTokensBasePools[i]
            );
        }

        // Test rest of pools
        address[8] memory lpTokensToTest = [
            FRAX_CURVE_METAPOOL_LP, // Meta
            STETH_WETH_CURVE_POOL_LP, // Stable
            SETH_WETH_CURVE_POOL_LP,
            RETH_WSTETH_CURVE_POOL_LP,
            ETH_FRXETH_CURVE_POOL_LP,
            CRV_ETH_CURVE_V2_LP, // V2
            CVX_ETH_CURVE_V2_LP,
            LDO_ETH_CURVE_V2_LP
        ];
        // For registration on `CurveValueProvider.sol`
        address[8] memory poolAddresses = [
            FRAX_CURVE_METAPOOL,
            STETH_WETH_CURVE_POOL,
            SETH_WETH_CURVE_POOL,
            RETH_WSTETH_CURVE_POOL,
            ETH_FRXETH_CURVE_POOL,
            CRV_ETH_CURVE_V2_POOL,
            CVX_ETH_CURVE_V2_POOL,
            LDO_ETH_CURVE_V2_POOL
        ];
        // For registration on `CurveValueProvider.sol`
        uint8[8] memory numPoolTokens = [1, 1, 1, 1, 1, 1, 1, 1];
        uint256[8] memory expectedValues = [
            uint256(543_081_414_449_912),
            uint256(1_037_013_610_000_000_000),
            uint256(1_018_492_320_000_000_000),
            uint256(1_035_339_630_000_000_000),
            uint256(1_000_843_540_000_000_000),
            uint256(48_761_367_100_000_000),
            uint256(108_519_257_000_000_000),
            uint256(73_960_884_500_000_000)
        ];
        for (uint256 i = 0; i < lpTokensToTest.length; ++i) {
            ethValueOracleMainnet.addValueProvider(lpTokensToTest[i], address(curveValueProvider));
            curveValueProvider.registerCurveLPToken(lpTokensToTest[i], poolAddresses[i], numPoolTokens[i]);
            uint256 contractCalculatedPrice =
                ethValueOracleMainnet.getPrice(lpTokensToTest[i], TokemakPricingPrecision.STANDARD_PRECISION, false);

            (uint256 upperBound, uint256 lowerBound) = _getOnePercentTolerance(expectedValues[i]);

            assertGt(upperBound, contractCalculatedPrice);
            assertLt(lowerBound, contractCalculatedPrice);
        }
    }

    function test_VelodromeValueProviderViaEthValueOracle() external {
        vm.selectFork(optimismFork);

        address[2] memory lpTokensToTest = [WETH_RETH_VELODROME_POOL, USDC_SUSD_VELODROME_POOL];
        uint256[2] memory expectedValues = [uint256(2_068_792_690_000_000_000), uint256(992_265_823_000_000_000_000)];

        for (uint256 i = 0; i < lpTokensToTest.length; ++i) {
            ethValueOracleOptimism.addValueProvider(lpTokensToTest[i], address(velodromeValueProvider));
            uint256 contractCalculatedPrice =
                ethValueOracleOptimism.getPrice(lpTokensToTest[i], TokemakPricingPrecision.STANDARD_PRECISION, false);

            (uint256 upperBound, uint256 lowerBound) = _getOnePercentTolerance(expectedValues[i]);

            assertGt(upperBound, contractCalculatedPrice);
            assertLt(lowerBound, contractCalculatedPrice);
        }
    }

    // __________________________ //
    // Test decimal operations
    // __________________________ //
    function test_ReturnsInEthPrecision() external {
        // Attempt to get price of 2000 usdc in Eth, make sure that value returned is in Eth precision (1e18).
        vm.selectFork(mainnetFork);

        uint256 price = ethValueOracleMainnet.getPrice(USDC_MAINNET, 2_000_000_000, false);

        uint256 expected = uint256(1_068_984_110_000_000_000);
        (uint256 upperBound, uint256 lowerBound) = _getOnePercentTolerance(expected);
        assertGt(upperBound, price);
        assertLt(lowerBound, price);
    }

    function test_ReturnsInInputPrecision() external {
        // Attempt to get price of 2000 usdc in usdc precision, make sure that value returned is in 1e6 precision.
        vm.selectFork(mainnetFork);

        uint256 price = ethValueOracleMainnet.getPrice(USDC_MAINNET, 2_000_000_000, true);

        uint256 expected = uint256(1_068_984);
        (uint256 upperBound, uint256 lowerBound) = _getOnePercentTolerance(expected);
        assertGt(upperBound, price);
        assertLt(lowerBound, price);
    }

    function _getOnePercentTolerance(uint256 expectedValue)
        internal
        pure
        returns (uint256 upperBound, uint256 lowerBound)
    {
        uint256 onePercentCalculatedValue = expectedValue / 100;
        upperBound = expectedValue + onePercentCalculatedValue;
        lowerBound = expectedValue - onePercentCalculatedValue;
    }
}
