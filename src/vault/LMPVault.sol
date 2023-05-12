// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import { IERC4626 } from "openzeppelin-contracts/interfaces/IERC4626.sol";
import { IERC20 } from "openzeppelin-contracts/token/ERC20/IERC20.sol";
import { ERC20 } from "openzeppelin-contracts/token/ERC20/ERC20.sol";
import { SafeERC20 } from "openzeppelin-contracts/token/ERC20/utils/SafeERC20.sol";
import { ERC20Permit } from "openzeppelin-contracts/token/ERC20/extensions/draft-ERC20Permit.sol";
import { EnumerableSet } from "openzeppelin-contracts/utils/structs/EnumerableSet.sol";
import { Math } from "openzeppelin-contracts/utils/math/Math.sol";

import { ILMPVault } from "src/interfaces/vault/ILMPVault.sol";
import { IDestinationVault } from "src/interfaces/vault/IDestinationVault.sol";
import { IStrategy } from "src/interfaces/strategy/IStrategy.sol";
import { IMainRewarder } from "src/interfaces/rewarders/IMainRewarder.sol";

import { SecurityBase } from "src/security/SecurityBase.sol";
import { ReentrancyGuard } from "openzeppelin-contracts/security/ReentrancyGuard.sol";
import { Pausable } from "openzeppelin-contracts/security/Pausable.sol";

import { LMPStorage } from "src/vault/LMPStorage.sol";

import { Roles } from "src/libs/Roles.sol";
import { Errors } from "src/utils/Errors.sol";

contract LMPVault is ILMPVault, LMPStorage, ERC20Permit, SecurityBase, Pausable, ReentrancyGuard {
    using Math for uint256;
    using SafeERC20 for ERC20;
    using SafeERC20 for IERC20;

    using EnumerableSet for EnumerableSet.AddressSet;

    IERC20 internal immutable _asset;

    IStrategy public immutable strategy;
    IMainRewarder public immutable rewarder;

    constructor(
        address _vaultAsset,
        address _accessController,
        address _strategy,
        address _rewarder
    )
        ERC20(
            string(abi.encodePacked(ERC20(_vaultAsset).name(), " Pool Token")),
            string(abi.encodePacked("lmp", ERC20(_vaultAsset).symbol()))
        )
        ERC20Permit(string(abi.encodePacked("lmp", ERC20(_vaultAsset).symbol())))
        SecurityBase(_accessController)
    {
        if (_vaultAsset == address(0)) revert Errors.ZeroAddress("token");
        _asset = IERC20(_vaultAsset);

        if (_strategy == address(0)) revert Errors.ZeroAddress("strategy");
        if (_rewarder == address(0)) revert Errors.ZeroAddress("rewarder");

        strategy = IStrategy(_strategy);
        rewarder = IMainRewarder(_rewarder);

        // // fill out tracked assets collection
        // NOTE: this code will be moved to strategy in the upcoming strategy work update
        // _trackedAssets.add(_vaultAsset);
        // address[] memory _strategyAssets = strategy.getDestinations();
        // for (uint256 i = 0; i < _strategyAssets.length; ++i) {
        //     //slither-disable-next-line unused-return
        //     _trackedAssets.add(_strategyAssets[i]);
        // }

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
        // make sure we have strategy set
        if (address(strategy) == address(0)) revert StrategyNotSet();

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
    //								Withdraw								//
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
        address[] calldata destinations
    ) public virtual override {
        // only rebalancer can pull tokens
        if (!_hasRole(Roles.REBALANCER_ROLE, msg.sender)) revert Errors.NotAuthorized();

        _bulkMoveTokens(tokens, amounts, destinations, true);

        emit TokensPulled(tokens, amounts, destinations);
    }

    function recover(
        address[] calldata tokens,
        uint256[] calldata amounts,
        address[] calldata destinations
    ) public virtual override {
        if (!_hasRole(Roles.TOKEN_RECOVERY_ROLE, msg.sender)) revert Errors.NotAuthorized();

        _bulkMoveTokens(tokens, amounts, destinations, false);

        emit TokensRecovered(tokens, amounts, destinations);
    }

    function updateDebt(uint256 newDebt) public virtual override {
        if (!_hasRole(Roles.REBALANCER_ROLE, msg.sender)) revert Errors.NotAuthorized();

        // update debt
        uint256 oldDebt = totalDebt;
        totalDebt = newDebt;

        emit DebtUpdated(oldDebt, newDebt);
    }

    function _bulkMoveTokens(
        address[] calldata tokens,
        uint256[] calldata amounts,
        address[] calldata destinations,
        bool onlyDoTracked
    ) private {
        // slither-disable-start reentrancy-no-eth

        // check for param numbers match
        if (!(tokens.length > 0) || tokens.length != amounts.length || tokens.length != destinations.length) {
            revert Errors.InvalidParams();
        }

        //
        // Actually pull / recover tokens
        //
        for (uint256 i = 0; i < tokens.length; ++i) {
            (address tokenAddress, uint256 amount, address destination) = (tokens[i], amounts[i], destinations[i]);

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

    /// @dev Order is set as list of interfaces to minimize gas used by users using the system
    // NOTE: this will be moved to the upcoming Strategy effort
    //     function setWithdrawalQueue(address[] calldata destinations) public virtual override whenNotPaused
    // nonReentrant {
    //         if (!_hasRole(Roles.SET_WITHDRAWAL_QUEUE_ROLE, msg.sender)) revert Errors.NotAuthorized();
    //
    //         // populate new target destination vault locations (and clear the previous data)
    //         // NOTE: due to limitations of how EVM treats arrays of interfaces, we can't just set length to 0,
    //         //       so need to overwrite what's there and delete the rest of elements to sync up to new version
    //         uint256 i;
    //         for (i = 0; i < destinations.length; ++i) {
    //             if (destinations[i] == address(0)) revert Errors.ZeroAddress("destination");
    //
    //             withdrawalQueue[i] = destinations[i];
    //         }
    //         // if still space left from previous array, delete those values
    //         if (i < withdrawalQueue.length - 1) {
    //             for (; i < withdrawalQueue.length; ++i) {
    //                 delete withdrawalQueue[i];
    //             }
    //         }
    //     }

    //     // solhint-disable-next-line no-unused-vars
    //     function setStrategy(IStrategy _strategy) public onlyOwner {
    //         // NOTE: changing of strategies not implemented yet (since math has to change)
    //         revert Errors.NotImplemented();
    //
    //         // TODO: update _trackedAssets
    //         // TODO: strategy = _strategy;
    //         // TODO: update withdrawal queue
    //         // TODO: emit StrategySet(address(_strategy));
    //     }

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
}
