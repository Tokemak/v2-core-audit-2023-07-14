// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

// solhint-disable func-name-mixedcase, var-name-mixedcase

/**
 * @notice Curve factory for V2 contracts.
 */
interface ICurveFactoryV2 {
    /// @notice Gets coin addresses for pool deployed by factory.
    function get_coins(address pool) external view returns (address[2] memory);

    /// @notice Gets balances of coins for pool deployed by factory.
    function get_balances(address pool) external view returns (uint256[2] memory);
}
