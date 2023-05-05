// SPDX-License-Identifier: MIT
pragma solidity >=0.8.7;

import { Roles } from "src/libs/Roles.sol";
import { Errors } from "src/utils/errors.sol";
import { SystemRegistry } from "src/SystemRegistry.sol";
import { ISystemBound } from "src/interfaces/ISystemBound.sol";
import { Test, StdCheats, StdUtils } from "forge-std/Test.sol";
import { DestinationVault } from "src/vault/DestinationVault.sol";
import { ISystemRegistry } from "src/interfaces/ISystemRegistry.sol";
import { DestinationVaultFactory } from "src/vault/DestinationVaultFactory.sol";
import { IAccessController, AccessController } from "src/security/AccessController.sol";
import { IDestinationRegistry } from "src/interfaces/destinations/IDestinationRegistry.sol";
import { IDestinationVaultRegistry } from "src/interfaces/vault/IDestinationVaultRegistry.sol";
import { IERC20Metadata as IERC20 } from "openzeppelin-contracts/token/ERC20/extensions/IERC20Metadata.sol";

contract DestinationVaultFactoryBaseTests is Test {
    address private testUser1;
    address private templateRegistry;
    address private vaultRegistry;

    SystemRegistry private systemRegistry;
    IAccessController private accessController;
    DestinationVaultFactory private factory;

    event Initialized(ISystemRegistry registry, bytes params);

    function setUp() public {
        testUser1 = vm.addr(1);

        systemRegistry = new SystemRegistry();
        templateRegistry = generateTemplateRegistry(systemRegistry);
        vaultRegistry = generateVaultRegistry(systemRegistry);
        accessController = new AccessController(address(systemRegistry));
        systemRegistry.setAccessController(address(accessController));
        systemRegistry.setDestinationTemplateRegistry(templateRegistry);
        systemRegistry.setDestinationVaultRegistry(vaultRegistry);

        factory = new DestinationVaultFactory(systemRegistry);
    }

    function testRequiresValidRegistry() public {
        vm.expectRevert();
        new DestinationVaultFactory(ISystemRegistry(address(0)));

        SystemRegistry incompleteRegistry = new SystemRegistry();
        vm.expectRevert();
        new DestinationVaultFactory(incompleteRegistry);
    }

    function testRequiresTemplateRegistryOnSetup() public {
        SystemRegistry incompleteRegistry = new SystemRegistry();
        AccessController access = new AccessController(address(incompleteRegistry));
        incompleteRegistry.setAccessController(address(access));

        // Try with nothing
        vm.expectRevert();
        new DestinationVaultFactory(incompleteRegistry);

        // Try with the vault, still missing template
        incompleteRegistry.setDestinationVaultRegistry(generateVaultRegistry(incompleteRegistry));
        vm.expectRevert();
        new DestinationVaultFactory(incompleteRegistry);

        // Should have everything now
        incompleteRegistry.setDestinationTemplateRegistry(generateTemplateRegistry(incompleteRegistry));
        new DestinationVaultFactory(incompleteRegistry);
    }

    function testRequiresVaultRegistryOnSetup() public {
        SystemRegistry incompleteRegistry = new SystemRegistry();
        AccessController access = new AccessController(address(incompleteRegistry));
        incompleteRegistry.setAccessController(address(access));

        // Try with nothing
        vm.expectRevert();
        new DestinationVaultFactory(incompleteRegistry);

        // Try with template still missing the vault
        incompleteRegistry.setDestinationTemplateRegistry(generateTemplateRegistry(incompleteRegistry));
        vm.expectRevert();
        new DestinationVaultFactory(incompleteRegistry);

        // Should have everything now
        incompleteRegistry.setDestinationVaultRegistry(generateVaultRegistry(incompleteRegistry));
        new DestinationVaultFactory(incompleteRegistry);
    }

    function testOnlyVaultCreatorCanCallCreate() public {
        vm.expectRevert(
            abi.encodeWithSelector(Errors.MissingRole.selector, Roles.CREATE_DESTINATION_VAULT_ROLE, address(this))
        );
        factory.create("x", address(8), "dex", abi.encode(""));

        bytes32 key = keccak256(abi.encode("x"));
        address template = vm.addr(6);
        registerTemplate(templateRegistry, key, template);
        accessController.grantRole(Roles.CREATE_DESTINATION_VAULT_ROLE, address(this));
        factory.create("x", address(8), "dex", abi.encode(""));
    }

    function testVaultTypeMustBeRegistered() public {
        accessController.grantRole(Roles.CREATE_DESTINATION_VAULT_ROLE, address(this));

        // Fails when it gets address(0)
        bytes32 badKey = keccak256(abi.encode("y"));
        registerTemplate(templateRegistry, badKey, address(0));
        vm.expectRevert(abi.encodeWithSelector(Errors.ZeroAddress.selector, "template"));
        factory.create("y", address(8), "dex", abi.encode(""));

        // Succeeds when a template is registered
        registerTemplate(templateRegistry, badKey, address(1));
        factory.create("y", address(8), "dex", abi.encode(""));
    }

    function testCallsInitializeWithProvidedParams() public {
        accessController.grantRole(Roles.CREATE_DESTINATION_VAULT_ROLE, address(this));

        // Fails when it gets address(0)
        bytes32 badKey = keccak256(abi.encode("y"));
        registerTemplate(templateRegistry, badKey, address(0));
        vm.expectRevert(abi.encodeWithSelector(Errors.ZeroAddress.selector, "template"));
        factory.create("y", address(8), "dex", abi.encode(""));

        // Succeeds when a template is registered
        TestVault tv = new TestVault();
        registerTemplate(templateRegistry, badKey, address(tv));
        bytes memory data = abi.encode("h");

        vm.expectEmit(true, true, true, true);
        emit Initialized(systemRegistry, data);
        factory.create("y", address(8), "dex", data);
    }

    function testAddsToRegistry() public {
        accessController.grantRole(Roles.CREATE_DESTINATION_VAULT_ROLE, address(this));

        bytes32 badKey = keccak256(abi.encode("y"));
        registerTemplate(templateRegistry, badKey, address(0));
        vm.expectRevert(abi.encodeWithSelector(Errors.ZeroAddress.selector, "template"));
        factory.create("y", address(8), "dex", abi.encode(""));

        TestVault tv = new TestVault();
        registerTemplate(templateRegistry, badKey, address(tv));
        bytes memory data = abi.encode("h");

        address nextAddress = computeCreateAddress(address(factory), 1);
        vm.expectCall(vaultRegistry, abi.encodeCall(IDestinationVaultRegistry.register, (nextAddress)));
        factory.create("y", address(8), "dex", data);
    }

    function registerTemplate(address templateReg, bytes32 key, address template) internal {
        vm.mockCall(
            templateReg, abi.encodeWithSelector(IDestinationRegistry.getAdapter.selector, key), abi.encode(template)
        );
    }

    function ensureVaultRegisterPasses(address vaultReg, address newVault) internal {
        vm.mockCall(
            vaultReg, abi.encodeWithSelector(IDestinationVaultRegistry.register.selector, newVault), abi.encode("")
        );
    }

    function generateTemplateRegistry(ISystemRegistry sysRegistry) internal returns (address) {
        address reg = vm.addr(1001);
        vm.mockCall(reg, abi.encodeWithSelector(ISystemBound.systemRegistry.selector), abi.encode(sysRegistry));
        return reg;
    }

    function generateVaultRegistry(ISystemRegistry sysRegistry) internal returns (address) {
        address reg = vm.addr(1002);
        vm.mockCall(reg, abi.encodeWithSelector(ISystemBound.systemRegistry.selector), abi.encode(sysRegistry));
        return reg;
    }
}

contract TestVault {
    event Initialized(ISystemRegistry registry, bytes params);

    function initialize(ISystemRegistry registry, IERC20, string memory, bytes memory params) external {
        emit Initialized(registry, params);
    }
}
