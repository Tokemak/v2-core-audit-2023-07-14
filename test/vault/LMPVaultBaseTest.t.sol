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

contract LMPVaultBaseTest is BaseTest {
    IDestinationVault public destinationVault;
    IDestinationVault public destinationVault2;
    LMPVault public lmpVault;
    ERC20 public baseAsset;

    event DestinationVaultAdded(address destination);
    event DestinationVaultRemoved(address destination);
    event WithdrawalQueueSet(address[] destinations);

    function setUp() public virtual override(BaseTest) {
        BaseTest.setUp();

        //
        // create and initialize factory
        //

        // create mock asset
        baseAsset = mockAsset("", "", uint256(1_000_000_000_000_000_000_000_000));

        // create destination vault mocks
        destinationVault = _createDestinationVault(address(baseAsset));
        destinationVault2 = _createDestinationVault(address(baseAsset));

        accessController.grantRole(Roles.DESTINATION_VAULTS_UPDATER, address(this));
        accessController.grantRole(Roles.SET_WITHDRAWAL_QUEUE_ROLE, address(this));

        // create test lmpVault
        lmpVault = LMPVault(
            systemRegistry.getLMPVaultFactoryByType(VaultTypes.LST).createVault(
                address(baseAsset), address(createMainRewarder()), ""
            )
        );

        assert(systemRegistry.lmpVaultRegistry().isVault(address(lmpVault)));
    }

    function _createDestinationVault(address asset) internal returns (IDestinationVault) {
        // create vault (no need to initialize since working with mock)
        IDestinationVault vault = new TestDestinationVault(asset);
        // mock "isRegistered" call
        vm.mockCall(
            address(systemRegistry.destinationVaultRegistry()),
            abi.encodeWithSelector(destinationVaultRegistry.isRegistered.selector, address(vault)),
            abi.encode(true)
        );

        return vault;
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

        vm.expectEmit(true, false, false, false);
        emit WithdrawalQueueSet(withdrawalDestinations);

        lmpVault.setWithdrawalQueue(withdrawalDestinations);

        // check queue
        IDestinationVault[] memory withdrawalQueue = lmpVault.getWithdrawalQueue();
        assert(withdrawalQueue.length == 2);
        assert(withdrawalQueue[0] == destinationVault2);
        assert(withdrawalQueue[1] == destinationVault);
    }

    function test_DestinationVault_remove() public {
        _addDestinationVault(destinationVault);
        assert(lmpVault.getDestinations()[0] == address(destinationVault));
        _removeDestinationVault(destinationVault);
        assert(lmpVault.getDestinations().length == 0);
    }

    function _addDestinationVault(IDestinationVault _destination) internal {
        uint256 numDestinationsBefore = lmpVault.getDestinations().length;
        address[] memory destinations = new address[](1);
        destinations[0] = address(_destination);
        vm.expectEmit(true, false, false, false);
        emit DestinationVaultAdded(destinations[0]);
        lmpVault.addDestinations(destinations);
        assert(lmpVault.getDestinations().length == numDestinationsBefore + 1);
    }

    function _removeDestinationVault(IDestinationVault _destination) internal {
        uint256 numDestinationsBefore = lmpVault.getDestinations().length;
        address[] memory destinations = new address[](1);
        destinations[0] = address(_destination);
        vm.expectEmit(true, false, false, false);
        emit DestinationVaultRemoved(destinations[0]);
        lmpVault.removeDestinations(destinations);
        assert(lmpVault.getDestinations().length == numDestinationsBefore - 1);
    }
}
