// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2023 Tokemak Foundation. All rights reserved.
pragma solidity 0.8.17;

import { IDestinationVault } from "src/interfaces/vault/IDestinationVault.sol";
import { Errors } from "src/utils/Errors.sol";

library LMPStrategy {
    /// @notice verify that a rebalance (swap between destinations) meets all the strategy constraints
    /// @dev Signature identical to IStrategy.verifyRebalance
    /// @param destinationIn The address of the destination vault that will increase
    /// @param tokenIn The address of the token that will be provided by the swapper
    /// @param amountIn The amount of the tokenIn that will be provided by the swapper
    /// @param destinationOut The address of the destination vault that will decrease
    /// @param tokenOut The address of the token that will be received by the swapper
    /// @param amountOut The amount of the tokenOut that will be received by the swapper

    function verifyRebalance(
        address destinationIn,
        address tokenIn,
        uint256 amountIn,
        address destinationOut,
        address tokenOut,
        uint256 amountOut
    ) internal view returns (bool success, string memory message) {
        // TODO: remove: setting dummy vars to avoid "unused parameter" warnings for now
        destinationIn = tokenIn = destinationOut = tokenOut = address(0);
        amountIn = amountOut = 0;
        // short-circuit for now
        // TODO: proper checks
        return (true, "");
    }
}
