/* solhint-disable func-name-mixedcase */
// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import { IPlasmaVaultRegistry, PlasmaVaultRegistry } from "src/vault/PlasmaVaultRegistry.sol";
import { IPlasmaVaultFactory, PlasmaVaultFactory } from "src/vault/PlasmaVaultFactory.sol";
import { IPlasmaVaultRouter, PlasmaVaultRouter } from "src/vault/PlasmaVaultRouter.sol";
import { IPlasmaVault, PlasmaVault } from "src/vault/PlasmaVault.sol";
import { ERC20 } from "openzeppelin-contracts/token/ERC20/ERC20.sol";
// import { IERC20 } from "openzeppelin-contracts/token/ERC20/IERC20.sol";
import { MockERC20 } from "test/mocks/MockERC20.sol";

import { BaseTest } from "test/BaseTest.t.sol";

import { WETH9_ADDRESS } from "test/utils/Addresses.sol";

// import { console2 as console } from "forge-std/console2.sol";

contract PlasmaVaultBaseTest is BaseTest {
    PlasmaVaultRegistry public registry;
    PlasmaVaultFactory public factory;
    PlasmaVaultRouter public router;
    IPlasmaVault public vault;
    ERC20 public poolAsset;
    address internal _mockPoolPrototypeAddress;

    function setUp() public virtual override (BaseTest) {
        BaseTest.setUp();

        // create registry
        registry = new PlasmaVaultRegistry(address(accessController));

        //
        // create and initialize factory
        //

        // create mock asset
        MockERC20 mockAsset = new MockERC20();
        deal(address(mockAsset), msg.sender, uint256(1_000_000_000_000_000_000_000_000));
        poolAsset = mockAsset;

        factory = new PlasmaVaultFactory(address(registry), address(accessController));
        // _mockPoolPrototypeAddress = address(new PlasmaVault());
        // factory.addPrototype(_mockPoolPrototypeAddress);
        factory.addPoolType(factory.POOLTYPE_PLASMAPOOL(), address(0));

        // NOTE: deployer grants factory permission to update the registry
        accessController.grantRole(registry.REGISTRY_UPDATER(), address(factory));

        // create router
        router = new PlasmaVaultRouter(WETH9_ADDRESS);

        // create sample vault
        vault = IPlasmaVault(factory.createPool(factory.POOLTYPE_PLASMAPOOL(), address(mockAsset), ""));
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
        assert(registry.isPool(address(vault)));
    }
}
