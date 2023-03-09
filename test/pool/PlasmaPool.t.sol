// SPDX-License-Identifier: MIT
pragma solidity >=0.8.7;

import { ERC4626Test } from "erc4626-tests/ERC4626.test.sol";

import { IPlasmaPool, PlasmaPool } from "src/PlasmaPool.sol";
import { ERC20Mock } from "openzeppelin-contracts/mocks/ERC20Mock.sol";
import { ERC4626Mock, IERC20Metadata } from "openzeppelin-contracts/mocks/ERC4626Mock.sol";

contract PlasmaPoolTest is ERC4626Test {
    function setUp() public override {
        _underlying_ = address(new ERC20Mock("MockERC20", "MockERC20", address(this), 0));
        IPlasmaPool pool = new PlasmaPool(_underlying_);
        _vault_ = address(pool);
        _delta_ = 0;
        _vaultMayBeEmpty = true;
        _unlimitedAmount = false;
    }
}
