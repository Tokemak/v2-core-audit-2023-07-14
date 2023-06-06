// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

contract ArraysConverter {
    /**
     * @notice Converts two uint256 values into a uint256 array
     * @param a The first uint256 value
     * @param b The second uint256 value
     * @return values The array containing the two uint256 inputs
     */
    function toUint256Array(uint256 a, uint256 b) public pure returns (uint256[] memory) {
        uint256[] memory values = new uint256[](2);
        values[0] = a;
        values[1] = b;
        return values;
    }
}
