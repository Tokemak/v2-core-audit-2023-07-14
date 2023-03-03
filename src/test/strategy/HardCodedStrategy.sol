// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "forge-std/Test.sol";

import { HardCodedStrategy } from "../../strategy/HardCodedStrategy.sol";
import { BaseStrategy } from "../../strategy/BaseStrategy.sol";
import { PRANK_ADDRESS } from "../utils/Addresses.sol";

contract HardCodedStrategyTest is Test {
    HardCodedStrategy private strategy;
    address[] private destinations;
    uint32[] private percentages;

    uint256 private constant MAX_DESTINATIONS = 16;

    function setUp() public {
        initDestinations(MAX_DESTINATIONS);
        strategy = new HardCodedStrategy(destinations);
    }

    function testConstructorRevertsWithLengthsMismatch() public {
        uint256 destinationCount = MAX_DESTINATIONS + 1;
        initDestinations(MAX_DESTINATIONS + 1);
        vm.expectRevert(abi.encodeWithSelector(BaseStrategy.TooManyDestinations.selector, destinationCount));
        strategy = new HardCodedStrategy(destinations);
    }

    function testSetPercentagesRevertsWithLengthsMismatch() public {
        initPercentages(MAX_DESTINATIONS - 1);
        vm.expectRevert(abi.encodeWithSelector(BaseStrategy.LenghtstMismatch.selector, 15, 16));
        strategy.setPercentages(percentages);
    }

    function testSetPercentagesRevertsWithInvalidPercentage() public {
        initPercentages(MAX_DESTINATIONS);
        percentages[5] = 100_001;
        vm.expectRevert(abi.encodeWithSelector(BaseStrategy.PercentageInvalid.selector, 100_011));
        strategy.setPercentages(percentages);
    }

    function testSetPercentagesRevertsWithNotOwner() public {
        initPercentages(MAX_DESTINATIONS);

        vm.prank(PRANK_ADDRESS);
        vm.expectRevert(bytes("Ownable: caller is not the owner"));
        strategy.setPercentages(percentages);
    }

    function testSetPercentages() public {
        initPercentages(MAX_DESTINATIONS);

        strategy.setPercentages(percentages);

        uint32[] memory result = strategy.getPercentages();
        for (uint256 i = 0; i < result.length; i++) {
            assertEq(result[i], percentages[i]);
        }

        uint256 testIndex = 5;
        address destination = destinations[5];
        uint256 index = strategy.getDestinationIndex(destination);

        assertEq(index, testIndex);
    }

    function initPercentages(uint256 count) private {
        percentages = new uint32[](count);
        for (uint256 i = 0; i < count; i++) {
            percentages[i] = uint32(i);
        }
    }

    function initDestinations(uint256 count) private {
        destinations = new address[](count);
        for (uint256 i = 0; i < count; i++) {
            destinations[i] = address(uint160(uint256(keccak256(abi.encodePacked(i)))));
        }
    }
}
