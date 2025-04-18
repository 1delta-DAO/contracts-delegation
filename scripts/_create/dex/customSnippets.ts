import { Chain } from "@1delta/asset-registry";
import { DexProtocol } from "./dexs";

/** 
 * these are override snippets to be used
 * where the uni V2 type callback cannot be validated via codeHash and factory address 
 */
export const customV2ValidationSnippets: { [p: string]: { [c: string]: string } } = {
    // ramses: multiple pool contracts
    "RAMSES_V1": {
        [Chain.ARBITRUM_ONE]: `
                    // selector for getPair(address,address,bool)
                    mstore(ptr, 0x6801cc3000000000000000000000000000000000000000000000000000000000)
                    mstore(add(ptr, 0x4), shr(96, calldataload(184))) // tokenIn
                    mstore(add(ptr, 0x24), shr(96, outData)) // tokenOut
                    mstore(add(ptr, 0x34), gt(forkId, 191)) // isStable
                    // get pair from ramses v2 factory
                    pop(staticcall(gas(), ffFactoryAddress, ptr, 0x48, ptr, 0x20))
                    `
    },
    // moe: uses immutable clone, can be calculated, results in bloated bytecode though
    // as this is only V2 and on a L2, we do not care to add a staticcall here
    [DexProtocol.MERCHANT_MOE]: {
        [Chain.MANTLE]: `
                    // selector for getPair(address,address)
                    mstore(ptr, 0xe6a4390500000000000000000000000000000000000000000000000000000000)
                    mstore(add(ptr, 0x4), shr(96, calldataload(184))) // tokenIn
                    mstore(add(ptr, 0x24), shr(96, outData)) // tokenOut
                    // get pair from merchant moe factory
                    pop(staticcall(gas(), ffFactoryAddress, ptr, 0x48, ptr, 0x20))
                    
    `}
}