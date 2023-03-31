// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import { IAccessControlEnumerable } from "openzeppelin-contracts/access/IAccessControlEnumerable.sol";

interface IAccessController is IAccessControlEnumerable {
    error AccessDenied();

    function setupRole(bytes32 role, address account) external;

    function verifyOwner(address account) external view;
}
