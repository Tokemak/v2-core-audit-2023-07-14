// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2023 Tokemak Foundation. All rights reserved.

pragma solidity 0.8.17;

import { Test } from "forge-std/Test.sol";
import { LSTCalculatorBase } from "src/stats/calculators/base/LSTCalculatorBase.sol";
import { ProxyLSTCalculator } from "src/stats/calculators/ProxyLSTCalculator.sol";
import { Roles } from "src/libs/Roles.sol";
import { SystemRegistry } from "src/SystemRegistry.sol";
import { AccessController } from "src/security/AccessController.sol";
import { Stats } from "src/stats/Stats.sol";
import { ISystemRegistry } from "src/interfaces/ISystemRegistry.sol";
import { IStatsCalculator } from "src/interfaces/stats/IStatsCalculator.sol";
import { TOKE_MAINNET, WETH_MAINNET } from "test/utils/Addresses.sol";

// solhint-disable func-name-mixedcase
contract ProxyLSTCalculatorTest is Test {
    SystemRegistry private _systemRegistry;
    AccessController private _accessController;

    LSTCalculatorHarness private _calculator;
    ProxyLSTCalculator private _proxyCalculator;

    function setUp() public {
        uint256 mainnetFork = vm.createFork(vm.envString("MAINNET_RPC_URL"));
        vm.selectFork(mainnetFork);

        _systemRegistry = new SystemRegistry(TOKE_MAINNET, WETH_MAINNET);
        _accessController = new AccessController(address(_systemRegistry));
        _systemRegistry.setAccessController(address(_accessController));
        _accessController.grantRole(Roles.STATS_SNAPSHOT_ROLE, address(this));

        _calculator = new LSTCalculatorHarness(_systemRegistry);
        _proxyCalculator = new ProxyLSTCalculator(_systemRegistry, _calculator);
    }

    function test_Revert_WhenSnapshot() public {
        vm.expectRevert(IStatsCalculator.NoSnapshotTaken.selector);
        _proxyCalculator.snapshot();
    }

    function test_shouldSnapshot_IsAlwaysFalse() public {
        bool val = _proxyCalculator.shouldSnapshot();
        assertFalse(val);
    }

    function test_current_Success() public {
        IStatsCalculator[] memory calculators = new IStatsCalculator[](0);
        Stats.CalculatedStats memory stats =
            Stats.CalculatedStats({ statsType: Stats.StatsType.DEX, data: "", dependentStats: calculators });

        vm.mockCall(address(_calculator), abi.encodeWithSelector(IStatsCalculator.current.selector), abi.encode(stats));

        Stats.CalculatedStats memory res = _proxyCalculator.current();
        assertTrue(res.statsType == stats.statsType);
        assertTrue(keccak256(res.data) == keccak256(stats.data));
        assertTrue(res.dependentStats.length == stats.dependentStats.length);
    }
}

contract LSTCalculatorHarness is LSTCalculatorBase {
    constructor(ISystemRegistry _systemRegistry) LSTCalculatorBase(_systemRegistry) { }

    function calculateEthPerToken() public pure override returns (uint256) {
        return 0;
    }
}
