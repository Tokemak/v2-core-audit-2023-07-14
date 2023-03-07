// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "forge-std/Test.sol";

import "erc4626-tests/ERC4626.test.sol";

import { console } from "forge-std/console.sol";
import { IPlasmaPoolRegistry, PlasmaPoolRegistry } from "src/PlasmaPoolRegistry.sol";
import { IPlasmaPoolFactory, PlasmaPoolFactory } from "src/PlasmaPoolFactory.sol";
import { IPlasmaPoolRouter, PlasmaPoolRouter } from "src/PlasmaPoolRouter.sol";
import { IPlasmaPool, PlasmaPool } from "src/PlasmaPool.sol";
import { ERC20 } from "openzeppelin-contracts/token/ERC20/ERC20.sol";
// import { IERC20 } from "openzeppelin-contracts/token/ERC20/IERC20.sol";
import { MockERC20 } from "./mocks/MockERC20.sol";

import { BaseTest } from "./BaseTest.t.sol";
import { console } from "forge-std/console.sol";

contract PlasmaVaultBaseTest is BaseTest {
    PlasmaPoolRegistry public registry;
    PlasmaPoolFactory public factory;
    PlasmaPoolRouter public router;
    IPlasmaPool public pool;
    ERC20 public poolAsset;
    address internal _mockPoolPrototypeAddress;

    function setUp() public virtual override (BaseTest) {
        BaseTest.setUp();

        // create registry
        registry = new PlasmaPoolRegistry();

        //
        // create and initialize factory
        //

        // create mock asset
        MockERC20 mockAsset = new MockERC20();
        deal(address(mockAsset), msg.sender, uint256(1_000_000_000_000_000_000_000_000));
        poolAsset = mockAsset;

        factory = new PlasmaPoolFactory(address(registry));
        // _mockPoolPrototypeAddress = address(new PlasmaPool());
        // factory.addPrototype(_mockPoolPrototypeAddress);
        factory.addPoolType(factory.POOLTYPE_PLASMAPOOL(), address(0));
        // TODO check that it's in the list / added

        // TODO: adding new factory to registry permission whitelist seems too manual...
        //      .. would delegateCall right inside factory creation be a better idea? @codenutt
        registry.grantRole(registry.REGISTRY_UPDATER(), address(factory));

        // create router
        router = new PlasmaPoolRouter();

        // create sample pool
        pool = IPlasmaPool(factory.createPool(factory.POOLTYPE_PLASMAPOOL(), address(mockAsset), ""));

        // // erc426-tests setup
        // _underlying_ = address(mockAsset);
        // _vault_ = address(pool);
        // _delta_ = 0;
        // _vaultMayBeEmpty = false;
        // _unlimitedAmount = false;
    }
}
