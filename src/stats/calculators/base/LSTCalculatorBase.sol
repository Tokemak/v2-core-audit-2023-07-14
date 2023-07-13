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
import { IRootPriceOracle } from "src/interfaces/oracles/IRootPriceOracle.sol";

abstract contract LSTCalculatorBase is ILSTStats, BaseStatsCalculator, Initializable {
    /// @notice time in seconds between apr snapshots
    uint256 public constant APR_SNAPSHOT_INTERVAL_IN_SEC = 3 * 24 * 60 * 60; // 3 days

    /// @notice time in seconds for the initialization period
    uint256 public constant APR_FILTER_INIT_INTERVAL_IN_SEC = 9 * 24 * 60 * 60; // 9 days

    /// @notice time in seconds between slashing snapshots
    uint256 public constant SLASHING_SNAPSHOT_INTERVAL_IN_SEC = 24 * 60 * 60; // 1 day

    /// @notice alpha for filter
    uint256 public constant ALPHA = 1e17; // 0.1; must be 0 < x <= 1e18

    /// @notice lstTokenAddress is the address for the LST that the stats are for
    address public lstTokenAddress;

    /// @notice ethPerToken at the last snapshot for base apr
    uint256 public lastBaseAprEthPerToken;

    /// @notice timestamp of the last snapshot for base apr
    uint256 public lastBaseAprSnapshotTimestamp;

    /// @notice ethPerToken at the last snapshot for slashing events
    uint256 public lastSlashingEthPerToken;

    /// @notice timestamp of the last snapshot for base apr
    uint256 public lastSlashingSnapshotTimestamp;

    /// @notice filtered base apr
    uint256 public baseApr;

    /// @notice indicates if baseApr filter is initialized
    bool public baseAprFilterInitialized;

    /// @notice list of slashing costs (slashing / value at the time)
    uint256[] public slashingCosts;

    /// @notice list of timestamps associated with slashing events
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
        baseAprFilterInitialized = false;
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
            uint256 newBaseApr;
            if (baseAprFilterInitialized) {
                newBaseApr = Stats.getFilteredValue(ALPHA, baseApr, currentApr);
            } else {
                // Speed up the baseApr filter ramp
                newBaseApr = currentApr;
                baseAprFilterInitialized = true;
            }

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
        if (baseAprFilterInitialized) {
            // slither-disable-next-line timestamp
            return block.timestamp >= lastBaseAprSnapshotTimestamp + APR_SNAPSHOT_INTERVAL_IN_SEC;
        } else {
            // slither-disable-next-line timestamp
            return block.timestamp >= lastBaseAprSnapshotTimestamp + APR_FILTER_INIT_INTERVAL_IN_SEC;
        }
    }

    function _timeForSlashingSnapshot() private view returns (bool) {
        // slither-disable-next-line timestamp
        return block.timestamp >= lastSlashingSnapshotTimestamp + SLASHING_SNAPSHOT_INTERVAL_IN_SEC;
    }

    function _hasSlashingOccurred(uint256 currentEthPerToken) private view returns (bool) {
        return currentEthPerToken < lastSlashingEthPerToken;
    }

    /// @inheritdoc ILSTStats
    function current() external returns (LSTStatsData memory) {
        uint256 lastSnapshotTimestamp;

        // return the most recent snapshot timestamp
        // the timestamp is used by the LMP to ensure that snapshots are occurring
        // so it is indifferent to which snapshot has occurred
        // slither-disable-next-line timestamp
        if (lastBaseAprSnapshotTimestamp < lastSlashingSnapshotTimestamp) {
            lastSnapshotTimestamp = lastSlashingSnapshotTimestamp;
        } else {
            lastSnapshotTimestamp = lastBaseAprSnapshotTimestamp;
        }

        IRootPriceOracle pricer = systemRegistry.rootPriceOracle();
        uint256 price = pricer.getPriceInEth(lstTokenAddress);

        // result is 1e18
        uint256 priceToBacking;
        if (isRebasing()) {
            priceToBacking = price;
        } else {
            uint256 backing = calculateEthPerToken();
            // price is always 1e18 and backing is in eth, which is 1e18
            priceToBacking = price * 1e18 / backing;
        }

        // positive value is a premium; negative value is a discount
        int256 premium = int256(priceToBacking) - 1e18;

        return LSTStatsData({
            lastSnapshotTimestamp: lastSnapshotTimestamp,
            baseApr: baseApr,
            premium: premium,
            slashingCosts: slashingCosts,
            slashingTimestamps: slashingTimestamps
        });
    }

    /// @inheritdoc ILSTStats
    function calculateEthPerToken() public view virtual returns (uint256);

    /// @inheritdoc ILSTStats
    function isRebasing() public view virtual returns (bool);
}
