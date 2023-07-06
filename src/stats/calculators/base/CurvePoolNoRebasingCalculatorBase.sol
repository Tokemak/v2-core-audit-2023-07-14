// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2023 Tokemak Foundation. All rights reserved.
pragma solidity 0.8.17;

import { Stats } from "src/stats/Stats.sol";
import { Errors } from "src/utils/Errors.sol";
import { ISystemRegistry } from "src/interfaces/ISystemRegistry.sol";
import { IStatsCalculator } from "src/interfaces/stats/IStatsCalculator.sol";
import { IDexLSTStats } from "src/interfaces/stats/IDexLSTStats.sol";
import { ICurveRegistry } from "src/interfaces/external/curve/ICurveRegistry.sol";
import { Initializable } from "openzeppelin-contracts/proxy/utils/Initializable.sol";
import { BaseStatsCalculator } from "src/stats/calculators/base/BaseStatsCalculator.sol";
import { IStatsCalculatorRegistry } from "src/interfaces/stats/IStatsCalculatorRegistry.sol";
import { ILSTStats } from "src/interfaces/stats/ILSTStats.sol";
import { ICurveResolver } from "src/interfaces/utils/ICurveResolver.sol";
import { IRootPriceOracle } from "src/interfaces/oracles/IRootPriceOracle.sol";
import { IPool } from "src/interfaces/external/curve/IPool.sol";

abstract contract CurvePoolNoRebasingCalculatorBase is IDexLSTStats, BaseStatsCalculator, Initializable {
    IRootPriceOracle public immutable pricer;

    bytes32[] public dependentLSTAprIds;
    ILSTStats[] public lstStats;
    address[] public reserveTokens;
    uint256 public numTokens;

    bytes32 private _aprId;
    address public poolAddress;
    address public lpToken;

    uint256 public feeApr;
    uint256 public lastSnapshotTimestamp;
    uint256 public lastVirtualPrice;

    struct InitData {
        address poolAddress;
    }

    error DependentAprIdsMismatchTokens(uint256 numDependentAprIds, uint256 numCoins);
    error InvalidPool(address poolAddress);

    constructor(ISystemRegistry _systemRegistry) BaseStatsCalculator(_systemRegistry) {
        pricer = systemRegistry.rootPriceOracle();
    }

    /// @inheritdoc IStatsCalculator
    function getAddressId() external view returns (address) {
        return lpToken;
    }

    /// @inheritdoc IStatsCalculator
    function getAprId() external view returns (bytes32) {
        return _aprId;
    }

    /// @inheritdoc IStatsCalculator
    function initialize(bytes32[] calldata dependentAprIds, bytes calldata initData) external override initializer {
        InitData memory decodedInitData = abi.decode(initData, (InitData));
        Errors.verifyNotZero(decodedInitData.poolAddress, "poolAddress");
        poolAddress = decodedInitData.poolAddress;

        ICurveResolver curveResolver = systemRegistry.curveResolver();
        (reserveTokens, numTokens, lpToken,) = curveResolver.resolveWithLpToken(poolAddress);

        Errors.verifyNotZero(lpToken, "lpToken");
        if (numTokens == 0) {
            revert InvalidPool(poolAddress);
        }

        // We should have the same number of calculators sent in as there are coins
        if (dependentAprIds.length != numTokens) {
            revert DependentAprIdsMismatchTokens(dependentAprIds.length, numTokens);
        }

        _aprId = Stats.generateCurvePoolIdentifier(poolAddress);

        IStatsCalculatorRegistry registry = systemRegistry.statsCalculatorRegistry();
        for (uint256 i = 0; i < numTokens; i++) {
            bytes32 dependentAprId = dependentAprIds[i];
            if (dependentAprId != Stats.NOOP_APR_ID) {
                address coin = reserveTokens[i];

                IStatsCalculator calculator = registry.getCalculator(dependentAprId);

                // Ensure that the calculator we configured is meant to handle the token
                // setup on the pool. Individual token calculators use the address of the token
                // itself as the address id
                if (calculator.getAddressId() != coin) {
                    revert Stats.CalculatorAssetMismatch(dependentAprId, address(calculator), coin);
                }

                lstStats.push(ILSTStats(address(calculator)));
            }
        }

        // need this later to determine if a stats should be skipped on processing
        dependentLSTAprIds = dependentAprIds;

        lastSnapshotTimestamp = block.timestamp;
        lastVirtualPrice = getVirtualPrice();
    }

    /// @inheritdoc IStatsCalculator
    function shouldSnapshot() public view returns (bool) {
        // slither-disable-next-line timestamp
        return block.timestamp >= lastSnapshotTimestamp + Stats.DEX_FEE_APR_SNAPSHOT_INTERVAL;
    }

    /// @inheritdoc IDexLSTStats
    function current() external returns (DexLSTStatsData memory) {
        ILSTStats.LSTStatsData[] memory lstStatsData = new ILSTStats.LSTStatsData[](numTokens);

        uint256[] memory reservesInEth = new uint256[](numTokens);

        // no-op stats do not get pushed into the lstStats array, so we have to track it separately
        uint256 y = 0;
        for (uint256 i = 0; i < numTokens; i++) {
            bytes32 dependentAprId = dependentLSTAprIds[i];
            reservesInEth[i] = pricer.getPriceInEth(reserveTokens[i]) * IPool(poolAddress).balances(i) / 1e18;

            if (dependentAprId != Stats.NOOP_APR_ID) {
                lstStatsData[i] = lstStats[y].current();
                ++y;
            }
        }
        return DexLSTStatsData({ feeApr: feeApr, lstStatsData: lstStatsData, reservesInEth: reservesInEth });
    }

    /// @notice Capture stat data about this setup
    /// @dev This is protected by the STATS_SNAPSHOT_ROLE
    function _snapshot() internal override {
        if (!shouldSnapshot()) {
            revert NoSnapshotTaken();
        }

        uint256 currentVirtualPrice = getVirtualPrice();

        uint256 currentFeeApr = Stats.calculateAnnualizedChangeMinZero(
            lastSnapshotTimestamp, lastVirtualPrice, block.timestamp, currentVirtualPrice
        );

        uint256 newFeeApr = ((feeApr * (1e18 - Stats.DEX_FEE_ALPHA)) + (currentFeeApr * Stats.DEX_FEE_ALPHA)) / 1e18;

        lastSnapshotTimestamp = block.timestamp;
        lastVirtualPrice = currentVirtualPrice;
        feeApr = newFeeApr;
    }

    function getVirtualPrice() internal virtual returns (uint256 virtualPrice);
}
