// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2023 Tokemak Foundation. All rights reserved.

pragma solidity 0.8.17;

import { Test } from "forge-std/Test.sol";
import { IERC20 } from "openzeppelin-contracts/token/ERC20/IERC20.sol";

import { Errors } from "src/utils/Errors.sol";
import { MaverickRewardsAdapter } from "src/destinations/adapters/rewards/MaverickRewardsAdapter.sol";
import { IReward } from "src/interfaces/external/maverick/IReward.sol";
import { LDO_MAINNET } from "test/utils/Addresses.sol";

// solhint-disable func-name-mixedcase
contract MaverickRewardsAdapterTest is Test {
    MaverickRewardsAdapter private _adapter;

    address private constant _REWARDER = 0x14edfe68031bBf229a765919EB52AE6F6F3347d4;
    IERC20 private constant _STACKING_TOKEN = IERC20(0xa2B4e72A9d2d3252DA335cB50e393f44a9f104eE);

    function _stakeForAdapter(uint256 amount) internal {
        deal(address(_STACKING_TOKEN), address(_adapter), amount);

        vm.startPrank(address(_adapter));

        _STACKING_TOKEN.approve(address(_REWARDER), amount);
        IReward(_REWARDER).stake(amount, address(_adapter));

        vm.stopPrank();

        // Move 7 days later
        vm.roll(block.number + 7200 * 7);
        // solhint-disable-next-line not-rely-on-time
        vm.warp(block.timestamp + 7 days);
    }

    function setUp() public {
        vm.createSelectFork(vm.envString("MAINNET_RPC_URL"));

        _adapter = new MaverickRewardsAdapter();

        _stakeForAdapter(1e18);
    }

    function test_Revert_IfAddressZero() public {
        vm.expectRevert(abi.encodeWithSelector(Errors.ZeroAddress.selector, "rewarder"));
        _adapter.claimRewards(address(0));
    }

    function test_claimRewards_Successful() public {
        (uint256[] memory amountsClaimed, IERC20[] memory rewardsToken) = _adapter.claimRewards(_REWARDER);

        // check based on previous execution
        assertEq(rewardsToken.length, 2);
        assertEq(address(rewardsToken[1]), LDO_MAINNET);
        assertTrue(amountsClaimed[1] > 0);
    }
}
