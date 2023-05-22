// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import { BaseValueProviderBalancerLP } from "src/pricing/value-providers/base/BaseValueProviderBalancerLP.sol";

/**
 * @title Gets the value in Eth of BeethovenX LP tokens.
 * @notice Contract has exact same functionality as BalancerV2LPProvider.sol.
 * @dev Returns values in 18 decimals of precision.
 */
contract BeethovenXValueProvider is BaseValueProviderBalancerLP {
    constructor(
        address _balancerVault,
        address _ethValueOracle
    ) BaseValueProviderBalancerLP(_balancerVault, _ethValueOracle) { }

    function getPrice(address tokenToPrice) external view override onlyValueOracle returns (uint256) {
        return _getPriceBalancerPool(tokenToPrice);
    }
}
