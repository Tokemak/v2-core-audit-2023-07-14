// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

interface IStrategy {
    event PercentagesSet(uint32[] percentages);
    event DestinationsSet(address[] destinations);

    /**
     * @notice Get destinations addresses.
     * @return list of destinations addresses.
     */
    function getDestinations() external view returns (address[] memory);

    /**
     * @notice Get percentages values for the destinations.
     * @return list of percentage. Order of elements in it matches that of the destinations array.
     */
    function getPercentages() external view returns (uint32[] memory);
}
