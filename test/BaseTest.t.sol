// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import { Test } from "forge-std/Test.sol";

import { ERC20Mock } from "openzeppelin-contracts/mocks/ERC20Mock.sol";
import { IERC20 } from "openzeppelin-contracts/token/ERC20/IERC20.sol";
import { IWETH9 } from "src/interfaces/utils/IWETH9.sol";
import { ISystemBound } from "src/interfaces/ISystemBound.sol";
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

    function setUp() public virtual {
        // BEFORE WE DO ANYTHING, FORK!!
        uint256 mainnetFork = vm.createFork(vm.envString("MAINNET_RPC_URL"));
        vm.selectFork(mainnetFork);
        assertEq(vm.activeFork(), mainnetFork, "forks don't match");

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
        lmpVaultRouter = new LMPVaultRouter(WETH_MAINNET);
        systemRegistry.setLMPVaultRouter(address(lmpVaultRouter));
        lmpVaultFactory = new LMPVaultFactory(systemRegistry);
        systemRegistry.setLMPVaultFactory(VaultTypes.LST, address(lmpVaultFactory));
        // NOTE: deployer grants factory permission to update the registry
        accessController.grantRole(Roles.REGISTRY_UPDATER, address(lmpVaultFactory));
    }

    function mockAsset(string memory name, string memory symbol, uint256 initialBalance) public returns (ERC20Mock) {
        ERC20Mock newMock = new ERC20Mock(name, symbol, address(this), 0);

        if (initialBalance > 0) {
            deal(address(newMock), msg.sender, initialBalance);
        }

        return newMock;
    }

    function createMainRewarder() public returns (MainRewarder) {
        if (address(gpToke) == address(0)) {
            deployGpToke();
        }

        return new MainRewarder(
            systemRegistry, // registry
            address(new StakeTrackingMock()), // stakeTracker
            vm.addr(1), // operator
            address(mockAsset("MAIN_REWARD", "MAIN_REWARD", 0)), // rewardToken
            800, // newRewardRatio
            100 // durationInBlock
        );
    }

    function deployGpToke() public {
        if (address(gpToke) != address(0)) return;

        gpToke = new GPToke(
            address(toke),
            //solhint-disable-next-line not-rely-on-time
            block.timestamp, // start epoch
            MIN_STAKING_DURATION,
            address(accessController)
        );
    }
}
