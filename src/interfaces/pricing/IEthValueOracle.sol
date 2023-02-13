// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

// solhint-disable-next-line no-empty-blocks
interface IEthValueOracle {
    /**
     * @notice Allows privledged address to add value providers.
     * @param provider Address of provider to be added.
     */
    function addProvider(address provider) external;
}
