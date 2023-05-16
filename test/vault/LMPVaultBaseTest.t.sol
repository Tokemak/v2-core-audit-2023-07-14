// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

/* solhint-disable func-name-mixedcase */

import { ERC20 } from "openzeppelin-contracts/token/ERC20/ERC20.sol";
import { AccessController } from "src/security/AccessController.sol";
import { MockERC20 } from "test/mocks/MockERC20.sol";
import { IDestinationVault, DestinationVault } from "src/vault/DestinationVault.sol";
import { ILMPVaultRegistry, LMPVaultRegistry } from "src/vault/LMPVaultRegistry.sol";
import { ILMPVaultFactory, LMPVaultFactory } from "src/vault/LMPVaultFactory.sol";
import { ILMPVaultRouter, LMPVaultRouter } from "src/vault/LMPVaultRouter.sol";
import { ILMPVault, LMPVault } from "src/vault/LMPVault.sol";
import { IStrategy } from "src/interfaces/strategy/IStrategy.sol";

import { SystemRegistry } from "src/SystemRegistry.sol";
import { Roles } from "src/libs/Roles.sol";
import { BaseTest } from "test/BaseTest.t.sol";
import { VaultTypes } from "src/vault/VaultTypes.sol";
import { TestDestinationVault } from "test/mocks/TestDestinationVault.sol";

import { WETH9_ADDRESS } from "test/utils/Addresses.sol";

import { console2 as console } from "forge-std/console2.sol";

contract LMPVaultBaseTest is BaseTest {
    IDestinationVault public destinationVault;
    IDestinationVault public destinationVault2;
    LMPVault public lmpVault;
    ERC20 public poolAsset;

    function setUp() public virtual override(BaseTest) {
        BaseTest.setUp();

        console.log("LMPVaultBaseTest.setUp() started");

        //
        // create and initialize factory
        //
        console.log("creating mock asset");
        // create mock asset
        poolAsset = mockAsset("", "", uint256(1_000_000_000_000_000_000_000_000));

        console.log("creating destinations setup");
        // create destination vaults
        destinationVault = new TestDestinationVault(address(poolAsset));
        destinationVaultRegistry.register(address(destinationVault));
        destinationVault2 = new TestDestinationVault(address(poolAsset));
        destinationVaultRegistry.register(address(destinationVault2));

        console.log("creating lmpVault");
        // create test lmpVault
        lmpVault = LMPVault(
            systemRegistry.getLMPVaultFactoryByType(VaultTypes.LST).createVault(
                address(poolAsset), address(createMainRewarder()), ""
            )
        );
    }

    function test_lmpVaultRegistered() public view {
        assert(systemRegistry.lmpVaultRegistry().isVault(address(lmpVault)));
    }

    //////////////////////////////////////////////////////////////////////
    //				    Destination Vaults lists						//
    //////////////////////////////////////////////////////////////////////

    function test_DestinationVault_add() public {
        _addDestinationVault(destinationVault);
        assert(lmpVault.getDestinations()[0] == address(destinationVault));
    }

    function test_DestinationVault_addExtra() public {
        _addDestinationVault(destinationVault);
        assert(lmpVault.getDestinations()[0] == address(destinationVault));
        _addDestinationVault(destinationVault2);
        assert(lmpVault.getDestinations().length == 2);
        assert(lmpVault.getDestinations()[1] == address(destinationVault2));
    }

    function test_WithdrawalQueue() public {
        // add some vaults
        _addDestinationVault(destinationVault);
        _addDestinationVault(destinationVault2);

        assert(lmpVault.getWithdrawalQueue().length == 0);

        // set the queue for same vaults but reverse order
        address[] memory withdrawalDestinations = new address[](2);
        withdrawalDestinations[0] = address(destinationVault2);
        withdrawalDestinations[1] = address(destinationVault);
        vm.expectEmit(true, true, true, true);
        lmpVault.setWithdrawalQueue(withdrawalDestinations);

        // check queue
        IDestinationVault[] memory withdrawalQueue = lmpVault.getWithdrawalQueue();
        assert(withdrawalQueue.length == 0);
        assert(withdrawalQueue[0] == destinationVault2);
        assert(withdrawalQueue[1] == destinationVault);
    }

    function test_DestinationVault_remove() public {
        _addDestinationVault(destinationVault);
        assert(lmpVault.getDestinations()[0] == address(destinationVault));
        vm.expectEmit(true, true, true, true);
        _removeDestinationVault(destinationVault);
        assert(lmpVault.getDestinations().length == 0);
    }

    function _addDestinationVault(IDestinationVault _destination) internal {
        uint256 numDestinationsBefore = lmpVault.getDestinations().length;
        address[] memory destinations = new address[](1);
        destinations[0] = address(_destination);
        vm.expectEmit(true, true, true, true);
        lmpVault.addDestinations(destinations);
        assert(lmpVault.getDestinations().length == numDestinationsBefore + 1);
    }

    function _removeDestinationVault(IDestinationVault _destination) internal {
        uint256 numDestinationsBefore = lmpVault.getDestinations().length;
        address[] memory destinations = new address[](1);
        destinations[0] = address(_destination);
        vm.expectEmit(true, true, true, true);
        lmpVault.removeDestinations(destinations);
        assert(lmpVault.getDestinations().length == numDestinationsBefore - 1);
    }
}
