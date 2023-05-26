// SPDX-License-Identifier: MIT
pragma solidity >=0.8.7;

import { Test } from "forge-std/Test.sol";
import { Stats } from "src/libs/Stats.sol";
import { Roles } from "src/libs/Roles.sol";
import { ISystemBound } from "src/interfaces/ISystemBound.sol";
import { ISystemRegistry } from "src/interfaces/ISystemRegistry.sol";
import { IStatsCalculator } from "src/interfaces/stats/IStatsCalculator.sol";

import { IAccessControl } from "openzeppelin-contracts/access/IAccessControl.sol";
import { IAccessController } from "src/interfaces/security/IAccessController.sol";
import { IStatsCalculatorRegistry } from "src/interfaces/stats/IStatsCalculatorRegistry.sol";
import { ICurveRegistry } from "src/interfaces/external/curve/ICurveRegistry.sol";
import { SystemRegistry } from "src/SystemRegistry.sol";
import { AccessController } from "src/security/AccessController.sol";
import { StatsCalculatorFactory } from "src/stats/StatsCalculatorFactory.sol";
import { StatsCalculatorRegistry } from "src/stats/StatsCalculatorRegistry.sol";
import { CurveV1PoolStatsCalculator } from "src/stats/calculators/CurveV1PoolStatsCalculator.sol";
import { CurveV1ConvexStatsCalculator } from "src/stats/calculators/CurveV1ConvexStatsCalculator.sol";
import { CurveV1PoolCalculatorBase } from "src/stats/calculators/base/CurveV1PoolCalculatorBase.sol";
import { IConvexBooster } from "src/interfaces/external/convex/IConvexBooster.sol";

contract CurveV1ConvexStatsCalculatorFrxEthEthTests is Test {
    ICurveRegistry private constant CURVE_REGISTRY = ICurveRegistry(0x90E00ACe148ca3b23Ac1bC8C240C2a7Dd9c2d7f5);
    address private constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address private constant FRXETH = 0x5E8422345238F34275888049021821E8E08CAa1f;
    address private constant FRXETH_ETH_POOL = 0xa1F8A6807c402E4A15ef4EBa36528A3FED24E577;
    IConvexBooster private constant CONVEX_BOOSTER = IConvexBooster(0xF403C135812408BFbE8713b5A23a04b3D48AAE31);

    SystemRegistry private systemRegistry;
    AccessController private accessController;
    StatsCalculatorRegistry private statsRegistry;
    StatsCalculatorFactory private statsFactory;

    IStatsCalculator private frxEthCurvePoolCalc;
    IStatsCalculator private frxEthCurveConvexWrapCalc;

    function setUp() public {
        uint256 mainnetFork = vm.createFork(vm.envString("MAINNET_RPC_URL"));
        vm.selectFork(mainnetFork);

        systemRegistry = new SystemRegistry();
        accessController = new AccessController(address(systemRegistry));
        systemRegistry.setAccessController(address(accessController));

        statsRegistry = new StatsCalculatorRegistry(systemRegistry);
        statsFactory = new StatsCalculatorFactory(systemRegistry);

        systemRegistry.setStatsCalculatorRegistry(address(statsRegistry));
        statsRegistry.setCalculatorFactory(address(statsFactory));

        // Setup permissions we can do everything
        accessController.grantRole(Roles.CREATE_STATS_CALC_ROLE, address(this));
        accessController.grantRole(Roles.STATS_CALC_TEMPLATE_MGMT_ROLE, address(this));
        accessController.grantRole(Roles.STATS_SNAPSHOT_ROLE, address(this));

        // We're setting up the frxETH/ETH pool
        // So we need an adapter for frxETH, the pool, then Convex

        // Setup the templates
        CurveV1PoolStatsCalculator curveV1CalculatorTemplate =
            new CurveV1PoolStatsCalculator(systemRegistry, CURVE_REGISTRY);
        bytes32 curveV1Id = keccak256("curveV1");
        statsFactory.registerTemplate(curveV1Id, address(curveV1CalculatorTemplate));

        CurveV1ConvexStatsCalculator curveV1ConvexStatsTemplate =
            new CurveV1ConvexStatsCalculator(systemRegistry, CURVE_REGISTRY, CONVEX_BOOSTER);
        bytes32 curveV1ConvexId = keccak256("curveV1Convex");
        statsFactory.registerTemplate(curveV1ConvexId, address(curveV1ConvexStatsTemplate));

        // Setup the Curve Pool
        CurveV1PoolCalculatorBase.InitData memory curvePoolInitData =
            CurveV1PoolCalculatorBase.InitData({ poolAddress: FRXETH_ETH_POOL });
        bytes memory encodedCurvePoolInitData = abi.encode(curvePoolInitData);
        bytes32[] memory curveDeps = new bytes32[](2);
        curveDeps[0] = Stats.NOOP_APR_ID; //ETH
        curveDeps[1] = Stats.NOOP_APR_ID; //frxETH
        (address curveCalc) = statsFactory.create(curveV1Id, curveDeps, encodedCurvePoolInitData);
        frxEthCurvePoolCalc = IStatsCalculator(curveCalc);
        bytes32 frxEthEthPoolId = frxEthCurvePoolCalc.getAprId();

        // Setup the Convex Pool
        CurveV1ConvexStatsCalculator.InitData memory curveConvexInitData = CurveV1ConvexStatsCalculator.InitData({
            curvePoolAddress: 0xa1F8A6807c402E4A15ef4EBa36528A3FED24E577,
            convexPoolId: 128
        });
        bytes memory encodedCurveConvexPoolInitData = abi.encode(curveConvexInitData);
        bytes32[] memory curveConvexDeps = new bytes32[](1);
        curveConvexDeps[0] = frxEthEthPoolId;
        (address convexCalc) = statsFactory.create(curveV1ConvexId, curveConvexDeps, encodedCurveConvexPoolInitData);
        frxEthCurveConvexWrapCalc = IStatsCalculator(convexCalc);
    }

    function testValuesRollup() public {
        // A Curve pool should populate a trading fee APR
        // A Convex wrap should populate an incentive APR

        // No snapshots have been made, should return 0
        Stats.CalculatedStats memory curveInit = frxEthCurvePoolCalc.current();
        Stats.CalculatedStats memory convexInit = frxEthCurveConvexWrapCalc.current();
        assertAllStatsZero(curveInit);
        assertAllStatsZero(convexInit);

        // Per snapshot so we can get some values
        frxEthCurvePoolCalc.snapshot();
        frxEthCurveConvexWrapCalc.snapshot();
        Stats.CalculatedStats memory curveAfterSnapshot = frxEthCurvePoolCalc.current();
        Stats.CalculatedStats memory convexAfterSnapshot = frxEthCurveConvexWrapCalc.current();

        // Note: This may start failing when these calculators are implemented for real change
        // change test as necessary
        assertEq(curveAfterSnapshot.tradingFeeApr, convexAfterSnapshot.tradingFeeApr);
        assertGe(convexAfterSnapshot.incentiveApr, 0);
    }

    function assertAllStatsZero(Stats.CalculatedStats memory stats) internal {
        assertEq(stats.baseApr, 0);
        assertEq(stats.tradingFeeApr, 0);
        assertEq(stats.incentiveApr, 0);
        assertEq(stats.incentiveDuration, 0);
        assertEq(stats.discount, 0);
        assertEq(stats.tokemakIncentiveApr, 0);
    }
}
