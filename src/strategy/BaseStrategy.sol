// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "../access/Ownable2Step.sol";
import "./IStrategy.sol";

contract BaseStrategy is IStrategy, Ownable2Step {
    uint32 public constant MAX_PERCENTAGE = 100_000;

    address[] public destinations;

    uint256 public packedPercentages;
    uint256 public packedPercentages2;

    error LenghtstMismatch(uint256 length1, uint256 length2);
    error PercentageInvalid(uint256 totalPercentage);
    error TooManyDestinations(uint256 destinationsLength);

    constructor(address[] memory _destinations) {
        if (_destinations.length > 16) {
            revert TooManyDestinations(_destinations.length);
        }
        destinations = _destinations;
    }

    /// @inheritdoc IStrategy
    function getDestinations() public view returns (address[] memory) {
        return destinations;
    }

    /// @inheritdoc IStrategy
    function getPercentages() public view returns (uint32[] memory) {
        return _getPercentages();
    }

    /**
     * @notice Get index by address.
     * @param destination destination address.
     */
    function getDestinationIndex(address destination) public view returns (uint256) {
        uint256 length = destinations.length;
        for (uint256 i = 0; i < length;) {
            if (destinations[i] == destination) {
                return i;
            }
            unchecked {
                ++i;
            }
        }
        revert("Destination not found.");
    }

    /**
     * @notice Store and set percentages addresses as a packed Uint256 value
     * @param percentages list of percentages for destinations.
     */
    function _setPercentages(uint32[] memory percentages) internal {
        uint256 length = percentages.length;
        if (length != destinations.length) {
            revert LenghtstMismatch(length, destinations.length);
        }
        uint256 pack = 0;
        uint256 pack2 = 0;
        uint256 total = 0;

        for (uint256 i = 0; i < length;) {
            total += percentages[i];
            if (total > MAX_PERCENTAGE) {
                revert PercentageInvalid(total);
            }

            if (i < 8) {
                pack |= uint256(percentages[i]) << (i * 32);
            } else {
                pack2 |= uint256(percentages[i]) << ((i - 8) * 32);
            }
            unchecked {
                ++i;
            }
        }

        packedPercentages = pack;
        packedPercentages2 = pack2;

        emit PercentagesSet(percentages);
    }

    /**
     * @notice Unpacked percentages from Uint256 values and return as array
     * @return list of percentages for destinations.
     */
    function _getPercentages() internal view returns (uint32[] memory) {
        uint256 length = destinations.length;
        uint32[] memory percentages = new uint32[](length);
        uint256 pack = packedPercentages;
        uint256 pack2 = packedPercentages2;

        uint256 i = 0;
        do {
            if (i < 8) {
                percentages[i] = uint32(pack >> (i * 32));
            } else {
                percentages[i] = uint32(pack2 >> ((i - 8) * 32));
            }
            unchecked {
                ++i;
            }
        } while (i < length);

        return percentages;
    }
}
