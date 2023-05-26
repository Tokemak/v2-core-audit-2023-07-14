// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

library Stats {
    /// TODO: Pick proper data types
    struct CalculatedStats {
        uint256 baseApr;
        uint256 tradingFeeApr;
        uint256 incentiveApr;
        uint256 incentiveDuration;
        uint256 discount;
        uint256 tokemakIncentiveApr;
    }

    /// @dev When registering dependent calculators, use this value for tokens/pools/etc that should be ignored
    bytes32 public constant NOOP_APR_ID = keccak256(abi.encode("NOOP_APR_ID"));

    error CalculatorAssetMismatch(bytes32 aprId, address calculator, address coin);

    /// @notice Generate an id for a stat calc representing a base ERC20
    /// @dev For rETH/stETH/cbETH etc. Do not use for pools, LP tokens, staking platforms.
    /// @param tokenAddress address of the token
    function generateRawTokenIdentifier(address tokenAddress) external pure returns (bytes32) {
        return keccak256(abi.encode("erc20", tokenAddress));
    }

    /// @notice Add together and return all values from the given stats
    /// @param first first set of stats
    /// @param first second set of stats
    /// @return combined stats with all values added together
    function combineStats(
        CalculatedStats memory first,
        CalculatedStats memory second
    ) external pure returns (CalculatedStats memory combined) {
        combined.baseApr = first.baseApr + second.baseApr;
        combined.tradingFeeApr = first.tradingFeeApr + second.tradingFeeApr;
        combined.incentiveApr = first.incentiveApr + second.incentiveApr;
        combined.incentiveDuration = first.incentiveDuration + second.incentiveDuration;
        combined.discount = first.discount + second.discount;
        combined.tokemakIncentiveApr = first.tokemakIncentiveApr + second.tokemakIncentiveApr;
    }
}
