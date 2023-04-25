// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import { AccessControlEnumerable } from "openzeppelin-contracts/access/AccessControlEnumerable.sol";
import { IAccessController } from "src/interfaces/security/IAccessController.sol";
import { Roles } from "src/libs/Roles.sol";

contract AccessController is IAccessController, AccessControlEnumerable {
    // ------------------------------------------------------------
    //          Pre-initialize roles list for deployer
    // ------------------------------------------------------------
    constructor() {
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setupRole(Roles.REBALANCER_ROLE, msg.sender);
        _setupRole(Roles.CREATE_POOL_ROLE, msg.sender);
    }

    // ------------------------------------------------------------
    //               Role management methods
    // ------------------------------------------------------------
    function setupRole(bytes32 role, address account) external {
        if (!hasRole(DEFAULT_ADMIN_ROLE, msg.sender)) {
            revert AccessDenied();
        }

        // only do if role is not registered already
        if (!hasRole(role, account)) {
            _setupRole(role, account);
        }
    }

    function verifyOwner(address account) public view {
        if (!hasRole(DEFAULT_ADMIN_ROLE, account)) {
            revert AccessDenied();
        }
    }
}
