// forked from https://github.com/Uniswap/v3-periphery/blob/main/contracts/base/Multicall.sol
// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.17;
pragma abicoder v2;

import { IMulticall } from "src/interfaces/utils/IMulticall.sol";

/// @title Multicall
/// @notice Enables calling multiple methods in a single call to the contract
abstract contract Multicall is IMulticall {
    /// @inheritdoc IMulticall
    function multicall(bytes[] calldata data) public payable override returns (bytes[] memory results) {
        results = new bytes[](data.length);

        /* solhint-disable avoid-low-level-calls, reason-string, no-inline-assembly */
        for (uint256 i = 0; i < data.length; i++) {
            // slither-disable-next-line delegatecall-loop,low-level-calls
            (bool success, bytes memory result) = address(this).delegatecall(data[i]);

            if (!success) {
                // Next 5 lines from https://ethereum.stackexchange.com/a/83577
                if (result.length < 68) revert();
                // slither-disable-next-line assembly
                assembly {
                    result := add(result, 0x04)
                }
                revert(abi.decode(result, (string)));
            }

            results[i] = result;
        }
        /* solhint-enable avoid-low-level-calls, reason-string, no-inline-assembly */
    }
}
