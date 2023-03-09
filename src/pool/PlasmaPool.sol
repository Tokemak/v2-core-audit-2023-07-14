// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import { IPlasmaPool } from "src/interfaces/pool/IPlasmaPool.sol";
import { IERC4626 } from "openzeppelin-contracts/interfaces/IERC4626.sol";
import { ERC20Permit } from "openzeppelin-contracts/token/ERC20/extensions/draft-ERC20Permit.sol";
import { IERC20 } from "openzeppelin-contracts/token/ERC20/IERC20.sol";
import { ERC20 } from "openzeppelin-contracts/token/ERC20/ERC20.sol";
import { Pausable } from "openzeppelin-contracts/security/Pausable.sol";
import { SafeERC20 } from "openzeppelin-contracts/token/ERC20/utils/SafeERC20.sol";
import { Math } from "openzeppelin-contracts/utils/math/Math.sol";

contract PlasmaPool is IPlasmaPool, ERC20Permit, Pausable {
    using Math for uint256;
    using SafeERC20 for ERC20;
    using SafeERC20 for IERC20;

    IERC20 internal immutable _asset;

    constructor(address _poolAsset)
        ERC20(
            string(abi.encodePacked(ERC20(_poolAsset).name(), " Pool Token")),
            string(abi.encodePacked("zn", ERC20(_poolAsset).symbol()))
        )
        ERC20Permit(string(abi.encodePacked("zn", ERC20(_poolAsset).symbol())))
    {
        if (_poolAsset == address(0)) revert TokenAddressZero();
        _asset = IERC20(_poolAsset);
    }

    /// @dev See {IERC4626-asset}.
    function asset() public view virtual override returns (address) {
        return address(_asset);
    }

    /// @dev See {IERC4626-totalAssets}.
    function totalAssets() public view virtual override returns (uint256 totalManagedAssets) {
        totalManagedAssets = _asset.balanceOf(address(this));
    }

    /// @dev See {IERC4626-convertToAssets}.
    function convertToAssets(uint256 shares) public view virtual override whenNotPaused returns (uint256 assets) {
        assets = _convertToAssets(shares, Math.Rounding.Down);
    }

    /// @dev See {IERC4626-convertToShares}.
    function convertToShares(uint256 assets) public view virtual override whenNotPaused returns (uint256 shares) {
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
    function previewDeposit(uint256 assets) public view virtual override returns (uint256 shares) {
        shares = _convertToShares(assets, Math.Rounding.Down);
    }

    /// @dev See {IERC4626-deposit}.
    function deposit(uint256 assets, address receiver) public virtual override whenNotPaused returns (uint256 shares) {
        if (assets > maxDeposit(receiver)) {
            revert ERC4626DepositExceedsMax(assets, maxDeposit(receiver));
        }

        shares = previewDeposit(assets);

        _transferAndMint(assets, shares, receiver, true);
        // shares = _deposit(assets, receiver);
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
    function maxRedeem(address owner) public view virtual override returns (uint256 maxShares) {
        maxShares = _maxRedeem(owner);
    }

    /// @dev See {IERC4626-previewMint}.
    function previewMint(uint256 shares) public view virtual override returns (uint256 assets) {
        assets = _convertToAssets(shares, Math.Rounding.Up);
    }

    /// @dev See {IERC4626-previewWithdraw}.
    function previewWithdraw(uint256 assets) public view virtual override returns (uint256 shares) {
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
    function mint(uint256 shares, address receiver) public virtual override whenNotPaused returns (uint256 assets) {
        if (shares > maxMint(receiver)) {
            revert ERC4626MintExceedsMax(shares, maxMint(receiver));
        }
        // OZ: // TODO: compare
        //         require(shares <= maxMint(receiver), "ERC4626: mint more than max");
        //
        //         uint256 assets = previewMint(shares);
        //         _deposit(_msgSender(), receiver, assets, shares);
        //
        //         return assets;
        assets = _mint(shares, receiver);
    }

    /// @dev See {IERC4626-withdraw}.
    function withdraw(
        uint256 assets,
        address receiver,
        address owner
    ) public virtual override whenNotPaused returns (uint256 shares) {
        // OZ: // TODO: compare
        //         require(assets <= maxWithdraw(owner), "ERC4626: withdraw more than max");
        //
        //         uint256 shares = previewWithdraw(assets);
        //         _withdraw(_msgSender(), receiver, owner, assets, shares);
        //
        //         return shares;
        shares = _withdraw(assets, receiver, owner);
    }

    /// @dev See {IERC4626-redeem}.
    function redeem(
        uint256 shares,
        address receiver,
        address owner
    ) public virtual override whenNotPaused returns (uint256 assets) {
        // OZ: // TODO: compare
        //         require(shares <= maxRedeem(owner), "ERC4626: redeem more than max");
        //
        //         uint256 assets = previewRedeem(shares);
        //         _withdraw(_msgSender(), receiver, owner, assets, shares);
        //
        //         return assets;
        assets = previewRedeem(shares);
        _burnTransfer(assets, shares, receiver, owner, true);
    }

    /**
     *          Internal implementations (overridable)
     */

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
        _transferAndMint(assets, shares, receiver, false);
    }

    function _withdraw(uint256 assets, address receiver, address owner) internal virtual returns (uint256 shares) {
        shares = previewWithdraw(assets);

        _burnTransfer(assets, shares, receiver, owner, false);
    }

    function _maxRedeem(address owner) internal view virtual returns (uint256 maxShares) {
        maxShares = paused() ? 0 : balanceOf(owner);
    }

    function _transferAndMint(uint256 assets, uint256 shares, address receiver, bool fromDeposit) internal virtual {
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

        _afterDepositHook(assets, shares, receiver, fromDeposit);
        _mint(receiver, shares);

        emit Deposit(_msgSender(), receiver, assets, shares);
    }

    function _burnTransfer(
        uint256 assets,
        uint256 shares,
        address receiver,
        address owner,
        bool fromRedeem
    ) internal virtual {
        // If caller is not the owner of the shares
        uint256 allowed = allowance(owner, msg.sender);
        if (msg.sender != owner && allowed != type(uint256).max) {
            if (shares > allowed) {
                revert AmountExceedsAllowance(shares, allowed);
            }

            _approve(owner, msg.sender, allowed - shares);
        }
        _beforeWithdrawHook(assets, shares, owner, fromRedeem);

        _burn(owner, shares);

        emit Withdraw(msg.sender, receiver, owner, assets, shares);

        _asset.safeTransfer(receiver, assets);
    }

    ///@dev Checks if vault is "healthy" in the sense of having assets backing the circulating shares.
    function _isVaultCollateralized() private view returns (bool) {
        return totalAssets() > 0 || totalSupply() == 0;
    }

    function _beforeWithdrawHook(
        uint256, /*assets*/
        uint256, /*shares*/
        address, /*owner*/
        bool /*fromRedeem*/
    ) internal virtual {
        // Do Nothing
    }

    function _afterDepositHook(
        uint256, /*assets*/
        uint256, /*shares*/
        address, /*receiver*/
        bool /*fromDeposit*/
    ) internal virtual {
        // Do Nothing
    }
}
