//SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import { ISystemBound } from "src/interfaces/ISystemBound.sol";

library Errors {
    ///////////////////////////////////////////////////////////////////
    //                       Set errors
    ///////////////////////////////////////////////////////////////////

    error AccessDenied();
    error ZeroAddress(string paramName);
    error ZeroAmount();
    error InsufficientBalance(address token);
    error AssetNotAllowed(address token);
    error NotImplemented();
    error InvalidAddress(address addr);
    error InvalidParam(string paramName);
    error InvalidParams();
    error AlreadySet(string param);
    error SlippageExceeded(uint256 expected, uint256 actual);

    error ItemNotFound();
    error ItemExists();
    error MissingRole(bytes32 role, address user);
    error RegistryItemMissing(string item);
    // Used to check storage slot is empty before setting.
    error MustBeZero();
    // Used to check storage slot set before deleting.
    error MustBeSet();

    error ApprovalFailed(address token);
    error FlashLoanFailed(address token, uint256 amount);

    error SystemMismatch(address source1, address source2);

    function verifyNotZero(address addr, string memory paramName) internal pure {
        if (addr == address(0)) {
            revert ZeroAddress(paramName);
        }
    }

    function verifyNotZero(bytes32 key, string memory paramName) internal pure {
        if (key == bytes32(0)) {
            revert InvalidParam(paramName);
        }
    }

    function verifyNotZero(uint256 num, string memory paramName) internal pure {
        if (num == 0) {
            revert InvalidParam(paramName);
        }
    }

    function verifySystemsMatch(ISystemBound component1, ISystemBound component2) internal view {
        if (component1.getSystemRegistry() != component2.getSystemRegistry()) {
            revert SystemMismatch(address(component1), address(component2));
        }
    }
}
