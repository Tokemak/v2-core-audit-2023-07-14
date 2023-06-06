import { BigNumber } from "ethers";

/**
 * Converts an object to an array, recursively converting BigNumber values to strings.
 * @param obj - The object to convert to an array.
 * @returns The converted array.
 */
export function objectToArray(obj: Record<string, unknown>): unknown[] {
	return Object.values(obj).map((value) => {
		if (BigNumber.isBigNumber(value)) {
			return value.toString();
		} else if (typeof value === "object" && value !== null) {
			return objectToArray(value as Record<string, unknown>);
		} else {
			return value;
		}
	});
}
