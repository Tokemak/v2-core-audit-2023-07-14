// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

// solhint-disable avoid-low-level-calls
contract SolverCaller {
    function execute(address target, bytes32[] memory data32, bytes[] memory data) public {
        (bool success, bytes memory result) =
            target.delegatecall(abi.encodeWithSignature("execute(bytes32[],bytes[])", data32, data));

        if (!success) {
            if (result.length == 0) revert("No reason found");
            // solhint-disable-next-line no-inline-assembly
            assembly {
                revert(add(32, result), mload(result))
            }
        }
    }
}
