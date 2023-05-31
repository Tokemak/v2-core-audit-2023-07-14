/* solhint-disable unused-parameter, state-mutability, no-unused-vars */
// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2023 Tokemak Foundation. All rights reserved.
pragma solidity 0.8.17;

import { IERC4626 } from "openzeppelin-contracts/interfaces/IERC4626.sol";
import { IERC20, ERC20 } from "openzeppelin-contracts/token/ERC20/ERC20.sol";
import { IERC3156FlashBorrower } from "openzeppelin-contracts/interfaces/IERC3156FlashBorrower.sol";
import { SafeERC20 } from "openzeppelin-contracts/token/ERC20/utils/SafeERC20.sol";
import { ERC20Permit } from "openzeppelin-contracts/token/ERC20/extensions/draft-ERC20Permit.sol";
import { EnumerableSet } from "openzeppelin-contracts/utils/structs/EnumerableSet.sol";
import { Math } from "openzeppelin-contracts/utils/math/Math.sol";

import { ISystemRegistry, IDestinationVaultRegistry } from "src/interfaces/ISystemRegistry.sol";
import { ILMPVault } from "src/interfaces/vault/ILMPVault.sol";
import { IDestinationVault } from "src/interfaces/vault/IDestinationVault.sol";
import { IStrategy } from "src/interfaces/strategy/IStrategy.sol";
import { IMainRewarder } from "src/interfaces/rewarders/IMainRewarder.sol";
import { LMPStrategy } from "src/strategy/LMPStrategy.sol";

import { SecurityBase } from "src/security/SecurityBase.sol";
import { ReentrancyGuard } from "openzeppelin-contracts/security/ReentrancyGuard.sol";
import { Pausable } from "openzeppelin-contracts/security/Pausable.sol";

import { VaultTypes } from "src/vault/VaultTypes.sol";
import { Roles } from "src/libs/Roles.sol";
import { Errors } from "src/utils/Errors.sol";

contract LMPVault is ILMPVault, IStrategy, ERC20Permit, SecurityBase, Pausable, ReentrancyGuard {
    using Math for uint256;
    using SafeERC20 for ERC20;
    using SafeERC20 for IERC20;

    using EnumerableSet for EnumerableSet.AddressSet;

    ISystemRegistry public immutable systemRegistry;

    IERC20 internal immutable _asset;

    // slither-disable-next-line immutable-states
    bytes32 public vaultType = VaultTypes.LST;

    // slither-disable-next-line constable-states
    uint256 public totalIdle = 0;
    // slither-disable-next-line constable-states
    uint256 public totalDebt = 0;

    EnumerableSet.AddressSet internal destinations;
    EnumerableSet.AddressSet internal removalQueue;

    IDestinationVault[] public withdrawalQueue;

    EnumerableSet.AddressSet internal _trackedAssets;

    IMainRewarder public immutable rewarder;

    constructor(
        ISystemRegistry _systemRegistry,
        address _vaultAsset,
        address _rewarder
    )
        ERC20(
            string(abi.encodePacked(ERC20(_vaultAsset).name(), " Pool Token")),
            string(abi.encodePacked("lmp", ERC20(_vaultAsset).symbol()))
        )
        ERC20Permit(string(abi.encodePacked("lmp", ERC20(_vaultAsset).symbol())))
        SecurityBase(address(_systemRegistry.accessController()))
    {
        systemRegistry = _systemRegistry;

        Errors.verifyNotZero(_vaultAsset, "token");
        _asset = IERC20(_vaultAsset);

        Errors.verifyNotZero(_rewarder, "rewarder");

        rewarder = IMainRewarder(_rewarder);

        // init withdrawalqueue to empty (slither issue)
        withdrawalQueue = new IDestinationVault[](0);
    }

    /// @dev See {IERC4626-asset}.
    function asset() public view virtual override returns (address) {
        return address(_asset);
    }

    function totalAssets() public view override returns (uint256) {
        return totalIdle + totalDebt;
    }

    /// @dev See {IERC4626-convertToAssets}.
    function convertToAssets(uint256 shares) public view virtual whenNotPaused returns (uint256 assets) {
        assets = _convertToAssets(shares, Math.Rounding.Down);
    }

    /// @dev See {IERC4626-convertToShares}.
    function convertToShares(uint256 assets) public view virtual whenNotPaused returns (uint256 shares) {
        shares = _convertToShares(assets, Math.Rounding.Down);
    }

    //////////////////////////////////////////////////////////////////////
    //								Deposit								//
    //////////////////////////////////////////////////////////////////////

    /// @dev See {IERC4626-maxDeposit}.
    function maxDeposit(address) public view virtual override returns (uint256 maxAssets) {
        maxAssets = paused() || !_isVaultCollateralized() ? 0 : type(uint256).max;
    }

    /// @dev See {IERC4626-previewDeposit}.
    function previewDeposit(uint256 assets) public view virtual returns (uint256 shares) {
        shares = _convertToShares(assets, Math.Rounding.Down);
    }

    function deposit(
        uint256 assets,
        address receiver
    ) public virtual override whenNotPaused nonReentrant returns (uint256 shares) {
        if (assets > maxDeposit(receiver)) {
            revert ERC4626DepositExceedsMax(assets, maxDeposit(receiver));
        }

        shares = previewDeposit(assets);

        _transferAndMint(assets, shares, receiver);

        // set a stake in rewarder
        rewarder.stake(receiver, shares);
    }

    /// @dev See {IERC4626-maxMint}.
    function maxMint(address) public view virtual override returns (uint256 maxShares) {
        return paused() ? 0 : type(uint256).max;
    }

    /// @dev See {IERC4626-maxWithdraw}.
    function maxWithdraw(address owner) public view virtual returns (uint256 maxAssets) {
        maxAssets = paused() ? 0 : previewRedeem(balanceOf(owner));
    }

    /// @dev See {IERC4626-maxRedeem}.
    function maxRedeem(address owner) public view virtual returns (uint256 maxShares) {
        maxShares = _maxRedeem(owner);
    }

    /// @dev See {IERC4626-previewMint}.
    function previewMint(uint256 shares) public view virtual returns (uint256 assets) {
        assets = _convertToAssets(shares, Math.Rounding.Up);
    }

    /// @dev See {IERC4626-previewWithdraw}.
    function previewWithdraw(uint256 assets) public view virtual returns (uint256 shares) {
        shares = _convertToShares(assets, Math.Rounding.Up);
    }

    /// @dev See {IERC4626-previewRedeem}.
    function previewRedeem(uint256 shares) public view virtual override returns (uint256) {
        return _convertToAssets(shares, Math.Rounding.Down);
    }

    /**
     * @dev See {IERC4626-mint}.
     *
     * As opposed to {deposit}, minting is allowed even if the vault is in a state where the price of a share is zero.
     * In this case, the shares will be minted without requiring any assets to be deposited.
     */
    function mint(
        uint256 shares,
        address receiver
    ) public virtual override whenNotPaused nonReentrant returns (uint256 assets) {
        if (shares > maxMint(receiver)) {
            revert ERC4626MintExceedsMax(shares, maxMint(receiver));
        }

        // do main mint
        assets = _mint(shares, receiver);

        // increment totalIdle
        totalIdle += assets;

        // set a stake in rewarder
        rewarder.stake(receiver, shares);
    }

    //////////////////////////////////////////////////////////////////////
    //								Withdraw							//
    //////////////////////////////////////////////////////////////////////

    /// @dev See {IERC4626-withdraw}.
    function withdraw(
        uint256 assets,
        address receiver,
        address owner
    ) public virtual override whenNotPaused nonReentrant returns (uint256 shares) {
        // query number of shares these assets match
        shares = previewWithdraw(assets);

        _withdraw(assets, shares, receiver, owner);
    }

    /// @dev See {IERC4626-redeem}.
    function redeem(
        uint256 shares,
        address receiver,
        address owner
    ) public virtual override whenNotPaused nonReentrant returns (uint256 assets) {
        assets = previewRedeem(shares);

        _withdraw(assets, shares, receiver, owner);
    }

    function _withdraw(
        uint256 assets,
        uint256 shares,
        address receiver,
        address owner
    ) private returns (uint256 returnedAssets, uint256 burnedShares, uint256 totalLoss) {
        // make user user has enough to withddraw
        if (balanceOf(owner) < shares) revert Errors.InsufficientBalance(address(this));

        uint256 assetsPulled = 0;
        uint256 assetsFromIdle = assets > totalIdle ? assets - totalIdle : assets;

        //
        // If not enough funds in idle, then pull what we need from strategies
        //
        if (assets > totalIdle) {
            // only try to find the deficit difference between sitting funds and what's asked
            uint256 assetsToPullFromDestinations = assets - totalIdle;
            uint256 userVaultShares = balanceOf(msg.sender);
            uint256 totalVaultShares = totalSupply();
            // keep cumulative track of loss (to know how much funds to withhold for fees/il)
            totalLoss = 0;

            // NOTE: using pre-set withdrawalQueue for withdrawal order to help minimize user gas
            for (uint256 i = 0; i < withdrawalQueue.length; ++i) {
                // Do withdraw:
                // - pass in: requested assets, total vault shares, and user's portion of them
                // - get back: assets actually received, and the cost incurred with process (and possibly due to IL)
                (uint256 amount, uint256 loss) = IDestinationVault(withdrawalQueue[i]).withdrawBaseAsset(
                    assetsToPullFromDestinations, userVaultShares, totalVaultShares
                );

                totalLoss += loss;

                // if received anything, adjust remaining deficit accordingly
                if (amount > 0) {
                    assetsPulled += amount;

                    // subtract both the amount sent back and the costs of pulling from vaults / IL
                    assetsToPullFromDestinations -= (amount + loss);

                    if (assetsToPullFromDestinations == 0) {
                        // we're done
                        break;
                    }
                }
            }

            // NOTE: if we still have a deficit, user gets whatever was available for retrieval
        }

        //
        // At this point should have all the funds we need sitting in Idle,
        // so proceed with withdrawal (but withhold the costs / il charged)
        returnedAssets = assetsFromIdle + assetsPulled; // keeps loss out?

        // subtract what's taken out of idle from totalIdle
        // slither-disable-next-line events-maths
        totalIdle -= assetsFromIdle;

        //
        // do the actual withdrawal (going off of total # requested)
        //
        uint256 allowed = allowance(owner, msg.sender);
        if (msg.sender != owner && allowed != type(uint256).max) {
            if (shares > allowed) revert AmountExceedsAllowance(shares, allowed);

            _approve(owner, msg.sender, returnedAssets);
        }

        // TODO: how to account for partial withdrawal (shares-wise?)
        _burn(owner, shares);
        burnedShares = shares;

        _asset.safeTransfer(receiver, returnedAssets);

        // remove stake from rewarder
        rewarder.withdraw(msg.sender, shares, false);

        emit Withdraw(msg.sender, receiver, owner, assets, shares);
    }

    function claimRewards() public whenNotPaused {
        rewarder.getReward(msg.sender, true);
    }

    function pullTokens(
        address[] calldata tokens,
        uint256[] calldata amounts,
        address[] calldata _destinations
    ) public virtual override hasRole(Roles.REBALANCER_ROLE) {
        _bulkMoveTokens(tokens, amounts, _destinations, true);

        emit TokensPulled(tokens, amounts, _destinations);
    }

    function recover(
        address[] calldata tokens,
        uint256[] calldata amounts,
        address[] calldata _destinations
    ) public virtual override hasRole(Roles.TOKEN_RECOVERY_ROLE) {
        _bulkMoveTokens(tokens, amounts, _destinations, false);

        emit TokensRecovered(tokens, amounts, _destinations);
    }

    function updateDebt(uint256 newDebt) public virtual override hasRole(Roles.REBALANCER_ROLE) {
        // update debt
        uint256 oldDebt = totalDebt;
        totalDebt = newDebt;

        emit DebtUpdated(oldDebt, newDebt);
    }

    function _bulkMoveTokens(
        address[] calldata tokens,
        uint256[] calldata amounts,
        address[] calldata _destinations,
        bool onlyDoTracked
    ) private {
        // slither-disable-start reentrancy-no-eth

        // check for param numbers match
        if (!(tokens.length > 0) || tokens.length != amounts.length || tokens.length != _destinations.length) {
            revert Errors.InvalidParams();
        }

        //
        // Actually pull / recover tokens
        //
        for (uint256 i = 0; i < tokens.length; ++i) {
            (address tokenAddress, uint256 amount, address destination) = (tokens[i], amounts[i], _destinations[i]);

            if (
                (onlyDoTracked && !_trackedAssets.contains(tokenAddress))
                    || (!onlyDoTracked && _trackedAssets.contains(tokenAddress))
            ) {
                revert Errors.AssetNotAllowed(tokenAddress);
            }

            IERC20 token = IERC20(tokenAddress);

            // check balance / allowance
            if (token.balanceOf(address(this)) < amount) revert Errors.InsufficientBalance(tokenAddress);

            // if matches base asset, subtract from idle
            if (onlyDoTracked && tokenAddress == address(_asset)) {
                // TODO: not sure if need this check, since checking balance above, but would prevent invalid state?
                if (totalIdle < amount) revert Errors.InsufficientBalance(tokenAddress);
                // subtract from idle
                totalIdle -= amount;
                totalDebt += amount;
            }

            // slither-disable-next-line reentrancy-events
            token.safeTransfer(destination, amount);
        }

        // slither-disable-end reentrancy-no-eth
    }

    // solhint-disable-next-line no-unused-vars
    function migrateVault(uint256 amount, address newLmpVault) public virtual override whenNotPaused nonReentrant {
        // TODO: validate it's really a vault by calling Registry (requires SystemRegistry to be plugged in)

        ILMPVault newVault = ILMPVault(newLmpVault);

        // withdraw from here
        claimRewards();
        // TODO: do we need slippage parameter?
        withdraw(amount, address(this), address(this));
        // deposit to new vault
        // TODO: slippage should be added below to compare expected shares?
        // slither-disable-next-line unused-return
        newVault.deposit(amount, msg.sender);

        // TODO: pull all assets in from destinations
        // TODO: push it to another vault
        revert Errors.NotImplemented();
    }

    /**
     * @dev Internal conversion function (from assets to shares) with support for rounding direction.
     *
     * Will revert if assets > 0, totalSupply > 0 and totalAssets = 0. That corresponds to a case where any asset
     * would represent an infinite amount of shares.
     */
    function _convertToShares(uint256 assets, Math.Rounding rounding) internal view virtual returns (uint256 shares) {
        uint256 supply = totalSupply();
        shares = (assets == 0 || supply == 0) ? assets : assets.mulDiv(supply, totalAssets(), rounding);
    }

    /// @dev Internal conversion function (from shares to assets) with support for rounding direction.
    function _convertToAssets(uint256 shares, Math.Rounding rounding) internal view virtual returns (uint256 assets) {
        uint256 supply = totalSupply();
        assets = !_isVaultCollateralized() ? shares : shares.mulDiv(totalAssets(), supply, rounding);
    }

    function _mint(uint256 shares, address receiver) internal virtual returns (uint256 assets) {
        assets = previewMint(shares);
        _transferAndMint(assets, shares, receiver);
    }

    function _maxRedeem(address owner) internal view virtual returns (uint256 maxShares) {
        maxShares = paused() ? 0 : balanceOf(owner);
    }

    function _transferAndMint(uint256 assets, uint256 shares, address receiver) internal virtual {
        // From OZ documentation:
        // ----------------------
        // If _asset is ERC777, `transferFrom` can trigger a reenterancy BEFORE the transfer happens through the
        // `tokensToSend` hook. On the other hand, the `tokenReceived` hook, that is triggered after the transfer,
        // calls the vault, which is assumed not malicious.
        //
        // Conclusion: we need to do the transfer before we mint so that any reentrancy would happen before the
        // assets are transferred and before the shares are minted, which is a valid state.
        // slither-disable-next-line reentrancy-no-eth
        _asset.safeTransferFrom(_msgSender(), address(this), assets);

        totalIdle += assets;

        _mint(receiver, shares);

        emit Deposit(_msgSender(), receiver, assets, shares);
    }

    ///@dev Checks if vault is "healthy" in the sense of having assets backing the circulating shares.
    function _isVaultCollateralized() internal view returns (bool) {
        return totalAssets() > 0 || totalSupply() == 0;
    }

    //////////////////////////////////////////////////////////////////////////
    //                                                                      //
    //							Strategy Related   							//
    //                                                                      //
    //////////////////////////////////////////////////////////////////////////

    //////////////////////////////////////////////////////////////////////////
    //							  Destinations     							//
    //////////////////////////////////////////////////////////////////////////

    function getDestinations() public view override returns (address[] memory) {
        return destinations.values();
    }

    function addDestinations(address[] calldata _destinations) public hasRole(Roles.DESTINATION_VAULTS_UPDATER) {
        IDestinationVaultRegistry destinationRegistry = systemRegistry.destinationVaultRegistry();

        uint256 numDestinations = _destinations.length;
        if (numDestinations == 0) revert Errors.InvalidParams();

        address dAddress;
        for (uint256 i = 0; i < numDestinations; ++i) {
            dAddress = _destinations[i];

            // slither-disable-next-line calls-loop
            if (dAddress == address(0) || !destinationRegistry.isRegistered(dAddress)) {
                revert Errors.InvalidAddress(dAddress);
            }

            if (!destinations.add(dAddress)) {
                revert Errors.ItemExists();
            }

            // just in case it's in removal queue, take it out
            // slither-disable-next-line unused-return
            removalQueue.remove(dAddress);

            emit DestinationVaultAdded(dAddress);
        }
    }

    function removeDestinations(address[] calldata _destinations) public hasRole(Roles.DESTINATION_VAULTS_UPDATER) {
        for (uint256 i = 0; i < _destinations.length; ++i) {
            address dAddress = _destinations[i];
            IDestinationVault destination = IDestinationVault(dAddress);

            // remove from main list (NOTE: done here so balance check below doesn't explode if address is invalid)
            if (!destinations.remove(dAddress)) {
                revert Errors.ItemNotFound();
            }

            // slither-disable-next-line calls-loop
            if (destination.balanceOf(address(this)) > 0 && !removalQueue.contains(dAddress)) {
                // we still have funds in it! move it to removalQueue for rebalancer to handle it later
                // slither-disable-next-line unused-return
                removalQueue.add(dAddress);

                emit AddedToRemovalQueue(dAddress);
            }

            emit DestinationVaultRemoved(dAddress);
        }
    }

    function getRemovalQueue() public view override returns (address[] memory) {
        return removalQueue.values();
    }

    function removeFromRemovalQueue(address vaultToRemove) public override hasRole(Roles.REBALANCER_ROLE) {
        if (!removalQueue.remove(vaultToRemove)) {
            revert Errors.ItemNotFound();
        }

        emit RemovedFromRemovalQueue(vaultToRemove);
    }

    // @dev Order is set as list of interfaces to minimize gas for our users
    function setWithdrawalQueue(address[] calldata _destinations)
        public
        override
        hasRole(Roles.SET_WITHDRAWAL_QUEUE_ROLE)
    {
        IDestinationVaultRegistry destinationVaultRegistry = systemRegistry.destinationVaultRegistry();
        (uint256 oldLength, uint256 newLength) = (withdrawalQueue.length, _destinations.length);

        // run through new destinations list and propagate the values to our existing collection
        uint256 i;
        for (i = 0; i < newLength; ++i) {
            address destAddress = _destinations[i];
            Errors.verifyNotZero(destAddress, "destination");

            // check if destination vault is registered with the system
            // slither-disable-next-line calls-loop
            if (!destinationVaultRegistry.isRegistered(destAddress)) {
                revert Errors.InvalidAddress(destAddress);
            }

            IDestinationVault destination = IDestinationVault(destAddress);

            // if we're still overwriting, just set the value
            if (i < oldLength) {
                // only write if values differ
                if (withdrawalQueue[i] != destination) {
                    withdrawalQueue[i] = destination;
                }
            } else {
                // if already past old bounds, append new values
                withdrawalQueue.push(destination);
            }
        }

        // if old list was larger than new list, pop the remaining values
        if (oldLength > newLength) {
            for (; i < oldLength; ++i) {
                // slither-disable-next-line costly-loop
                withdrawalQueue.pop();
            }
        }

        emit WithdrawalQueueSet(_destinations);
    }

    function getWithdrawalQueue() public view override returns (IDestinationVault[] memory withdrawalDestinations) {
        return withdrawalQueue;
    }

    /// @inheritdoc IStrategy
    function rebalance(
        address destinationIn,
        address tokenIn,
        uint256 amountIn,
        address destinationOut,
        address tokenOut,
        uint256 amountOut
    ) public onlyOwner {
        address swapper = msg.sender;

        // make sure there's something to do
        if (amountIn == 0 && amountOut == 0) {
            revert Errors.InvalidParams();
        }

        // make sure we have a valid path
        (bool success, string memory message) =
            LMPStrategy.verifyRebalance(destinationIn, tokenIn, amountIn, destinationOut, tokenOut, amountOut);
        if (!success) {
            revert RebalanceFailed(message);
        }

        //
        // Handle decrease (shares going "Out", cashing in shares and sending underlying back to swapper)
        //
        if (amountOut > 0) {
            // withdraw underlying from dv
            uint256 underlyerReceived = IDestinationVault(destinationOut).withdrawUnderlying(amountOut);

            // send to swapper
            IERC20(tokenOut).safeTransfer(swapper, underlyerReceived);
        }

        //
        // Handle increase (shares coming "In", getting underlying from the swapper and trading for new shares)
        //
        if (amountIn > 0) {
            // transfer dv underlying lp from swapper to here
            IERC20(tokenIn).safeTransferFrom(swapper, address(this), amountIn);

            // deposit to dv (already checked in `verifyRebalance` so no need to check return of deposit)

            if (!IERC20(tokenIn).approve(destinationIn, amountIn)) revert Errors.ApprovalFailed(tokenIn);
            // slither-disable-next-line unused-return
            IDestinationVault(destinationIn).depositUnderlying(amountIn);
        }
    }

    /// @inheritdoc IStrategy
    function flashRebalance(
        IERC3156FlashBorrower receiver,
        address destinationIn,
        address tokenIn,
        uint256 amountIn,
        address destinationOut,
        address tokenOut,
        uint256 amountOut,
        bytes calldata data
    ) public onlyOwner {
        address swapper = msg.sender;

        // make sure there's something to do
        if (amountIn == 0 && amountOut == 0) {
            revert Errors.InvalidParams();
        }

        // make sure we have a valid path
        (bool success, string memory message) =
            LMPStrategy.verifyRebalance(destinationIn, tokenIn, amountIn, destinationOut, tokenOut, amountOut);
        if (!success) {
            revert RebalanceFailed(message);
        }

        //
        // Handle "Out"
        //
        if (amountOut > 0) {
            // withdraw underlying from dv
            uint256 underlyingReceived = IDestinationVault(destinationOut).withdrawUnderlying(amountOut);

            // send to receiver (?? @samhagan receiver or swapper or is it the same?)
            IERC20(tokenOut).safeTransfer(address(receiver), underlyingReceived);
        }

        //
        // Handle "In"
        //
        if (amountIn > 0) {
            // get "before" counts
            // uint256 dvSharesBefore = IERC20(destinationIn).balanceOf(address(this));
            uint256 tokenInBalanceBefore = IERC20(tokenIn).balanceOf(address(this));

            // flash loan
            // TODO: vet out mechanics fit!! (and checks for returns!)
            //slither-disable-next-line unused-return
            receiver.onFlashLoan(swapper, tokenIn, amountIn, 0, data);

            // verify that vault balance of underlyerIn increased
            if (IERC20(tokenIn).balanceOf(address(this)) != tokenInBalanceBefore + amountIn) {
                revert Errors.FlashLoanFailed(tokenIn);
            }

            // deposit to dv
            if (!IERC20(tokenIn).approve(destinationIn, amountIn)) revert Errors.ApprovalFailed(tokenIn);
            // slither-disable-next-line unused-return
            IDestinationVault(destinationIn).depositUnderlying(amountIn);
        }
    }

    /// @inheritdoc IStrategy
    function verifyRebalance(
        address destinationIn,
        address tokenIn,
        uint256 amountIn,
        address destinationOut,
        address tokenOut,
        uint256 amountOut
    ) public view returns (bool success, string memory message) {
        return LMPStrategy.verifyRebalance(destinationIn, tokenIn, amountIn, destinationOut, tokenOut, amountOut);
    }
}
