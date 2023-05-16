// solhint-disable func-name-mixedcase
// solhint-disable var-name-mixedcase
// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

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
