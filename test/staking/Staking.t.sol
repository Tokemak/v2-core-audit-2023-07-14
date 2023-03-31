// solhint-disable no-console
// solhint-disable not-rely-on-time
// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import { BaseTest } from "test/BaseTest.t.sol";
import { GPToke } from "src/staking/GPToke.sol";
import { IGPToke } from "src/interfaces/staking/IGPToke.sol";
// import { PRANK_ADDRESS } from "../utils/Addresses.sol";

contract StakingTest is BaseTest {
    GPToke private gpToke;
    uint256 private stakeAmount = 1000;
    uint256 private minDuration = 30 days;
    uint256 private maxDuration = 1461 days;
    uint256 private oneYear = 365 days;
    uint256 private oneMonth = 30 days;

    function setUp() public virtual override {
        super.setUp();

        string memory endpoint = vm.envString("MAINNET_RPC_URL");
        uint256 forkId = vm.createFork(endpoint, 16_770_565);
        vm.selectFork(forkId);

        // get some toke
        deal(address(toke), address(this), 1 ether);

        // deploy gpToke
        gpToke = new GPToke(
            address(toke),
            //solhint-disable-next-line not-rely-on-time
            block.timestamp, // start epoch
            minDuration
        );

        assertEq(gpToke.name(), "Staked Toke");
        assertEq(gpToke.symbol(), "gpToke");

        // approve future spending
        toke.approve(address(gpToke), toke.balanceOf(address(this)));
    }

    function testStakingCanBePaused() public {
        // make sure not paused
        assertEq(gpToke.paused(), false);
        // stake
        gpToke.stake(stakeAmount, oneYear);
        // pause
        gpToke.pause();
        // try to stake again (should revert)
        vm.expectRevert("Pausable: paused");
        gpToke.stake(stakeAmount, oneYear);
        // unpause
        gpToke.unpause();
        // stake again
        gpToke.stake(stakeAmount, oneYear);
    }

    function testTransfersDisabled() public {
        vm.expectRevert(IGPToke.TransfersDisabled.selector);
        gpToke.transfer(address(0), 1);
        vm.expectRevert(IGPToke.TransfersDisabled.selector);
        gpToke.transferFrom(address(this), address(0), 1);
    }

    function testPreviewPoints() public {
        (uint256 points, uint256 end) = gpToke.previewPoints(stakeAmount, oneYear);
        assertEq(points, 1799);
        assertEq(end, block.timestamp + oneYear);
    }

    function testInvalidDurationsNotAllowed() public {
        // try to stake too short
        vm.expectRevert(IGPToke.StakingDurationTooShort.selector);
        gpToke.stake(stakeAmount, minDuration - 1);
        // try to stake too long
        vm.expectRevert(IGPToke.StakingDurationTooLong.selector);
        gpToke.stake(stakeAmount, maxDuration + 1);
    }

    function testStakingAndUnstaking() public {
        //
        // stake
        //
        stake(oneYear);

        IGPToke.Lockup[] memory lockups = gpToke.getLockups(address(this));
        assert(lockups.length == 1);

        uint256 lockupId = 0;
        IGPToke.Lockup memory lockup = lockups[lockupId];

        assertEq(lockup.amount, stakeAmount);
        assertEq(lockup.end, block.timestamp + oneYear);

        // voting power
        assertEq(gpToke.balanceOf(address(this)), stakeAmount * 18 / 10 - 1);

        //
        // Unstake
        //

        // make sure can't unstake too early
        vm.warp(block.timestamp + oneYear - 1);
        vm.expectRevert(IGPToke.NotUnlockableYet.selector);
        gpToke.unstake(lockupId);
        // get to proper timestamp and unlock
        vm.warp(block.timestamp + 1);
        gpToke.unstake(lockupId);
    }

    function testStakingMultipleTimePeriods() public {
        // stake 1: 2 years lockup
        stake(2 * oneYear);
        // stake 2: 1 year lockup
        warpAndStake(oneYear, oneYear);
        // voting power should be identical
        IGPToke.Lockup[] memory lockups = gpToke.getLockups(address(this));
        assert(lockups.length == 2);
        assertEq(lockups[0].points, lockups[1].points, "Lockup points should be identical");

        // unstake first lock (try without warp first)
        vm.expectRevert(IGPToke.NotUnlockableYet.selector);
        gpToke.unstake(0);

        warpAndUnstake(oneYear, 0);

        IGPToke.Lockup memory lockup0 = gpToke.getLockups(address(this))[0];
        assertEq(lockup0.amount, 0);
        assertEq(lockup0.points, 0);

        // unstake second lock
        gpToke.unstake(1);
        IGPToke.Lockup memory lockup1 = gpToke.getLockups(address(this))[1];
        assertEq(lockup1.amount, 0);
        assertEq(lockup1.points, 0);
        assertEq(gpToke.balanceOf(address(this)), 0);
    }

    function testExtend() public {
        // original stake
        stake(oneYear);
        (uint256 amountBefore,, uint256 pointsBefore) = gpToke.lockups(address(this), 0);
        // extend to 2 years
        gpToke.extend(0, 2 * oneYear);
        // verify that duration (and points) increased
        IGPToke.Lockup memory lockup = gpToke.getLockups(address(this))[0];
        assertEq(lockup.amount, amountBefore);
        assertEq(lockup.end, block.timestamp + 2 * oneYear);
        assert(lockup.points > pointsBefore);
    }

    function stake(uint256 stakeTimespan) private {
        gpToke.stake(stakeAmount, stakeTimespan);
    }

    function warpAndStake(uint256 warpTimespan, uint256 stakeTimespan) private {
        vm.warp(block.timestamp + warpTimespan);
        gpToke.stake(stakeAmount, stakeTimespan);
    }

    function warpAndUnstake(uint256 warpTimespan, uint256 lockupId) private {
        vm.warp(block.timestamp + warpTimespan);
        gpToke.unstake(lockupId);
    }
}
