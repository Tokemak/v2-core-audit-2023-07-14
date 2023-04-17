// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import { Stats } from "./PoolStats.sol";

library FakePool {
    function getStats() public view returns (Stats.PoolStats memory) {
        return Stats.PoolStats({baseApr: 1});
    }
}
