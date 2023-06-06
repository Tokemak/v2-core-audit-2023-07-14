// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

contract Integer {
    /**
     * @notice NotLessThan error is emitted when a >= b.
     * @param a The first unsigned integer.
     * @param b The second unsigned integer.
     */
    error NotLessThan(uint256 a, uint256 b);

    /**
     * @notice Checks if a given unsigned integer 'a' is greater than another unsigned integer 'b'.
     * @param a The first unsigned integer.
     * @param b The second unsigned integer.
     */
    function isGte(uint256 a, uint256 b) public pure {
        if (a < b) {
            revert NotLessThan(a, b);
        }
    }

    /**
     * @notice Adds two unsigned integers and returns the result.
     * @param a The first unsigned integer.
     * @param b The second unsigned integer.
     * @return The sum of a and b.
     */
    function add(uint256 a, uint256 b) public pure returns (uint256) {
        return a + b;
    }
}
