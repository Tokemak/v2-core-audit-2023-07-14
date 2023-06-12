// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import { Stats } from "src/stats/Stats.sol";
import { ISystemRegistry } from "src/interfaces/ISystemRegistry.sol";

interface IStakedTokenV1 {
    function exchangeRate() external view returns (uint256 _exchangeRate);
}
