// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2023 Tokemak Foundation. All rights reserved.
pragma solidity 0.8.17;

import { Test } from "forge-std/Test.sol";
import { CurveUtils } from "src/stats/utils/CurveUtils.sol";
import { Stats } from "src/stats/Stats.sol";
import { RETH_MAINNET, USDC_MAINNET } from "test/utils/Addresses.sol";

contract CurveUtilsTest is Test {
    function setUp() public {
        vm.createSelectFork(vm.envString("MAINNET_RPC_URL"));
    }

    function testGetDecimals() public {
        uint256 curveEthDecimals = CurveUtils.getDecimals(Stats.CURVE_ETH);
        assertEq(curveEthDecimals, 18);

        uint256 rEthDecimals = CurveUtils.getDecimals(RETH_MAINNET);
        assertEq(rEthDecimals, 18);

        uint256 usdcDecimals = CurveUtils.getDecimals(USDC_MAINNET);
        assertEq(usdcDecimals, 6);
    }
}
