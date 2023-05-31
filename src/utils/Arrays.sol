// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2023 Tokemak Foundation. All rights reserved.

pragma solidity 0.8.17;

library Arrays {
    /// @notice Convert Curve token and array data into a dynamic array
    /// @param tokens fixed 8 item array from Curve
    /// @param numTokens number of reported actual tokens from Curve
    /// @return dynTokens array of token data with numToken number of items
    function convertFixedCurveTokenArrayToDynamic(
        address[8] memory tokens,
        uint256 numTokens
    ) external pure returns (address[] memory dynTokens) {
        dynTokens = new address[](numTokens);
        for (uint256 i = 0; i < numTokens;) {
            dynTokens[i] = tokens[i];

            unchecked {
                ++i;
            }
        }
    }
}
