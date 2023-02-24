// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import { HardCodedStrategy } from "./HardCodedStrategy.sol";

contract StrategyFactory {
    function createStrategy(address[] memory destinations) public returns (address) {
        return address(new HardCodedStrategy(destinations));
    }
}
