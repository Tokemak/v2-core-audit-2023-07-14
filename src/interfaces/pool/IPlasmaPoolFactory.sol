// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

interface IPlasmaPoolFactory {
    error ZeroAddress();
    error PermissionDenied();
    error PoolTypeNotFound();

    /**
     * @notice Spin up a new PlasmaPool
     * @param _poolType Name of the type of pool to instantiate
     * @param _poolAsset Underlyer asset
     * @param extraParams Extra parameters for pool initialization
     */
    function createPool(
        bytes32 _poolType,
        address _poolAsset,
        bytes calldata extraParams
    ) external returns (address newPoolAddress);

    /**
     * @notice List all PlasmaPool prototypes
     */
    function listPoolTypes() external view returns (bytes32[] memory poolTypes);

    /**
     * @notice Add a PlasmaPool prototype to the whitelist
     * @param _poolType Name of the type of pool to instantiate
     * @param _plasmaPoolPrototype Address of deployed PlasmaPool prototype
     */
    function addPoolType(bytes32 _poolType, address _plasmaPoolPrototype) external;

    /**
     * @notice Remove a PlasmaPool prototype from the whitelist
     * @param _poolType Pool type to remove implementation reference of
     */
    function removePoolType(bytes32 _poolType) external;
}
