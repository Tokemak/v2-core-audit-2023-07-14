//SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

library Errors {
    ///////////////////////////////////////////////////////////////////
    //                       Set errors
    ///////////////////////////////////////////////////////////////////

    error AccessDenied();
    error NotAuthorized();
    error ZeroAddress(string paramName);
    error ZeroAmount();
    error InsufficientBalance(address token);
    error AssetNotAllowed(address token);
    error NotImplemented();
    error InvalidParams();

    error ItemNotFound();
    error ItemExists();
    error MissingRole(bytes32 role, address user);
    error RegistryItemMissing(string item);

    function verifyNotZero(address addr, string memory paramName) external pure {
        if (addr == address(0)) {
            revert ZeroAddress(paramName);
        }
    }
}