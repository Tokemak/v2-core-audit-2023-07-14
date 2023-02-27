// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import { IDestinationAdapter } from "./IDestinationAdapter.sol";

interface IDestinationRegistry {
    event Register(bytes32 indexed destination, address indexed target);
    event Replace(bytes32 indexed destination, address indexed target);
    event Unregister(bytes32 indexed destination, address indexed target);

    ///@notice Adds a new address of the given destination type
    ///@dev Fails if trying to overwrite previous value of the same destination type
    ///@param destination One from the destination type whitelist
    ///@param target address of the deployed DestinationAdapter
    function register(bytes32 destination, address target) external;

    ///@notice Replaces an address of the given destination type
    ///@dev Fails if given destination type was not set previously
    ///@param destination One from the destination type whitelist
    ///@param target address of the deployed DestinationAdapter
    function replace(bytes32 destination, address target) external;

    ///@notice Removes an address of the given destination type
    ///@param destination One from the destination type whitelist
    function unregister(bytes32 destination) external;

    ///@notice Gives an address of the given destination type
    ///@param destination One from the destination type whitelist
    function getAdapter(bytes32 destination) external returns (IDestinationAdapter);
}
