import { ethers } from "hardhat";
import { Planner } from "@weiroll/weiroll.js";
import { expect } from "chai";

import { MaverickAdapter } from "../commands/MaverickAdapter";
import { BalancerV2MetaStablePoolAdapter } from "../commands/BalancerV2MetaStablePoolAdapter";
import { BeethovenAdapter } from "../commands/BeethovenAdapter";
import { CurveV2FactoryCryptoAdapter } from "../commands/CurveV2FactoryCryptoAdapter";
import { readFileSync } from "fs";
import { BigNumber } from "ethers";
import { VelodromeAdapter } from "../commands/VelodromeAdapter";

const ONE_ETH = ethers.utils.parseEther("1");
const ONE_HALF_ETH = ethers.utils.parseEther("1.5");
const HALF_ETH = ethers.utils.parseEther("0.5");
const ZERO_ETH = ethers.utils.parseEther("0");

/*
To add a new adapter test, follow these steps:

1. Import the adapter from your commands directory.

2. Inside the main 'describe' function, add a new 'describe' block for your adapter. 
*/

describe("Adapaters Plans", function () {
	async function deployContract(
		name: string,
		initializable: boolean,
		args?: unknown,
		libraries?: Record<string, string>,
	) {
		const factory = await ethers.getContractFactory(name, libraries ? { libraries } : {});
		if (initializable) {
			const contract = await factory.deploy();
			args ? contract.initialize(args) : contract.initialize();
			return contract;
		}
		return args ? factory.deploy(args) : factory.deploy();
	}

	describe("MaverickAdapter Plans", function () {
		const amounts = [ONE_ETH, ONE_ETH];
		const commonExtraParams = {
			poolAddress: "0x2eBE19AA2e29C8ACaDb14Be3E7De153b0141e2aa",
			tokenId: 0,
			deadline: ethers.BigNumber.from(1e13),
		};
		// @dev - Based on MaverickAdapterTest.testAddLiquidityWethWstEth test
		it("Should add liquidity using MaverickAdapter", async function () {
			const extraParams = {
				...commonExtraParams,
				maverickParams: [
					{
						kind: 3,
						pos: 0,
						isDelta: true,
						deltaA: ethers.utils.parseUnits("5", 18),
						deltaB: ethers.utils.parseUnits("5", 18),
					},
				],
			};

			const planner = new Planner();
			const adapter = await deployContract(
				"MaverickAdapter",
				false,
				"0xc3B7aF1d8c3ca78F375Eb125F0211164b9071Cc0",
			);

			const call = await new MaverickAdapter(adapter.address).addLiquidity({
				amounts,
				minLpMintAmount: 1,
				extraParams,
			});

			planner.add(call);

			const plan = planner.plan();

			writeJson("maverick-add-liquidity", plan);
		});

		// @dev - Based on MaverickAdapterTest.testRemoveLiquidityWethWstEth test
		it("Should remove liquidity using MaverickAdapter", async function () {
			const maxLpBurnAmount = BigNumber.from("5000000000000000000");
			const extraParams = {
				...commonExtraParams,
				tokenId: 400,
				maverickParams: [{ binId: 49, amount: maxLpBurnAmount }],
			};

			const planner = new Planner();
			const adapter = await deployContract(
				"MaverickAdapter",
				false,
				"0xc3B7aF1d8c3ca78F375Eb125F0211164b9071Cc0",
			);

			const call = await new MaverickAdapter(adapter.address).removeLiquidity({
				amounts,
				maxLpBurnAmount,
				extraParams,
			});

			planner.add(call);

			const plan = planner.plan();

			writeJson("maverick-remove-liquidity", plan);
		});
	});

	describe("BalancerV2Adapter Plans", function () {
		const extraParams = {
			poolAddress: "0x9c6d47Ff73e0F5E51BE5FD53236e3F595C5793F2",
			tokens: ["0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0", "0xBe9895146f7AF43049ca1c1AE358B0541Ea49704"],
		};

		// @dev - Based on BalancerV2MetaStablePoolAdapterTest testAddLiquidityWstEthCbEth test
		it("Should add liquidity using BalancerV2Adapter", async function () {
			const planner = new Planner();

			const adapter = await deployContract(
				"BalancerV2MetaStablePoolAdapter",
				true,
				"0xBA12222222228d8Ba445958a75a0704d566BF2C8",
			);

			const call = await new BalancerV2MetaStablePoolAdapter(adapter.address).addLiquidity({
				amounts: [HALF_ETH, HALF_ETH],
				minLpMintAmount: 1,
				extraParams,
			});

			planner.add(call);

			const plan = planner.plan();

			writeJson("balancerv2-add-liquidity", plan);
		});

		// @dev - Based on BalancerV2MetaStablePoolAdapterTest testRemoveLiquidityWstEthCbEth test
		it("Should remove liquidity using BalancerV2Adapter", async function () {
			const planner = new Planner();
			const adapter = await deployContract(
				"BalancerV2MetaStablePoolAdapter",
				true,
				"0xBA12222222228d8Ba445958a75a0704d566BF2C8",
			);

			const call = await new BalancerV2MetaStablePoolAdapter(adapter.address).removeLiquidity({
				amounts: [ONE_ETH, ONE_ETH],
				maxLpBurnAmount: BigNumber.from("3212038264081460660"), // comes from uint256 preLpBalance = lpToken.balanceOf(address(adapter));
				extraParams,
			});

			planner.add(call);

			const plan = planner.plan();

			writeJson("balancerv2-remove-liquidity", plan);
		});
	});

	describe("BeethovenAdapter Plans", function () {
		const extraParams = {
			poolAddress: "0x7B50775383d3D6f0215A8F290f2C9e2eEBBEceb2",
			// [WSTETH_OPTIMISM, WETH9_OPTIMISM]
			tokens: ["0x1F32b1c2345538c0c6f582fCB022739c4A194Ebb", "0x4200000000000000000000000000000000000006"],
		};

		// @dev - Based on the testAddLiquidityWstEthWeth test
		it("Should add liquidity using BeethovenAdapter", async function () {
			const amounts = [HALF_ETH, HALF_ETH];

			const planner = new Planner();
			const adapter = await deployContract(
				"BeethovenAdapter",
				true,
				"0xBA12222222228d8Ba445958a75a0704d566BF2C8",
			);

			const call = await new BeethovenAdapter(adapter.address).addLiquidity({
				amounts,
				minLpMintAmount: 1,
				extraParams,
			});

			planner.add(call);

			const plan = planner.plan();

			writeJson("beethoven-add-liquidity", plan);
		});

		// @dev - Based on the testRemoveLiquidityWstEthWeth test
		it("Should remove liquidity using BeethovenAdapter", async function () {
			const amounts = [ONE_ETH, ONE_ETH];

			const planner = new Planner();
			const adapter = await deployContract(
				"BeethovenAdapter",
				true,
				"0xBA12222222228d8Ba445958a75a0704d566BF2C8",
			);

			const call = await new BeethovenAdapter(adapter.address).removeLiquidity({
				amounts,
				maxLpBurnAmount: BigNumber.from("3164812633443414211"), // comes from uint256 preLpBalance = lpToken.balanceOf(address(adapter));
				extraParams,
			});

			planner.add(call);

			const plan = planner.plan();

			writeJson("beethoven-remove-liquidity", plan);
		});
	});

	describe("CurveV2FactoryCryptoAdapter Plans", function () {
		const extraParams = {
			poolAddress: "0x5FAE7E604FC3e24fd43A72867ceBaC94c65b404A",
			lpToken: "0x5b6C539b224014A09B3388e51CaAA8e354c959C8", // gotten from poolAddress.token()
			useEth: false,
		};

		// @dev - Based on the CurveV2FactoryCryptoAdapter testAddLiquidityWethStEth test
		it("Should add liquidity using CurveV2FactoryCryptoAdapter", async function () {
			const planner = new Planner();
			const adapter = await deployContract("CurveV2FactoryCryptoAdapter", false);

			const call = await new CurveV2FactoryCryptoAdapter(adapter.address).addLiquidity({
				amounts: [HALF_ETH, ZERO_ETH],
				minLpMintAmount: 1,
				extraParams,
			});

			planner.add(call);

			const plan = planner.plan();

			writeJson("curvev2-add-liquidity", plan);
		});

		// @dev - Based on the CurveV2FactoryCryptoAdapter testRemoveLiquidityWethStEth test
		it("Should remove liquidity using CurveV2FactoryCryptoAdapter", async function () {
			const planner = new Planner();
			const adapter = await deployContract("CurveV2FactoryCryptoAdapter", false);

			const call = await new CurveV2FactoryCryptoAdapter(adapter.address).removeLiquidity({
				amounts: [HALF_ETH, ZERO_ETH],
				maxLpBurnAmount: HALF_ETH,
				extraParams,
			});

			planner.add(call);

			const plan = planner.plan();

			writeJson("curvev2-remove-liquidity", plan);
		});
	});

	describe("VelodromeAdapter Plans", function () {
		const extraParams = {
			tokenA: "0x4200000000000000000000000000000000000006", // WETH9_OPTIMISM
			tokenB: "0xE405de8F52ba7559f9df3C368500B6E6ae6Cee49", // SETH_OPTIMISM
			stable: true,
			amountAMin: 1,
			amountBMin: 1,
			deadline: BigNumber.from("1680802264"), // comes from block.timestamp + 10_000
		};

		// @dev - Based on the VelodromeAdapter testAddLiquidityWethSeth test
		it("Should add liquidity using VelodromeAdapter", async function () {
			const planner = new Planner();
			const adapter = await deployContract(
				"VelodromeAdapter",
				false,
				"0x9c12939390052919aF3155f41Bf4160Fd3666A6f",
			);

			const call = await new VelodromeAdapter(adapter.address).addLiquidity({
				amounts: [ONE_HALF_ETH, ONE_HALF_ETH],
				minLpMintAmount: 1,
				extraParams,
			});

			planner.add(call);

			const plan = planner.plan();

			writeJson("velodrome-add-liquidity", plan);
		});

		// @dev - Based on the VelodromeAdapter testRemoveLiquidityWethSeth test
		it("Should remove liquidity using VelodromeAdapter", async function () {
			const planner = new Planner();
			const adapter = await deployContract(
				"VelodromeAdapter",
				false,
				"0x9c12939390052919aF3155f41Bf4160Fd3666A6f",
			);

			const call = await new VelodromeAdapter(adapter.address).removeLiquidity({
				amounts: [ONE_ETH, ONE_ETH],
				maxLpBurnAmount: BigNumber.from("891390736386885209"), // comes from uint256 preLpBalance = lpToken.balanceOf(address(adapter));
				extraParams,
			});

			planner.add(call);

			const plan = planner.plan();

			writeJson("velodrome-remove-liquidity", plan);
		});
	});
});

// create a function that write a json file with the commands and state
function writeJson(name: string, json: { commands: string[]; state: string[] }) {
	const filePath = `./solver/test/payloads/adapters/${name}.json`;
	const current = JSON.parse(readFileSync(filePath, { encoding: "utf8" }));

	for (let i = 0; i < json.commands.length; i++) {
		// remove the target address from the command
		expect(current.commands[i].slice(0, -40) === json.commands[i].slice(0, -40)).to.be.true;
	}

	//expect(JSON.stringify(current.state) === JSON.stringify(json.state)).to.be.true;

	// @dev - Uncomment this line to write the json file
	// eslint-disable-next-line  no-unused-vars
	// writeFileSync(filePath, JSON.stringify(json));
}
