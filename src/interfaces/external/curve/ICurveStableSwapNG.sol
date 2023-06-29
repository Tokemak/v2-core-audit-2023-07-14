// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

// solhint-disable func-name-mixedcase

/// @notice Interface for next generation Curve pool oracle functionality.
interface ICurveStableSwapNG {
    /// @notice Returns current price in pool.
    function price_oracle() external view returns (uint256);
}
