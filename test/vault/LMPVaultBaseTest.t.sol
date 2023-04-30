// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

/* solhint-disable func-name-mixedcase */

import { ERC20 } from "openzeppelin-contracts/token/ERC20/ERC20.sol";
import { AccessController } from "src/security/AccessController.sol";
import { MockERC20 } from "test/mocks/MockERC20.sol";
import { ILMPVaultRegistry, LMPVaultRegistry } from "src/vault/LMPVaultRegistry.sol";
import { ILMPVaultFactory, LMPVaultFactory } from "src/vault/LMPVaultFactory.sol";
import { ILMPVaultRouter, LMPVaultRouter } from "src/vault/LMPVaultRouter.sol";
import { ILMPVault, LMPVault } from "src/vault/LMPVault.sol";

import { SystemRegistry } from "src/SystemRegistry.sol";

import { Roles } from "src/libs/Roles.sol";

import { BaseTest } from "test/BaseTest.t.sol";

import { WETH9_ADDRESS } from "test/utils/Addresses.sol";

contract LMPVaultBaseTest is BaseTest {
    LMPVaultRegistry public registry;
    LMPVaultFactory public factory;
    LMPVaultRouter public router;
    ILMPVault public vault;
    ERC20 public poolAsset;

    function setUp() public virtual override (BaseTest) {
        BaseTest.setUp();

        // create registry
        registry = new LMPVaultRegistry(systemRegistry);

        //
        // create and initialize factory
        //

        // create mock asset
        MockERC20 mockAsset = new MockERC20();
        deal(address(mockAsset), msg.sender, uint256(1_000_000_000_000_000_000_000_000));
        poolAsset = mockAsset;

        factory = new LMPVaultFactory(address(registry), address(accessController));

        // NOTE: deployer grants factory permission to update the registry
        accessController.grantRole(Roles.REGISTRY_UPDATER, address(factory));

        // create router
        router = new LMPVaultRouter(WETH9_ADDRESS);

        // create sample vault
        // NOTE: dummy address passed instead of strategy since that whole thing will be redone
        vault = ILMPVault(factory.createVault(address(mockAsset), address(1), address(createMainRewarder()), ""));
    }

    function test_registryCreated() public view {
        assert(address(registry) != address(0));
    }

    function test_routerCreated() public view {
        assert(address(router) != address(0));
    }

    function test_vaultCreated() public view {
        assert(address(vault) != address(0));
    }

    function test_vaultRegistered() public view {
        assert(registry.isVault(address(vault)));
    }
}
