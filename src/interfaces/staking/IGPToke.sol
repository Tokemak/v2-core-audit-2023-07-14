// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import { IERC20 } from "openzeppelin-contracts/token/ERC20/IERC20.sol";
import { ERC20 } from "openzeppelin-contracts/token/ERC20/ERC20.sol";

interface IGPToke {
    ///////////////////////////////////////////////////////////////////
    //                        Variables
    ///////////////////////////////////////////////////////////////////

    function startEpoch() external view returns (uint256);
    function minStakeDuration() external view returns (uint256);

    struct Lockup {
        uint128 amount;
        uint128 end;
        uint256 points;
    }

    function getLockups(address user) external view returns (Lockup[] memory);
    function toke() external view returns (ERC20);

    ///////////////////////////////////////////////////////////////////
    //                        Errors
    ///////////////////////////////////////////////////////////////////

    error StakingDurationTooShort();
    error StakingDurationTooLong();
    error StakingPointsExceeded();
    error StakingAmountExceeded();
    error StakingAmountInsufficient();
    error InsufficientFunds();
    error LockupDoesNotExist();
    error NotUnlockableYet();
    error AlreadyUnlocked();
    error ExtendDurationTooShort();
    error TransfersDisabled();
    error TransferFailed();
    error ZeroAddress();

    ///////////////////////////////////////////////////////////////////
    //                        Events
    ///////////////////////////////////////////////////////////////////
    event Stake(address indexed user, uint256 lockupId, uint256 amount, uint256 end, uint256 points);
    event Unstake(address indexed user, uint256 lockupId, uint256 amount, uint256 end, uint256 points);
    event Extend(
        address indexed user, uint256 lockupId, uint256 oldEnd, uint256 newEnd, uint256 oldPoints, uint256 newPoints
    );

    ///////////////////////////////////////////////////////////////////
    //
    //                        Methods
    //
    ///////////////////////////////////////////////////////////////////

    /**
     * @notice Stake TOKE to an address that may not be the same as the sender of the funds. This can be used to give
     * staked funds to someone else.
     *
     * If staking before the start of staking (epoch), then the lockup start and end dates are shifted forward so that
     * the lockup starts at the epoch.
     *
     * @param amount TOKE to lockup in the stake
     * @param duration in seconds for the stake
     * @param to address to receive ownership of the stake
     */
    function stake(uint256 amount, uint256 duration, address to) external;

    /**
     * @notice Stake TOKE
     *
     * If staking before the start of staking (epoch), then the lockup start and end dates are shifted forward so that
     * the lockup starts at the epoch.
     *
     * @notice Stake TOKE for myself.
     * @param amount TOKE to lockup in the stake
     * @param duration in seconds for the stake
     */
    function stake(uint256 amount, uint256 duration) external;

    /**
     * @notice Collect staked OGV for a lockup and any earned rewards.
     * @param lockupId the id of the lockup to unstake
     */
    function unstake(uint256 lockupId) external;

    /**
     * @notice Extend a stake lockup for additional points.
     *
     * The stake end time is computed from the current time + duration, just like it is for new stakes. So a new stake
     * for seven days duration and an old stake extended with a seven days duration would have the same end.
     *
     * If an extend is made before the start of staking, the start time for the new stake is shifted forwards to the
     * start of staking, which also shifts forward the end date.
     *
     * @param lockupId the id of the old lockup to extend
     * @param duration number of seconds from now to stake for
     */
    function extend(uint256 lockupId, uint256 duration) external;

    /**
     * @notice Preview the number of points that would be returned for the
     * given amount and duration.
     *
     * @param amount TOKE to be staked
     * @param duration number of seconds to stake for
     * @return points staking points that would be returned
     * @return end staking period end date
     */
    function previewPoints(uint256 amount, uint256 duration) external view returns (uint256, uint256);
}
