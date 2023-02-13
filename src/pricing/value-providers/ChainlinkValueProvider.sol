// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "../../interfaces/pricing/IBaseValueProvider.sol";

import "../../interfaces/external/IChainlinkFeedRegistry.sol";

contract ChainlinkValueProvider is IBaseValueProvider {
    IChainlinkFeedRegistry public immutable registry;

    error RegsitryAddressZero();

    constructor(address _registry) {
        if (_registry == address(0)) {
            revert RegsitryAddressZero();
        }
        registry = IChainlinkFeedRegistry(_registry);
    }

    function getPrice(address token) external { }
}
