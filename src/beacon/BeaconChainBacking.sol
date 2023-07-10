// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2023 Tokemak Foundation. All rights reserved.
pragma solidity 0.8.17;

import { IERC20Metadata } from "openzeppelin-contracts/token/ERC20/extensions/IERC20Metadata.sol";

import { IBeaconChainBacking } from "src/interfaces/beacon/IBeaconChainBacking.sol";
import { ISystemRegistry } from "src/interfaces/ISystemRegistry.sol";
import { SecurityBase } from "src/security/SecurityBase.sol";
import { SystemComponent } from "src/SystemComponent.sol";
import { Errors } from "src/utils/Errors.sol";
import { Roles } from "src/libs/Roles.sol";

contract BeaconChainBacking is SystemComponent, SecurityBase, IBeaconChainBacking {
    address public immutable token;
    uint256 public immutable decimalPad;

    Ratio public currentRatio;

    struct Ratio {
        uint256 ratio;
        uint256 timestamp;
    }

    constructor(
        ISystemRegistry _systemRegistry,
        address _token
    ) SystemComponent(_systemRegistry) SecurityBase(address(_systemRegistry.accessController())) {
        Errors.verifyNotZero(_token, "_token");
        // slither-disable-next-line missing-zero-check
        token = _token;
        decimalPad = 10 ** IERC20Metadata(token).decimals();
    }

    /// @inheritdoc IBeaconChainBacking
    function update(
        uint256 totalAssets,
        uint256 totalLiabilities,
        uint256 queriedTimestamp
    ) public hasRole(Roles.LSD_BACKING_UPDATER) {
        if (totalAssets > type(uint208).max) {
            revert Errors.InvalidParam("totalAssets");
        }
        if (totalLiabilities > type(uint208).max) {
            revert Errors.InvalidParam("totalLiabilities");
        }
        if (queriedTimestamp > type(uint48).max) {
            revert Errors.InvalidParam("queriedTimestamp");
        }
        uint256 ratio = totalAssets * decimalPad / totalLiabilities;
        currentRatio = Ratio(ratio, queriedTimestamp);
    }

    /// @inheritdoc IBeaconChainBacking
    function current() public view returns (uint256 ratio, uint256 queriedTimestamp) {
        ratio = currentRatio.ratio;
        queriedTimestamp = currentRatio.timestamp;
    }
}
