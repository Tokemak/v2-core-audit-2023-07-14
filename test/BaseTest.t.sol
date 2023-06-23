// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import { Test } from "forge-std/Test.sol";

import { ERC20Mock } from "openzeppelin-contracts/mocks/ERC20Mock.sol";
import { IERC20 } from "openzeppelin-contracts/token/ERC20/IERC20.sol";
import { IWETH9 } from "src/interfaces/utils/IWETH9.sol";
import { ISystemRegistry, SystemRegistry } from "src/SystemRegistry.sol";
import { ILMPVaultRegistry, LMPVaultRegistry } from "src/vault/LMPVaultRegistry.sol";
import { ILMPVaultRouter, LMPVaultRouter } from "src/vault/LMPVaultRouter.sol";
import { ILMPVaultFactory, LMPVaultFactory } from "src/vault/LMPVaultFactory.sol";
import { IDestinationVaultRegistry, DestinationVaultRegistry } from "src/vault/DestinationVaultRegistry.sol";
import { IDestinationVaultFactory, DestinationVaultFactory } from "src/vault/DestinationVaultFactory.sol";
import { TestDestinationVault } from "test/mocks/TestDestinationVault.sol";
import { IAccessController, AccessController } from "src/security/AccessController.sol";
import { StrategyFactory } from "src/strategy/StrategyFactory.sol";
import { StakeTrackingMock } from "test/mocks/StakeTrackingMock.sol";
import { IMainRewarder, MainRewarder } from "src/rewarders/MainRewarder.sol";

import { IGPToke, GPToke } from "src/staking/GPToke.sol";

import { VaultTypes } from "src/vault/VaultTypes.sol";
import { Roles } from "src/libs/Roles.sol";
import { TOKE_MAINNET, USDC_MAINNET, WETH_MAINNET } from "test/utils/Addresses.sol";

contract BaseTest is Test {
    mapping(bytes => address) internal _tokens;

    SystemRegistry public systemRegistry;

    LMPVaultRegistry public lmpVaultRegistry;
    LMPVaultRouter public lmpVaultRouter;
    ILMPVaultFactory public lmpVaultFactory;

    DestinationVaultRegistry public destinationVaultRegistry;
    DestinationVaultFactory public destinationVaultFactory;

    TestDestinationVault public testDestinationVault;

    IAccessController public accessController;

    // -- Staking -- //
    GPToke public gpToke;
    uint256 public constant MIN_STAKING_DURATION = 30 days;

    // -- tokens -- //
    IERC20 public usdc;
    IERC20 public toke;
    IWETH9 public weth;

    // -- generally useful values -- //
    uint256 internal constant ONE_YEAR = 365 days;
    uint256 internal constant ONE_MONTH = 30 days;

    bool internal toFork = true;

    function setUp() public virtual {
        if (toFork) {
            fork();
        }

        //////////////////////////////////////
        // Set up misc values
        //////////////////////////////////////

        toke = IERC20(TOKE_MAINNET);
        usdc = IERC20(USDC_MAINNET);
        weth = IWETH9(WETH_MAINNET);

        //////////////////////////////////////
        // Set up system registry
        //////////////////////////////////////

        systemRegistry = new SystemRegistry(TOKE_MAINNET, WETH_MAINNET);

        accessController = new AccessController(address(systemRegistry));
        systemRegistry.setAccessController(address(accessController));
        lmpVaultRegistry = new LMPVaultRegistry(systemRegistry);
        systemRegistry.setLMPVaultRegistry(address(lmpVaultRegistry));
        lmpVaultRouter = new LMPVaultRouter(systemRegistry, WETH_MAINNET);
        systemRegistry.setLMPVaultRouter(address(lmpVaultRouter));
        lmpVaultFactory = new LMPVaultFactory(systemRegistry);
        systemRegistry.setLMPVaultFactory(VaultTypes.LST, address(lmpVaultFactory));
        // NOTE: deployer grants factory permission to update the registry
        accessController.grantRole(Roles.REGISTRY_UPDATER, address(lmpVaultFactory));

        // NOTE: these pieces were taken out so that each set of tests can init only the components it needs!
        //       Saves a ton of unnecessary setup time and makes fuzzing tests run much much faster
        //       (since these unnecessary (in those cases) setup times add up)
        //       (Left the code for future reference)
        // lmpVaultRegistry = new LMPVaultRegistry(systemRegistry);
        // systemRegistry.setLMPVaultRegistry(address(lmpVaultRegistry));
        // lmpVaultRouter = new LMPVaultRouter(WETH_MAINNET);
        // systemRegistry.setLMPVaultRouter(address(lmpVaultRouter));
        // lmpVaultFactory = new LMPVaultFactory(systemRegistry);
        // systemRegistry.setLMPVaultFactory(VaultTypes.LST, address(lmpVaultFactory));
        // // NOTE: deployer grants factory permission to update the registry
        // accessController.grantRole(Roles.REGISTRY_UPDATER, address(lmpVaultFactory));
    }

    function fork() internal {
        // BEFORE WE DO ANYTHING, FORK!!
        uint256 mainnetFork = vm.createFork(vm.envString("MAINNET_RPC_URL"));
        vm.selectFork(mainnetFork);
        assertEq(vm.activeFork(), mainnetFork, "forks don't match");
    }

    function mockAsset(string memory name, string memory symbol, uint256 initialBalance) public returns (ERC20Mock) {
        ERC20Mock newMock = new ERC20Mock(name, symbol, address(this), 0);

        if (initialBalance > 0) {
            deal(address(newMock), msg.sender, initialBalance);
        }

        return newMock;
    }

    function createMainRewarder(address asset) public returns (MainRewarder) {
        return createMainRewarder(asset, address(new StakeTrackingMock()));
    }

    function createMainRewarder(address asset, address lmpVault) public returns (MainRewarder) {
        return new MainRewarder(
            systemRegistry, // registry
            lmpVault, // stakeTracker
            asset, // address(mockAsset("MAIN_REWARD", "MAIN_REWARD", 0)), // rewardToken
            800, // newRewardRatio
            100 // durationInBlock
        );
    }

    function deployGpToke() public {
        if (address(gpToke) != address(0)) return;

        gpToke = new GPToke(
            systemRegistry,
            address(toke),
            //solhint-disable-next-line not-rely-on-time
            block.timestamp, // start epoch
            MIN_STAKING_DURATION
        );

        systemRegistry.setGPToke(address(gpToke));
    }

    function deployLMPVaultRegistry() public {
        if (address(lmpVaultRegistry) != address(0)) return;

        lmpVaultRegistry = new LMPVaultRegistry(systemRegistry);
        systemRegistry.setLMPVaultRegistry(address(lmpVaultRegistry));
    }

    function deployLMPVaultRouter() public {
        if (address(lmpVaultRouter) != address(0)) return;

        lmpVaultRouter = new LMPVaultRouter(systemRegistry, WETH_MAINNET);
        systemRegistry.setLMPVaultRouter(address(lmpVaultRouter));
    }

    function deployLMPVaultFactory() public {
        if (address(lmpVaultFactory) != address(0)) return;

        lmpVaultFactory = new LMPVaultFactory(systemRegistry);
        systemRegistry.setLMPVaultFactory(VaultTypes.LST, address(lmpVaultFactory));
        // NOTE: deployer grants factory permission to update the registry
        accessController.grantRole(Roles.REGISTRY_UPDATER, address(lmpVaultFactory));
    }
}
