// SPDX-License-Identifier: MIT
pragma solidity >=0.8.7;

import { Roles } from "src/libs/Roles.sol";
import { Errors } from "src/utils/Errors.sol";
import { SystemRegistry } from "src/SystemRegistry.sol";
import { ISystemComponent } from "src/interfaces/ISystemComponent.sol";
import { Test, StdCheats, StdUtils } from "forge-std/Test.sol";
import { Clones } from "openzeppelin-contracts/proxy/Clones.sol";
import { DestinationVault } from "src/vault/DestinationVault.sol";
import { ISystemRegistry } from "src/interfaces/ISystemRegistry.sol";
import { IMainRewarder } from "src/interfaces/rewarders/IMainRewarder.sol";
import { IStakeTracking } from "src/interfaces/rewarders/IStakeTracking.sol";
import { IDestinationVault } from "src/interfaces/vault/IDestinationVault.sol";
import { DestinationVaultFactory } from "src/vault/DestinationVaultFactory.sol";
import { IAccessController, AccessController } from "src/security/AccessController.sol";
import { IDestinationRegistry } from "src/interfaces/destinations/IDestinationRegistry.sol";
import { IDestinationVaultRegistry } from "src/interfaces/vault/IDestinationVaultRegistry.sol";
import { IERC20Metadata as IERC20 } from "openzeppelin-contracts/token/ERC20/extensions/IERC20Metadata.sol";
import { TOKE_MAINNET, WETH_MAINNET } from "test/utils/Addresses.sol";

contract DestinationVaultFactoryBaseTests is Test {
    address private testUser1;
    address private templateRegistry;
    address private vaultRegistry;

    SystemRegistry private systemRegistry;
    IAccessController private accessController;
    DestinationVaultFactory private factory;

    address private fakeUnderlyer;
    address[] private fakeTracked;

    event Initialized(ISystemRegistry registry, bytes params);

    function setUp() public {
        testUser1 = vm.addr(1);

        systemRegistry = new SystemRegistry(TOKE_MAINNET, WETH_MAINNET);
        templateRegistry = generateTemplateRegistry(systemRegistry);
        vaultRegistry = generateVaultRegistry(systemRegistry);
        accessController = new AccessController(address(systemRegistry));
        systemRegistry.setAccessController(address(accessController));
        systemRegistry.setDestinationTemplateRegistry(templateRegistry);
        systemRegistry.setDestinationVaultRegistry(vaultRegistry);

        factory = new DestinationVaultFactory(systemRegistry, 1, 1000);

        fakeUnderlyer = vm.addr(10);
        fakeTracked = new address[](0);
    }

    function testRequiresValidRegistry() public {
        vm.expectRevert();
        new DestinationVaultFactory(ISystemRegistry(address(0)), 1, 1000);

        SystemRegistry incompleteRegistry = new SystemRegistry(TOKE_MAINNET, WETH_MAINNET);
        vm.expectRevert();
        new DestinationVaultFactory(incompleteRegistry, 1, 1000);
    }

    function testRequiresTemplateRegistryOnSetup() public {
        SystemRegistry incompleteRegistry = new SystemRegistry(TOKE_MAINNET, WETH_MAINNET);
        AccessController access = new AccessController(address(incompleteRegistry));
        incompleteRegistry.setAccessController(address(access));

        // Try with nothing
        vm.expectRevert();
        new DestinationVaultFactory(incompleteRegistry, 1, 1000);

        // Try with the vault, still missing template
        incompleteRegistry.setDestinationVaultRegistry(generateVaultRegistry(incompleteRegistry));
        vm.expectRevert();
        new DestinationVaultFactory(incompleteRegistry, 1, 1000);

        // Should have everything now
        incompleteRegistry.setDestinationTemplateRegistry(generateTemplateRegistry(incompleteRegistry));
        new DestinationVaultFactory(incompleteRegistry, 1, 1000);
    }

    function testRequiresVaultRegistryOnSetup() public {
        SystemRegistry incompleteRegistry = new SystemRegistry(TOKE_MAINNET, WETH_MAINNET);
        AccessController access = new AccessController(address(incompleteRegistry));
        incompleteRegistry.setAccessController(address(access));

        // Try with nothing
        vm.expectRevert();
        new DestinationVaultFactory(incompleteRegistry, 1, 1000);

        // Try with template still missing the vault
        incompleteRegistry.setDestinationTemplateRegistry(generateTemplateRegistry(incompleteRegistry));
        vm.expectRevert();
        new DestinationVaultFactory(incompleteRegistry, 1, 1000);

        // Should have everything now
        incompleteRegistry.setDestinationVaultRegistry(generateVaultRegistry(incompleteRegistry));
        new DestinationVaultFactory(incompleteRegistry, 1, 1000);
    }

    function testOnlyVaultCreatorCanCallCreate() public {
        vm.expectRevert(
            abi.encodeWithSelector(Errors.MissingRole.selector, Roles.CREATE_DESTINATION_VAULT_ROLE, address(this))
        );
        factory.create("x", address(8), fakeUnderlyer, fakeTracked, keccak256("abc"), abi.encode(""));

        bytes32 key = keccak256(abi.encode("x"));
        address template = vm.addr(6);
        registerTemplate(templateRegistry, key, template);
        accessController.grantRole(Roles.CREATE_DESTINATION_VAULT_ROLE, address(this));
        factory.create("x", address(8), fakeUnderlyer, fakeTracked, keccak256("abc"), abi.encode(""));
    }

    function testVaultTypeMustBeRegistered() public {
        accessController.grantRole(Roles.CREATE_DESTINATION_VAULT_ROLE, address(this));

        // Fails when it gets address(0)
        bytes32 badKey = keccak256(abi.encode("y"));
        registerTemplate(templateRegistry, badKey, address(0));
        vm.expectRevert(abi.encodeWithSelector(Errors.ZeroAddress.selector, "template"));
        factory.create("y", address(8), fakeUnderlyer, fakeTracked, keccak256("abc"), abi.encode(""));

        // Succeeds when a template is registered
        registerTemplate(templateRegistry, badKey, address(1));
        factory.create("y", address(8), fakeUnderlyer, fakeTracked, keccak256("abc"), abi.encode(""));
    }

    function testCallsInitializeWithProvidedParams() public {
        accessController.grantRole(Roles.CREATE_DESTINATION_VAULT_ROLE, address(this));

        // Fails when it gets address(0)
        bytes32 badKey = keccak256(abi.encode("y"));
        registerTemplate(templateRegistry, badKey, address(0));
        vm.expectRevert(abi.encodeWithSelector(Errors.ZeroAddress.selector, "template"));
        factory.create("y", address(8), fakeUnderlyer, fakeTracked, keccak256("abc"), abi.encode(""));

        // Succeeds when a template is registered
        TestVault tv = new TestVault(systemRegistry);
        registerTemplate(templateRegistry, badKey, address(tv));
        bytes memory data = abi.encode("h");

        vm.expectEmit(true, true, true, true);
        emit Initialized(systemRegistry, data);
        factory.create("y", address(8), fakeUnderlyer, fakeTracked, keccak256("abc"), data);
    }

    function testAddsToRegistry() public {
        accessController.grantRole(Roles.CREATE_DESTINATION_VAULT_ROLE, address(this));

        bytes32 badKey = keccak256(abi.encode("y"));
        bytes32 salt = keccak256("abc");
        registerTemplate(templateRegistry, badKey, address(0));
        vm.expectRevert(abi.encodeWithSelector(Errors.ZeroAddress.selector, "template"));
        factory.create("y", address(8), fakeUnderlyer, fakeTracked, salt, abi.encode(""));

        TestVault tv = new TestVault(systemRegistry);
        registerTemplate(templateRegistry, badKey, address(tv));
        bytes memory data = abi.encode("h");

        address nextAddress = Clones.predictDeterministicAddress(address(tv), salt, address(factory));
        vm.expectCall(vaultRegistry, abi.encodeCall(IDestinationVaultRegistry.register, nextAddress));
        factory.create("y", address(8), fakeUnderlyer, fakeTracked, salt, data);
    }

    function testRewarderEndsUpWithCorrectStakeToken() public {
        accessController.grantRole(Roles.CREATE_DESTINATION_VAULT_ROLE, address(this));
        bytes32 salt = keccak256("abc");
        bytes32 key = keccak256(abi.encode("y"));
        TestVault tv = new TestVault(systemRegistry);
        registerTemplate(templateRegistry, key, address(tv));
        bytes memory data = abi.encode("h");

        address nextAddress = Clones.predictDeterministicAddress(address(tv), salt, address(factory));
        vm.expectCall(vaultRegistry, abi.encodeCall(IDestinationVaultRegistry.register, nextAddress));
        address newVault = factory.create("y", address(8), fakeUnderlyer, fakeTracked, salt, data);

        IMainRewarder rewarder = IMainRewarder(IDestinationVault(newVault).rewarder());
        IStakeTracking stakeToken = rewarder.stakeTracker();

        assertEq(newVault, address(stakeToken));
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
        vm.mockCall(reg, abi.encodeWithSelector(ISystemComponent.getSystemRegistry.selector), abi.encode(sysRegistry));
        return reg;
    }

    function generateVaultRegistry(ISystemRegistry sysRegistry) internal returns (address) {
        address reg = vm.addr(1002);
        vm.mockCall(reg, abi.encodeWithSelector(ISystemComponent.getSystemRegistry.selector), abi.encode(sysRegistry));
        return reg;
    }
}

contract TestVault {
    ISystemRegistry public immutable systemRegistry;

    event Initialized(ISystemRegistry registry, bytes params);

    address public rewarder;

    constructor(ISystemRegistry systemRegistry_) {
        systemRegistry = systemRegistry_;
    }

    function initialize(IERC20, IERC20, IMainRewarder _rewarder, address[] memory, bytes memory params) external {
        emit Initialized(systemRegistry, params);

        rewarder = address(_rewarder);
    }
}
