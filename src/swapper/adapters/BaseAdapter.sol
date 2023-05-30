// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2023 Tokemak Foundation. All rights reserved.
pragma solidity 0.8.17;

import { Errors } from "src/utils/Errors.sol";
import { ISwapRouter } from "src/interfaces/swapper/ISwapRouter.sol";

contract BaseAdapter {
    ISwapRouter public immutable router;

    constructor(address _router) {
        Errors.verifyNotZero(_router, "router");
        router = ISwapRouter(_router);
    }

    /// @dev Reverts if the delegate caller is not the router.
    modifier onlyRouter() {
        if (address(this) != address(router)) revert Errors.AccessDenied();
        _;
    }
}
