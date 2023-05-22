// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import { Denominations } from "src/pricing/library/Denominations.sol";
import { BaseValueProvider } from "src/pricing/value-providers/base/BaseValueProvider.sol";
import { TokemakPricingPrecision } from "src/pricing/library/TokemakPricingPrecision.sol";
import { Denominations } from "src/pricing/library/Denominations.sol";
import { Errors } from "src/utils/Errors.sol";

import { IWstEth } from "src/interfaces/external/wsteth/IWstEth.sol";

contract WstEthValueProvider is BaseValueProvider {
    IWstEth public immutable wstEth;

    /// @notice Thrown if wstEth contract does not return 18 decimals.
    error IncorrectDecimals();

    /// @notice Emitted when wstEth contract address set.
    event WstEthSet(address wstEth);

    constructor(address _wstEth, address _ethValueOracle) BaseValueProvider(_ethValueOracle) {
        Errors.verifyNotZero(_wstEth, "wstEthOracle");
        if (TokemakPricingPrecision.getDecimals(_wstEth) != 18) revert IncorrectDecimals();
        wstEth = IWstEth(_wstEth);

        emit WstEthSet(_wstEth);
    }

    function getPrice(address) external view override onlyValueOracle returns (uint256) {
        /**
         * Remove precision as both prices are to 18 decimals of precision.  wstEth is always priced in stEth
         *    when using the `tokensPerStEth()` function.
         */
        return TokemakPricingPrecision.removePrecision(
            ethValueOracle.getPrice(Denominations.STETH_MAINNET, TokemakPricingPrecision.STANDARD_PRECISION, true)
                * wstEth.tokensPerStEth()
        );
    }
}
