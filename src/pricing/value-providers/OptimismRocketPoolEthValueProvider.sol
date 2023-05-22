// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import { BaseValueProvider } from "src/pricing/value-providers/base/BaseValueProvider.sol";
import { IRocketOvmPriceOracle } from "src/interfaces/external/rocket-pool/IRocketOvmPriceOracle.sol";
import { Errors } from "src/utils/Errors.sol";

/**
 * @title Returns rEth price in Eth on Optimism
 * @dev rEth does not have a Chainlink price feed on Optimism.
 * @dev Returns price in 18 decimals of precision.
 */
contract OptimismRocketPoolEthValueProvider is BaseValueProvider {
    IRocketOvmPriceOracle public immutable rocketOvmOracle;

    event RocketOvmOracleSet(address rocketOvmOracle);

    constructor(address _rocketOvmOracle, address _ethValueOracle) BaseValueProvider(_ethValueOracle) {
        Errors.verifyNotZero(_rocketOvmOracle, "rocketOracle");
        rocketOvmOracle = IRocketOvmPriceOracle(_rocketOvmOracle);

        emit RocketOvmOracleSet(_rocketOvmOracle);
    }

    function getPrice(address) external view override onlyValueOracle returns (uint256) {
        return rocketOvmOracle.rate();
    }
}
