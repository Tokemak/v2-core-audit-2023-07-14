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
import { ILSTStats } from "src/interfaces/stats/ILSTStats.sol";
import { TOKE_MAINNET, WETH_MAINNET } from "test/utils/Addresses.sol";

contract LSTCalculatorBaseTest is Test {
    SystemRegistry private systemRegistry;
    AccessController private accessController;

    TestLSTCalculator private testCalculator;
    address private mockToken = vm.addr(1);

    uint256 private constant START_BLOCK = 17_371_713;
    uint256 private constant START_TIMESTAMP = 1_685_449_343;
    uint256 private constant END_BLOCK = 17_393_019;
    uint256 private constant END_TIMESTAMP = 1_686_486_143;

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

    event SlashingEventRecorded(uint256 slashingCost, uint256 slashingTimestamp);

    function setUp() public {
        uint256 mainnetFork = vm.createFork(vm.envString("MAINNET_RPC_URL"), START_BLOCK);
        vm.selectFork(mainnetFork);

        systemRegistry = new SystemRegistry(TOKE_MAINNET, WETH_MAINNET);
        accessController = new AccessController(address(systemRegistry));
        systemRegistry.setAccessController(address(accessController));
        accessController.grantRole(Roles.STATS_SNAPSHOT_ROLE, address(this));

        testCalculator = new TestLSTCalculator(systemRegistry);
    }

    function testAprInitIncreaseSnapshot() public {
        // Test intializes the baseApr filter and processes the next snapshot
        // where eth backing increases
        uint256 startingEthPerShare = 1_126_467_900_855_209_627;
        mockCalculateEthPerToken(startingEthPerShare);
        initCalculator();

        assertEq(testCalculator.lastBaseAprSnapshotTimestamp(), START_TIMESTAMP);
        assertEq(testCalculator.lastBaseAprEthPerToken(), startingEthPerShare);
        assertEq(testCalculator.lastSlashingSnapshotTimestamp(), START_TIMESTAMP);
        assertEq(testCalculator.lastSlashingEthPerToken(), startingEthPerShare);

        uint256 endingEthPerShare = 1_126_897_087_511_522_171;
        uint256 endingTimestamp = START_TIMESTAMP + testCalculator.APR_FILTER_INIT_INTERVAL_IN_SEC();
        vm.warp(endingTimestamp);
        mockCalculateEthPerToken(endingEthPerShare);

        uint256 annualizedApr = Stats.calculateAnnualizedChangeMinZero(
            START_TIMESTAMP, startingEthPerShare, endingTimestamp, endingEthPerShare
        );

        // the starting baseApr is equal to the init value measured over init interval
        uint256 expectedBaseApr = annualizedApr;

        vm.expectEmit(true, true, true, true);
        emit BaseAprSnapshotTaken(
            startingEthPerShare, START_TIMESTAMP, endingEthPerShare, endingTimestamp, 0, expectedBaseApr
        );

        testCalculator.snapshot();

        assertEq(testCalculator.lastBaseAprSnapshotTimestamp(), endingTimestamp);
        assertEq(testCalculator.lastBaseAprEthPerToken(), endingEthPerShare);
        assertEq(testCalculator.lastSlashingSnapshotTimestamp(), endingTimestamp);
        assertEq(testCalculator.lastSlashingEthPerToken(), endingEthPerShare);

        ILSTStats.LSTStatsData memory stats = testCalculator.current();
        assertEq(stats.baseApr, expectedBaseApr);
        assertEq(stats.slashingCosts.length, 0);
        assertEq(stats.slashingTimestamps.length, 0);

        // APR Increase
        startingEthPerShare = 1_126_897_087_511_522_171;

        uint256 postInitTimestamp = START_TIMESTAMP + testCalculator.APR_FILTER_INIT_INTERVAL_IN_SEC();
        assertEq(testCalculator.lastBaseAprSnapshotTimestamp(), postInitTimestamp);
        assertEq(testCalculator.lastBaseAprEthPerToken(), startingEthPerShare);
        assertEq(testCalculator.lastSlashingSnapshotTimestamp(), postInitTimestamp);
        assertEq(testCalculator.lastSlashingEthPerToken(), startingEthPerShare);

        vm.warp(END_TIMESTAMP);
        endingEthPerShare = 1_127_097_087_511_522_171;
        mockCalculateEthPerToken(endingEthPerShare);

        annualizedApr = Stats.calculateAnnualizedChangeMinZero(
            postInitTimestamp, startingEthPerShare, END_TIMESTAMP, endingEthPerShare
        );

        // the starting baseApr is non-zero so the result is filtered with ALPHA
        expectedBaseApr = (
            ((testCalculator.baseApr() * (1e18 - testCalculator.ALPHA())) + annualizedApr * testCalculator.ALPHA())
                / 1e18
        );

        vm.expectEmit(true, true, false, false);
        emit BaseAprSnapshotTaken(
            startingEthPerShare,
            postInitTimestamp,
            endingEthPerShare,
            END_TIMESTAMP,
            testCalculator.baseApr(),
            expectedBaseApr
        );

        testCalculator.snapshot();

        assertEq(testCalculator.lastBaseAprSnapshotTimestamp(), END_TIMESTAMP);
        assertEq(testCalculator.lastBaseAprEthPerToken(), endingEthPerShare);
        assertEq(testCalculator.lastSlashingSnapshotTimestamp(), END_TIMESTAMP);
        assertEq(testCalculator.lastSlashingEthPerToken(), endingEthPerShare);

        stats = testCalculator.current();
        assertEq(stats.baseApr, expectedBaseApr);
        assertEq(stats.slashingCosts.length, 0);
        assertEq(stats.slashingTimestamps.length, 0);
    }

    function testAprInitDecreaseSnapshot() public {
        // Test intializes the baseApr filter and processes the next snapshot
        // where eth backing decreases. Slashing event list should be updated
        uint256 startingEthPerShare = 1_126_467_900_855_209_627;
        mockCalculateEthPerToken(startingEthPerShare);
        initCalculator();

        assertEq(testCalculator.lastBaseAprSnapshotTimestamp(), START_TIMESTAMP);
        assertEq(testCalculator.lastBaseAprEthPerToken(), startingEthPerShare);
        assertEq(testCalculator.lastSlashingSnapshotTimestamp(), START_TIMESTAMP);
        assertEq(testCalculator.lastSlashingEthPerToken(), startingEthPerShare);

        uint256 endingEthPerShare = 1_126_897_087_511_522_171;
        uint256 endingTimestamp = START_TIMESTAMP + testCalculator.APR_FILTER_INIT_INTERVAL_IN_SEC();
        vm.warp(endingTimestamp);
        mockCalculateEthPerToken(endingEthPerShare);

        uint256 annualizedApr = Stats.calculateAnnualizedChangeMinZero(
            START_TIMESTAMP, startingEthPerShare, endingTimestamp, endingEthPerShare
        );

        // the starting baseApr is equal to the init value measured over init interval
        uint256 expectedBaseApr = annualizedApr;

        vm.expectEmit(true, true, true, true);
        emit BaseAprSnapshotTaken(
            startingEthPerShare, START_TIMESTAMP, endingEthPerShare, endingTimestamp, 0, expectedBaseApr
        );

        testCalculator.snapshot();

        assertEq(testCalculator.lastBaseAprSnapshotTimestamp(), endingTimestamp);
        assertEq(testCalculator.lastBaseAprEthPerToken(), endingEthPerShare);
        assertEq(testCalculator.lastSlashingSnapshotTimestamp(), endingTimestamp);
        assertEq(testCalculator.lastSlashingEthPerToken(), endingEthPerShare);

        ILSTStats.LSTStatsData memory stats = testCalculator.current();
        assertEq(stats.baseApr, expectedBaseApr);
        assertEq(stats.slashingCosts.length, 0);
        assertEq(stats.slashingTimestamps.length, 0);

        // APR Decrease
        startingEthPerShare = 1_126_897_087_511_522_171;

        uint256 postInitTimestamp = START_TIMESTAMP + testCalculator.APR_FILTER_INIT_INTERVAL_IN_SEC();
        assertEq(testCalculator.lastBaseAprSnapshotTimestamp(), postInitTimestamp);
        assertEq(testCalculator.lastBaseAprEthPerToken(), startingEthPerShare);
        assertEq(testCalculator.lastSlashingSnapshotTimestamp(), postInitTimestamp);
        assertEq(testCalculator.lastSlashingEthPerToken(), startingEthPerShare);

        vm.warp(END_TIMESTAMP);
        endingEthPerShare = startingEthPerShare - 1e17;

        mockCalculateEthPerToken(endingEthPerShare);
        assertTrue(testCalculator.shouldSnapshot());

        mockCalculateEthPerToken(endingEthPerShare);

        // the starting baseApr is non-zero so the result is filtered with ALPHA
        // Current value is 0 since current interval ETH backing decreased
        expectedBaseApr =
            (((testCalculator.baseApr() * (1e18 - testCalculator.ALPHA())) + 0 * testCalculator.ALPHA()) / 1e18);
        // Determine slashing cost
        uint256 slashingCost = Stats.calculateUnannualizedNegativeChange(startingEthPerShare, endingEthPerShare);

        testCalculator.snapshot();

        assertEq(testCalculator.lastBaseAprSnapshotTimestamp(), END_TIMESTAMP);
        assertEq(testCalculator.lastBaseAprEthPerToken(), endingEthPerShare);
        assertEq(testCalculator.lastSlashingSnapshotTimestamp(), END_TIMESTAMP);
        assertEq(testCalculator.lastSlashingEthPerToken(), endingEthPerShare);

        stats = testCalculator.current();
        assertEq(stats.baseApr, expectedBaseApr);
        assertEq(stats.slashingCosts.length, 1);
        assertEq(stats.slashingTimestamps.length, 1);
        assertEq(stats.slashingTimestamps[0], END_TIMESTAMP);
        assertEq(stats.slashingCosts[0], slashingCost);
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

        ILSTStats.LSTStatsData memory stats = testCalculator.current();
        assertEq(stats.baseApr, 0);
        assertEq(stats.slashingCosts.length, 0);
        assertEq(stats.slashingTimestamps.length, 0);
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

        uint256 expectedSlashingCost = 1e17;

        vm.expectEmit(true, true, true, true);
        emit SlashingEventRecorded(expectedSlashingCost, endingTimestamp);

        vm.expectEmit(true, true, true, true);
        emit SlashingSnapshotTaken(startingEthPerShare, START_TIMESTAMP, endingEthPerShare, endingTimestamp);

        testCalculator.snapshot();

        assertEq(testCalculator.lastBaseAprSnapshotTimestamp(), START_TIMESTAMP);
        assertEq(testCalculator.lastBaseAprEthPerToken(), startingEthPerShare);
        assertEq(testCalculator.lastSlashingSnapshotTimestamp(), endingTimestamp);
        assertEq(testCalculator.lastSlashingEthPerToken(), endingEthPerShare);

        ILSTStats.LSTStatsData memory stats = testCalculator.current();
        assertEq(stats.baseApr, 0);
        assertEq(stats.slashingCosts.length, 1);
        assertEq(stats.slashingTimestamps.length, 1);
        assertEq(stats.slashingTimestamps[0], endingTimestamp);
        assertEq(stats.slashingCosts[0], expectedSlashingCost);
    }

    function initCalculator() private {
        bytes32[] memory dependantAprs = new bytes32[](0);
        LSTCalculatorBase.InitData memory initData = LSTCalculatorBase.InitData({ lstTokenAddress: mockToken });
        testCalculator.initialize(dependantAprs, abi.encode(initData));
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
