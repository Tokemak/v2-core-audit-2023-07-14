// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.17;

import { IDestinationRegistry } from "../interfaces/destinations/IDestinationRegistry.sol";
import { IDestinationAdapter } from "../interfaces/destinations/IDestinationAdapter.sol";

// TODO: access control
contract DestinationRegistry is IDestinationRegistry {
    mapping(DestinationType => IDestinationAdapter) private destinations;

    function register(DestinationType destination, address target) public override {
        if (target == address(0)) {
            revert("target cannot be 0 address");
        }
        if (address(destinations[destination]) != address(0)) {
            revert("destination is already set");
        }
        destinations[destination] = IDestinationAdapter(target);

        emit Register(destination, target);
    }

    function replace(DestinationType destination, address target) public override {
        if (target == address(0)) {
            revert("target cannot be 0 address");
        }
        IDestinationAdapter existingDestination = destinations[destination];
        if (address(existingDestination) == address(0)) {
            revert("destination is not present");
        }
        destinations[destination] = IDestinationAdapter(target);

        emit Replace(destination, target);
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
