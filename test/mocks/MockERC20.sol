// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2023 Tokemak Foundation. All rights reserved.
pragma solidity >=0.8.7;

import { ERC20 } from "openzeppelin-contracts/token/ERC20/ERC20.sol";

contract MockERC20 is ERC20 {
    constructor() ERC20("Mock ERC20", "MOCK") {
        this;
    }

    function mint(address to, uint256 amount) public {
        _mint(to, amount);
    }
}
