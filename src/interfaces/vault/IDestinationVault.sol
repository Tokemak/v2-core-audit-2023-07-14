// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import { IBaseAssetVault } from "./IBaseAssetVault.sol";
import { ISystemRegistry } from "src/interfaces/ISystemRegistry.sol";
import { IERC20Metadata as IERC20 } from "openzeppelin-contracts/token/ERC20/extensions/IERC20Metadata.sol";

interface IDestinationVault is IBaseAssetVault, IERC20 {
    /* ******************************** */
    /* View                             */
    /* ******************************** */

    /// @notice Amount of baseAsset sitting in contract
    /// @dev In terms of the baseAsset
    function idle() external view returns (uint256);

    /// @notice Debt we have sent out to underlying destination
    /// @dev In terms of the baseAsset
    function debt() external view returns (uint256);

    /* ******************************** */
    /* Events                           */
    /* ******************************** */

    event Donated(address sender, uint256 amount);
    event Withdraw(
        uint256 target, uint256 actual, uint256 debtLoss, uint256 claimLoss, uint256 fromIdle, uint256 fromDebt
    );

    /* ******************************** */
    /* Errors                           */
    /* ******************************** */

    error ZeroAddress(string paramName);

    /* ******************************** */
    /* Functions                        */
    /* ******************************** */

    /// @notice Setup the contract. These will be cloned so no constructor
    /// @param systemRegistry The system this vault will be used in
    /// @param _baseAsset Base asset of the system. WETH/USDC/etc
    /// @param baseName Name of the DEX pool this vault proxies
    /// @param params Any parameters needed to setup the contract
    function initialize(
        ISystemRegistry systemRegistry,
        IERC20 _baseAsset,
        string memory baseName,
        bytes memory params
    ) external;

    /// @notice Calculates the current value of our debt
    /// @dev Queries the current value of all tokens we have deployed, whether its a single place, multiple, staked, etc
    /// @return value The current value of our debt in terms of the baseAsset
    function debtValue() external returns (uint256 value);

    /// @notice Calculates the current value of any vested-but-not-realized rewards
    /// @return value The current value of our rewards in terms of the baseAsset
    function rewardValue() external returns (uint256 value);

    /// @notice Claims any rewards that have been previously claimed and are vesting
    /// @return amount The amount claimed in terms of the baseAsset
    function claimVested() external returns (uint256 amount);

    /// @notice Deposit some amount of the base asset
    /// @dev Receives no token or share in response
    /// @param amount Amount of base asset to deposit
    function donate(uint256 amount) external;

    /// @notice Attempt to withdraw the target amount of the baseAsset
    /// @dev Partial amounts may be returned. Pct numbers must be of the same precision.
    /// @param targetAmount Desired amount of baseAsset
    /// @param ownerPctNumerator Numerator of the pct of caller shares we're allowed to burn in the event of a deficit
    /// @param ownerPctDenominator Denominator of the pct of caller shares we're allowed to burn in the event of a
    /// deficit
    /// @return amount Actual amount of baseAsset returned
    /// @return loss Loss realized as part of the operation
    function withdrawBaseAsset(
        uint256 targetAmount,
        uint256 ownerPctNumerator,
        uint256 ownerPctDenominator
    ) external returns (uint256 amount, uint256 loss);

    /// @notice Pull any non-tracked token to the specified destination
    /// @dev Should be limited to TOKEN_RECOVERY_ROLE
    function recover(address[] calldata tokens, uint256[] calldata amounts, address[] calldata destinations) external;
}
