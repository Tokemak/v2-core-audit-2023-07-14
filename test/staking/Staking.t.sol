// solhint-disable no-console
// solhint-disable not-rely-on-time
// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import { IGPToke, GPToke, BaseTest } from "test/BaseTest.t.sol";

contract StakingTest is BaseTest {
    uint256 private stakeAmount = 1000;
    uint256 private maxDuration = 1461 days;

    event Stake(address indexed user, uint256 lockupId, uint256 amount, uint256 end, uint256 points);
    event Unstake(address indexed user, uint256 lockupId, uint256 amount, uint256 end, uint256 points);
    event Extend(
        address indexed user, uint256 lockupId, uint256 oldEnd, uint256 newEnd, uint256 oldPoints, uint256 newPoints
    );

    function setUp() public virtual override {
        super.setUp();

        // get some toke
        deal(address(toke), address(this), 1 ether);

        // deploy gpToke
        gpToke = new GPToke(
            systemRegistry,
            address(toke),
            //solhint-disable-next-line not-rely-on-time
            block.timestamp, // start epoch
            MIN_STAKING_DURATION
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
        gpToke.stake(stakeAmount, ONE_YEAR);
        // pause
        gpToke.pause();
        // try to stake again (should revert)
        vm.expectRevert("Pausable: paused");
        gpToke.stake(stakeAmount, ONE_YEAR);
        // unpause
        gpToke.unpause();
        // stake again
        gpToke.stake(stakeAmount, ONE_YEAR);
    }

    function testTransfersDisabled() public {
        vm.expectRevert(IGPToke.TransfersDisabled.selector);
        gpToke.transfer(address(0), 1);
        vm.expectRevert(IGPToke.TransfersDisabled.selector);
        gpToke.transferFrom(address(this), address(0), 1);
    }

    function testPreviewPoints() public {
        (uint256 points, uint256 end) = gpToke.previewPoints(stakeAmount, ONE_YEAR);
        assertEq(points, 1799);
        assertEq(end, block.timestamp + ONE_YEAR);
    }

    function testInvalidDurationsNotAllowed() public {
        // try to stake too short
        vm.expectRevert(IGPToke.StakingDurationTooShort.selector);
        gpToke.stake(stakeAmount, MIN_STAKING_DURATION - 1);
        // try to stake too long
        vm.expectRevert(IGPToke.StakingDurationTooLong.selector);
        gpToke.stake(stakeAmount, maxDuration + 1);
    }

    function testSetMaxDuration() public {
        // regular stake for two years
        gpToke.stake(stakeAmount, 2 * ONE_YEAR);
        // change staking duration to shorter, try staking again (should fail)
        gpToke.setMaxStakeDuration(ONE_YEAR);
        vm.expectRevert();
        gpToke.stake(stakeAmount, 2 * ONE_YEAR);
    }

    function testStakingAndUnstaking() public {
        //
        // stake
        //
        stake(ONE_YEAR);

        IGPToke.Lockup[] memory lockups = gpToke.getLockups(address(this));
        assert(lockups.length == 1);

        uint256 lockupId = 0;
        IGPToke.Lockup memory lockup = lockups[lockupId];

        assertEq(lockup.amount, stakeAmount);
        assertEq(lockup.end, block.timestamp + ONE_YEAR);

        // voting power
        assertEq(gpToke.balanceOf(address(this)), stakeAmount * 18 / 10 - 1);

        //
        // Unstake
        //

        // make sure can't unstake too early
        vm.warp(block.timestamp + ONE_YEAR - 1);
        vm.expectRevert(IGPToke.NotUnlockableYet.selector);
        gpToke.unstake(lockupId);
        // get to proper timestamp and unlock
        vm.warp(block.timestamp + 1);
        gpToke.unstake(lockupId);
    }

    function testStakingMultipleTimePeriods() public {
        // stake 1: 2 years lockup
        stake(2 * ONE_YEAR);
        // stake 2: 1 year lockup
        warpAndStake(ONE_YEAR, ONE_YEAR);
        // voting power should be identical
        IGPToke.Lockup[] memory lockups = gpToke.getLockups(address(this));
        assert(lockups.length == 2);
        assertEq(lockups[0].points, lockups[1].points, "Lockup points should be identical");

        // unstake first lock (try without warp first)
        vm.expectRevert(IGPToke.NotUnlockableYet.selector);
        gpToke.unstake(0);

        warpAndUnstake(ONE_YEAR, 0);

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
        stake(ONE_YEAR);
        (uint256 amountBefore,, uint256 pointsBefore) = gpToke.lockups(address(this), 0);
        // extend to 2 years
        vm.expectEmit(true, false, false, false);
        emit Extend(address(this), 0, 0, 0, 0, 0);
        gpToke.extend(0, 2 * ONE_YEAR);
        // verify that duration (and points) increased
        IGPToke.Lockup memory lockup = gpToke.getLockups(address(this))[0];
        assertEq(lockup.amount, amountBefore);
        assertEq(lockup.end, block.timestamp + 2 * ONE_YEAR);
        assert(lockup.points > pointsBefore);
    }

    function stake(uint256 stakeTimespan) private {
        vm.expectEmit(true, false, false, false);
        emit Stake(address(this), 0, 0, 0, 0);
        gpToke.stake(stakeAmount, stakeTimespan);
    }

    function warpAndStake(uint256 warpTimespan, uint256 stakeTimespan) private {
        vm.warp(block.timestamp + warpTimespan);
        vm.expectEmit(true, false, false, false);
        emit Stake(address(this), 0, 0, 0, 0);
        gpToke.stake(stakeAmount, stakeTimespan);
    }

    function warpAndUnstake(uint256 warpTimespan, uint256 lockupId) private {
        vm.expectEmit(true, false, false, false);
        emit Unstake(address(this), 0, 0, 0, 0);
        vm.warp(block.timestamp + warpTimespan);
        gpToke.unstake(lockupId);
    }
}
