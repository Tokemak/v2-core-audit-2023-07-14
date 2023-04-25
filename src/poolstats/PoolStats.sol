// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

library Stats {
    struct PoolStats {
        uint32 baseApr;
        uint32 feeApr;
        uint32 incentiveApr;
        uint32 marketPriceTvl;
        uint32 underlyingPriceTvl;
        uint32 lpTokenTotalSupply;
        uint32 timestamp;
    }
}
