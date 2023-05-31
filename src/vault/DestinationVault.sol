// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import { Math } from "openzeppelin-contracts/utils/math/Math.sol";
import { ERC20 } from "openzeppelin-contracts/token/ERC20/ERC20.sol";
import { SafeERC20 } from "openzeppelin-contracts/token/ERC20/utils/SafeERC20.sol";
import { Initializable } from "openzeppelin-contracts/proxy/utils/Initializable.sol";
import { IERC20Metadata as IERC20 } from "openzeppelin-contracts/token/ERC20/extensions/IERC20Metadata.sol";
import { EnumerableSet } from "openzeppelin-contracts/utils/structs/EnumerableSet.sol";

import { ISystemRegistry } from "src/interfaces/ISystemRegistry.sol";
import { IDestinationVault } from "src/interfaces/vault/IDestinationVault.sol";
import { Roles } from "src/libs/Roles.sol";
import { Errors } from "src/utils/Errors.sol";

// TODO: Ensure that baseAsset decimals are the same as the Vaults decimals
// TODO: Evaluate the conditions to burn destination vault shares
// TODO: Restrict function visibility so only LMP Vault could access
abstract contract DestinationVault is ERC20, Initializable, IDestinationVault {
    using SafeERC20 for ERC20;
    using SafeERC20 for IERC20;
    using EnumerableSet for EnumerableSet.AddressSet;

    event ClaimedVested(uint256 indexed amount);
    event Recovered(address[] tokens, uint256[] amounts, address[] destinations);

    error ArrayLengthMismatch();
    error PullingNonTrackedToken(address token);
    error RecoveringTrackedToken(address token);
    error RecoveringMoreThanAvailable(address token, uint256 amount, uint256 availableAmount);

    /* ******************************** */
    /* State Variables                  */
    /* ******************************** */

    string private _name;
    string private _symbol;

    IERC20 public baseAsset;

    EnumerableSet.AddressSet internal trackedTokens;

    /// @notice Amount of baseAsset sitting in contract
    uint256 public idle = 0;

    /// @notice Debt we have sent out to underlying destination
    uint256 public debt = 0;

    ISystemRegistry public systemRegistry;

    constructor() ERC20("", "") { }

    modifier onlyOperator() {
        // if (!_hasRole(Roles.DESTINATION_VAULT_OPERATOR_ROLE, msg.sender)) revert Errors.AccessDenied();
        _;
    }

    function initialize(
        ISystemRegistry _systemRegistry,
        IERC20 _baseAsset,
        string memory baseName,
        bytes memory
    ) public initializer {
        _name = string.concat("gpDV", baseName);
        _symbol = string.concat("gpDV", _baseAsset.symbol());

        Errors.verifyNotZero(address(_baseAsset), "_baseAsset");

        systemRegistry = _systemRegistry;
        baseAsset = _baseAsset;

        //slither-disable-next-line unused-return
        trackedTokens.add(address(_baseAsset));
    }

    /// @inheritdoc IDestinationVault
    function underlying() public view virtual returns (address) {
        revert Errors.NotImplemented();
    }

    /// @inheritdoc ERC20
    function name() public view virtual override(ERC20, IERC20) returns (string memory) {
        return _name;
    }

    /// @inheritdoc ERC20
    function symbol() public view virtual override(ERC20, IERC20) returns (string memory) {
        return _symbol;
    }

    /// @inheritdoc IDestinationVault
    function debtValue() public virtual override returns (uint256 value);

    /// @inheritdoc IDestinationVault
    function rewardValue() public virtual returns (uint256 value);

    /// @inheritdoc IDestinationVault
    function claimVested() public virtual onlyOperator returns (uint256 amount) {
        amount = claimVested_();
        idle += amount;
        emit ClaimedVested(amount);
    }

    /// @notice Checks if given token is tracked by Vault
    /// @param token Address to verify
    /// @return bool True if token is within Vault's tracked assets
    function isTrackedToken(address token) public view returns (bool) {
        return trackedTokens.contains(token);
    }

    /// @notice Claims any rewards that have been previously claimed and are vesting
    /// @dev Should not update idle
    /// @return amount The amount claimed in terms of the baseAsset
    function claimVested_() internal virtual returns (uint256 amount);

    /// @notice Burns a percent of the shares we hold for our debt
    /// @param pctNumerator Numerator in the number that make up the pct to burn
    /// @param pctDenominator Denominator in the number that make up the pct to burn
    /// @return amount Amount of baseAsset reclaimed
    /// @return loss Amount of baseAsset lost
    function reclaimDebt(
        uint256 pctNumerator,
        uint256 pctDenominator
    ) internal onlyOperator returns (uint256 amount, uint256 loss) {
        (amount, loss) = reclaimDebt_(pctNumerator, pctDenominator);
        debt -= Math.mulDiv(debt, pctNumerator, pctDenominator, Math.Rounding.Up);
    }

    /// @notice Burns a percent of the shares we hold for our debt
    /// @dev Should burn from all sources according to the same pct. Should swap to baseAsset. Should not update debt
    /// @param pctNumerator Numerator in the number that make up the pct to burn
    /// @param pctDenominator Denominator in the number that make up the pct to burn
    /// @return amount Amount of baseAsset reclaimed
    /// @return loss Amount of baseAsset lost
    function reclaimDebt_(
        uint256 pctNumerator,
        uint256 pctDenominator
    ) internal virtual returns (uint256 amount, uint256 loss);

    /// @inheritdoc IDestinationVault
    function donate(uint256 amount) external onlyOperator {
        idle += amount;

        emit Donated(msg.sender, amount);

        // Safe transfer of base asset from caller
        baseAsset.safeTransferFrom(msg.sender, address(this), amount);
    }

    /// @notice Attempt to sideline enough assets to cover the requested amount from idle, rewards, debt, etc.
    /// @dev Specified amount should already be validated as available to the user
    /// @param amount Amount of assets to attempt to retrieve
    /// @return totalActual Actual amount of asset available
    /// @return loss How much loss was incurred in the recovery process
    /// @return fromIdle Amount of asset that was recovered from idle (includes claimed rewards)
    /// @return fromDebt Amount of asset that was recovered by burning debt
    function freeUpAssets(uint256 amount)
        internal
        virtual
        onlyOperator
        returns (uint256 totalActual, uint256 loss, uint256 fromIdle, uint256 fromDebt)
    {
        // Now we figure out where to take it from.
        uint256 remaining = amount;

        // Easiest is to pull fully from idle so we try there first
        if (idle >= amount) {
            idle -= amount;
            remaining -= amount;
            fromIdle += amount;
        }

        // If there are vested rewards we could claim, claim them and try idle again
        // This will move assets to idle if any were claimed
        if (remaining > 0) {
            claimVested();

            if (idle >= amount) {
                idle -= amount;
                remaining -= amount;
                fromIdle += amount;
            }
        }

        // Partially from idle?
        if (remaining > 0 && idle > 0) {
            remaining -= idle;
            fromIdle += idle;
            idle = 0;
        }

        // If idle didn't do it for us, we have to try LP
        if (remaining > 0) {
            uint256 currentDebtValue = debtValue();

            // If our take is greater than the entire debt value, tweak the numbers so we take it all
            // If currentDebtValue is used in any way than just passing it to reclaimDebt re-evaluate
            // this operation as it probably won't make sense. reclaimDebt uses the numbers as a ratio
            // and we want it to 1:1
            if (remaining > currentDebtValue) {
                currentDebtValue = remaining;
            }

            // TODO: Should we short circuit on some threshold of loss?
            (uint256 reclaimAmount, uint256 reclaimedLoss) = reclaimDebt(remaining, currentDebtValue);

            loss = reclaimedLoss;

            if (reclaimAmount > 0) {
                // It's possible we end up getting more then we need
                // from reclaim so make sure we only take what we're owed putting the rest into idle
                if (reclaimAmount > remaining) {
                    uint256 amtForIdle = reclaimAmount - remaining;
                    idle += amtForIdle;
                    reclaimAmount = remaining;
                }
                remaining -= reclaimAmount;
                fromDebt = reclaimAmount;
            }
        }

        totalActual = amount - remaining;
    }

    /// @dev 1:1 ratio is assumed
    /// @inheritdoc IDestinationVault
    function depositUnderlying(uint256 amount) public returns (uint256 shares) {
        // transfer underlying
        IERC20(underlying()).safeTransferFrom(msg.sender, address(this), amount);
        // mint shares
        _mint(msg.sender, amount);

        return amount;
    }

    /// @dev 1:1 ratio is assumed
    /// @inheritdoc IDestinationVault
    function withdrawUnderlying(uint256 shares) public returns (uint256 amount) {
        // make sure there's enough
        if (balanceOf(msg.sender) < shares) revert Errors.InsufficientBalance(address(this));

        // burn shares
        _burn(msg.sender, shares);

        // transfer underlying
        IERC20(underlying()).safeTransfer(msg.sender, shares);

        return shares;
    }

    /// @inheritdoc IDestinationVault
    function withdrawBaseAsset(
        uint256 targetAmount,
        uint256 ownerPctNumerator,
        uint256 ownerPctDenominator
    ) external virtual onlyOperator returns (uint256 amount, uint256 loss) {
        uint256 originalTarget = targetAmount;
        uint256 sharesCanBurn = balanceOf(msg.sender);
        if (sharesCanBurn == 0) {
            // TODO: Revert?
            return (0, 0);
        }

        // To figure out how much we're allowed to take we need to figure
        // out if there are any losses, which will tell us how much we can burn
        uint256 debtVal = debtValue();
        uint256 ourLoss = 0;
        uint256 totalSupply = totalSupply();
        if (debtVal < debt) {
            // We only need to take our portion of the loss
            ourLoss = Math.mulDiv(
                (debt - debtVal), sharesCanBurn * ownerPctNumerator, totalSupply * ownerPctDenominator, Math.Rounding.Up
            );

            // We have a loss so we can only burn the portion that the user
            // owns at the lmp level to ensure we don't lock in a loss
            // for everyone or take more of the loss than required
            sharesCanBurn = Math.mulDiv(sharesCanBurn, ownerPctNumerator, ownerPctDenominator, Math.Rounding.Down);

            // Take our loss out of our target amount, we don't get that now
            if (targetAmount < ourLoss) {
                targetAmount = 0;
            } else {
                targetAmount -= ourLoss;
            }
        }

        // Now we figure out the Vaults NAV so we know we how what the max amt is
        // we can withdraw.
        uint256 maxWithdraw = ((idle + debtVal + rewardValue()) * sharesCanBurn) / totalSupply;

        // Check if the loss so high that we have nothing to do
        if (ourLoss >= maxWithdraw) {
            _burn(msg.sender, sharesCanBurn);
            return (0, ourLoss);
        }

        // Nothing to take, nothing to do
        if (maxWithdraw == 0) {
            // TODO: Should we burn any shares if there is nothing to take?
            _burn(msg.sender, sharesCanBurn);
            return (0, ourLoss);
        }

        // Can't take more than we're allowed, so change the target
        if (maxWithdraw < targetAmount) {
            targetAmount = maxWithdraw;
        }

        // Now we know how much we can get, so lets go get it
        (uint256 totalActual, uint256 claimLoss, uint256 fromIdle, uint256 fromDebt) = freeUpAssets(targetAmount);

        amount = totalActual;
        loss = ourLoss + claimLoss;

        emit Withdraw(originalTarget, amount, ourLoss, claimLoss, fromIdle, fromDebt);

        if (totalActual > 0) {
            baseAsset.safeTransfer(msg.sender, totalActual);
        }
    }

    function recover(
        address[] calldata tokens,
        uint256[] calldata amounts,
        address[] calldata destinations
    ) external override onlyOperator {
        uint256 length = tokens.length;
        if (length == 0 || length != amounts.length || length != destinations.length) {
            revert ArrayLengthMismatch();
        }
        emit Recovered(tokens, amounts, destinations);

        //slither-disable-start calls-loop
        for (uint256 i = 0; i < tokens.length; ++i) {
            IERC20 token = IERC20(tokens[i]);

            // Check if it's a really non-tracked token
            if (isTrackedToken(tokens[i])) revert RecoveringTrackedToken(tokens[i]);

            uint256 tokenBalance = token.balanceOf(address(this));
            if (tokenBalance < amounts[i]) revert RecoveringMoreThanAvailable(tokens[i], amounts[i], tokenBalance);

            token.safeTransfer(destinations[i], amounts[i]);
        }
        //slither-disable-end calls-loop
    }
}
