// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

interface ILMPVaultFactory {
    ///////////////////////////////////////////////////////////////////
    //                        Vault Creation
    ///////////////////////////////////////////////////////////////////

    /**
     * @notice Spin up a new LMPVault
     * @param _vaultAsset Underlyer asset
     * @param extraParams Extra parameters for vault initialization
     */
    function createVault(
        address _vaultAsset,
        address _rewarder,
        bytes calldata extraParams
    ) external returns (address newVaultAddress);
}
