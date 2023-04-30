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

    /**
     * @notice Get breakdown of the deposit by vault and corresponding amount
     * @return destinationVaults List of destionation vaults to spread the deposit in
     * @return amounts List of amounts to deposit in each vault
     */
    function getDepositBreakup(uint256 forAmount)
        external
        returns (address[] memory destinationVaults, uint256[] memory amounts);
}
