// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

// import "openzeppelin-contracts/proxy/Clones.sol";
import { AccessControl } from "openzeppelin-contracts/access/AccessControl.sol";
import { EnumerableSet } from "openzeppelin-contracts/utils/structs/EnumerableSet.sol";

import { IPlasmaPoolFactory } from "./interfaces/pool/IPlasmaPoolFactory.sol";
import { IPlasmaPoolRegistry } from "./interfaces/pool/IPlasmaPoolRegistry.sol";
import { PlasmaPool } from "./PlasmaPool.sol";

contract PlasmaPoolFactory is IPlasmaPoolFactory, AccessControl {
    using EnumerableSet for EnumerableSet.Bytes32Set;

    mapping(bytes32 => address) public poolTypeToPrototype;
    EnumerableSet.Bytes32Set private _poolTypes;

    IPlasmaPoolRegistry public immutable poolRegistry;

    // solhint-disable-next-line var-name-mixedcase
    bytes32 public immutable CREATE_POOL_ROLE = keccak256("CREATE_POOL_ROLE");

    // solhint-disable-next-line var-name-mixedcase
    bytes32 public immutable POOLTYPE_PLASMAPOOL = keccak256("POOLTYPE_PLASMAPOOL");

    constructor(address _poolRegistry) {
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setupRole(CREATE_POOL_ROLE, msg.sender);

        poolRegistry = IPlasmaPoolRegistry(_poolRegistry);
    }

    modifier onlyAdmin() {
        if (!hasRole(DEFAULT_ADMIN_ROLE, _msgSender())) revert PermissionDenied();
        _;
    }

    function createPool(
        bytes32 _poolType,
        address _poolAsset,
        bytes calldata /*extraParams*/
    ) external returns (address newPoolAddress) {
        if (!hasRole(CREATE_POOL_ROLE, _msgSender()) && !hasRole(DEFAULT_ADMIN_ROLE, _msgSender())) {
            revert PermissionDenied();
        }

        // verify params
        if (_poolAsset == address(0)) revert ZeroAddress();
        if (!_poolTypes.contains(_poolType)) revert PoolTypeNotFound();

        // create new and initialize
        newPoolAddress = address(new PlasmaPool(_poolAsset));

        // add to PoolRegistry
        poolRegistry.addPool(newPoolAddress);
    }

    ///////////////////////////////////////////////////////////////////
    //
    //                        Enumeration Methods
    //
    ///////////////////////////////////////////////////////////////////

    function listPoolTypes() external view returns (bytes32[] memory poolTypes) {
        return _poolTypes.values();
    }

    function addPoolType(bytes32 poolType, address _plasmaPoolPrototype) public onlyAdmin {
        // add prototype
        if (!_poolTypes.add(poolType)) {
            revert PoolTypeAlreadyExists();
        }

        emit PoolTypeAdded(poolType, _plasmaPoolPrototype);
    }

    function removePoolType(bytes32 poolType) public onlyAdmin {
        // remove actual prototype
        if (!_poolTypes.remove(poolType)) {
            revert PoolTypeNotFound();
        }

        emit PoolTypeRemoved(poolType);
    }

    function replacePoolType(bytes32 poolType, address plasmaPoolPrototype) external onlyAdmin {
        removePoolType(poolType);
        addPoolType(poolType, plasmaPoolPrototype);
    }
}
