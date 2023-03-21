// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "openzeppelin-contracts/access/Ownable2Step.sol";

import "../interfaces/destinations/IDestinationRegistry.sol";
import "../interfaces/destinations/IDestinationAdapter.sol";

contract DestinationRegistry is IDestinationRegistry, Ownable2Step {
    mapping(bytes32 => IDestinationAdapter) public destinations;
    mapping(bytes32 => bool) public allowedTypes;

    error ArraysLengthMismatch();
    error ZeroAddress(string param);
    error NotAllowedDestination();
    error DestinationAlreadySet();
    error DestinationNotPresent();

    modifier arrayLengthMatch(bytes32[] calldata destinationTypes, address[] calldata targets) {
        if (destinationTypes.length != targets.length) {
            revert ArraysLengthMismatch();
        }
        _;
    }

    function ensureTargetNotZero(address target) private pure {
        if (target == address(0)) {
            revert ZeroAddress("target");
        }
    }

    function ensureDestinationIsPresent(IDestinationAdapter destination) private pure {
        if (address(destination) == address(0)) {
            revert DestinationNotPresent();
        }
    }

    function register(
        bytes32[] calldata destinationTypes,
        address[] calldata targets
    ) public override onlyOwner arrayLengthMatch(destinationTypes, targets) {
        for (uint256 i = 0; i < destinationTypes.length; ++i) {
            bytes32 destination = destinationTypes[i];
            if (!isWhitelistedDestination(destination)) {
                revert NotAllowedDestination();
            }
            address target = targets[i];
            ensureTargetNotZero(target);

            if (address(destinations[destination]) != address(0)) {
                revert DestinationAlreadySet();
            }
            destinations[destination] = IDestinationAdapter(target);
        }
        emit Register(destinationTypes, targets);
    }

    function replace(
        bytes32[] calldata destinationTypes,
        address[] calldata targets
    ) public override onlyOwner arrayLengthMatch(destinationTypes, targets) {
        for (uint256 i = 0; i < destinationTypes.length; ++i) {
            address target = targets[i];
            ensureTargetNotZero(target);

            bytes32 destination = destinationTypes[i];
            IDestinationAdapter existingDestination = destinations[destination];
            ensureDestinationIsPresent(existingDestination);

            if (address(existingDestination) == target) {
                revert DestinationAlreadySet();
            }
            destinations[destination] = IDestinationAdapter(target);
        }
        emit Replace(destinationTypes, targets);
    }

    function unregister(bytes32[] calldata destinationTypes) public override onlyOwner {
        for (uint256 i = 0; i < destinationTypes.length; ++i) {
            bytes32 destination = destinationTypes[i];
            ensureDestinationIsPresent(destinations[destination]);
            //slither-disable-next-line costly-loop
            delete destinations[destination];
        }
        emit Unregister(destinationTypes);
    }

    function getAdapter(bytes32 destinationType) public view override returns (IDestinationAdapter target) {
        target = destinations[destinationType];
        ensureDestinationIsPresent(target);
    }

    function addToWhitelist(bytes32[] calldata destinationTypes) external override onlyOwner {
        for (uint256 i = 0; i < destinationTypes.length; ++i) {
            if (allowedTypes[destinationTypes[i]]) {
                revert DestinationAlreadySet();
            }
            allowedTypes[destinationTypes[i]] = true;
        }
        emit Whitelist(destinationTypes);
    }

    function removeFromWhitelist(bytes32[] calldata destinationTypes) external override onlyOwner {
        for (uint256 i = 0; i < destinationTypes.length; ++i) {
            bytes32 destination = destinationTypes[i];
            if (!allowedTypes[destination]) {
                revert DestinationNotPresent();
            }
            if (address(destinations[destination]) != address(0)) {
                // cannot remove from whitelist already registered type – must unregister first
                revert DestinationAlreadySet();
            }
            //slither-disable-next-line costly-loop
            delete allowedTypes[destination];
        }
        emit RemoveFromWhitelist(destinationTypes);
    }

    function isWhitelistedDestination(bytes32 destinationType) public view override returns (bool) {
        return allowedTypes[destinationType];
    }
}
