// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

contract Bytes32 {
    /**
     * @notice Converts a bytes32 value to a uint256 value.
     * @param val The bytes32 value to be converted.
     * @return The converted uint256 value.
     */
    function toUint256(bytes32 val) public pure returns (uint256) {
        return uint256(val);
    }
}
