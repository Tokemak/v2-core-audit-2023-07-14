// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2023 Tokemak Foundation. All rights reserved.

pragma solidity 0.8.17;

// solhint-disable func-name-mixedcase
// solhint-disable var-name-mixedcase

import { BaseTest } from "test/BaseTest.t.sol";

contract AccessControlTest is BaseTest {
    function setUp() public virtual override(BaseTest) {
        BaseTest.setUp();
    }

    function testRoles() public {
        bytes32 ROLE = keccak256("ROLE");
        assertFalse(accessController.hasRole(ROLE, address(this)));
        accessController.setupRole(ROLE, address(this));
        assertTrue(accessController.hasRole(ROLE, address(this)));
        accessController.revokeRole(ROLE, address(this));
        assertFalse(accessController.hasRole(ROLE, address(this)));
    }
}
