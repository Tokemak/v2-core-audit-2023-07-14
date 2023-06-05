// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import { Test } from "forge-std/Test.sol";

import { ERC20Mock } from "openzeppelin-contracts/mocks/ERC20Mock.sol";
import { IERC20 } from "openzeppelin-contracts/token/ERC20/IERC20.sol";

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
import { WETH9_ADDRESS } from "test/utils/Addresses.sol";

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
    uint256 public minStakingDuration = 30 days;

    // -- tokens -- //
    IERC20 public usdc;
    IERC20 public toke;

    // -- generally useful values -- //
    uint256 internal oneYear = 365 days;
    uint256 internal oneMonth = 30 days;

    function setUp() public virtual {
        // BEFORE WE DO ANYTHING, FORK!!
        uint256 mainnetFork = vm.createFork(vm.envString("MAINNET_RPC_URL"));
        vm.selectFork(mainnetFork);
        assertEq(vm.activeFork(), mainnetFork, "forks don't match");

        //////////////////////////////////////
        // Set up system registry
        //////////////////////////////////////

        systemRegistry = new SystemRegistry();

        accessController = new AccessController(address(systemRegistry));
        systemRegistry.setAccessController(address(accessController));
        lmpVaultRegistry = new LMPVaultRegistry(systemRegistry);
        systemRegistry.setLMPVaultRegistry(address(lmpVaultRegistry));
        lmpVaultRouter = new LMPVaultRouter(WETH9_ADDRESS);
        systemRegistry.setLMPVaultRouter(address(lmpVaultRouter));
        lmpVaultFactory = new LMPVaultFactory(systemRegistry);
        systemRegistry.setLMPVaultFactory(VaultTypes.LST, address(lmpVaultFactory));
        // NOTE: deployer grants factory permission to update the registry
        accessController.grantRole(Roles.REGISTRY_UPDATER, address(lmpVaultFactory));

        //////////////////////////////////////
        // Set up misc values
        //////////////////////////////////////

        // TODO: export addresses to separate config
        _tokens["USDC"] = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
        _tokens["TOKE"] = 0x2e9d63788249371f1DFC918a52f8d799F4a38C94;

        toke = IERC20(_tokens["TOKE"]);
        usdc = IERC20(_tokens["USDC"]);
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
            100, // durationInBlock
            address(gpToke) // gpToke
        );
    }

    function deployGpToke() public {
        if (address(gpToke) != address(0)) return;

        gpToke = new GPToke(
            address(toke),
            //solhint-disable-next-line not-rely-on-time
            block.timestamp, // start epoch
            minStakingDuration,
            address(accessController)
        );
    }
}
