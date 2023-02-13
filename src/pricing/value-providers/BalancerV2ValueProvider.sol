// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "../../interfaces/pricing/IBaseValueProvider.sol";

contract BalancerV2ValueProvider is IBaseValueProvider {
    function getPrice(address balancerPoolToken) external { }
}
