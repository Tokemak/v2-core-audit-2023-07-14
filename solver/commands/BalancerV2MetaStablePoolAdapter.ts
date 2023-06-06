import { artifacts } from "hardhat";
import { BaseAdapter } from "./BaseAdapter";

const artifact = artifacts.readArtifactSync("BalancerV2MetaStablePoolAdapter");

export class BalancerV2MetaStablePoolAdapter extends BaseAdapter {
	/**
	 * Initializes the BalancerV2MetaStablePoolAdapter with the pool address, ABI, and the structures for the extra parameters
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
		return ["tuple(address poolAddress, address[] tokens)"];
	}

	/**
	 * Provides the structure for the "remove liquidity" extra parameters.
	 */
	get removeLiquidityExtraParamsStruct(): string[] {
		return ["tuple(address poolAddress, address[] tokens)"];
	}
}
