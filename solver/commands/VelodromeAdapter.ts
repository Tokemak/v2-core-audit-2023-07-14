import { artifacts } from "hardhat";
import { BaseAdapter } from "./BaseAdapter";

const artifact = artifacts.readArtifactSync("VelodromeAdapter");

export class VelodromeAdapter extends BaseAdapter {
	/**
	 * Initializes the VelodromeAdapter with the pool address, ABI, and the structures for the extra parameters
	 *
	 * @param address - The address of the pool
	 */
	constructor(address: string) {
		super(address, artifact.abi);
	}

	/**
	 * Provides the structure for the "add liquidity" extra parameters.
	 */
	get addLiquidityExtraParamsStruct(): string[] {
		return [
			"tuple(address tokenA, address tokenB, bool stable, uint256 amountAMin, uint256 amountBMin, uint256 deadline)",
		];
	}

	/**
	 * Provides the structure for the "remove liquidity" extra parameters.
	 */
	get removeLiquidityExtraParamsStruct(): string[] {
		return [
			"tuple(address tokenA, address tokenB, bool stable, uint256 amountAMin, uint256 amountBMin, uint256 deadline)",
		];
	}
}
