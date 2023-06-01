// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2023 Tokemak Foundation. All rights reserved.

pragma solidity 0.8.17;

import { ISystemBound } from "src/interfaces/ISystemBound.sol";

interface IRootPriceOracle is ISystemBound {
    function getPriceInEth(address token) external returns (uint256);
}
