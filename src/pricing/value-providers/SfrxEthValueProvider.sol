// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import { ISfrxEth } from "src/interfaces/external/frax/ISfrxEth.sol";
import { BaseValueProvider } from "src/pricing/value-providers/base/BaseValueProvider.sol";
import { Errors } from "src/utils/Errors.sol";

/**
 * @title Gets price of sfrxEth in frxEth on mainnet.
 * @dev Only works on mainnet, sfrxEth uses a different contract on other chains that does not include
 *      the `pricePerShare()` function used here or another function.  There is also no current
 *      oracle feed for sfrxEth on any chain.
 * @dev Returns price in 18 decimals of precision.
 */
contract SfrxEthValueProvider is BaseValueProvider {
    ISfrxEth public immutable sfrxEth;

    /// @notice Emitted when sfrxEth address set.
    event SfrxEthSet(address sfrxEth);

    constructor(address _sfrxEth, address _ethValueOracle) BaseValueProvider(_ethValueOracle) {
        Errors.verifyNotZero(_sfrxEth, "sfrxEthOracle");
        sfrxEth = ISfrxEth(_sfrxEth);

        emit SfrxEthSet(_sfrxEth);
    }

    function getPrice(address) external view override onlyValueOracle returns (uint256) {
        return sfrxEth.pricePerShare();
    }
}
