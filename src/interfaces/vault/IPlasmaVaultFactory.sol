// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

interface IPlasmaVaultFactory {
    ///////////////////////////////////////////////////////////////////
    //                        Errors
    ///////////////////////////////////////////////////////////////////

    error ZeroAddress();
    error PermissionDenied();
    error PoolTypeNotFound();
    error PoolTypeAlreadyExists();

    ///////////////////////////////////////////////////////////////////
    //                        Events
    ///////////////////////////////////////////////////////////////////

    event PoolTypeAdded(bytes32 poolType, address poolPrototype);
    event PoolTypeRemoved(bytes32 poolType);

    ///////////////////////////////////////////////////////////////////
    //                        Pool Creation
    ///////////////////////////////////////////////////////////////////

    /**
     * @notice Spin up a new PlasmaVault
     * @param _vaultType Name of the type of vault to instantiate
     * @param _vaultAsset Underlyer asset
     * @param extraParams Extra parameters for vault initialization
     */
    function createPool(
        bytes32 _vaultType,
        address _vaultAsset,
        bytes calldata extraParams
    ) external returns (address newPoolAddress);

    ///////////////////////////////////////////////////////////////////
    //                        Pool Types Management
    ///////////////////////////////////////////////////////////////////

    /**
     * @notice List all PlasmaVault prototypes
     */
    function listPoolTypes() external view returns (bytes32[] memory poolTypes);

    /**
     * @notice Add a PlasmaVault prototype to the whitelist
     * @param _vaultType Name of the type of vault to instantiate
     * @param _plasmaVaultPrototype Address of deployed PlasmaVault prototype
     */
    function addPoolType(bytes32 _vaultType, address _plasmaVaultPrototype) external;

    /**
     * @notice Remove a PlasmaVault prototype from the whitelist
     * @param _vaultType Pool type to remove implementation reference of
     */
    function removePoolType(bytes32 _vaultType) external;

    /**
     * @notice Replace a PlasmaVault prototype from the whitelist
     * @param poolType Pool type to remove implementation reference of
     * @param _plasmaVaultPrototype Address of deployed PlasmaVault prototype
     */
    function replacePoolType(bytes32 poolType, address _plasmaVaultPrototype) external;
}
