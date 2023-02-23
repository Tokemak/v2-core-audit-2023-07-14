// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.17;

import "openzeppelin-contracts/access/AccessControl.sol";

import { IDestinationRegistry } from "../interfaces/destinations/IDestinationRegistry.sol";
import { IDestinationAdapter } from "../interfaces/destinations/IDestinationAdapter.sol";

contract DestinationRegistry is IDestinationRegistry, AccessControl {
    mapping(DestinationType => IDestinationAdapter) private destinations;

    error ZeroAddress(string param);
    error DestinationAlreadySet();
    error DestinationNotPresent();

    function register(DestinationType destination, address target) public override {
        if (target == address(0)) {
            revert ZeroAddress("target");
        }
        if (address(destinations[destination]) != address(0)) {
            revert DestinationAlreadySet();
        }
        destinations[destination] = IDestinationAdapter(target);

        emit Register(destination, target);
    }

    function replace(DestinationType destination, address target) public override {
        if (target == address(0)) revert ZeroAddress("target");

        IDestinationAdapter existingDestination = destinations[destination];
        if (address(existingDestination) == address(0)) {
            revert DestinationNotPresent();
        }
        if (address(destinations[destination]) == target) {
            revert DestinationAlreadySet();
        }
        destinations[destination] = IDestinationAdapter(target);

        emit Replace(destination, target);
    }

    function unregister(DestinationType destination) public override {
        IDestinationAdapter target = destinations[destination];
        if (address(target) == address(0)) {
            revert DestinationNotPresent();
        }
        delete destinations[destination];

        emit Unregister(destination, address(target));
    }

    function getAdapter(DestinationType destination) public view override returns (IDestinationAdapter target) {
        target = destinations[destination];
        if (address(target) == address(0)) {
            revert DestinationNotPresent();
        }
    }
}
