// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2023 Tokemak Foundation. All rights reserved.
pragma solidity 0.8.17;

import { Stats } from "src/stats/Stats.sol";
import { Errors } from "src/utils/Errors.sol";
import { ISystemRegistry } from "src/interfaces/ISystemRegistry.sol";
import { IStatsCalculator } from "src/interfaces/stats/IStatsCalculator.sol";
import { ICurveRegistry } from "src/interfaces/external/curve/ICurveRegistry.sol";
import { Initializable } from "openzeppelin-contracts/proxy/utils/Initializable.sol";
import { BaseStatsCalculator } from "src/stats/calculators/base/BaseStatsCalculator.sol";
import { IStatsCalculatorRegistry } from "src/interfaces/stats/IStatsCalculatorRegistry.sol";

abstract contract CurveV1PoolCalculatorBase is BaseStatsCalculator, Initializable {
    ICurveRegistry public immutable curveRegistry;

    uint256 public lastTradingFeeApr;
    address public poolAddress;
    address public lpToken;

    bytes32 private _aprId;

    struct InitData {
        address poolAddress;
    }

    error DependentAprIdsMismatchTokens(uint256 numDependentAprIds, uint256 numCoins);
    error InvalidPool(address poolAddress);

    constructor(ISystemRegistry _systemRegistry, ICurveRegistry _curveRegistry) BaseStatsCalculator(_systemRegistry) {
        Errors.verifyNotZero(address(_curveRegistry), "_curveRegistry");

        curveRegistry = _curveRegistry;
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

        lpToken = curveRegistry.get_lp_token(decodedInitData.poolAddress);
        Errors.verifyNotZero(lpToken, "lpToken");
        _aprId = keccak256(abi.encode("curveV1", lpToken));

        // We will register a calculator specific to meta pools and should
        // ignore underlying tokens here
        uint256 nCoins = curveRegistry.get_n_coins(decodedInitData.poolAddress)[0];
        if (nCoins == 0) {
            revert InvalidPool(decodedInitData.poolAddress);
        }
        address[8] memory tokens = curveRegistry.get_coins(decodedInitData.poolAddress);

        // We should have the same number of calculators sent in as there are coins
        if (dependentAprIds.length != nCoins) {
            revert DependentAprIdsMismatchTokens(dependentAprIds.length, nCoins);
        }

        IStatsCalculatorRegistry registry = systemRegistry.statsCalculatorRegistry();
        for (uint256 i = 0; i < nCoins; i++) {
            bytes32 dependentAprId = dependentAprIds[i];

            if (dependentAprId != Stats.NOOP_APR_ID) {
                address coin = tokens[i];

                //slither-disable-start calls-loop
                IStatsCalculator calculator = registry.getCalculator(dependentAprIds[i]);

                // Ensure that the calculator we configured is meant to handle the token
                // setup on the pool. Individual token calculators use the address of the token
                // itself as the address id
                if (calculator.getAddressId() != coin) {
                    revert Stats.CalculatorAssetMismatch(dependentAprId[i], address(calculator), coin);
                }
                //slither-disable-end calls-loop

                calculators.push(calculator);
            }
        }
    }
}
