// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import { Errors } from "src/utils/Errors.sol";
import { Math } from "openzeppelin-contracts/utils/math/Math.sol";
import { IERC20 } from "openzeppelin-contracts/token/ERC20/IERC20.sol";
import { IERC20Metadata } from "openzeppelin-contracts/token/ERC20/extensions/IERC20Metadata.sol";
import { SafeERC20 } from "openzeppelin-contracts/token/ERC20/utils/SafeERC20.sol";
import { EnumerableSet } from "openzeppelin-contracts/utils/structs/EnumerableSet.sol";

import { DestinationVault } from "src/vault/DestinationVault.sol";
import { ISystemRegistry } from "src/interfaces/ISystemRegistry.sol";
import { MainRewarder } from "src/rewarders/MainRewarder.sol";
import { ISwapRouter } from "src/interfaces/swapper/ISwapRouter.sol";
import { IClaimableRewardsAdapter } from "src/interfaces/destinations/IClaimableRewardsAdapter.sol";
import { IVault } from "src/interfaces/external/balancer/IVault.sol";
import { AuraAdapter } from "src/destinations/adapters/staking/AuraAdapter.sol";
import { BalancerV2MetaStablePoolAdapter } from "src/destinations/adapters/BalancerV2MetaStablePoolAdapter.sol";

contract BalancerAuraDestinationVault is AuraAdapter, BalancerV2MetaStablePoolAdapter, DestinationVault {
    using SafeERC20 for IERC20;
    using EnumerableSet for EnumerableSet.AddressSet;

    error InvalidPoolId();
    error NothingToClaim();
    error NoDebtReclaimed();

    /* ******************************** */
    /* State Variables                  */
    /* ******************************** */

    MainRewarder public rewarder;
    ISwapRouter public swapper;

    address public staking;
    bytes32 public poolId;

    EnumerableSet.AddressSet internal _trackedTokens;

    ///@notice In `_trackedTokens` LP token must be at first position
    function initialize(
        ISystemRegistry _systemRegistry,
        IERC20Metadata _baseAsset,
        string memory baseName,
        bytes memory data,
        IVault _vault,
        MainRewarder _rewarder,
        ISwapRouter _swapper,
        address _staking,
        bytes32 _poolId,
        address[] calldata trackedTokensArr
    ) public initializer {
        //slither-disable-start missing-zero-check
        DestinationVault.initialize(_systemRegistry, _baseAsset, baseName, data);
        BalancerV2MetaStablePoolAdapter.initialize(_vault);

        Errors.verifyNotZero(address(_rewarder), "_rewarder");
        Errors.verifyNotZero(address(_swapper), "_swapper");
        Errors.verifyNotZero(address(_staking), "_staking");

        rewarder = _rewarder;
        swapper = _swapper;
        staking = _staking;

        if (_poolId.length == 0) revert InvalidPoolId();
        poolId = _poolId;

        if (trackedTokensArr.length == 0) revert ArrayLengthMismatch();
        for (uint256 i = 0; i < trackedTokensArr.length; ++i) {
            //slither-disable-next-line unused-return
            _trackedTokens.add(trackedTokensArr[i]);
        }
        //slither-disable-end missing-zero-check
    }

    function lpToken() public view returns (address) {
        return _trackedTokens.at(0);
    }

    function poolTokens() public view returns (IERC20[] memory trackedPoolTokens) {
        trackedPoolTokens = new IERC20[](_trackedTokens.length());

        for (uint256 i = 1; i < _trackedTokens.length(); ++i) {
            trackedPoolTokens[i] = IERC20(_trackedTokens.at(i));
        }
    }

    function trackedTokens() public view returns (address[] memory trackedTokensArr) {
        trackedTokensArr = new address[](_trackedTokens.length());

        for (uint256 i = 0; i < _trackedTokens.length(); ++i) {
            trackedTokensArr[i] = _trackedTokens.at(i);
        }
    }

    function auraBalance() public view returns (uint256) {
        return IERC20(staking).balanceOf(address(this));
    }

    function balancerBalance() public view returns (uint256) {
        return IERC20(lpToken()).balanceOf(address(this));
    }

    function totalLpAmount() public view returns (uint256) {
        return auraBalance() + balancerBalance();
    }

    function debtValue() public view override returns (uint256 value) {
        // solhint-disable-next-line no-unused-vars
        uint256 auraCurrentBalance = auraBalance();
        // solhint-disable-next-line no-unused-vars
        uint256 balancerLpAmount = balancerBalance();
        // TODO: integrate pricing:
        // value += lpAmountPrice;
    }

    function rewardValue() public view override returns (uint256 value) {
        value = rewarder.earned(address(this));

        //slither-disable-start calls-loop
        for (uint256 i = 0; i < rewarder.extraRewardsLength(); ++i) {
            IERC20 rewardToken = IERC20(rewarder.extraRewards(i));
            // solhint-disable-next-line no-unused-vars
            uint256 rewardAmount = rewardToken.balanceOf(address(this));
            // TODO: integrate pricing:
            // value += rewardPrice;
        }
        //slither-disable-end calls-loop
    }

    function isTrackedToken_(address token) internal view virtual override returns (bool) {
        return _trackedTokens.contains(token);
    }

    function claimVested_() internal virtual override nonReentrant returns (uint256 amount) {
        uint256 balanceBefore = baseAsset.balanceOf(address(this));
        rewarder.getReward();
        amount = baseAsset.balanceOf(address(this)) - balanceBefore;
        // slither-disable-next-line incorrect-equality
        if (amount == 0) revert NothingToClaim();
    }

    function reclaimDebt_(
        uint256 pctNumerator,
        uint256 pctDenominator
    ) internal virtual override nonReentrant returns (uint256 amount, uint256 loss) {
        // defining total amount we want to burn in base asset value
        uint256 totalBurnAmount = Math.mulDiv(debt, pctNumerator, pctDenominator, Math.Rounding.Down);
        // defining total amount we want to burn in terms of LP quantity
        uint256 totalLpBurnAmount = Math.mulDiv(totalLpAmount(), pctNumerator, pctDenominator, Math.Rounding.Down);

        // 1) withdraw Aura if we cannot cover all (we prefer not to pull Aura to stake as long as we can)
        uint256 auraLpBurnAmount = 0;
        uint256 balancerLpBalance = balancerBalance();
        if (totalLpBurnAmount > balancerLpBalance) {
            auraLpBurnAmount = totalLpBurnAmount - balancerLpBalance;
            withdrawStake(lpToken(), staking, auraLpBurnAmount);
        }

        // 2) withdraw Balancer
        uint256 balancerLpBurnAmount = totalLpBurnAmount - auraLpBurnAmount;
        IERC20[] memory tokens = poolTokens();
        uint256[] memory minAmountsOut = new uint256[](tokens.length);

        uint256[] memory sellAmounts = removeLiquidityImbalance(poolId, balancerLpBurnAmount, tokens, minAmountsOut);

        // 3) swap what we receive
        for (uint256 i = 0; i < tokens.length; ++i) {
            address sellToken = address(poolTokens[i]);
            uint256 sellAmount = sellAmounts[i];
            IERC20(sellToken).safeApprove(address(swapper), sellAmount);
            amount += swapper.swapForQuote(sellToken, sellAmount, address(baseAsset), 0);
        }

        // 4) check amount and loss
        // slither-disable-next-line incorrect-equality
        if (amount == 0) {
            revert NoDebtReclaimed();
        }
        if (amount < totalBurnAmount) {
            loss = totalBurnAmount - amount;
        }
    }
}
