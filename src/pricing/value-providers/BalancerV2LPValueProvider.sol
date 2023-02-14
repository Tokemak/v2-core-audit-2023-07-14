// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import { BaseValueProviderBalancerLP } from "./base/BaseValueProviderBalancerLP.sol";

/**
 * @title Gets the value in Eth of BPT tokens.
 * @dev Value returned has 18 decimals of precision.
 */
contract BalancerV2LPValueProvider is BaseValueProviderBalancerLP {
    constructor(
        address _balancerVault,
        address _ethValueOracle
    ) BaseValueProviderBalancerLP(_balancerVault, _ethValueOracle) { }

    function getPrice(address tokenToPrice) external view override onlyValueOracle returns (uint256) {
        return _getPriceBalancerPool(tokenToPrice);
    }
}
