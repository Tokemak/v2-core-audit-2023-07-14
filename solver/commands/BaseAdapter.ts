import { ethers } from "hardhat";
import { Contract, FunctionCall } from "@weiroll/weiroll.js";
import { objectToArray } from "../helpers/common";
import { FuncArg } from "../typings/common";

/**
 * Type for parameters used when adding liquidity to a pool
 */
export type AddLiquidity = {
	amounts: FuncArg<ethers.BigNumberish[]>;
	minLpMintAmount: FuncArg<ethers.BigNumberish>;
	extraParams: FuncArg<unknown>;
};

/**
 * Type for parameters used when removing liquidity from a pool
 */
export type RemoveLiquidity = {
	amounts: FuncArg<ethers.BigNumberish[]>;
	maxLpBurnAmount: FuncArg<ethers.BigNumberish>;
	extraParams: FuncArg<unknown>;
};

/**
 * BaseAdapter is an abstract class that provides a basic structure and methods
 * for adding and removing liquidity from a pool. It is intended to be extended by other classes.
 */
export abstract class BaseAdapter {
	/**
	 * The address of the pool
	 */
	public address: string;

	/**
	 * The contract instance
	 */
	public library: Contract | null;

	/**
	 * The ABI of the contract
	 */
	public abi: unknown;

	/**
	 * Initializes the BaseAdapter with the pool address, ABI, and the structures for the extra parameters
	 *
	 * @param address - The address of the pool
	 * @param abi - The ABI of the contract
	 */
	constructor(address: string, abi: unknown[]) {
		this.address = address;
		this.library = null;
		this.abi = abi;
	}

	/**
	 * Abstract getter that each subclass must implement.
	 * It should return the structure for the "add liquidity" extra parameters.
	 */
	abstract get addLiquidityExtraParamsStruct(): string[];

	/**
	 * Abstract getter that each subclass must implement.
	 * It should return the structure for the "remove liquidity" extra parameters.
	 */
	abstract get removeLiquidityExtraParamsStruct(): string[];

	/**
	 * Method for adding liquidity to the pool
	 *
	 * @param params - Parameters used for adding liquidity
	 * @returns - A promise that resolves to a FunctionCall instance
	 */
	async addLiquidity(params: AddLiquidity): Promise<FunctionCall> {
		const library = await this.getLibrary(this.address);
		const extraParams = this.encodeExtraParams(this.addLiquidityExtraParamsStruct, params.extraParams);
		return library.addLiquidity(params.amounts, params.minLpMintAmount, extraParams);
	}

	/**
	 * Method for removing liquidity from the pool
	 *
	 * @param params - Parameters used for removing liquidity
	 * @returns - A promise that resolves to a FunctionCall instance
	 */
	async removeLiquidity(params: RemoveLiquidity): Promise<FunctionCall> {
		const library = await this.getLibrary(this.address);
		const extraParams = this.encodeExtraParams(this.removeLiquidityExtraParamsStruct, params.extraParams);
		return library.removeLiquidity(params.amounts, params.maxLpBurnAmount, extraParams);
	}

	/**
	 * Method for getting the contract instance
	 *
	 * @param poolAddress - The address of the pool
	 * @returns - A promise that resolves to a Contract instance
	 */
	protected async getLibrary(poolAddress: string): Promise<Contract> {
		if (this.library) {
			return this.library;
		}

		const poolAdapter = await ethers.getContractAt(this.abi, poolAddress);

		return Contract.createLibrary(poolAdapter);
	}

	/**
	 * Method for encoding the extra parameters
	 *
	 * @param structType - The structure of the extra parameters
	 * @param params - The parameters to be encoded
	 * @returns - The encoded parameters
	 */
	encodeExtraParams(structType: string[], params: Record<string, unknown>): string {
		const arr = objectToArray(params);
		const extraParams = ethers.utils.defaultAbiCoder.encode(structType, [arr]);
		return extraParams;
	}
}
