// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2023 Tokemak Foundation. All rights reserved.

pragma solidity 0.8.17;

// solhint-disable func-name-mixedcase
// solhint-disable var-name-mixedcase

import { Test } from "forge-std/Test.sol";
import { console } from "forge-std/console.sol";
import {
    BAL_VAULT,
    CURVE_META_REGISTRY_MAINNET,
    SFRXETH_MAINNET,
    TELLOR_ORACLE,
    WSTETH_MAINNET,
    STETH_MAINNET,
    RETH_MAINNET,
    DAI_MAINNET,
    USDC_MAINNET,
    USDT_MAINNET,
    CBETH_MAINNET,
    STETH_CL_FEED_MAINNET,
    RETH_CL_FEED_MAINNET,
    DAI_CL_FEED_MAINNET,
    USDC_CL_FEED_MAINNET,
    USDT_CL_FEED_MAINNET,
    CBETH_CL_FEED_MAINNET,
    WSETH_RETH_SFRXETH_BAL_POOL,
    USDC_DAI_USDT_BAL_POOL,
    CBETH_WSTETH_BAL_POOL,
    RETH_WETH_BAL_POOL,
    WSETH_WETH_BAL_POOL,
    ST_ETH_CURVE_LP_TOKEN_MAINNET,
    STETH_ETH_CURVE_POOL,
    THREE_CURVE_POOL_MAINNET_LP,
    STETH_ETH_UNIV2,
    ETH_USDT_UNIV2,
    WETH9_ADDRESS,
    CURVE_ETH,
    FRXETH_MAINNET,
    THREE_CURVE_MAINNET,
    USDC_IN_USD_CL_FEED_MAINNET,
    ETH_CL_FEED_MAINNET,
    ETH_FRXETH_CURVE_POOL_LP,
    ETH_FRXETH_CURVE_POOL,
    STETH_NG_POOL_AND_TOKEN_CURVE,
    STETH_FRXETH_POOL_AND_TOKEN_CURVE,
    RETH_WSTETH_CURVE_POOL_LP,
    RETH_WSTETH_CURVE_POOL,
    RETH_WETH_CURVE_POOL,
    RETH_ETH_CURVE_LP,
    FRXETH_MAINNET
} from "../utils/Addresses.sol";

import { SystemRegistry } from "src/SystemRegistry.sol";
import { RootPriceOracle, IPriceOracle } from "src/oracles/RootPriceOracle.sol";
import { AccessController } from "src/security/AccessController.sol";
import { BalancerLPComposableStableEthOracle } from "src/oracles/providers/BalancerLPComposableStableEthOracle.sol";
import { BalancerLPMetaStableEthOracle } from "src/oracles/providers/BalancerLPMetaStableEthOracle.sol";
import { ChainlinkOracle } from "src/oracles/providers/ChainlinkOracle.sol";
import { CurveV1StableEthOracle } from "src/oracles/providers/CurveV1StableEthOracle.sol";
import { EthPeggedOracle } from "src/oracles/providers/EthPeggedOracle.sol";
import { SfrxEthEthOracle } from "src/oracles/providers/SfrxEthEthOracle.sol";
import { UniswapV2EthOracle } from "src/oracles/providers/UniswapV2EthOracle.sol";
import { WstETHEthOracle } from "src/oracles/providers/WstETHEthOracle.sol";
import { BaseOracleDenominations } from "src/oracles/providers/base/BaseOracleDenominations.sol";

import { IVault as IBalancerVault } from "src/interfaces/external/balancer/IVault.sol";
import { CurveResolverMainnet, ICurveResolver, ICurveMetaRegistry } from "src/utils/CurveResolverMainnet.sol";
import { IAggregatorV3Interface } from "src/interfaces/external/chainlink/IAggregatorV3Interface.sol";

/**
 * This series of tests compares expected values with contract calculated values for lp token pricing.  Below is a guide
 *      that can be used to add tests to this contract.
 *
 *      1) Using `vm.createSelectFork`, create a new fork at a recent block number.  This ensures that the safe price
 *            calculated is using recent data.
 *      2) Register new pool with `priceOracle`, check to see if individual tokens need to be registered with Chainlink
 *            or Tellor, and if lp token needs to be registered with a specific lp token oracle.
 *      3) Using an external source (coingecko, protocol UI, Etherscan), retrieve total value of the pool in USD.
 *            Divide this value by the current price of Eth in USD to get the total value of the pool in Eth.
 *      4) Normalize value of pool in Eth to e18, divide by total number of lp tokens (will already be in e18 in most
 *            cases). Normalize value returned to e18 decimals, this will be the value expected to be returned by
 *            the safe price contract.
 */

contract RootOracleIntegrationTest is Test {
    SystemRegistry public systemRegistry;
    RootPriceOracle public priceOracle;
    AccessController public accessControl;
    CurveResolverMainnet public curveResolver;

    BalancerLPComposableStableEthOracle public balancerComposableOracle;
    BalancerLPMetaStableEthOracle public balancerMetaOracle;
    ChainlinkOracle public chainlinkOracle;
    CurveV1StableEthOracle public curveStableOracle;
    EthPeggedOracle public ethPegOracle;
    SfrxEthEthOracle public sfrxEthOracle;
    UniswapV2EthOracle public uniV2EthOracle;
    WstETHEthOracle public wstEthOracle;

    function setUp() external {
        vm.createSelectFork(vm.envString("MAINNET_RPC_URL"), 17_474_729);

        // Set up system level contracts.
        systemRegistry = new SystemRegistry();
        accessControl = new AccessController(address(systemRegistry));

        systemRegistry.setAccessController(address(accessControl));
        priceOracle = new RootPriceOracle(systemRegistry);

        systemRegistry.setRootPriceOracle(address(priceOracle));
        curveResolver = new CurveResolverMainnet(ICurveMetaRegistry(CURVE_META_REGISTRY_MAINNET));

        // Set up various oracle contracts
        balancerComposableOracle = new BalancerLPComposableStableEthOracle(systemRegistry, IBalancerVault(BAL_VAULT));
        balancerMetaOracle = new BalancerLPMetaStableEthOracle(systemRegistry, IBalancerVault(BAL_VAULT));
        chainlinkOracle = new ChainlinkOracle(systemRegistry);
        curveStableOracle = new CurveV1StableEthOracle(systemRegistry, ICurveResolver(curveResolver));
        ethPegOracle = new EthPeggedOracle(systemRegistry);
        sfrxEthOracle = new SfrxEthEthOracle(systemRegistry, SFRXETH_MAINNET);
        uniV2EthOracle = new UniswapV2EthOracle(systemRegistry);
        wstEthOracle = new WstETHEthOracle(systemRegistry, WSTETH_MAINNET);

        //
        // Make persistent for multiple forks
        //
        vm.makePersistent(address(systemRegistry));
        vm.makePersistent(address(accessControl));
        vm.makePersistent(address(priceOracle));
        vm.makePersistent(address(curveResolver));
        vm.makePersistent(address(balancerComposableOracle));
        vm.makePersistent(address(balancerMetaOracle));
        vm.makePersistent(address(chainlinkOracle));
        vm.makePersistent(address(curveStableOracle));
        vm.makePersistent(address(ethPegOracle));
        vm.makePersistent(address(sfrxEthOracle));
        vm.makePersistent(address(uniV2EthOracle));
        vm.makePersistent(address(wstEthOracle));

        //
        // Root price oracle setup
        //
        priceOracle.registerMapping(STETH_MAINNET, IPriceOracle(address(chainlinkOracle)));
        priceOracle.registerMapping(RETH_MAINNET, IPriceOracle(address(chainlinkOracle)));
        priceOracle.registerMapping(DAI_MAINNET, IPriceOracle(address(chainlinkOracle)));
        priceOracle.registerMapping(USDC_MAINNET, IPriceOracle(address(chainlinkOracle)));
        priceOracle.registerMapping(USDT_MAINNET, IPriceOracle(address(chainlinkOracle)));
        priceOracle.registerMapping(CBETH_MAINNET, IPriceOracle(address(chainlinkOracle)));

        // Balancer composable stable pool
        priceOracle.registerMapping(WSETH_RETH_SFRXETH_BAL_POOL, IPriceOracle(address(balancerComposableOracle)));
        priceOracle.registerMapping(USDC_DAI_USDT_BAL_POOL, IPriceOracle(address(balancerComposableOracle)));

        // Balancer meta stable pool
        priceOracle.registerMapping(CBETH_WSTETH_BAL_POOL, IPriceOracle(address(balancerMetaOracle)));
        priceOracle.registerMapping(RETH_WETH_BAL_POOL, IPriceOracle(address(balancerMetaOracle)));
        priceOracle.registerMapping(WSETH_WETH_BAL_POOL, IPriceOracle(address(balancerMetaOracle)));

        // Curve V1
        priceOracle.registerMapping(ST_ETH_CURVE_LP_TOKEN_MAINNET, IPriceOracle(address(curveStableOracle)));
        priceOracle.registerMapping(THREE_CURVE_POOL_MAINNET_LP, IPriceOracle(address(curveStableOracle)));
        priceOracle.registerMapping(ETH_FRXETH_CURVE_POOL_LP, IPriceOracle(address(curveStableOracle)));
        priceOracle.registerMapping(STETH_NG_POOL_AND_TOKEN_CURVE, IPriceOracle(address(curveStableOracle)));
        priceOracle.registerMapping(STETH_FRXETH_POOL_AND_TOKEN_CURVE, IPriceOracle(address(curveStableOracle)));
        priceOracle.registerMapping(RETH_WSTETH_CURVE_POOL_LP, IPriceOracle(address(curveStableOracle)));

        // UniV2
        priceOracle.registerMapping(STETH_ETH_UNIV2, IPriceOracle(address(uniV2EthOracle)));
        priceOracle.registerMapping(ETH_USDT_UNIV2, IPriceOracle(address(uniV2EthOracle)));

        // Eth 1:1 setup
        priceOracle.registerMapping(WETH9_ADDRESS, IPriceOracle(address(ethPegOracle)));
        priceOracle.registerMapping(CURVE_ETH, IPriceOracle(address(ethPegOracle)));
        priceOracle.registerMapping(FRXETH_MAINNET, IPriceOracle(address(ethPegOracle)));

        // Lst special pricing case setup
        priceOracle.registerMapping(SFRXETH_MAINNET, IPriceOracle(address(sfrxEthOracle)));
        priceOracle.registerMapping(WSTETH_MAINNET, IPriceOracle(address(wstEthOracle)));

        // Chainlink setup
        chainlinkOracle.registerChainlinkOracle(
            STETH_MAINNET,
            IAggregatorV3Interface(STETH_CL_FEED_MAINNET),
            BaseOracleDenominations.Denomination.ETH,
            24 hours
        );
        chainlinkOracle.registerChainlinkOracle(
            RETH_MAINNET,
            IAggregatorV3Interface(RETH_CL_FEED_MAINNET),
            BaseOracleDenominations.Denomination.ETH,
            24 hours
        );
        chainlinkOracle.registerChainlinkOracle(
            DAI_MAINNET, IAggregatorV3Interface(DAI_CL_FEED_MAINNET), BaseOracleDenominations.Denomination.ETH, 24 hours
        );
        chainlinkOracle.registerChainlinkOracle(
            USDC_MAINNET,
            IAggregatorV3Interface(USDC_CL_FEED_MAINNET),
            BaseOracleDenominations.Denomination.ETH,
            24 hours
        );
        chainlinkOracle.registerChainlinkOracle(
            USDT_MAINNET,
            IAggregatorV3Interface(USDT_CL_FEED_MAINNET),
            BaseOracleDenominations.Denomination.ETH,
            24 hours
        );
        chainlinkOracle.registerChainlinkOracle(
            CBETH_MAINNET,
            IAggregatorV3Interface(CBETH_CL_FEED_MAINNET),
            BaseOracleDenominations.Denomination.ETH,
            24 hours
        );

        // Curve pool setup
        curveStableOracle.registerPool(STETH_ETH_CURVE_POOL, ST_ETH_CURVE_LP_TOKEN_MAINNET, false);
        curveStableOracle.registerPool(THREE_CURVE_MAINNET, THREE_CURVE_POOL_MAINNET_LP, false);
        curveStableOracle.registerPool(ETH_FRXETH_CURVE_POOL, ETH_FRXETH_CURVE_POOL_LP, false);
        curveStableOracle.registerPool(STETH_NG_POOL_AND_TOKEN_CURVE, STETH_NG_POOL_AND_TOKEN_CURVE, false);
        curveStableOracle.registerPool(STETH_FRXETH_POOL_AND_TOKEN_CURVE, STETH_FRXETH_POOL_AND_TOKEN_CURVE, false);
        curveStableOracle.registerPool(RETH_WSTETH_CURVE_POOL, RETH_WSTETH_CURVE_POOL_LP, false);

        // Uni pool setup
        uniV2EthOracle.register(STETH_ETH_UNIV2);
        uniV2EthOracle.register(ETH_USDT_UNIV2);
    }

    //
    // Test Lp token pricing
    //
    function test_BalComposableStablePoolOracle() external {
        vm.createSelectFork(vm.envString("MAINNET_RPC_URL"), 17_475_350);

        // Calculated - 573334720000000
        // Safe price - 575991341828605
        uint256 calculatedPrice = uint256(573_334_720_000_000);
        uint256 safePrice = priceOracle.getPriceInEth(USDC_DAI_USDT_BAL_POOL);
        (uint256 upperBound, uint256 lowerBound) = _getTwoPercentTolerance(calculatedPrice);
        assertGt(upperBound, safePrice);
        assertLt(lowerBound, safePrice);

        vm.createSelectFork(vm.envString("MAINNET_RPC_URL"), 17_478_924);

        // Calculated - 1010782811000000000
        // Safe price - 1055299120697408989
        calculatedPrice = uint256(1_010_782_811_000_000_000);
        safePrice = priceOracle.getPriceInEth(WSETH_RETH_SFRXETH_BAL_POOL);
        (upperBound, lowerBound) = _getTwoPercentTolerance(calculatedPrice);
        assertGt(upperBound, safePrice);
        assertLt(lowerBound, safePrice);
    }

    function test_CurveStableV1PoolOracle() external {
        vm.createSelectFork(vm.envString("MAINNET_RPC_URL"), 17_475_426);

        // Calculated - 1073735977000000000
        // Safe price - 1073637176979605953
        uint256 calculatedPrice = uint256(1_073_735_977_000_000_000);
        uint256 safePrice = priceOracle.getPriceInEth(ST_ETH_CURVE_LP_TOKEN_MAINNET);
        (uint256 upperBound, uint256 lowerBound) = _getTwoPercentTolerance(calculatedPrice);
        assertGt(upperBound, safePrice);
        assertLt(lowerBound, safePrice);

        // Calculated - 587546836000000
        // Safe price - 590481873156925
        calculatedPrice = uint256(587_546_836_000_000);
        safePrice = priceOracle.getPriceInEth(THREE_CURVE_POOL_MAINNET_LP);
        (upperBound, lowerBound) = _getTwoPercentTolerance(calculatedPrice);
        assertGt(upperBound, safePrice);
        assertLt(lowerBound, safePrice);

        // Newer tests, new fork.
        vm.createSelectFork(vm.envString("MAINNET_RPC_URL"), 17_480_014);

        // Calculated - 1003869775000000000
        // Safe price - 1001074825252786600
        calculatedPrice = uint256(1_003_869_775_000_000_000);
        safePrice = priceOracle.getPriceInEth(ETH_FRXETH_CURVE_POOL_LP);
        (upperBound, lowerBound) = _getTwoPercentTolerance(calculatedPrice);
        assertGt(upperBound, safePrice);
        assertLt(lowerBound, safePrice);

        // Calculated - 1006028244000000000
        // Safe price - 1001718276876133469
        calculatedPrice = uint256(1_006_028_244_000_000_000);
        safePrice = priceOracle.getPriceInEth(STETH_NG_POOL_AND_TOKEN_CURVE);
        (upperBound, lowerBound) = _getTwoPercentTolerance(calculatedPrice);
        assertGt(upperBound, safePrice);
        assertLt(lowerBound, safePrice);

        // Calculated - 1012223904000000000
        // Safe price - 1008312837172276871
        calculatedPrice = uint256(1_012_223_904_000_000_000);
        safePrice = priceOracle.getPriceInEth(STETH_FRXETH_POOL_AND_TOKEN_CURVE);
        (upperBound, lowerBound) = _getTwoPercentTolerance(calculatedPrice);
        assertGt(upperBound, safePrice);
        assertLt(lowerBound, safePrice);

        // Calculated - 1098321582000000000
        // Safe price - 1077905860822595469
        calculatedPrice = uint256(1_098_321_582_000_000_000);
        safePrice = priceOracle.getPriceInEth(RETH_WSTETH_CURVE_POOL_LP);
        (upperBound, lowerBound) = _getTwoPercentTolerance(calculatedPrice);
        assertGt(upperBound, safePrice);
        assertLt(lowerBound, safePrice);
    }

    function test_UniV2PoolOracle() external {
        vm.createSelectFork(vm.envString("MAINNET_RPC_URL"), 17_475_530);

        // Calculated - 2692923915000000000
        // Safe price - 2719124222286442720
        uint256 calculatedPrice = uint256(2_692_923_915_000_000_000);
        uint256 safePrice = priceOracle.getPriceInEth(STETH_ETH_UNIV2);
        (uint256 upperBound, uint256 lowerBound) = _getTwoPercentTolerance(calculatedPrice);
        assertGt(upperBound, safePrice);
        assertLt(lowerBound, safePrice);

        // Calculated - 111063607400000000000000
        // Safe price - 111696966269313545001725
        calculatedPrice = uint256(111_063_607_400_000_000_000_000);
        safePrice = priceOracle.getPriceInEth(ETH_USDT_UNIV2);
        (upperBound, lowerBound) = _getTwoPercentTolerance(calculatedPrice);
        assertGt(upperBound, safePrice);
        assertLt(lowerBound, safePrice);
    }

    function test_BalMetaStablePoolOracle() external {
        vm.createSelectFork(vm.envString("MAINNET_RPC_URL"), 17_475_744);

        // Calculated - 1010052287000000000
        // Safe price - 1049623347233950707
        uint256 calculatedPrice = uint256(1_010_052_287_000_000_000);
        uint256 safePrice = priceOracle.getPriceInEth(CBETH_WSTETH_BAL_POOL);
        (uint256 upperBound, uint256 lowerBound) = _getTwoPercentTolerance(calculatedPrice);
        assertGt(upperBound, safePrice);
        assertLt(lowerBound, safePrice);

        // Calculated - 1023468806000000000
        // Safe price - 1023189295745953671
        calculatedPrice = uint256(1_023_691_743_000_000_000);
        safePrice = priceOracle.getPriceInEth(RETH_WETH_BAL_POOL);
        (upperBound, lowerBound) = _getTwoPercentTolerance(calculatedPrice);
        assertGt(upperBound, safePrice);
        assertLt(lowerBound, safePrice);

        // Calculated - 1035273715000000000
        // Safe price - 1035531137827401614
        calculatedPrice = uint256(1_034_447_288_000_000_000);
        safePrice = priceOracle.getPriceInEth(WSETH_WETH_BAL_POOL);
        (upperBound, lowerBound) = _getTwoPercentTolerance(calculatedPrice);
        assertGt(upperBound, safePrice);
        assertLt(lowerBound, safePrice);
    }

    // Specifically test path when asset is priced in USD
    function test_EthInUsdPath() external {
        // Use bal usdc - usdt - dai pool, usdc denominated in USD

        address ETH_IN_USD = address(bytes20("ETH_IN_USD"));
        vm.createSelectFork(vm.envString("MAINNET_RPC_URL"), 17_475_310);

        chainlinkOracle.removeChainlinkRegistration(USDC_MAINNET);
        chainlinkOracle.registerChainlinkOracle(
            USDC_MAINNET,
            IAggregatorV3Interface(USDC_IN_USD_CL_FEED_MAINNET),
            BaseOracleDenominations.Denomination.USD,
            24 hours
        );
        priceOracle.registerMapping(ETH_IN_USD, IPriceOracle(address(chainlinkOracle)));
        chainlinkOracle.registerChainlinkOracle(
            ETH_IN_USD, IAggregatorV3Interface(ETH_CL_FEED_MAINNET), BaseOracleDenominations.Denomination.USD, 0
        );

        // calculated - 588167942000000
        // safe price - 587583813652788
        uint256 calculatedPrice = uint256(588_167_942_000_000);
        uint256 safePrice = priceOracle.getPriceInEth(THREE_CURVE_POOL_MAINNET_LP);
        (uint256 upperBound, uint256 lowerBound) = _getTwoPercentTolerance(calculatedPrice);
        assertGt(upperBound, safePrice);
        assertLt(lowerBound, safePrice);
    }

    function _getTwoPercentTolerance(uint256 price) internal pure returns (uint256 upperBound, uint256 lowerBound) {
        uint256 twoPercentToleranceValue = (price * 2) / 100;

        upperBound = price + twoPercentToleranceValue;
        lowerBound = price - twoPercentToleranceValue;
    }
}
