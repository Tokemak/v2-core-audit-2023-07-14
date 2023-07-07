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
import { IERC20Metadata } from "openzeppelin-contracts/token/ERC20/extensions/IERC20Metadata.sol";

abstract contract CurvePoolRebasingCalculatorBase is IDexLSTStats, BaseStatsCalculator, Initializable {
    ILSTStats[] public lstStats;
    address[] public reserveTokens;
    uint8[] public reserveTokenDecimals;
    uint256 public numTokens;

    bytes32 private _aprId;
    address public poolAddress;
    address public lpToken;
    uint256 public rebasingTokenIdx;

    uint256 public feeApr;
    uint256 public lastSnapshotTimestamp;
    uint256 public lastVirtualPrice;
    uint256 public lastRebasingTokenEthPerShare;

    struct InitData {
        address poolAddress;
        uint256 rebasingTokenIdx;
    }

    error DependentAprIdsMismatchTokens(uint256 numDependentAprIds, uint256 numCoins);
    error InvalidPool(address poolAddress);
    error InvalidRebasingTokenIndex(uint256 index, uint256 numTokens);

    constructor(ISystemRegistry _systemRegistry) BaseStatsCalculator(_systemRegistry) { }

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
        rebasingTokenIdx = decodedInitData.rebasingTokenIdx;

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

        if (rebasingTokenIdx >= numTokens) {
            revert InvalidRebasingTokenIndex(rebasingTokenIdx, numTokens);
        }

        _aprId = Stats.generateCurvePoolIdentifier(poolAddress);

        IStatsCalculatorRegistry registry = systemRegistry.statsCalculatorRegistry();
        lstStats = new ILSTStats[](numTokens);
        reserveTokenDecimals = new uint8[](numTokens);

        for (uint256 i = 0; i < numTokens; i++) {
            bytes32 dependentAprId = dependentAprIds[i];
            address coin = reserveTokens[i];

            if (dependentAprId != Stats.NOOP_APR_ID) {
                IStatsCalculator calculator = registry.getCalculator(dependentAprId);

                // Ensure that the calculator we configured is meant to handle the token
                // setup on the pool. Individual token calculators use the address of the token
                // itself as the address id
                if (calculator.getAddressId() != coin) {
                    revert Stats.CalculatorAssetMismatch(dependentAprId, address(calculator), coin);
                }

                lstStats[i] = ILSTStats(address(calculator));
            }

            if (coin == Stats.CURVE_ETH) {
                reserveTokenDecimals[i] = 18;
            } else {
                reserveTokenDecimals[i] = IERC20Metadata(coin).decimals();
            }
        }

        lastSnapshotTimestamp = block.timestamp;
        lastVirtualPrice = getVirtualPrice();
        lastRebasingTokenEthPerShare = lstStats[rebasingTokenIdx].calculateEthPerToken();
    }

    /// @inheritdoc IStatsCalculator
    function shouldSnapshot() public view override returns (bool) {
        // slither-disable-next-line timestamp
        return block.timestamp >= lastSnapshotTimestamp + Stats.DEX_FEE_APR_SNAPSHOT_INTERVAL;
    }

    /// @inheritdoc IDexLSTStats
    function current() external returns (DexLSTStatsData memory) {
        IRootPriceOracle pricer = systemRegistry.rootPriceOracle();
        ILSTStats.LSTStatsData[] memory lstStatsData = new ILSTStats.LSTStatsData[](numTokens);

        uint256[] memory reservesInEth = new uint256[](numTokens);

        for (uint256 i = 0; i < numTokens; i++) {
            reservesInEth[i] = calculateReserveInEthByIndex(pricer, i);

            if (address(lstStats[i]) != address(0)) {
                lstStatsData[i] = lstStats[i].current();
            }
        }
        return DexLSTStatsData({ feeApr: feeApr, lstStatsData: lstStatsData, reservesInEth: reservesInEth });
    }

    /// @notice Capture stat data about this setup
    /// @dev This is protected by the STATS_SNAPSHOT_ROLE
    function _snapshot() internal override {
        IRootPriceOracle pricer = systemRegistry.rootPriceOracle();

        uint256 currentVirtualPrice = getVirtualPrice();
        uint256 currentRebasingTokenEthPerShare = lstStats[rebasingTokenIdx].calculateEthPerToken();

        // TODO: should we check the pool price against the oracle to ensure that the pool isn't being attacked
        // an attacker could shift the balance of the pool, causing us to believe the fee apr is higher or lower
        // either way, this calculation is an approximation b/c it uses the point-in-time reserve balances to
        // estimate the yield earned from the rebasing token
        uint256 rebasingTokenEth = 0;
        uint256 totalPoolEth = 0;
        for (uint256 i = 0; i < numTokens; i++) {
            uint256 reserveInEth = calculateReserveInEthByIndex(pricer, i);
            if (i == rebasingTokenIdx) {
                rebasingTokenEth = reserveInEth;
            }
            totalPoolEth += reserveInEth;
        }

        uint256 currentFeeApr = Stats.calculateAnnualizedChangeMinZero(
            lastSnapshotTimestamp, lastVirtualPrice, block.timestamp, currentVirtualPrice
        );

        // if rebasingTokenEth > 0 then totalPoolEth > 0
        if (rebasingTokenEth > 0) {
            uint256 rebasingTokenApr = Stats.calculateAnnualizedChangeMinZero(
                lastSnapshotTimestamp, lastRebasingTokenEthPerShare, block.timestamp, currentRebasingTokenEthPerShare
            );

            // scale the apr by the share in the pool
            rebasingTokenApr = rebasingTokenApr * rebasingTokenEth / totalPoolEth;

            // slither-disable-next-line timestamp
            if (currentFeeApr > rebasingTokenApr) {
                currentFeeApr -= rebasingTokenApr;
            } else {
                currentFeeApr = 0;
            }
        }

        uint256 newFeeApr = ((feeApr * (1e18 - Stats.DEX_FEE_ALPHA)) + (currentFeeApr * Stats.DEX_FEE_ALPHA)) / 1e18;

        lastSnapshotTimestamp = block.timestamp;
        lastVirtualPrice = currentVirtualPrice;
        lastRebasingTokenEthPerShare = currentRebasingTokenEthPerShare;
        feeApr = newFeeApr;
    }

    function calculateReserveInEthByIndex(IRootPriceOracle pricer, uint256 index) internal returns (uint256) {
        // the price oracle is always 18 decimals, so divide by the decimals of the token
        // to ensure that we always report the value in ETH as 18 decimals
        uint256 divisor = 10 ** reserveTokenDecimals[index];

        // the pricer handles the reentrancy issue for curve
        // slither-disable-next-line reentrancy-benign
        return pricer.getPriceInEth(reserveTokens[index]) * IPool(poolAddress).balances(index) / divisor;
    }

    function getVirtualPrice() internal virtual returns (uint256 virtualPrice);
}
