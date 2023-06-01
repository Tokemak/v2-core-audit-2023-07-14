// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

//import { console } from "forge-std/console.sol";

import { SFRXETH_MAINNET } from "test/utils/Addresses.sol";
import { Test, StdCheats, StdUtils } from "forge-std/Test.sol";
import { ISfrxEth } from "src/interfaces/external/frax/ISfrxEth.sol";
import { ISystemRegistry } from "src/interfaces/ISystemRegistry.sol";
import { SfrxEthEthOracle } from "src/oracles/providers/SfrxEthEthOracle.sol";
import { IRootPriceOracle } from "src/interfaces/oracles/IRootPriceOracle.sol";
import { IERC20Metadata } from "openzeppelin-contracts/token/ERC20/extensions/IERC20Metadata.sol";

contract SfrxEthEthOracleTests is Test {
    uint256 private _addrIx;

    IRootPriceOracle private _rootPriceOracle;
    ISystemRegistry private _systemRegistry;
    SfrxEthEthOracle private _oracle;
    ISfrxEth private _sfrxETH;

    function setUp() public {
        uint256 mainnetFork = vm.createFork(vm.envString("MAINNET_RPC_URL"), 17_378_229);
        vm.selectFork(mainnetFork);

        _rootPriceOracle = IRootPriceOracle(vm.addr(324));
        _systemRegistry = _generateSystemRegistry(address(_rootPriceOracle));
        _oracle = new SfrxEthEthOracle(_systemRegistry, SFRXETH_MAINNET);
        _sfrxETH = ISfrxEth(SFRXETH_MAINNET);
    }

    function testBasicPrice() public {
        _mockRootPrice(_sfrxETH.asset(), 998_907_980_000_000_000);
        uint256 price = _oracle.getPriceInEth(address(_sfrxETH));

        assertApproxEqAbs(price, 1_041_589_000_000_000_000, 5e16);
    }

    function testOnlySftxEth() public {
        address fakeAddr = vm.addr(34_343);
        vm.expectRevert(abi.encodeWithSelector(SfrxEthEthOracle.InvalidToken.selector, fakeAddr));
        _oracle.getPriceInEth(address(fakeAddr));
    }

    function _generateToken(uint8 decimals) internal returns (address) {
        address addr = vm.addr(239_874 + _addrIx++);
        vm.mockCall(addr, abi.encodeWithSelector(IERC20Metadata.decimals.selector), abi.encode(decimals));
        return addr;
    }

    function _mockRootPrice(address token, uint256 price) internal {
        vm.mockCall(
            address(_rootPriceOracle),
            abi.encodeWithSelector(IRootPriceOracle.getPriceInEth.selector, token),
            abi.encode(price)
        );
    }

    function _generateSystemRegistry(address rootOracle) internal returns (ISystemRegistry) {
        address registry = vm.addr(327_849);
        vm.mockCall(registry, abi.encodeWithSelector(ISystemRegistry.rootPriceOracle.selector), abi.encode(rootOracle));
        return ISystemRegistry(registry);
    }
}
