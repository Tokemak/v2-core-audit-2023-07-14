// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2023 Tokemak Foundation. All rights reserved.
pragma solidity 0.8.17;

// NOTE: should be put back in once the fuzzing constraints can be implemented

import { ERC4626Test } from "erc4626-tests/ERC4626.test.sol";

import { ERC20Mock } from "openzeppelin-contracts/mocks/ERC20Mock.sol";
import { ERC4626Mock, IERC20Metadata } from "openzeppelin-contracts/mocks/ERC4626Mock.sol";
import { BaseTest } from "test/BaseTest.t.sol";

import { IMainRewarder, MainRewarder } from "src/rewarders/MainRewarder.sol";

import { ILMPVault, LMPVault } from "src/vault/LMPVault.sol";

import { Roles } from "src/libs/Roles.sol";

contract LMPVaultTest is ERC4626Test, BaseTest {
    function setUp() public override(BaseTest, ERC4626Test) {
        // everything's mocked, so disable forking
        super._setUp(false);

        _underlying_ = address(mockAsset("MockERC20", "MockERC20", uint256(1_000_000_000_000_000_000_000_000)));

        // create vault
        LMPVault vault = new LMPVault(
                systemRegistry,
                _underlying_,
                type(uint256).max,
                type(uint256).max
            );

        // create and set rewarder
        MainRewarder rewarder = createMainRewarder(_underlying_, address(vault), true);
        accessController.grantRole(Roles.DV_REWARD_MANAGER_ROLE, address(this));
        accessController.grantRole(Roles.REGISTRY_UPDATER, address(this));
        rewarder.setTokeLockDuration(0);
        vault.setRewarder(address(rewarder));

        lmpVaultRegistry.addVault(address(vault));

        _vault_ = address(vault);
        _delta_ = 0;
        _vaultMayBeEmpty = true;
        _unlimitedAmount = false;
    }
}
