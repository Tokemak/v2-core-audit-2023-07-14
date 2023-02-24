// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "../access/Ownable2Step.sol";
import "./IStrategy.sol";
import "./BaseStrategy.sol";

contract MaxiStrategy is BaseStrategy {
    constructor(address[] memory _destinations) BaseStrategy(_destinations) { }

    function calculatePercentagesFromAPR() external {
        // address[] memory _destinations = destinations;
        // get APRS
        // create percentages
        // set percentages
    }
}
