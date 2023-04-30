// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import { Test } from "forge-std/Test.sol";

import { ERC20Mock } from "openzeppelin-contracts/mocks/ERC20Mock.sol";
import { IERC20 } from "openzeppelin-contracts/token/ERC20/IERC20.sol";

import { SystemRegistry } from "src/SystemRegistry.sol";
import { ISystemRegistry } from "src/interfaces/ISystemRegistry.sol";
import { IAccessController, AccessController } from "src/security/AccessController.sol";
import { StrategyFactory } from "src/strategy/StrategyFactory.sol";
import { StakeTrackingMock } from "test/mocks/StakeTrackingMock.sol";
import { IMainRewarder, MainRewarder } from "src/rewarders/MainRewarder.sol";

contract BaseTest is Test {
    mapping(bytes => address) internal _tokens;

    SystemRegistry public systemRegistry;
    IAccessController public accessController;

    // -- tokens -- //
    IERC20 public usdc;
    IERC20 public toke;

    function setUp() public virtual {
        // BEFORE WE DO ANYTHING, FORK!!
        uint256 mainnetFork = vm.createFork(vm.envString("MAINNET_RPC_URL"));
        vm.selectFork(mainnetFork);
        // assertEq(vm.activeFork(), mainnetFork, "forks don't match");

        systemRegistry = new SystemRegistry();

        // set up central permissions registry
        accessController = new AccessController(address(systemRegistry));
        systemRegistry.setAccessController(address(accessController));

        // TODO: export addresses to separate config
        _tokens["USDC"] = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
        _tokens["TOKE"] = 0x2e9d63788249371f1DFC918a52f8d799F4a38C94;

        toke = IERC20(_tokens["TOKE"]);
        usdc = IERC20(_tokens["USDC"]);
    }

    function mockAsset(string memory name, string memory symbol) public returns (ERC20Mock) {
        return new ERC20Mock(name, symbol, address(this), 0);
    }

    function createMainRewarder() public returns (MainRewarder) {
        return new MainRewarder(
            address(new StakeTrackingMock()),
            vm.addr(1),
            address(mockAsset("MAIN_REWARD", "MAIN_REWARD")),
            vm.addr(1),
            800,
            100
        );
    }
}
