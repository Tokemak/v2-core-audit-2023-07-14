import { artifacts } from "hardhat";
import { BaseAdapter } from "./BaseAdapter";

const artifact = artifacts.readArtifactSync("IPoolAdapter");

export class MaverickAdapter extends BaseAdapter {
	/**
	 * Initializes the MaverickAdapter with the pool address, ABI, and the structures for the extra parameters
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
			"tuple(address, uint256, uint256, tuple(uint8 kind, int32 pos, bool isDelta, uint128 deltaA, uint128 deltaB)[] maverickParams)",
		];
	}

	/**
	 * Provides the structure for the "remove liquidity" extra parameters.
	 */
	get removeLiquidityExtraParamsStruct(): string[] {
		return ["tuple(address, uint256, uint256, tuple(uint128 binId, uint128 amount)[] maverickParams)"];
	}
}
