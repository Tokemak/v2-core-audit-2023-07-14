// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2023 Tokemak Foundation. All rights reserved.
pragma solidity 0.8.17;

import { BaseStatsCalculator } from "src/stats/calculators/base/BaseStatsCalculator.sol";
import { Initializable } from "openzeppelin-contracts/proxy/utils/Initializable.sol";
import { ILSTStats } from "src/interfaces/stats/ILSTStats.sol";
import { IStatsCalculator } from "src/interfaces/stats/IStatsCalculator.sol";
import { ISystemRegistry } from "src/interfaces/ISystemRegistry.sol";
import { Stats } from "src/stats/Stats.sol";
import { SecurityBase } from "src/security/SecurityBase.sol";

abstract contract LSTCalculatorBase is ILSTStats, BaseStatsCalculator, Initializable {
    uint256 public constant APR_SNAPSHOT_INTERVAL_IN_SEC = 3 * 24 * 60 * 60; // 3 days
    uint256 public constant SLASHING_SNAPSHOT_INTERVAL_IN_SEC = 24 * 60 * 60; // 1 day
    uint256 public constant ALPHA = 1e17; // 0.1; must be less than 1e18

    address public lstTokenAddress;
    uint256 public lastBaseAprEthPerToken;
    uint256 public lastBaseAprSnapshotTimestamp;
    uint256 public lastSlashingEthPerToken;
    uint256 public lastSlashingSnapshotTimestamp;

    uint256 public baseApr;
    uint256[] public slashingCosts;
    uint256[] public slashingTimestamps;

    bytes32 private _aprId;

    struct InitData {
        address lstTokenAddress;
    }

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

    constructor(ISystemRegistry _systemRegistry) BaseStatsCalculator(_systemRegistry) { }

    /// @inheritdoc IStatsCalculator
    function initialize(bytes32[] calldata, bytes calldata initData) external override initializer {
        InitData memory decodedInitData = abi.decode(initData, (InitData));
        lstTokenAddress = decodedInitData.lstTokenAddress;
        _aprId = Stats.generateRawTokenIdentifier(lstTokenAddress);

        uint256 currentEthPerToken = calculateEthPerToken();
        lastBaseAprEthPerToken = currentEthPerToken;
        lastBaseAprSnapshotTimestamp = block.timestamp;
        lastSlashingEthPerToken = currentEthPerToken;
        lastSlashingSnapshotTimestamp = block.timestamp;
    }

    /// @inheritdoc IStatsCalculator
    function getAddressId() external view returns (address) {
        return lstTokenAddress;
    }

    /// @inheritdoc IStatsCalculator
    function getAprId() external view returns (bytes32) {
        return _aprId;
    }

    function _snapshot() internal override {
        uint256 currentEthPerToken = calculateEthPerToken();
        if (_timeForAprSnapshot()) {
            uint256 currentApr = Stats.calculateAnnualizedChangeMinZero(
                lastBaseAprSnapshotTimestamp, lastBaseAprEthPerToken, block.timestamp, currentEthPerToken
            );
            uint256 newBaseApr = ((baseApr * (1e18 - ALPHA)) + (currentApr * ALPHA)) / 1e18;

            emit BaseAprSnapshotTaken(
                lastBaseAprEthPerToken,
                lastBaseAprSnapshotTimestamp,
                currentEthPerToken,
                block.timestamp,
                baseApr,
                newBaseApr
            );

            baseApr = newBaseApr;
            lastBaseAprEthPerToken = currentEthPerToken;
            lastBaseAprSnapshotTimestamp = block.timestamp;
        }

        if (_hasSlashingOccurred(currentEthPerToken)) {
            uint256 cost = Stats.calculateUnannualizedNegativeChange(lastSlashingEthPerToken, currentEthPerToken);
            slashingCosts.push(cost);
            slashingTimestamps.push(block.timestamp);

            emit SlashingEventRecorded(cost, block.timestamp);
            emit SlashingSnapshotTaken(
                lastSlashingEthPerToken, lastSlashingSnapshotTimestamp, currentEthPerToken, block.timestamp
            );

            lastSlashingEthPerToken = currentEthPerToken;
            lastSlashingSnapshotTimestamp = block.timestamp;
        } else if (_timeForSlashingSnapshot()) {
            emit SlashingSnapshotTaken(
                lastSlashingEthPerToken, lastSlashingSnapshotTimestamp, currentEthPerToken, block.timestamp
            );
            lastSlashingEthPerToken = currentEthPerToken;
            lastSlashingSnapshotTimestamp = block.timestamp;
        }
    }

    /// @inheritdoc IStatsCalculator
    function shouldSnapshot() public view override returns (bool) {
        uint256 currentEthPerToken = calculateEthPerToken();
        if (_timeForAprSnapshot()) {
            return true;
        }

        if (_hasSlashingOccurred(currentEthPerToken)) {
            return true;
        }

        if (_timeForSlashingSnapshot()) {
            return true;
        }

        return false;
    }

    function _timeForAprSnapshot() private view returns (bool) {
        // slither-disable-next-line timestamp
        return block.timestamp >= lastBaseAprSnapshotTimestamp + APR_SNAPSHOT_INTERVAL_IN_SEC;
    }

    function _timeForSlashingSnapshot() private view returns (bool) {
        // slither-disable-next-line timestamp
        return block.timestamp >= lastSlashingSnapshotTimestamp + SLASHING_SNAPSHOT_INTERVAL_IN_SEC;
    }

    function _hasSlashingOccurred(uint256 currentEthPerToken) private view returns (bool) {
        return currentEthPerToken < lastSlashingEthPerToken;
    }

    /// @inheritdoc ILSTStats
    function current() external view returns (LSTStatsData memory) {
        return LSTStatsData({ baseApr: baseApr, slashingCosts: slashingCosts, slashingTimestamps: slashingTimestamps });
    }

    /// @inheritdoc ILSTStats
    function calculateEthPerToken() public view virtual returns (uint256);
}
