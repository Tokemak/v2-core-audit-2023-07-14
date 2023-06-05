// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import { IERC20 } from "openzeppelin-contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "openzeppelin-contracts/token/ERC20/utils/SafeERC20.sol";
import { ReentrancyGuard } from "openzeppelin-contracts/security/ReentrancyGuard.sol";

import { ISystemRegistry } from "src/interfaces/ISystemRegistry.sol";

import { IStakeTracking } from "../interfaces/rewarders/IStakeTracking.sol";
import { IExtraRewarder } from "../interfaces/rewarders/IExtraRewarder.sol";
import { AbstractRewarder } from "./AbstractRewarder.sol";

import { Errors } from "src/utils/Errors.sol";

contract ExtraRewarder is AbstractRewarder, IExtraRewarder, ReentrancyGuard {
    address public immutable mainReward;

    error MainRewardOnly();

    constructor(
        ISystemRegistry _systemRegistry,
        address _stakeTracker,
        address _operator,
        address _rewardToken,
        address _mainReward,
        uint256 _newRewardRatio,
        uint256 _durationInBlock,
        address _gpTokeAddress
    )
        AbstractRewarder(
            _systemRegistry,
            _stakeTracker,
            _operator,
            _rewardToken,
            _newRewardRatio,
            _durationInBlock,
            _gpTokeAddress
        )
    {
        Errors.verifyNotZero(_mainReward, "_mainReward");

        // slither-disable-next-line missing-zero-check
        mainReward = _mainReward;
    }

    modifier mainRewardOnly() {
        if (msg.sender != mainReward) {
            revert MainRewardOnly();
        }
        _;
    }

    function stake(address account, uint256 amount) external mainRewardOnly {
        _updateReward(account);
        _stake(account, amount);
    }

    function withdraw(address account, uint256 amount) external mainRewardOnly {
        _updateReward(account);
        _withdraw(account, amount);
    }

    function getReward(address account) public nonReentrant {
        _updateReward(account);
        _getReward(account);
    }

    function getReward() external {
        getReward(msg.sender);
    }
}
