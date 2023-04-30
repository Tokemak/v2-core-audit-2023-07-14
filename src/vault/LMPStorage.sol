// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import { EnumerableSet } from "openzeppelin-contracts/utils/structs/EnumerableSet.sol";

import { IDestinationVault } from "src/interfaces/vault/IDestinationVault.sol";

abstract contract LMPStorage {
    // slither-disable-next-line constable-states
    uint256 public totalIdle = 0;
    // slither-disable-next-line constable-states
    uint256 public totalDebt = 0;
    IDestinationVault[] public withdrawalQueue;

    EnumerableSet.AddressSet internal _trackedAssets;
}
