// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2023 Tokemak Foundation. All rights reserved.

pragma solidity 0.8.17;

import { IPool } from "src/interfaces/external/maverick/IPool.sol";
import { IPoolPositionDynamicSlim } from "src/interfaces/external/maverick/IPoolPositionDynamicSlim.sol";
import { Errors } from "src/utils/Errors.sol";
import { IPriceOracle } from "src/interfaces/oracles/IPriceOracle.sol";
import { IRootPriceOracle } from "src/interfaces/oracles/IRootPriceOracle.sol";
import { ISystemRegistry } from "src/interfaces/ISystemRegistry.sol";
import { SecurityBase } from "src/security/SecurityBase.sol";

contract MavEthOracle is IPriceOracle, SecurityBase {
    /// @notice Emitted when new maximum bin width is set.
    event MaxTotalBinWidthSet(uint256 newMaxBinWidth);

    /// @notice Thrown when the total width of all bins being priced exceeds the max.
    error TotalBinWidthExceedsMax();

    ISystemRegistry public immutable systemRegistry;
    // 100 = 1% spacing, 10 = .1% spacing, 1 = .01% spacing etc.
    uint256 public maxTotalBinWidth = 50;

    constructor(ISystemRegistry _systemRegistry) SecurityBase(address(_systemRegistry.accessController())) {
        Errors.verifyNotZero(address(_systemRegistry), "_systemRegistry");
        Errors.verifyNotZero(address(_systemRegistry.rootPriceOracle()), "priceOracle");

        systemRegistry = _systemRegistry;
    }

    /**
     * @notice Gives ability to set total bin width to system owner.
     * @param _maxTotalBinWidth New max bin width.
     */
    function setMaxTotalBinWidth(uint256 _maxTotalBinWidth) external onlyOwner {
        Errors.verifyNotZero(_maxTotalBinWidth, "_maxTotalbinWidth");
        maxTotalBinWidth = _maxTotalBinWidth;

        emit MaxTotalBinWidthSet(_maxTotalBinWidth);
    }

    /// @inheritdoc IPriceOracle
    function getPriceInEth(address _boostedPosition) external returns (uint256) {
        // slither-disable-start similar-names
        Errors.verifyNotZero(_boostedPosition, "_boostedPosition");

        IPoolPositionDynamicSlim boostedPosition = IPoolPositionDynamicSlim(_boostedPosition);
        IPool pool = IPool(boostedPosition.pool());

        Errors.verifyNotZero(address(pool), "pool");

        // Check that total width of all bins in position does not exceed what we deem safe.
        if (pool.tickSpacing() * boostedPosition.allBinIds().length > maxTotalBinWidth) {
            revert TotalBinWidthExceedsMax();
        }

        // Get reserves in boosted position.
        (uint256 reserveTokenA, uint256 reserveTokenB) = boostedPosition.getReserves();

        // Get total supply of lp tokens from boosted position.
        uint256 boostedPositionTotalSupply = boostedPosition.totalSupply();

        IRootPriceOracle rootPriceOracle = systemRegistry.rootPriceOracle();

        // Price pool tokens.
        uint256 priceInEthTokenA = rootPriceOracle.getPriceInEth(address(pool.tokenA()));
        uint256 priceInEthTokenB = rootPriceOracle.getPriceInEth(address(pool.tokenB()));

        // Calculate total value of each token in boosted position.
        uint256 totalBoostedPositionValueTokenA = reserveTokenA * priceInEthTokenA;
        uint256 totalBoostedPositionValueTokenB = reserveTokenB * priceInEthTokenB;

        // Return price of lp token in boosted position.
        return (totalBoostedPositionValueTokenA + totalBoostedPositionValueTokenB) / boostedPositionTotalSupply;
        // slither-disable-end similar-names
    }

    function getSystemRegistry() external view returns (address) {
        return address(systemRegistry);
    }
}
