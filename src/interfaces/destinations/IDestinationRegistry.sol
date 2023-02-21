// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.17;

import { IDestinationAdapter } from "./IDestinationAdapter.sol";

interface IDestinationRegistry {
    event Register(DestinationType destination, address target);
    event Replace(DestinationType destination, address target);
    event Unregister(DestinationType destination, address target);

    enum DestinationType {
        BalancerV2MetaStablePoolAdapter,
        CurveV2FactoryCryptoAdapter
    }

    ///@notice Adds a new address of the given DestinationType
    ///@dev Fails if trying to overwrite previous value of the same DestinationType
    ///@param destination One from the DestinationType whitelist
    ///@param target address of the deployed DestinationAdapter
    function register(DestinationType destination, address target) external;

    ///@notice Replaces an address of the given DestinationType
    ///@dev Fails if given DestinationType was not set previously
    ///@param destination One from the DestinationType whitelist
    ///@param target address of the deployed DestinationAdapter
    function replace(DestinationType destination, address target) external;

    ///@notice Removes an address of the given DestinationType
    ///@param destination One from the DestinationType whitelist
    function unregister(DestinationType destination) external;

    ///@notice Gives an address of the given DestinationType
    ///@param destination One from the DestinationType whitelist
    function getAdapter(DestinationType destination) external returns (IDestinationAdapter);
}
