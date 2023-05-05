// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import { ISystemBound } from "src/interfaces/ISystemBound.sol";
import { IAccessControlEnumerable } from "openzeppelin-contracts/access/IAccessControlEnumerable.sol";

interface IAccessController is ISystemBound, IAccessControlEnumerable {
    error AccessDenied();

    function setupRole(bytes32 role, address account) external;

    function verifyOwner(address account) external view;
}
