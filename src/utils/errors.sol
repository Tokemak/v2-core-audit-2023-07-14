//SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

library Errors {
    ///////////////////////////////////////////////////////////////////
    //                       Set errors
    ///////////////////////////////////////////////////////////////////

    error ItemNotFound();
    error ItemExists();
    error MissingRole(bytes32 role, address user);
    error RegistryItemMissing(string item);
    error ZeroAddress(string paramName);

    function verifyNotZero(address addr, string memory paramName) external pure {
        if (addr == address(0)) {
            revert ZeroAddress(paramName);
        }
    }
}
