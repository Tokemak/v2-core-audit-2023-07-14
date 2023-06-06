import { artifacts } from "hardhat";
import { BaseAdapter } from "./BaseAdapter";

const artifact = artifacts.readArtifactSync("BalancerV2MetaStablePoolAdapter");

export class CurveV2FactoryCryptoAdapter extends BaseAdapter {
	/**
	 * Initializes the CurveV2FactoryCryptoAdapter with the pool address, ABI, and the structures for the extra parameters
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
		return ["tuple(address poolAddress, address lpToken, bool useEth)"];
	}

	/**
	 * Provides the structure for the "remove liquidity" extra parameters.
	 */
	get removeLiquidityExtraParamsStruct(): string[] {
		return ["tuple(address poolAddress, address lpToken, bool useEth)"];
	}
}
