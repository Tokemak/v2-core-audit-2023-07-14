// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2023 Tokemak Foundation. All rights reserved.
pragma solidity 0.8.17;

import { IDestinationVault } from "src/interfaces/vault/IDestinationVault.sol";
import { Errors } from "src/utils/Errors.sol";
import { IStrategy } from "src/interfaces/strategy/IStrategy.sol";

library LMPStrategy {
    /// @notice verify that a rebalance (swap between destinations) meets all the strategy constraints
    /// @dev Signature identical to IStrategy.verifyRebalance
    function verifyRebalance(IStrategy.RebalanceParams memory)
        internal
        pure
        returns (bool success, string memory message)
    {
        // short-circuit for now
        // TODO: proper checks
        return (true, "");
    }
}
