// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2023 Tokemak Foundation. All rights reserved.
pragma solidity 0.8.17;

import { Roles } from "src/libs/Roles.sol";
import { Errors } from "src/utils/Errors.sol";
import { Pausable } from "src/security/Pausable.sol";
import { VaultTypes } from "src/vault/VaultTypes.sol";
import { NonReentrant } from "src/utils/NonReentrant.sol";
import { SystemComponent } from "src/SystemComponent.sol";
import { LMPStrategy } from "src/strategy/LMPStrategy.sol";
import { SecurityBase } from "src/security/SecurityBase.sol";
import { ILMPVault } from "src/interfaces/vault/ILMPVault.sol";
import { IStrategy } from "src/interfaces/strategy/IStrategy.sol";
import { Math } from "openzeppelin-contracts/utils/math/Math.sol";
import { ERC20 } from "openzeppelin-contracts/token/ERC20/ERC20.sol";
import { IERC4626 } from "openzeppelin-contracts/interfaces/IERC4626.sol";
import { IMainRewarder } from "src/interfaces/rewarders/IMainRewarder.sol";
import { IDestinationVault } from "src/interfaces/vault/IDestinationVault.sol";
import { SafeERC20 } from "openzeppelin-contracts/token/ERC20/utils/SafeERC20.sol";
import { EnumerableSet } from "openzeppelin-contracts/utils/structs/EnumerableSet.sol";
import { ISystemRegistry, IDestinationVaultRegistry } from "src/interfaces/ISystemRegistry.sol";
import { ERC20Permit } from "openzeppelin-contracts/token/ERC20/extensions/draft-ERC20Permit.sol";
import { IERC3156FlashBorrower } from "openzeppelin-contracts/interfaces/IERC3156FlashBorrower.sol";
import { IERC20Metadata as IERC20 } from "openzeppelin-contracts/token/ERC20/extensions/IERC20Metadata.sol";

// Cross functional reetrancy was identified between updateDebtReporting and the
// destinationInfo. Have nonReentrant and read-only nonReentrant modifier on them both
// but slither was still complaining
//slither-disable-start reentrancy-no-eth,reentrancy-benign

// TODO: Be on the look out for an issue for where the destination vaults decimals are different than
// the LMPVaults decimals. It's in here, just lost track of it.
contract LMPVault is SystemComponent, ILMPVault, IStrategy, ERC20Permit, SecurityBase, Pausable, NonReentrant {
    using EnumerableSet for EnumerableSet.AddressSet;
    using Math for uint256;
    using SafeERC20 for ERC20;
    using SafeERC20 for IERC20;

    struct DestinationInfo {
        /// @notice Current underlying and reward value at the destination vault
        /// @dev Used for calculating totalDebt of the LMPVault
        uint256 currentDebt;
        /// @notice Last block timestamp this info was updated
        uint256 lastReport;
        /// @notice How many shares of the destination vault we owned at last report
        uint256 ownedShares;
        /// @notice Amount of baseAsset transferred out in service of deployments
        /// @dev Used for calculating 'in profit' or not during user withdrawals
        uint256 debtBasis;
    }

    /// @dev In memory struct only for managing vars in _withdraw
    struct WithdrawInfo {
        uint256 currentIdle;
        uint256 assetsFromIdle;
        uint256 totalAssetsToPull;
        uint256 totalAssetsPulled;
        uint256 idleIncrease;
        uint256 debtDecrease;
    }

    /// @notice Max fee. 100% == 10000
    uint256 public constant MAX_FEE_BPS = 10_000;

    uint256 public constant NAV_CHANGE_ROUNDING_BUFFER = 100;

    /// @notice Factory contract that created this vault
    address public immutable factory;

    /// @notice Overarching baseAsset type
    bytes32 public immutable vaultType = VaultTypes.LST;

    /// @dev The asset that is deposited into the vault
    IERC20 internal immutable _baseAsset;

    /// @notice Decimals of the base asset. Used as the decimals for the vault itself
    uint8 internal immutable _baseAssetDecimals;

    /// @dev Full list of possible destinations that could be deployed to
    EnumerableSet.AddressSet internal destinations;

    /// @dev Destinations that queued for removal
    EnumerableSet.AddressSet internal removalQueue;

    /// @dev destinationVaultAddress -> Info .. Debt reporting snapshot info
    mapping(address => DestinationInfo) internal destinationInfo;

    /// @notice The amount of baseAsset deposited into the contract pending deployment
    uint256 public totalIdle = 0;

    /// @notice The current (though cached) value of assets we've deployed
    uint256 public totalDebt = 0;

    /// @notice The destinations, in order, in which withdrawals will be attempted from
    IDestinationVault[] public withdrawalQueue;

    /// @notice Main rewarder for this contract
    IMainRewarder public rewarder;

    /// @notice Current performance fee taken on profit. 100% == 10000
    uint256 public performanceFeeBps;

    /// @notice Where claimed fees are sent
    address public feeSink;

    /// @notice The last nav/share height we took fees at
    uint256 public navPerShareHighMark = MAX_FEE_BPS;

    /// @notice The last timestamp we took fees at
    uint256 public navPerShareHighMarkTimestamp;

    /// @notice The max total supply of shares we'll allow to be minted
    uint256 public totalSupplyLimit;

    /// @notice The max shares a single wallet is allowed to hold
    uint256 public perWalletLimit;

    error TooFewAssets(uint256 requested, uint256 actual);
    error WithdrawShareCalcInvalid(uint256 currentShares, uint256 cachedShares);
    error InvalidFee(uint256 newFee);
    error RewarderAlreadySet();
    error RebalanceDestinationsMatch(address destinationVault);
    error InvalidDestination(address destination);
    error NavChanged(uint256 oldNav, uint256 newNav);
    error NavOpsInProgress();
    error OverWalletLimit(address to);

    event PerformanceFeeSet(uint256 newFee);
    event FeeSinkSet(address newFeeSink);
    event NewNavHighWatermark(uint256 navPerShare, uint256 timestamp);
    event TotalSupplyLimitSet(uint256 limit);
    event PerWalletLimitSet(uint256 limit);

    modifier noNavChange() {
        uint256 ts = totalSupply();
        if (ts > 0) {
            uint256 oldNav = _snapStartNav();
            _;
            _ensureNoNavChange(oldNav);
        } else {
            _;
        }
    }

    modifier ensureNoNavOps() {
        if (systemRegistry.systemSecurity().navOpsInProgress() > 0) {
            revert NavOpsInProgress();
        }
        _;
    }

    modifier trackNavOps() {
        systemRegistry.systemSecurity().enterNavOperation();
        _;
        systemRegistry.systemSecurity().exitNavOperation();
    }

    constructor(
        ISystemRegistry _systemRegistry,
        address _vaultAsset,
        uint256 supplyLimit,
        uint256 walletLimit
    )
        SystemComponent(_systemRegistry)
        ERC20(
            string(abi.encodePacked(ERC20(_vaultAsset).name(), " Pool Token")),
            string(abi.encodePacked("lmp", ERC20(_vaultAsset).symbol()))
        )
        ERC20Permit(string(abi.encodePacked("lmp", ERC20(_vaultAsset).symbol())))
        SecurityBase(address(_systemRegistry.accessController()))
        Pausable(_systemRegistry)
    {
        _baseAsset = IERC20(_vaultAsset);
        _baseAssetDecimals = IERC20(_vaultAsset).decimals();

        // init withdrawal queue to empty (slither issue)
        withdrawalQueue = new IDestinationVault[](0);

        factory = msg.sender;
        navPerShareHighMarkTimestamp = block.timestamp;

        _setTotalSupplyLimit(supplyLimit);
        _setPerWalletLimit(walletLimit);
    }

    /// @inheritdoc IERC20
    function decimals() public view virtual override(ERC20, IERC20) returns (uint8) {
        return _baseAssetDecimals;
    }

    /// @notice Set the global share limit
    /// @dev Zero is allowed here and used as a way to stop deposits but allow withdrawals
    /// @param newSupplyLimit new total amount of shares allowed to be minted
    function setTotalSupplyLimit(uint256 newSupplyLimit) external onlyOwner {
        _setTotalSupplyLimit(newSupplyLimit);
    }

    /// @notice Set the per-wallet share limit
    /// @param newWalletLimit new total shares a wallet is allowed to hold
    function setPerWalletLimit(uint256 newWalletLimit) external onlyOwner {
        _setPerWalletLimit(newWalletLimit);
    }

    /// @notice Set the fee that will be taken when profit is realized
    /// @dev Resets the high water to current value
    /// @param fee Percent. 100% == 10000
    function setPerformanceFeeBps(uint256 fee) external nonReentrant hasRole(Roles.LMP_FEE_SETTER_ROLE) {
        if (fee >= MAX_FEE_BPS) {
            revert InvalidFee(fee);
        }

        performanceFeeBps = fee;

        // Set the high mark when we change the fee so we aren't able to go farther back in
        // time than one debt reporting and claim fee's against past profits
        uint256 supply = totalSupply();
        if (supply > 0) {
            navPerShareHighMark = (totalAssets() * MAX_FEE_BPS) / supply;
        } else {
            // The default high mark is 1:1. We don't want to be able to take
            // fee's before the first debt reporting
            // Before a rebalance, everything will be in idle and we don't want to take
            // fee's on pure idle
            navPerShareHighMark = MAX_FEE_BPS;
        }

        emit PerformanceFeeSet(fee);
    }

    /// @notice Set the address that will receive fees
    /// @param newFeeSink Address that will receive fees
    function setFeeSink(address newFeeSink) external onlyOwner {
        emit FeeSinkSet(newFeeSink);

        // Zero is valid. One way to disable taking fees
        // slither-disable-next-line missing-zero-check
        feeSink = newFeeSink;
    }

    /// @notice Set the rewarder contract used by the vault
    /// @dev Must be set immediately on initialization/creation and only once
    function setRewarder(address _rewarder) external {
        if (msg.sender != factory) {
            revert Errors.AccessDenied();
        }

        Errors.verifyNotZero(_rewarder, "rewarder");

        if (address(rewarder) != address(0)) {
            revert RewarderAlreadySet();
        }

        rewarder = IMainRewarder(_rewarder);

        emit RewarderSet(_rewarder);
    }

    /// @dev See {IERC4626-asset}.
    function asset() public view virtual override returns (address) {
        return address(_baseAsset);
    }

    function totalAssets() public view override returns (uint256) {
        return totalIdle + totalDebt;
    }

    /// @dev See {IERC4626-convertToShares}.
    function convertToShares(uint256 assets) public view virtual returns (uint256 shares) {
        shares = _convertToShares(assets, Math.Rounding.Down);
    }

    /// @dev See {IERC4626-convertToAssets}.
    function convertToAssets(uint256 shares) public view virtual returns (uint256 assets) {
        assets = _convertToAssets(shares, Math.Rounding.Down);
    }

    //////////////////////////////////////////////////////////////////////
    //								Deposit								//
    //////////////////////////////////////////////////////////////////////

    /// @dev See {IERC4626-maxDeposit}.
    function maxDeposit(address wallet) public view virtual override returns (uint256 maxAssets) {
        maxAssets = convertToAssets(_maxMint(wallet));
    }

    /// @dev See {IERC4626-previewDeposit}.
    function previewDeposit(uint256 assets) public view virtual returns (uint256 shares) {
        shares = _convertToShares(assets, Math.Rounding.Down);
    }

    function deposit(
        uint256 assets,
        address receiver
    ) public virtual override nonReentrant noNavChange ensureNoNavOps returns (uint256 shares) {
        Errors.verifyNotZero(assets, "assets");
        if (assets > maxDeposit(receiver)) {
            revert ERC4626DepositExceedsMax(assets, maxDeposit(receiver));
        }

        shares = previewDeposit(assets);

        _transferAndMint(assets, shares, receiver);
    }

    /// @dev See {IERC4626-maxMint}.
    function maxMint(address wallet) public view virtual override returns (uint256 maxShares) {
        maxShares = _maxMint(wallet);
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
    ) public virtual override nonReentrant noNavChange ensureNoNavOps returns (uint256 assets) {
        if (shares > maxMint(receiver)) {
            revert ERC4626MintExceedsMax(shares, maxMint(receiver));
        }

        assets = previewMint(shares);

        _transferAndMint(assets, shares, receiver);
    }

    //////////////////////////////////////////////////////////////////////
    //								Withdraw							//
    //////////////////////////////////////////////////////////////////////

    /// @dev See {IERC4626-withdraw}.
    function withdraw(
        uint256 assets,
        address receiver,
        address owner
    ) public virtual override nonReentrant noNavChange ensureNoNavOps returns (uint256 shares) {
        Errors.verifyNotZero(assets, "assets");
        uint256 maxAssets = maxWithdraw(owner);
        if (assets > maxAssets) {
            revert ERC4626ExceededMaxWithdraw(owner, assets, maxAssets);
        }

        // query number of shares these assets match
        shares = previewWithdraw(assets);

        uint256 actualAssets = _withdraw(assets, shares, receiver, owner);

        if (actualAssets < assets) {
            revert TooFewAssets(assets, actualAssets);
        }
    }

    /// @dev See {IERC4626-redeem}.
    function redeem(
        uint256 shares,
        address receiver,
        address owner
    ) public virtual override nonReentrant noNavChange ensureNoNavOps returns (uint256 assets) {
        uint256 maxShares = maxRedeem(owner);
        if (shares > maxShares) {
            revert ERC4626ExceededMaxRedeem(owner, shares, maxShares);
        }

        assets = previewRedeem(shares);

        _withdraw(assets, shares, receiver, owner);
    }

    function _calcUserWithdrawSharesToBurn(
        IDestinationVault destVault,
        uint256 userShares,
        uint256 maxAssetsToPull,
        uint256 totalVaultShares
    ) internal returns (uint256 sharesToBurn, uint256 totalDebtBurn) {
        // Figure out how many shares we can burn from the destination as well
        // as what our totalDebt deduction should be (totalDebt being a cached value).
        // If the destination vault is currently sitting at a profit, then the user can burn
        // all the shares this vault owns. If its at a loss, they can only burn an amount
        // proportional to their ownership of this vault. This is so a user doesn't lock in
        // a loss for the entire vault during their withdrawal

        address vault = address(destVault);
        uint256 currentDvShares = destVault.balanceOf(address(this));

        // slither-disable-next-line incorrect-equality
        if (currentDvShares == 0) {
            return (0, 0);
        }

        // Calculate the current value of our shares
        uint256 currentDvDebtValue = destVault.debtValue(currentDvShares);

        // Get the basis for the current deployment
        uint256 cachedDebtBasis = destinationInfo[vault].debtBasis;

        // The amount of shares we had at the last debt reporting
        uint256 cachedDvShares = destinationInfo[vault].ownedShares;

        // The value of our debt + earned rewards at last debt reporting
        uint256 cachedCurrentDebt = destinationInfo[vault].currentDebt;

        // Our current share balance should only ever be lte the last snapshot
        // Any update to the deployment should update the snapshot and withdrawals
        // can only lower it
        if (currentDvShares > cachedDvShares) {
            revert WithdrawShareCalcInvalid(currentDvShares, cachedDvShares);
        }

        // Recalculated what the debtBasis is with the current number of shares
        uint256 updatedDebtBasis = cachedDebtBasis.mulDiv(currentDvShares, cachedDvShares, Math.Rounding.Up);

        // Neither of these numbers include rewards from the DV
        if (currentDvDebtValue < updatedDebtBasis) {
            // We are currently sitting at a loss. Limit the value we can pull from
            // the destination vault
            currentDvDebtValue = currentDvDebtValue.mulDiv(userShares, totalVaultShares, Math.Rounding.Down);
            currentDvShares = currentDvShares.mulDiv(userShares, totalVaultShares, Math.Rounding.Down);
        }

        // Shouldn't pull more than we want
        // Or, we're not in profit so we limit the pull
        if (currentDvDebtValue < maxAssetsToPull) {
            maxAssetsToPull = currentDvDebtValue;
        }

        // Calculate the portion of shares to burn based on the assets we need to pull
        // and the current total debt value. These are destination vault shares.
        sharesToBurn = currentDvShares.mulDiv(maxAssetsToPull, currentDvDebtValue, Math.Rounding.Up);

        // This is what will be deducted from totalDebt with the withdrawal. The totalDebt number
        // is calculated based on the cached values so we need to be sure to reduce it
        // proportional to the original cached debt value
        totalDebtBurn = cachedCurrentDebt.mulDiv(sharesToBurn, cachedDvShares, Math.Rounding.Up);
    }

    // slither-disable-next-line cyclomatic-complexity
    function _withdraw(
        uint256 assets,
        uint256 shares,
        address receiver,
        address owner
    ) internal virtual returns (uint256) {
        uint256 idle = totalIdle;
        WithdrawInfo memory info = WithdrawInfo({
            currentIdle: idle,
            assetsFromIdle: assets >= idle ? idle : assets,
            totalAssetsToPull: assets - (assets >= idle ? idle : assets),
            totalAssetsPulled: 0,
            idleIncrease: 0,
            debtDecrease: 0
        });

        // If not enough funds in idle, then pull what we need from destinations
        if (info.totalAssetsToPull > 0) {
            uint256 totalVaultShares = totalSupply();

            // Using pre-set withdrawalQueue for withdrawal order to help minimize user gas
            uint256 withdrawalQueueLength = withdrawalQueue.length;
            for (uint256 i = 0; i < withdrawalQueueLength; ++i) {
                IDestinationVault destVault = IDestinationVault(withdrawalQueue[i]);
                (uint256 sharesToBurn, uint256 totalDebtBurn) = _calcUserWithdrawSharesToBurn(
                    destVault, shares, info.totalAssetsToPull - info.totalAssetsPulled, totalVaultShares
                );
                if (sharesToBurn == 0) {
                    continue;
                }

                info.totalAssetsPulled += destVault.withdrawBaseAsset(sharesToBurn, address(this));
                info.debtDecrease += totalDebtBurn;

                // It's possible we'll get back more assets than we anticipate from a swap
                // so if we do, throw it in idle and stop processing. You don't get more than we've calculated
                if (info.totalAssetsPulled > info.totalAssetsToPull) {
                    info.idleIncrease = info.totalAssetsPulled - info.totalAssetsToPull;
                    info.totalAssetsPulled = info.totalAssetsToPull;
                    break;
                }

                // No need to keep going if we have the amount we're looking for
                // Any overage is accounted for above. Anything lower and we need to keep going
                // slither-disable-next-line incorrect-equality
                if (info.totalAssetsPulled == info.totalAssetsToPull) {
                    break;
                }
            }
        }

        // At this point should have all the funds we need sitting in in the vault
        uint256 returnedAssets = info.assetsFromIdle + info.totalAssetsPulled;

        // subtract what's taken out of idle from totalIdle
        // slither-disable-next-line events-maths
        totalIdle = info.currentIdle + info.idleIncrease - info.assetsFromIdle;

        if (info.debtDecrease > totalDebt) {
            totalDebt = 0;
        } else {
            totalDebt -= info.debtDecrease;
        }

        // do the actual withdrawal (going off of total # requested)
        uint256 allowed = allowance(owner, msg.sender);
        if (msg.sender != owner && allowed != type(uint256).max) {
            if (shares > allowed) revert AmountExceedsAllowance(shares, allowed);

            unchecked {
                _approve(owner, msg.sender, allowed - shares);
            }
        }

        _burn(owner, shares);

        emit Withdraw(msg.sender, receiver, owner, assets, shares);

        _baseAsset.safeTransfer(receiver, returnedAssets);

        return returnedAssets;
    }

    function claimRewards() public whenNotPaused {
        rewarder.getReward(msg.sender, true);
    }

    function recover(
        address[] calldata tokens,
        uint256[] calldata amounts,
        address[] calldata _destinations
    ) external virtual override hasRole(Roles.TOKEN_RECOVERY_ROLE) {
        uint256 len = tokens.length;
        Errors.verifyArrayLengths(len, amounts.length, "tokens+amounts");
        Errors.verifyArrayLengths(len, _destinations.length, "tokens+_destinations");

        emit TokensRecovered(tokens, amounts, _destinations);

        for (uint256 i = 0; i < len; ++i) {
            (address tokenAddress, uint256 amount, address destination) = (tokens[i], amounts[i], _destinations[i]);

            if (_isTrackedAsset(tokenAddress)) {
                revert Errors.AssetNotAllowed(tokenAddress);
            }

            IERC20(tokenAddress).safeTransfer(destination, amount);
        }
    }

    /**
     * @dev Internal conversion function (from assets to shares) with support for rounding direction.
     *
     * Will revert if assets > 0, totalSupply > 0 and totalAssets = 0. That corresponds to a case where any asset
     * would represent an infinite amount of shares.
     */
    function _convertToShares(uint256 assets, Math.Rounding rounding) internal view virtual returns (uint256 shares) {
        uint256 supply = totalSupply();

        // slither-disable-next-line incorrect-equality
        shares = (assets == 0 || supply == 0) ? assets : assets.mulDiv(supply, totalAssets(), rounding);
    }

    /// @dev Internal conversion function (from shares to assets) with support for rounding direction.
    function _convertToAssets(uint256 shares, Math.Rounding rounding) internal view virtual returns (uint256 assets) {
        uint256 supply = totalSupply();
        assets = (supply == 0) ? shares : shares.mulDiv(totalAssets(), supply, rounding);
    }

    function _maxRedeem(address owner) internal view virtual returns (uint256 maxShares) {
        maxShares = paused() ? 0 : balanceOf(owner);
    }

    function _transferAndMint(uint256 assets, uint256 shares, address receiver) internal virtual {
        // From OZ documentation:
        // ----------------------
        // If _asset is ERC777, `transferFrom` can trigger a reentrancy BEFORE the transfer happens through the
        // `tokensToSend` hook. On the other hand, the `tokenReceived` hook, that is triggered after the transfer,
        // calls the vault, which is assumed not malicious.
        //
        // Conclusion: we need to do the transfer before we mint so that any reentrancy would happen before the
        // assets are transferred and before the shares are minted, which is a valid state.
        // slither-disable-next-line reentrancy-no-eth
        _baseAsset.safeTransferFrom(msg.sender, address(this), assets);

        totalIdle += assets;

        _mint(receiver, shares);

        emit Deposit(msg.sender, receiver, assets, shares);
    }

    ///@dev Checks if vault is "healthy" in the sense of having assets backing the circulating shares.
    function _isVaultCollateralized() internal view returns (bool) {
        return totalAssets() > 0 || totalSupply() == 0;
    }

    function updateDebtReporting(address[] calldata _destinations) external nonReentrant trackNavOps {
        _updateDebtReporting(_destinations);
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

    function isDestinationRegistered(address destination) external view returns (bool) {
        return destinations.contains(destination);
    }

    function addDestinations(address[] calldata _destinations) public hasRole(Roles.DESTINATION_VAULTS_UPDATER) {
        IDestinationVaultRegistry destinationRegistry = systemRegistry.destinationVaultRegistry();

        uint256 numDestinations = _destinations.length;
        if (numDestinations == 0) revert Errors.InvalidParams();

        address dAddress;
        for (uint256 i = 0; i < numDestinations; ++i) {
            dAddress = _destinations[i];

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

    function getDestinationInfo(address destVault)
        external
        view
        nonReentrantReadOnly
        returns (DestinationInfo memory)
    {
        return destinationInfo[destVault];
    }

    /// @inheritdoc IStrategy
    function rebalance(
        address destinationIn,
        address tokenIn,
        uint256 amountIn,
        address destinationOut,
        address tokenOut,
        uint256 amountOut
    ) public nonReentrant hasRole(Roles.SOLVER_ROLE) trackNavOps {
        uint256 debtDecrease = 0;
        uint256 debtIncrease = 0;
        uint256 idleDecrease = 0;
        uint256 idleIncrease = 0;

        // make sure there's something to do
        if (amountIn == 0 && amountOut == 0) {
            revert Errors.InvalidParams();
        }

        if (destinationIn == destinationOut) {
            revert RebalanceDestinationsMatch(destinationOut);
        }

        // make sure we have a valid path
        {
            (bool success, string memory message) =
                LMPStrategy.verifyRebalance(destinationIn, tokenIn, amountIn, destinationOut, tokenOut, amountOut);
            if (!success) {
                revert RebalanceFailed(message);
            }
        }

        // Handle decrease (shares going "Out", cashing in shares and sending underlying back to swapper)
        // If the tokenOut is _asset we assume they are taking idle
        // which is already in the contract
        (debtDecrease, debtIncrease, idleDecrease, idleIncrease) =
            _handleRebalanceOut(msg.sender, destinationOut, amountOut, tokenOut);

        // Handle increase (shares coming "In", getting underlying from the swapper and trading for new shares)
        if (amountIn > 0) {
            // transfer dv underlying lp from swapper to here
            IERC20(tokenIn).safeTransferFrom(msg.sender, address(this), amountIn);

            // deposit to dv (already checked in `verifyRebalance` so no need to check return of deposit)

            if (tokenIn != address(_baseAsset)) {
                IDestinationVault dvIn = IDestinationVault(destinationIn);
                (uint256 debtDecreaseIn, uint256 debtIncreaseIn) = _handleRebalanceIn(dvIn, tokenIn, amountIn);
                debtDecrease += debtDecreaseIn;
                debtIncrease += debtIncreaseIn;
            } else {
                idleIncrease += amountIn;
            }
        }

        {
            uint256 idle = totalIdle;
            uint256 debt = totalDebt;

            if (idleDecrease > 0 || idleIncrease > 0) {
                idle = idle + idleIncrease - idleDecrease;

                // Value always emitted in collectFees regardless of change
                // slither-disable-next-line events-maths
                totalIdle = idle;
            }

            if (debtDecrease > 0 || debtIncrease > 0) {
                debt = debt + debtIncrease - debtDecrease;

                // Value always emitted in collectFees regardless of change
                // slither-disable-next-line events-maths
                totalDebt = debt;
            }

            _collectFees(idle, debt);
        }
    }

    /// @inheritdoc IStrategy
    function flashRebalance(
        FlashRebalanceParams memory rebalanceParams,
        bytes calldata data
    ) public nonReentrant hasRole(Roles.SOLVER_ROLE) trackNavOps {
        uint256 debtDecrease = 0;
        uint256 debtIncrease = 0;
        uint256 idleDecrease = 0;
        uint256 idleIncrease = 0;

        // make sure there's something to do
        if (rebalanceParams.amountIn == 0 && rebalanceParams.amountOut == 0) {
            revert Errors.InvalidParams();
        }

        if (rebalanceParams.destinationIn == rebalanceParams.destinationOut) {
            revert RebalanceDestinationsMatch(rebalanceParams.destinationOut);
        }

        // make sure we have a valid path
        {
            (bool success, string memory message) = LMPStrategy.verifyRebalance(
                rebalanceParams.destinationIn,
                rebalanceParams.tokenIn,
                rebalanceParams.amountIn,
                rebalanceParams.destinationOut,
                rebalanceParams.tokenOut,
                rebalanceParams.amountOut
            );
            if (!success) {
                revert RebalanceFailed(message);
            }
        }

        // Handle decrease (shares going "Out", cashing in shares and sending underlying back to swapper)
        // If the tokenOut is _asset we assume they are taking idle
        // which is already in the contract
        (debtDecrease, debtIncrease, idleDecrease, idleIncrease) = _handleRebalanceOut(
            address(rebalanceParams.receiver),
            rebalanceParams.destinationOut,
            rebalanceParams.amountOut,
            rebalanceParams.tokenOut
        );

        // Handle increase (shares coming "In", getting underlying from the swapper and trading for new shares)
        if (rebalanceParams.amountIn > 0) {
            IDestinationVault dvIn = IDestinationVault(rebalanceParams.destinationIn);

            // get "before" counts
            uint256 tokenInBalanceBefore = IERC20(rebalanceParams.tokenIn).balanceOf(address(this));

            // Give control back to the solver so they can make use of the "out" assets
            // and get our "in" asset
            bytes32 flashResult = rebalanceParams.receiver.onFlashLoan(
                msg.sender, rebalanceParams.tokenIn, rebalanceParams.amountIn, 0, data
            );

            // We assume the solver will send us the assets
            uint256 tokenInBalanceAfter = IERC20(rebalanceParams.tokenIn).balanceOf(address(this));

            // Make sure the call was successful and verify we have at least the assets we think
            // we were getting
            if (
                flashResult != keccak256("ERC3156FlashBorrower.onFlashLoan")
                    || tokenInBalanceAfter < tokenInBalanceBefore + rebalanceParams.amountIn
            ) {
                revert Errors.FlashLoanFailed(rebalanceParams.tokenIn, rebalanceParams.amountIn);
            }

            if (rebalanceParams.tokenIn != address(_baseAsset)) {
                (uint256 debtDecreaseIn, uint256 debtIncreaseIn) =
                    _handleRebalanceIn(dvIn, rebalanceParams.tokenIn, tokenInBalanceAfter);
                debtDecrease += debtDecreaseIn;
                debtIncrease += debtIncreaseIn;
            } else {
                idleIncrease += tokenInBalanceAfter - tokenInBalanceBefore;
            }
        }

        {
            uint256 idle = totalIdle;
            uint256 debt = totalDebt;

            if (idleDecrease > 0 || idleIncrease > 0) {
                idle = idle + idleIncrease - idleDecrease;
                totalIdle = idle;
            }

            if (debtDecrease > 0 || debtIncrease > 0) {
                debt = debt + debtIncrease - debtDecrease;
                totalDebt = debt;
            }

            _collectFees(idle, debt);
        }
    }

    /// @notice Perform deposit and debt info update for the "in" destination during a rebalance
    /// @dev This "in" function performs less validations than its "out" version
    /// @param dvIn The "in" destination vault
    /// @param tokenIn The underlyer for dvIn
    /// @param depositAmount The amount of tokenIn that will be deposited
    /// @return debtDecrease The previous amount of debt dvIn accounted for in totalDebt
    /// @return debtIncrease The current amount of debt dvIn should account for in totalDebt
    function _handleRebalanceIn(
        IDestinationVault dvIn,
        address tokenIn,
        uint256 depositAmount
    ) private returns (uint256 debtDecrease, uint256 debtIncrease) {
        IERC20(tokenIn).safeApprove(address(dvIn), depositAmount);

        // Snapshot our current shares so we know how much to back out
        uint256 originalShareBal = dvIn.balanceOf(address(this));

        // deposit to dv
        uint256 newShares = dvIn.depositUnderlying(depositAmount);

        // Update the debt info snapshot
        (uint256 totalDebtDecrease, uint256 totalDebtIncrease) =
            _recalculateDestInfo(dvIn, originalShareBal, originalShareBal + newShares, true);
        debtDecrease = totalDebtDecrease;
        debtIncrease = totalDebtIncrease;
    }

    /// @notice Perform withdraw and debt info update for the "out" destination during a rebalance
    /// @dev This "out" function performs more validations and handles idle as opposed to "in" which does not
    /// @param receiver Address that will received the withdrawn underlyer
    /// @param destinationOut The "out" destination vault
    /// @param amountOut The amount of tokenOut that will be withdrawn
    /// @param tokenOut The underlyer for destinationOut
    /// @return debtDecrease The previous amount of debt destinationOut accounted for in totalDebt
    /// @return debtIncrease The current amount of debt destinationOut should account for in totalDebt
    /// @return idleDecrease Amount of baseAsset that was sent from the vault. > 0 only when tokenOut == baseAsset
    /// @return idleIncrease Amount of baseAsset that was claimed from Destination Vault
    function _handleRebalanceOut(
        address receiver,
        address destinationOut,
        uint256 amountOut,
        address tokenOut
    ) private returns (uint256 debtDecrease, uint256 debtIncrease, uint256 idleDecrease, uint256 idleIncrease) {
        // Handle decrease (shares going "Out", cashing in shares and sending underlying back to swapper)
        // If the tokenOut is _asset we assume they are taking idle
        // which is already in the contract
        if (amountOut > 0) {
            if (tokenOut != address(_baseAsset)) {
                IDestinationVault dvOut = IDestinationVault(destinationOut);

                // Snapshot our current shares so we know how much to back out
                uint256 originalShareBal = dvOut.balanceOf(address(this));

                // Burning our shares will claim any pending baseAsset
                // rewards and send them to us. Make sure we capture them
                // so they can end up in idle
                uint256 beforeBaseAssetBal = _baseAsset.balanceOf(address(this));

                // withdraw underlying from dv
                // slither-disable-next-line unused-return
                dvOut.withdrawUnderlying(amountOut, receiver);

                idleIncrease = _baseAsset.balanceOf(address(this)) - beforeBaseAssetBal;

                // Update the debt info snapshot
                (debtDecrease, debtIncrease) =
                    _recalculateDestInfo(dvOut, originalShareBal, originalShareBal - amountOut, true);
            } else {
                // Working with idle baseAsset which should be in the vault already
                // Just send it out
                IERC20(tokenOut).safeTransfer(receiver, amountOut);
                idleDecrease = amountOut;
            }
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
    ) public view virtual returns (bool success, string memory message) {
        (success, message) =
            LMPStrategy.verifyRebalance(destinationIn, tokenIn, amountIn, destinationOut, tokenOut, amountOut);
    }

    function _updateDebtReporting(address[] memory _destinations) private {
        // TODO: Access control
        // TODO: Decide if we need to enforce all destinations to be processed as a set
        uint256 nDest = _destinations.length;

        uint256 idleIncrease = 0;
        uint256 prevNTotalDebt = 0;
        uint256 afterNTotalDebt = 0;

        for (uint256 i = 0; i < nDest; ++i) {
            IDestinationVault destVault = IDestinationVault(_destinations[i]);

            if (!destinations.contains(address(destVault))) {
                revert InvalidDestination(address(destVault));
            }

            // Get the reward value we've earned. DV rewards are always in terms of base asset
            // We track the gas used purely for off-chain stats purposes
            // Main rewarder on DV's store the earned and liquidated rewards
            // Any extra rewarders would not be taken into account here as they still need liquidated
            uint256 claimGasUsed = gasleft();
            uint256 beforeBaseAsset = _baseAsset.balanceOf(address(this));
            // We don't want any extras, those would likely not be baseAsset
            IMainRewarder(destVault.rewarder()).getReward(address(this), false);
            uint256 claimedRewardValue = _baseAsset.balanceOf(address(this)) - beforeBaseAsset;
            claimGasUsed -= gasleft();
            idleIncrease += claimedRewardValue;

            // Recalculate the debt info figuring out the change in
            // total debt value we can roll up later
            (uint256 totalDebtDecrease, uint256 totalDebtIncrease) = _recalculateDestInfo(destVault, false);
            prevNTotalDebt += totalDebtDecrease;
            afterNTotalDebt += totalDebtIncrease;

            emit DestinationDebtReporting(address(destVault), totalDebtIncrease, claimedRewardValue, claimGasUsed);
        }

        uint256 idle = totalIdle + idleIncrease;
        uint256 debt = totalDebt - prevNTotalDebt + afterNTotalDebt;

        totalIdle = idle;
        totalDebt = debt;

        _collectFees(idle, debt);
    }

    function _collectFees(uint256 idle, uint256 debt) private {
        address sink = feeSink;
        uint256 fees = 0;
        uint256 shares = 0;
        uint256 profit = 0;

        uint256 totalSupply = totalSupply();

        if (totalSupply == 0) {
            return;
        }

        uint256 currentNavPerShare = ((idle + debt) * MAX_FEE_BPS) / totalSupply;
        uint256 effectiveNavPerShareHighMark = navPerShareHighMark;

        if (currentNavPerShare > effectiveNavPerShareHighMark) {
            profit = (currentNavPerShare - effectiveNavPerShareHighMark) * totalSupply;
            fees = profit.mulDiv(performanceFeeBps, (MAX_FEE_BPS ** 2), Math.Rounding.Up);
            if (fees > 0 && sink != address(0)) {
                shares = _convertToShares(fees, Math.Rounding.Up);
                _mint(sink, shares);
                emit Deposit(address(this), sink, fees, shares);
            }
            // Set our new high water mark
            navPerShareHighMark = currentNavPerShare;
            navPerShareHighMarkTimestamp = block.timestamp;
            emit NewNavHighWatermark(currentNavPerShare, block.timestamp);
        }
        emit FeeCollected(fees, sink, shares, profit, idle, debt);
    }

    function _recalculateDestInfo(
        IDestinationVault destVault,
        bool resetDebtBasis
    ) private returns (uint256 totalDebtDecrease, uint256 totalDebtIncrease) {
        uint256 currentShareBalance = destVault.balanceOf(address(this));
        (totalDebtDecrease, totalDebtIncrease) =
            _recalculateDestInfo(destVault, currentShareBalance, currentShareBalance, resetDebtBasis);
    }

    function _recalculateDestInfo(
        IDestinationVault destVault,
        uint256 originalShares,
        uint256 currentShares,
        bool resetDebtBasis
    ) private returns (uint256 totalDebtDecrease, uint256 totalDebtIncrease) {
        // Figure out what to back out of our totalDebt number.
        // We could have had withdraws since the last snapshot which means our
        // cached currentDebt number should be decreased based on the remaining shares
        // totalDebt is decreased using the same proportion of shares method during withdrawals
        // so this should represent whatever is remaining.

        // Figure out how much our debt is currently worth
        uint256 dvDebtValue = destVault.debtValue(currentShares);

        // Calculate what we're backing out based on the original shares
        uint256 currentDebt = (destinationInfo[address(destVault)].currentDebt * originalShares)
            / Math.max(destinationInfo[address(destVault)].ownedShares, 1);
        destinationInfo[address(destVault)].currentDebt = dvDebtValue;
        destinationInfo[address(destVault)].lastReport = block.timestamp;
        destinationInfo[address(destVault)].ownedShares = currentShares;
        if (resetDebtBasis) {
            destinationInfo[address(destVault)].debtBasis = dvDebtValue;
        }

        totalDebtDecrease = currentDebt;
        totalDebtIncrease = dvDebtValue;
    }

    function _beforeTokenTransfer(address from, address to, uint256 amount) internal virtual override whenNotPaused {
        // Nothing to do really do here
        if (from == to) {
            return;
        }

        // If this isn't a mint of new tokens, then they are being transferred
        // from someone who is "staked" in the rewarder. Make sure they stop earning
        // When they transfer those funds
        if (from != address(0)) {
            rewarder.withdraw(from, amount, true);
        }

        // Make sure the destination wallet total share balance doesn't go above the
        // current perWalletLimit
        if (balanceOf(to) + amount > perWalletLimit) {
            revert OverWalletLimit(to);
        }
    }

    function _afterTokenTransfer(address from, address to, uint256 amount) internal virtual override {
        // Nothing to do really do here
        if (from == to) {
            return;
        }

        // If this isn't a burn, then the recipient should be earning in the rewarder
        // "Stake" the tokens there so they start earning
        if (to != address(0)) {
            rewarder.stake(to, amount);
        }
    }

    function _snapStartNav() private view returns (uint256 oldNav) {
        oldNav = (totalAssets() * MAX_FEE_BPS) / totalSupply();
    }

    function _ensureNoNavChange(uint256 oldNav) private view {
        uint256 lowerBound = Math.max(oldNav, NAV_CHANGE_ROUNDING_BUFFER) - NAV_CHANGE_ROUNDING_BUFFER;
        uint256 upperBound = oldNav > type(uint256).max - NAV_CHANGE_ROUNDING_BUFFER
            ? type(uint256).max
            : oldNav + NAV_CHANGE_ROUNDING_BUFFER;
        uint256 ts = totalSupply();
        if (ts > 0) {
            uint256 newNav = (totalAssets() * MAX_FEE_BPS) / ts;

            if (newNav < lowerBound || newNav > upperBound) {
                revert NavChanged(oldNav, newNav);
            }
        }
    }

    function _isTrackedAsset(address _asset) private view returns (bool) {
        if (_asset == address(this) || _asset == address(_baseAsset)) {
            return true;
        }
        return destinations.contains(_asset);
    }

    function _maxMint(address wallet) internal view virtual returns (uint256 shares) {
        if (paused()) {
            return 0;
        }

        uint256 tsLimit = totalSupplyLimit;
        uint256 walletLimit = perWalletLimit;

        if (!_isVaultCollateralized()) {
            return Math.min(tsLimit, walletLimit);
        }

        // Return max if there is no limit
        if (tsLimit == type(uint256).max && walletLimit == type(uint256).max) {
            return type(uint256).max;
        }

        // Ensure we aren't over the total supply limit
        uint256 totalSupply = totalSupply();
        if (totalSupply >= tsLimit) {
            return 0;
        }

        // Ensure the wallet isn't over the per wallet limit
        uint256 walletBalance = balanceOf(wallet);

        if (walletBalance >= perWalletLimit) {
            return 0;
        }

        shares = Math.min(tsLimit - totalSupply, walletLimit - walletBalance);
    }

    /// @notice Set the global share limit
    /// @dev Zero is allowed here and used as a way to stop deposits but allow withdrawals
    /// @param newSupplyLimit new total amount of shares allowed to be minted
    function _setTotalSupplyLimit(uint256 newSupplyLimit) private {
        // We do not expect that a decrease in this value will affect any shares already minted
        // Just that new shares won't be minted until existing fall below the limit

        totalSupplyLimit = newSupplyLimit;

        emit TotalSupplyLimitSet(newSupplyLimit);
    }

    /// @notice Set the per-wallet share limit
    /// @param newWalletLimit new total shares a wallet is allowed to hold
    function _setPerWalletLimit(uint256 newWalletLimit) private {
        Errors.verifyNotZero(newWalletLimit, "newWalletLimit");

        perWalletLimit = newWalletLimit;

        emit PerWalletLimitSet(newWalletLimit);
    }
}

//slither-disable-end reentrancy-no-eth,reentrancy-benign
