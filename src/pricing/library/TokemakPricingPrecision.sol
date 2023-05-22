// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import { Denominations } from "src/pricing/library/Denominations.sol";

import { IERC20Metadata } from "openzeppelin-contracts/token/ERC20/extensions/IERC20Metadata.sol";

library TokemakPricingPrecision {
    uint256 public constant STANDARD_PRECISION = 1e18;
    uint256 public constant STANDARD_DECIMALS = 18;

    /// @notice Increases precision on value by 1e18
    function increasePrecision(uint256 value) external pure returns (uint256) {
        return value * STANDARD_PRECISION;
    }

    /// @notice Removes 1e18 precision.
    function removePrecision(uint256 value) external pure returns (uint256) {
        return value / STANDARD_PRECISION;
    }

    /// @notice Checks tokens decimals and modifies value if needed.
    function checkAndNormalizeDecimals(uint256 decimals, uint256 value) external pure returns (uint256) {
        if (decimals == STANDARD_DECIMALS) {
            return value;
        } else {
            uint256 decimalsToIncreaseBy = STANDARD_DECIMALS - decimals;
            return value * (10 ** decimalsToIncreaseBy);
        }
    }

    /// @notice Gets decimal precision on IERC20 adherent token.
    function getDecimals(address token) external view returns (uint256) {
        // Takes care of Eth edge case.
        if (token == Denominations.ETH) return 18;
        return IERC20Metadata(token).decimals();
    }
}
