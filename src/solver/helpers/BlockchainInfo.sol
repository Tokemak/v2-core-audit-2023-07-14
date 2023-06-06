// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

/**
 * @dev A contract to retrieve basic blockchain information
 */
contract BlockchainInfo {
    /**
     * @notice Get the current block number
     * @return The current block number
     */
    function getCurrentBlockNumber() public view returns (uint256) {
        return block.number;
    }

    /**
     * @notice Get the current block timestamp
     * @return The current block timestamp in seconds since Unix epoch
     */
    function getCurrentBlockTimestamp() public view returns (uint256) {
        // solhint-disable-next-line not-rely-on-time
        return block.timestamp;
    }

    /**
     * @notice Get the current block gas limit
     * @return The current block gas limit
     */
    function getCurrentBlockGasLimit() public view returns (uint256) {
        return block.gaslimit;
    }
}
