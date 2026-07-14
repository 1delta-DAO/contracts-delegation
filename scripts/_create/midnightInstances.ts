import {Chain} from "@1delta/chain-registry";

/**
 * Canonical Morpho Midnight singleton per chain.
 *
 * Midnight is not (yet) part of `@1delta/data-sdk`, so its deployment addresses live here. The
 * flash-loan callback generator emits + wires `MidnightCallback.sol` ONLY for chains present in this
 * map (`writeOrDeleteCallback(..., MIDNIGHT_INSTANCES[chain] !== undefined, ...)`), i.e. only where the
 * contract actually exists. Add a new entry as Midnight deploys to further chains.
 */
export const MIDNIGHT_INSTANCES: {[chainId: string]: string} = {
    [Chain.BASE]: "0xAdedD8ab6dE832766Fedf0FaC4992E5C4D3EA18A",
};
