// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "./IBaseValueProvider.sol";

contract ChainlinkValueProvider is IBaseValueProvider {
    function getPrice(address token) external { }
}
