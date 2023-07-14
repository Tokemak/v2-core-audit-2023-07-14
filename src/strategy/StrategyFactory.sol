// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2023 Tokemak Foundation. All rights reserved.

pragma solidity 0.8.17;

/* solhint-disable no-unused-vars */
/* solhint-disable state-mutability */

contract StrategyFactory {
    // solhint-disable-next-line no-unused-vars
    function createStrategy(address[] memory) public pure returns (address) {
        // NOTE: shortcircuited just as a place holder for now
        return address(1);
    }
}
