// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import { IPair } from "src/interfaces/external/velodrome/IPair.sol";

import { BaseValueProviderUniV2LP } from "src/pricing/value-providers/base/BaseValueProviderUniV2LP.sol";

/**
 * @title Gets value of Velodrome LP tokens.
 * @dev Returns 18 decimals of precision.
 */
contract VelodromeValueProvider is BaseValueProviderUniV2LP {
    constructor(address _ethValueOracle) BaseValueProviderUniV2LP(_ethValueOracle) { }

    function getPrice(address velodromeLpTokenAddress) external view override onlyValueOracle returns (uint256) {
        // Partial return values are intentionally ignored. This call provides the most efficient way to obtain the
        // data.
        // slither-disable-next-line unused-return
        (uint256 reserve0, uint256 reserve1,) = IPair(velodromeLpTokenAddress).getReserves();
        return _getPriceUniV2Contract(velodromeLpTokenAddress, reserve0, reserve1);
    }
}
