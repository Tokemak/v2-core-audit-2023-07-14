// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2023 Tokemak Foundation. All rights reserved.
pragma solidity >=0.8.7;

import { ERC20 } from "openzeppelin-contracts/token/ERC20/ERC20.sol";

contract TestERC20 is ERC20 {
    uint8 private _decimals;

    constructor(string memory name_, string memory symbol_) ERC20(name_, symbol_) {
        _decimals = 18;
    }

    function decimals() public view override returns (uint8) {
        return _decimals;
    }

    function setDecimals(uint8 newDecimals) external {
        _decimals = newDecimals;
    }

    function mint(address account, uint256 amount) external {
        _mint(account, amount);
    }

    function burn(address account, uint256 amount) external {
        _burn(account, amount);
    }
}
