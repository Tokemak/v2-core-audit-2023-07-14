// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import { Errors } from "src/utils/Errors.sol";
import { ISwapRouter } from "src/interfaces/swapper/ISwapRouter.sol";

contract BaseAdapter {
    ISwapRouter public immutable router;

    constructor(address _router) {
        router = ISwapRouter(_router);
    }

    /// @dev Reverts if the delegate caller is not the router.
    modifier onlyRouter() {
        if (address(this) != address(router)) revert Errors.AccessDenied();
        _;
    }
}
