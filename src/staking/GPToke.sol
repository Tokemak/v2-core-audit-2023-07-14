// solhint-disable not-rely-on-time
// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import { ERC20 } from "openzeppelin-contracts/token/ERC20/ERC20.sol";
import { ERC20Votes } from "openzeppelin-contracts/token/ERC20/extensions/ERC20Votes.sol";
import { ERC20Permit } from "openzeppelin-contracts/token/ERC20/extensions/draft-ERC20Permit.sol";
import { Ownable } from "openzeppelin-contracts/access/Ownable.sol";
import { ReentrancyGuard } from "openzeppelin-contracts/security/ReentrancyGuard.sol";
import { Pausable } from "openzeppelin-contracts/security/Pausable.sol";

import { PRBMathUD60x18 } from "prb-math/contracts/PRBMathUD60x18.sol";

import { IGPToke } from "src/interfaces/staking/IGPToke.sol";

contract GPToke is IGPToke, ERC20Votes, Ownable, ReentrancyGuard, Pausable {
    // variables
    uint256 public immutable startEpoch;
    uint256 public immutable minStakeDuration;

    mapping(address => Lockup[]) public lockups;

    uint256 private constant YEAR_BASE_BOOST = 18e17;

    ERC20 public immutable toke;

    constructor(
        address _toke,
        uint256 _startEpoch,
        uint256 _minStakeDuration
    ) ERC20("Staked Toke", "gpToke") ERC20Permit("gpToke") {
        if (_toke == address(0)) revert ZeroAddress();

        toke = ERC20(_toke);
        startEpoch = _startEpoch;
        minStakeDuration = _minStakeDuration;
    }

    // short-circuit transfers
    function transfer(address, uint256) public pure override returns (bool) {
        revert TransfersDisabled();
    }

    function transferFrom(address, address, uint256) public pure override returns (bool) {
        revert TransfersDisabled();
    }

    /// @inheritdoc IGPToke
    function stake(uint256 amount, uint256 duration, address to) external nonReentrant {
        _stake(amount, duration, to);
    }

    /// @inheritdoc IGPToke
    function stake(uint256 amount, uint256 duration) external nonReentrant {
        _stake(amount, duration, msg.sender);
    }

    function _stake(uint256 amount, uint256 duration, address to) internal whenNotPaused {
        if (to == address(0)) revert ZeroAddress();
        if (amount > type(uint128).max) revert StakingAmountExceeded();
        if (amount == 0) revert StakingAmountInsufficient();
        if (amount > toke.balanceOf(msg.sender)) revert InsufficientFunds();

        // duration checked inside previewPoints
        (uint256 points, uint256 end) = previewPoints(amount, duration);

        if (points + totalSupply() > type(uint192).max) {
            revert StakingPointsExceeded();
        }

        lockups[to].push(Lockup({amount: uint128(amount), end: uint128(end), points: points}));

        _mint(to, points);
        // checking return value to keep slither happy
        if (!toke.transferFrom(msg.sender, address(this), amount)) revert TransferFailed();

        emit Stake(to, lockups[to].length - 1, amount, end, points);
    }

    /// @inheritdoc IGPToke
    function unstake(uint256 lockupId) external nonReentrant whenNotPaused {
        Lockup memory lockup = lockups[msg.sender][lockupId];
        uint256 amount = lockup.amount;
        uint256 end = lockup.end;
        uint256 points = lockup.points;

        // slither-disable-next-line timestamp
        if (block.timestamp < end) revert NotUnlockableYet();
        if (end == 0) revert AlreadyUnlocked();

        delete lockups[msg.sender][lockupId];

        _burn(msg.sender, points);

        if (!toke.transfer(msg.sender, amount)) revert TransferFailed();

        emit Unstake(msg.sender, lockupId, amount, end, points);
    }

    /// @inheritdoc IGPToke
    function extend(uint256 lockupId, uint256 duration) external whenNotPaused {
        // duration checked inside previewPoints
        Lockup memory lockup = lockups[msg.sender][lockupId];
        uint256 oldAmount = lockup.amount;
        uint256 oldEnd = lockup.end;
        uint256 oldPoints = lockup.points;

        (uint256 newPoints, uint256 newEnd) = previewPoints(oldAmount, duration);

        if (newEnd <= oldEnd) revert ExtendDurationTooShort();
        lockup.end = uint128(newEnd);
        lockup.points = newPoints;
        lockups[msg.sender][lockupId] = lockup;
        _mint(msg.sender, newPoints - oldPoints);

        emit Unstake(msg.sender, lockupId, oldAmount, oldEnd, oldPoints);
        emit Stake(msg.sender, lockupId, oldAmount, newEnd, newPoints);
    }

    /// @inheritdoc IGPToke
    function previewPoints(uint256 amount, uint256 duration) public view returns (uint256 points, uint256 end) {
        if (duration < minStakeDuration) revert StakingDurationTooShort();
        if (duration > 1461 days) revert StakingDurationTooLong();

        // TODO: find nearest day rounding?
        // slither-disable-next-line timestamp
        uint256 start = block.timestamp > startEpoch ? block.timestamp : startEpoch;
        end = start + duration;

        uint256 endYearpoc = ((end - startEpoch) * 1e18) / 365 days;
        uint256 multiplier = PRBMathUD60x18.pow(YEAR_BASE_BOOST, endYearpoc);

        points = (amount * multiplier) / 1e18;
    }

    function getLockups(address user) external view returns (Lockup[] memory) {
        return lockups[user];
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }
}
