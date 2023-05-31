// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import { Test, StdCheats, StdUtils } from "forge-std/Test.sol";
import { ISystemRegistry } from "src/interfaces/ISystemRegistry.sol";
import { EthPeggedOracle } from "src/oracles/providers/EthPeggedOracle.sol";

contract EthPeggedOracleTests is Test {
    ISystemRegistry private _systemRegistry;
    EthPeggedOracle private _oracle;

    function setUp() public {
        _systemRegistry = ISystemRegistry(vm.addr(324));
        _oracle = new EthPeggedOracle(_systemRegistry);
    }

    function testBasicPrice(address token) public {
        uint256 price = _oracle.getPriceEth(token);

        assertEq(price, 1e18);
    }
}
