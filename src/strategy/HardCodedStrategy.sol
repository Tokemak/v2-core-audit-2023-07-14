// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import { Ownable2Step } from "src/access/Ownable2Step.sol";
import { IStrategy } from "src/interfaces/strategy/IStrategy.sol";
import { BaseStrategy } from "./BaseStrategy.sol";

contract HardCodedStrategy is BaseStrategy {
    constructor(address[] memory _destinations) BaseStrategy(_destinations) { }

    function setPercentages(uint32[] memory percentages) external onlyOwner {
        _setPercentages(percentages);
    }
}
