// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import { BaseValueProvider } from "./base/BaseValueProvider.sol";

// TODO: Finish - backlog
contract TokemakPlasmaPoolValueProvider is BaseValueProvider {
    constructor(address _ethValueOracle) BaseValueProvider(_ethValueOracle) { }

    function getPrice(address plasmaPoolLpToPrice) external view override onlyValueOracle returns (uint256 price) { }
}
