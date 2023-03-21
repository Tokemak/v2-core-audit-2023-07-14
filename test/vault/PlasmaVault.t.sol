// SPDX-License-Identifier: MIT
pragma solidity >=0.8.7;

import { ERC4626Test } from "erc4626-tests/ERC4626.test.sol";

import { IPlasmaVault, PlasmaVault } from "src/vault/PlasmaVault.sol";
import { ERC20Mock } from "openzeppelin-contracts/mocks/ERC20Mock.sol";
import { ERC4626Mock, IERC20Metadata } from "openzeppelin-contracts/mocks/ERC4626Mock.sol";

contract PlasmaVaultTest is ERC4626Test {
    function setUp() public override {
        _underlying_ = address(new ERC20Mock("MockERC20", "MockERC20", address(this), 0));
        IPlasmaVault vault = new PlasmaVault(_underlying_);
        _vault_ = address(vault);
        _delta_ = 0;
        _vaultMayBeEmpty = true;
        _unlimitedAmount = false;
    }
}
