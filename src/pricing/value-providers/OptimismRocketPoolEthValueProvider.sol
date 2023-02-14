// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import { BaseValueProvider } from "./base/BaseValueProvider.sol";
import { IRocketOvmPriceOracle } from "../../interfaces/external/rocket-pool/IRocketOvmPriceOracle.sol";

/**
 * @title Returns rEth price in Eth on Optimism
 * @dev rEth does not have a Chainlink price feed on Optimism.
 * @dev Returns price in 18 decimals of precision.
 */
contract OptimismRocketPoolEthValueProvider is BaseValueProvider {
    IRocketOvmPriceOracle public immutable rocketOvmOracle;

    event RocketOvmOracleSet(address rocketOvmOracle);

    constructor(address _rocketOvmOracle, address _ethValueOracle) BaseValueProvider(_ethValueOracle) {
        if (_rocketOvmOracle == address(0)) revert CannotBeZeroAddress();
        rocketOvmOracle = IRocketOvmPriceOracle(_rocketOvmOracle);

        emit RocketOvmOracleSet(_rocketOvmOracle);
    }

    function getPrice(address) external view override onlyValueOracle returns (uint256) {
        return rocketOvmOracle.rate();
    }
}
