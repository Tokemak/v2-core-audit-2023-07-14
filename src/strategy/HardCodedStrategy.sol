// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "../access/Ownable2Step.sol";
import "./IStrategy.sol";
import "./BaseStrategy.sol";

contract HardCodedStrategy is BaseStrategy {
    constructor(address[] memory _destinations) BaseStrategy(_destinations) { }

    function setPercentages(uint32[] memory percentages) external onlyOwner {
        _setPercentages(percentages);
    }
}
