// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import { IAccessController } from "src/interfaces/security/IAccessController.sol";
import { Context } from "openzeppelin-contracts/utils/Context.sol";

contract SecurityBase {
    IAccessController public immutable accessController;

    error UndefinedAddress();

    constructor(address _accessController) {
        if (_accessController == address(0)) revert UndefinedAddress();

        accessController = IAccessController(_accessController);
    }

    modifier onlyOwner() {
        accessController.verifyOwner(msg.sender);
        _;
    }

    ///////////////////////////////////////////////////////////////////
    //
    //  Forward all the regular methods to central security module
    //
    ///////////////////////////////////////////////////////////////////

    function _hasRole(bytes32 role, address account) internal view returns (bool) {
        return accessController.hasRole(role, account);
    }

    // NOTE: left commented forward methods in here for potential future use
    //     function _getRoleAdmin(bytes32 role) internal view returns (bytes32) {
    //         return accessController.getRoleAdmin(role);
    //     }
    //
    //     function _grantRole(bytes32 role, address account) internal {
    //         accessController.grantRole(role, account);
    //     }
    //
    //     function _revokeRole(bytes32 role, address account) internal {
    //         accessController.revokeRole(role, account);
    //     }
    //
    //     function _renounceRole(bytes32 role, address account) internal {
    //         accessController.renounceRole(role, account);
    //     }
}
