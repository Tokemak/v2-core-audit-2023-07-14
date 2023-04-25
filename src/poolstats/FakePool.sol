// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import { Stats } from "./PoolStats.sol";

library FakePool {
    function getStats() public view returns (Stats.PoolStats memory) {
        return Stats.PoolStats({
            baseApr: 100,
            feeApr: 1,
            incentiveApr: 1000,
            marketPriceTvl: 1000,
            underlyingPriceTvl: 1010,
            lpTokenTotalSupply: 990,
            timestamp: 1_682_451_824
        });
    }
}
