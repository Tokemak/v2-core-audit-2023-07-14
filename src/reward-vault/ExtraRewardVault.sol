// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import { IERC20 } from "openzeppelin-contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "openzeppelin-contracts/token/ERC20/utils/SafeERC20.sol";

import { IStakeTracking } from "../interfaces/reward-vault/IStakeTracking.sol";
import { IExtraReward } from "../interfaces/reward-vault/IExtraReward.sol";
import { AbstractRewardVault } from "./AbstractRewardVault.sol";

contract ExtraRewardVault is AbstractRewardVault, IExtraReward {
    address public immutable mainReward;

    error MainRewardOnly();

    constructor(
        address _stakeTracker,
        address _operator,
        address _rewardToken,
        address _mainReward
    ) AbstractRewardVault(_stakeTracker, _operator, _rewardToken) {
        if (_mainReward == address(0)) {
            revert ZeroAddress();
        }
        mainReward = _mainReward;
    }

    modifier mainRewardOnly() {
        if (msg.sender != mainReward) {
            revert MainRewardOnly();
        }
        _;
    }

    function stake(address account, uint256 amount) public mainRewardOnly updateReward(account) {
        _stake(account, amount);
    }

    function withdraw(address account, uint256 amount) public mainRewardOnly updateReward(account) {
        _withdraw(account, amount);
    }

    function getReward(address account) public updateReward(account) {
        _getReward(account);
    }

    function getReward() public {
        getReward(msg.sender);
    }
}
