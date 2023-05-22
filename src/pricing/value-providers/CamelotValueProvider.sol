// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import { ICamelotPair } from "src/interfaces/external/camelot/ICamelotPair.sol";

import { BaseValueProviderUniV2LP } from "src/pricing/value-providers/base/BaseValueProviderUniV2LP.sol";

/**
 * @title Gets value of Camelot LP tokens.
 * @dev Returns 18 decimals of precision.
 */
contract CamelotValueProvider is BaseValueProviderUniV2LP {
    constructor(address _ethValueOracle) BaseValueProviderUniV2LP(_ethValueOracle) { }

    function getPrice(address camelotLpTokenAddress) external view override onlyValueOracle returns (uint256) {
        (uint112 reserve0, uint112 reserve1,,) = ICamelotPair(camelotLpTokenAddress).getReserves();
        return _getPriceUniV2Contract(camelotLpTokenAddress, reserve0, reserve1);
    }
}
