// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

// solhint-disable func-name-mixedcase

import { Test } from "forge-std/Test.sol";
import { WSTETH_MAINNET } from "test/utils/Addresses.sol";

import { WstEthValueProvider } from "src/pricing/value-providers/WstEthValueProvider.sol";

contract WstEthValueProviderTest is Test {
    error MustBeEthValueOracle();

    event WstEthSet(address _wstEth);

    function setUp() external {
        vm.createSelectFork(vm.envString("MAINNET_RPC_URL"));
    }

    function test_Constructor() external {
        vm.expectEmit(false, false, false, true);
        emit WstEthSet(WSTETH_MAINNET);

        WstEthValueProvider wstEthValueProvider = new WstEthValueProvider(WSTETH_MAINNET, address(1));

        assertEq(address(wstEthValueProvider.wstEth()), WSTETH_MAINNET);
    }

    // Test onlyValueOracle
    function test_OnlyValueOracleRevert() external {
        WstEthValueProvider wstEthValueProvider = new WstEthValueProvider(WSTETH_MAINNET, address(1));

        vm.expectRevert(MustBeEthValueOracle.selector);
        wstEthValueProvider.getPrice(address(0));
    }
}
