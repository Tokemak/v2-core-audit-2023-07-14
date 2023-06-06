# Solver SDK

The Solver SDK is a tool designed to facilitate interaction with our V2 contracts. It is built on top of Weiroll.js, a planner for the operation-chaining/scripting language Weiroll.

The project is divided into two parts:

-   Solidity Project: The Solidity project is located in the src/solver directory. It consists of a VM contract that decrypts programs to be executed on-chain.
-   Hardhat Project: The Hardhat project complements the Solidity project by providing an environment for creating programs that involve a sequence of function calls to external contracts. It is used for development and testing purposes.

While the v2-core project primarily relies on Foundry, the Solver project requires Hardhat for testing. As a result, a mixed project has been created, incorporating both Foundry and Hardhat

Two Hardhat commands have been added to the package.json file, enabling you to compile the code and run tests using Hardhat.

# Test

Every command in the Solver SDK undergoes thorough testing.
These tests are based on existing Foundry tests and are designed to generate Weiroll commands that call the V2 contract we are testing.

You can refer to the test/Adapters.ts file for examples of these tests, which cover various use cases.

The testing process involves comparing the generated Weiroll command payloads with the corresponding JSON files. Each test has its own JSON file to ensure precise matching of expected values.

`"Should add liquidity using MaverickAdapter" -> maverick-add-liquidity.json`

This ensures that the payloads precisely match the expected values through time and updates

The JSON file is then tested in a Foundry test, where the commands are executed through the solver VM contract.

The purpose of this test is to verify that the generated command call performs the intended actions as expected, with our V2 contracts.

## Supported contracts

This project provides a collection of wrapper files, each of which serves as a Weiroll wrapper around a specific V2 contract.

Adapters:
Each are wrapper around contracts that implements the IPoolAdapter interface

-   BalancerV2Adapter
-   BalancerV2MetaStablePoolAdapter
-   BeethovenAdapter
-   CurveV2FactoryCryptoAdapter
-   MaverickAdapter
-   VelodromeAdapter

The functions within these adapters, such as addLiquidity and removeLiquidity, return Weiroll FunctionCall objects that can be added to a Weiroll Plan.

These FunctionCalls represent commands that can be decoded by our Solver contract, based on the Weiroll VM contract, and delegated to the corresponding target contract.

## Weiroll

Weiroll is a scripting language that enables the following capabilities:

-   Calling functions on a list of contracts.
-   Using the single value returned from one call as input to another call (can't tuple returns).

For more information, refer to the Weiroll.js documentation.

Here's an example to illustrate Weiroll usage:

```
balance = a.removeLiquidity(100);
b.addLiquidity(balance);
c.sayHi("fix value here");
```

To expand the capabilities of Weiroll, we have deployed helper contracts that provide additional functionality. Some of the already implemented contracts include:

-   ArraysConverter: Converts two uint256 values into a uint256 array.
-   Blockchain: Retrieves basic blockchain information such as the current block number.
-   Bytes32: Converts a bytes32 value to a uint256 value.
-   Integer: Provides functions to compare numbers and perform basic mathematical operations.
-   Tupler: Extracts elements from a tuple.

Here's an example of how to use Weiroll with the Solver SDK and helper contracts:

```
status = system.getStatus(); // returns { toWithdraw: uint256, toDeploy: uint256 }
bytes32Val = status.extractElement(tuple, 0); // 0 -> toWithdraw
toWithdraw = bytes32.toUint256(bytes32Val);
math.gte(toDeploy, 10);
pool.withdraw(toDeploy);
```

## Usage

Here's an example of how to use the SDK with the BalancerV2MetaStablePoolAdapter:

```typescript
const planner = new Planner()
const adapter = await deployLibrary("BalancerV2MetaStablePoolAdapter", "0xBA12222222228d8Ba445958a75a0704d566BF2C8")

const call = await new BalancerV2MetaStablePoolAdapter(adapter.address).addLiquidity({
	amounts: [HALF_ETH, HALF_ETH],
	minLpMintAmount: 1,
	extraParams: {
		poolId: "0x9c6d47ff73e0f5e51be5fd53236e3f595c5793f200020000000000000000042c",
		tokens: ["0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0", "0xBe9895146f7AF43049ca1c1AE358B0541Ea49704"],
	},
})

planner.add(call)

const { commands, state } = planner.plan()
```
