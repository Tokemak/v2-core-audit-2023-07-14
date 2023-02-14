// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import { Denominations } from "../library/Denominations.sol";
import { BaseValueProvider } from "./base/BaseValueProvider.sol";
import { TokemakPricingPrecision } from "../library/TokemakPricingPrecision.sol";
import { Denominations } from "../library/Denominations.sol";

import { IWstEth } from "../../interfaces/external/wsteth/IWstEth.sol";

contract WstEthValueProvider is BaseValueProvider {
    IWstEth public immutable wstEth;

    event WstEthSet(address wstEth);

    constructor(address _wstEth, address _ethValueOracle) BaseValueProvider(_ethValueOracle) {
        if (_wstEth == address(0)) revert CannotBeZeroAddress();
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
