// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import { Test } from "forge-std/Test.sol";
import {
    THREE_CURVE_POOL_MAINNET_LP,
    THREE_CURVE_MAINNET,
    DAI_MAINNET,
    USDT_MAINNET,
    USDC_MAINNET
} from "test/utils/Addresses.sol";

import { CurveValueProvider } from "src/pricing/value-providers/CurveValueProvider.sol";

// solhint-disable func-name-mixedcase
contract CurveValueProviderTest is Test {
    CurveValueProvider public curveValueProvider;

    error ZeroAddress(string paramName);

    event CurvePoolRegistered(address lpToken, address pool);
    event CurvePoolRemoved(address lpToken, address pool);

    function setUp() external {
        vm.createSelectFork(vm.envString("MAINNET_RPC_URL"));

        // EthValueOracle.sol doesn't need to be deployed for these tests.
        curveValueProvider = new CurveValueProvider(address(1));
    }

    // Test `registerCurveLpToken()`
    function test_OnlyOwnerOnRegister() external {
        vm.expectRevert("Ownable: caller is not the owner");
        vm.prank(address(2));

        curveValueProvider.registerCurveLPToken(
            THREE_CURVE_POOL_MAINNET_LP, CurveValueProvider.PoolRegistryLocation.MetaStableRegistry
        );
    }

    function test_LpTokenZeroAddress() external {
        vm.expectRevert(abi.encodeWithSelector(ZeroAddress.selector, "lpToken"));

        curveValueProvider.registerCurveLPToken(address(0), CurveValueProvider.PoolRegistryLocation.MetaStableRegistry);
    }

    function test_RevertAlreadyRegistered() external {
        curveValueProvider.registerCurveLPToken(
            THREE_CURVE_POOL_MAINNET_LP, CurveValueProvider.PoolRegistryLocation.MetaStableRegistry
        );
        vm.expectRevert(CurveValueProvider.CurvePoolAlreadyRegistered.selector);

        curveValueProvider.registerCurveLPToken(
            THREE_CURVE_POOL_MAINNET_LP, CurveValueProvider.PoolRegistryLocation.MetaStableRegistry
        );
    }

    function test_RevertPoolNotRegisteredOnCurve() external {
        CurveValueProvider.PoolRegistryLocation[5] memory locations = [
            CurveValueProvider.PoolRegistryLocation.MetaStableRegistry,
            CurveValueProvider.PoolRegistryLocation.MetaStableFactory,
            CurveValueProvider.PoolRegistryLocation.MetaPoolFactory,
            CurveValueProvider.PoolRegistryLocation.V2Registry,
            CurveValueProvider.PoolRegistryLocation.V2Factory
        ];
        for (uint256 i = 0; i < 5; ++i) {
            vm.expectRevert(); // Different signatures, so not specifiying.
            curveValueProvider.registerCurveLPToken(address(1), locations[i]);
        }
    }

    function test_ProperRegistration() external {
        vm.expectEmit(false, false, false, true);
        emit CurvePoolRegistered(THREE_CURVE_POOL_MAINNET_LP, THREE_CURVE_MAINNET);

        curveValueProvider.registerCurveLPToken(
            THREE_CURVE_POOL_MAINNET_LP, CurveValueProvider.PoolRegistryLocation.MetaStableRegistry
        );

        CurveValueProvider.CurvePool memory curvePool = curveValueProvider.getPoolInfo(THREE_CURVE_POOL_MAINNET_LP);

        assertEq(curvePool.pool, THREE_CURVE_MAINNET);
        assertEq(curvePool.numCoins, 3);
        assertEq(curvePool.tokensInPool[0], DAI_MAINNET);
        assertEq(curvePool.tokensInPool[1], USDC_MAINNET);
        assertEq(curvePool.tokensInPool[2], USDT_MAINNET);
    }

    // Test `removeCurveLpToken()`
    function test_OnlyOwnerOnRemove() external {
        vm.expectRevert("Ownable: caller is not the owner");
        vm.prank(address(2));

        curveValueProvider.removeCurveLPToken(THREE_CURVE_POOL_MAINNET_LP);
    }

    function test_LpTokenZeroAddressRemove() external {
        vm.expectRevert(abi.encodeWithSelector(ZeroAddress.selector, "lpToken"));

        curveValueProvider.removeCurveLPToken(address(0));
    }

    function test_RevertPoolNotRegistered() external {
        vm.expectRevert(CurveValueProvider.CurvePoolNotRegistered.selector);

        curveValueProvider.removeCurveLPToken(THREE_CURVE_POOL_MAINNET_LP);
    }

    function test_ProperRemoval() external {
        curveValueProvider.registerCurveLPToken(
            THREE_CURVE_POOL_MAINNET_LP, CurveValueProvider.PoolRegistryLocation.MetaStableRegistry
        );

        vm.expectEmit(false, false, false, true);
        emit CurvePoolRemoved(THREE_CURVE_POOL_MAINNET_LP, THREE_CURVE_MAINNET);

        curveValueProvider.removeCurveLPToken(THREE_CURVE_POOL_MAINNET_LP);

        CurveValueProvider.CurvePool memory curvePool = curveValueProvider.getPoolInfo(THREE_CURVE_POOL_MAINNET_LP);

        assertEq(curvePool.pool, address(0));
        assertEq(curvePool.numCoins, 0);
    }
}
