// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.17;

import { IDestinationRegistry } from "../interfaces/destinations/IDestinationRegistry.sol";
import { IDestinationAdapter } from "../interfaces/destinations/IDestinationAdapter.sol";

contract DestinationRegistry is IDestinationRegistry {
    mapping(DestinationType => IDestinationAdapter) private destinations;

    // TODO: access control
    function register(DestinationType destination, address target) public override {
        if (target == address(0)) {
            revert("target cannot be 0 address");
        }
        destinations[destination] = IDestinationAdapter(target);

        emit Register(destination, target);
    }

    function unregister(DestinationType destination) public override {
        IDestinationAdapter target = destinations[destination];
        if (address(target) == address(0)) {
            revert("destination is not present");
        }
        delete destinations[destination];

        emit Unregister(destination, address(target));
    }

    function getAdapter(DestinationType destination) public view override returns (IDestinationAdapter target) {
        target = destinations[destination];
        if (address(target) == address(0)) {
            revert("destination is not present");
        }
    }
}
