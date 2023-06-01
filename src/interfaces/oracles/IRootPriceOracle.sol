// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2023 Tokemak Foundation. All rights reserved.

pragma solidity 0.8.17;

import { ISystemBound } from "src/interfaces/ISystemBound.sol";

/// @notice Retrieve a price for any token used in the system
interface IRootPriceOracle is ISystemBound {
    /// @notice Returns a fair price for the provided token in ETH
    /// @param token token to get the price of
    /// @return price the price of the token in ETH
    function getPriceInEth(address token) external returns (uint256 price);
}
