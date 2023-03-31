// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

library Roles {
    // --------------------------------------------------------------------
    // Central roles list used by all contracts that call AccessController
    // --------------------------------------------------------------------

    bytes32 public constant REBALANCER_ROLE = keccak256("REBALANCER_ROLE");
    bytes32 public constant CREATE_POOL_ROLE = keccak256("CREATE_POOL_ROLE");
    bytes32 public constant REGISTRY_UPDATER = keccak256("REGISTRY_UPDATER");
}
