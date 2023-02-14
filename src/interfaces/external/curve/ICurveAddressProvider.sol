// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

// solhint-disable func-name-mixedcase

interface ICurveAddressProvider {
    /**
     * @notice returns address of main registry contract, which stores stableswap, metapool and lending addresses
     */
    function get_registry() external view returns (address);

    /**
     * @notice Returns address associated with Id.
     * @param id Id associated with address.  More info here:
     * https://curve.readthedocs.io/registry-address-provider.html#address-ids
     */
    function get_address(uint256 id) external view returns (address);
}
