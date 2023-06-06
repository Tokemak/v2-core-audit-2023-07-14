// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2023 Tokemak Foundation. All rights reserved.
pragma solidity 0.8.17;

import { Test } from "forge-std/Test.sol";
import { LSTCalculatorBase } from "src/stats/calculators/base/LSTCalculatorBase.sol";
import { Roles } from "src/libs/Roles.sol";
import { SystemRegistry } from "src/SystemRegistry.sol";
import { AccessController } from "src/security/AccessController.sol";
import { Stats } from "src/stats/Stats.sol";
import { ISystemRegistry } from "src/interfaces/ISystemRegistry.sol";
import { IStatsCalculator } from "src/interfaces/stats/IStatsCalculator.sol";

contract LSTCalculatorBaseTest is Test {
    SystemRegistry private systemRegistry;
    AccessController private accessController;

    TestLSTCalculator private testCalculator;
    address private mockToken = vm.addr(1);

    uint256 private constant START_BLOCK = 17_371_713;
    uint256 private constant START_TIMESTAMP = 1_685_449_343;
    uint256 private constant END_BLOCK = 17_393_019;
    uint256 private constant END_TIMESTAMP = 1_685_708_543;

    event BaseAprSnapshotTaken(
        uint256 priorEthPerToken,
        uint256 priorTimestamp,
        uint256 currentEthPerToken,
        uint256 currentTimestamp,
        uint256 priorBaseApr,
        uint256 currentBaseApr
    );

    event SlashingSnapshotTaken(
        uint256 priorEthPerToken, uint256 priorTimestamp, uint256 currentEthPerToken, uint256 currentTimestamp
    );

    event SlashingEventRecorded(LSTCalculatorBase.SlashingEvent slashingEvent);

    function setUp() public {
        uint256 mainnetFork = vm.createFork(vm.envString("MAINNET_RPC_URL"), START_BLOCK);
        vm.selectFork(mainnetFork);

        systemRegistry = new SystemRegistry();
        accessController = new AccessController(address(systemRegistry));
        systemRegistry.setAccessController(address(accessController));
        accessController.grantRole(Roles.STATS_SNAPSHOT_ROLE, address(this));

        testCalculator = new TestLSTCalculator(systemRegistry);
    }

    function testAprIncreaseSnapshot() public {
        uint256 startingEthPerShare = 1_126_467_900_855_209_627;
        mockCalculateEthPerToken(startingEthPerShare);
        initCalculator();

        assertEq(testCalculator.lastBaseAprSnapshotTimestamp(), START_TIMESTAMP);
        assertEq(testCalculator.lastBaseAprEthPerToken(), startingEthPerShare);
        assertEq(testCalculator.lastSlashingSnapshotTimestamp(), START_TIMESTAMP);
        assertEq(testCalculator.lastSlashingEthPerToken(), startingEthPerShare);

        vm.warp(END_TIMESTAMP);
        uint256 endingEthPerShare = 1_126_897_087_511_522_171;
        mockCalculateEthPerToken(endingEthPerShare);

        uint256 annualizedApr = Stats.calculateAnnualizedChangeMinZero(
            START_TIMESTAMP, startingEthPerShare, END_TIMESTAMP, endingEthPerShare
        );

        // the starting baseApr is 0 so the result is annualizedApr * ALPHA
        uint256 expectedBaseApr = annualizedApr * testCalculator.ALPHA() / 1e18;

        vm.expectEmit(true, true, true, true);
        emit BaseAprSnapshotTaken(
            startingEthPerShare, START_TIMESTAMP, endingEthPerShare, END_TIMESTAMP, 0, expectedBaseApr
        );

        testCalculator.snapshot();

        assertEq(testCalculator.lastBaseAprSnapshotTimestamp(), END_TIMESTAMP);
        assertEq(testCalculator.lastBaseAprEthPerToken(), endingEthPerShare);
        assertEq(testCalculator.lastSlashingSnapshotTimestamp(), END_TIMESTAMP);
        assertEq(testCalculator.lastSlashingEthPerToken(), endingEthPerShare);

        Stats.CalculatedStats memory stats = testCalculator.current();
        LSTCalculatorBase.LSTStatsData memory decoded = checkAndDecodeCurrent(stats);
        assertEq(decoded.baseApr, expectedBaseApr);
        assertEq(decoded.slashingEvents.length, 0);
    }

    function testAprDecreaseSnapshot() public {
        uint256 startingEthPerShare = 1e18;
        mockCalculateEthPerToken(startingEthPerShare);
        initCalculator();

        assertEq(testCalculator.lastBaseAprSnapshotTimestamp(), START_TIMESTAMP);
        assertEq(testCalculator.lastBaseAprEthPerToken(), startingEthPerShare);
        assertEq(testCalculator.lastSlashingSnapshotTimestamp(), START_TIMESTAMP);
        assertEq(testCalculator.lastSlashingEthPerToken(), startingEthPerShare);

        vm.warp(END_TIMESTAMP);
        uint256 endingEthPerShare = startingEthPerShare - 1e17;

        mockCalculateEthPerToken(endingEthPerShare);
        assertTrue(testCalculator.shouldSnapshot());

        mockCalculateEthPerToken(endingEthPerShare);

        testCalculator.snapshot();

        assertEq(testCalculator.lastBaseAprSnapshotTimestamp(), END_TIMESTAMP);
        assertEq(testCalculator.lastBaseAprEthPerToken(), endingEthPerShare);
        assertEq(testCalculator.lastSlashingSnapshotTimestamp(), END_TIMESTAMP);
        assertEq(testCalculator.lastSlashingEthPerToken(), endingEthPerShare);

        Stats.CalculatedStats memory stats = testCalculator.current();
        LSTCalculatorBase.LSTStatsData memory decoded = checkAndDecodeCurrent(stats);

        assertEq(decoded.baseApr, 0);
        assertEq(decoded.slashingEvents.length, 1);
        assertEq(decoded.slashingEvents[0].timestamp, END_TIMESTAMP);
        assertEq(decoded.slashingEvents[0].cost, 1e17);
    }

    function testRevertNoSnapshot() public {
        uint256 startingEthPerShare = 1e18;
        mockCalculateEthPerToken(startingEthPerShare);
        initCalculator();

        // move each value forward so we can verify that a snapshot was not taken
        uint256 endingEthPerShare = startingEthPerShare + 1; // do not trigger slashing
        vm.warp(START_TIMESTAMP + 1);
        mockCalculateEthPerToken(endingEthPerShare);
        assertFalse(testCalculator.shouldSnapshot());

        vm.expectRevert(abi.encodeWithSelector(IStatsCalculator.NoSnapshotTaken.selector));
        testCalculator.snapshot();
    }

    function testSlashingTimeExpire() public {
        uint256 startingEthPerShare = 1e18;
        mockCalculateEthPerToken(startingEthPerShare);
        initCalculator();

        uint256 endingEthPerShare = startingEthPerShare + 1; // do not trigger slashing event
        uint256 endingTimestamp = START_TIMESTAMP + testCalculator.SLASHING_SNAPSHOT_INTERVAL_IN_SEC();
        vm.warp(endingTimestamp);

        mockCalculateEthPerToken(endingEthPerShare);
        assertTrue(testCalculator.shouldSnapshot());

        mockCalculateEthPerToken(endingEthPerShare);

        vm.expectEmit(true, true, true, true);
        emit SlashingSnapshotTaken(startingEthPerShare, START_TIMESTAMP, endingEthPerShare, endingTimestamp);
        testCalculator.snapshot();

        assertEq(testCalculator.lastBaseAprSnapshotTimestamp(), START_TIMESTAMP);
        assertEq(testCalculator.lastBaseAprEthPerToken(), startingEthPerShare);
        assertEq(testCalculator.lastSlashingSnapshotTimestamp(), endingTimestamp);
        assertEq(testCalculator.lastSlashingEthPerToken(), endingEthPerShare);

        Stats.CalculatedStats memory stats = testCalculator.current();
        LSTCalculatorBase.LSTStatsData memory decoded = checkAndDecodeCurrent(stats);

        assertEq(decoded.baseApr, 0);
        assertEq(decoded.slashingEvents.length, 0);
    }

    function testSlashingEventOccurred() public {
        uint256 startingEthPerShare = 1e18;
        mockCalculateEthPerToken(startingEthPerShare);
        initCalculator();

        uint256 endingEthPerShare = startingEthPerShare - 1e17; // trigger slashing event
        uint256 endingTimestamp = START_TIMESTAMP + 1;
        vm.warp(endingTimestamp);

        mockCalculateEthPerToken(endingEthPerShare);
        assertTrue(testCalculator.shouldSnapshot());

        mockCalculateEthPerToken(endingEthPerShare);

        LSTCalculatorBase.SlashingEvent memory expectedSlashingEvent =
            LSTCalculatorBase.SlashingEvent({ cost: 1e17, timestamp: endingTimestamp });

        vm.expectEmit(true, true, true, true);
        emit SlashingEventRecorded(expectedSlashingEvent);

        vm.expectEmit(true, true, true, true);
        emit SlashingSnapshotTaken(startingEthPerShare, START_TIMESTAMP, endingEthPerShare, endingTimestamp);

        testCalculator.snapshot();

        assertEq(testCalculator.lastBaseAprSnapshotTimestamp(), START_TIMESTAMP);
        assertEq(testCalculator.lastBaseAprEthPerToken(), startingEthPerShare);
        assertEq(testCalculator.lastSlashingSnapshotTimestamp(), endingTimestamp);
        assertEq(testCalculator.lastSlashingEthPerToken(), endingEthPerShare);

        Stats.CalculatedStats memory stats = testCalculator.current();
        LSTCalculatorBase.LSTStatsData memory decoded = checkAndDecodeCurrent(stats);

        assertEq(decoded.baseApr, 0);
        assertEq(decoded.slashingEvents.length, 1);
        assertEq(decoded.slashingEvents[0].timestamp, expectedSlashingEvent.timestamp);
        assertEq(decoded.slashingEvents[0].cost, expectedSlashingEvent.cost);
    }

    function initCalculator() private {
        bytes32[] memory dependantAprs = new bytes32[](0);
        LSTCalculatorBase.InitData memory initData = LSTCalculatorBase.InitData({ lstTokenAddress: mockToken });
        testCalculator.initialize(dependantAprs, abi.encode(initData));
    }

    function checkAndDecodeCurrent(Stats.CalculatedStats memory current)
        private
        returns (LSTCalculatorBase.LSTStatsData memory)
    {
        assertEq(uint256(current.statsType), uint256(Stats.StatsType.LST));
        assertEq(current.dependentStats.length, 0);

        return abi.decode(current.data, (LSTCalculatorBase.LSTStatsData));
    }

    function mockCalculateEthPerToken(uint256 amount) private {
        vm.mockCall(mockToken, abi.encodeWithSelector(MockToken.getValue.selector), abi.encode(amount));
    }
}

interface MockToken {
    function getValue() external view returns (uint256);
}

contract TestLSTCalculator is LSTCalculatorBase {
    constructor(ISystemRegistry _systemRegistry) LSTCalculatorBase(_systemRegistry) { }

    function calculateEthPerToken() public view override returns (uint256) {
        // always mock the value
        return MockToken(lstTokenAddress).getValue();
    }
}
