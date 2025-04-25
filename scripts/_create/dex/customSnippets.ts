import { Chain } from "@1delta/asset-registry";
import { DexProtocol } from "@1delta/dex-registry";

/** 
 * these are override snippets to be used
 * where the uni V2 type callback cannot be validated via codeHash and factory address 
 */
export const customV2ValidationSnippets: { [p: string]: { [c: string]: string } } = {
    // ramses: multiple pool contract implementations
    "RAMSES_V1": {
        [Chain.ARBITRUM_ONE]: `
                    // selector for getPair(address,address,bool)
                    mstore(ptr, 0x6801cc3000000000000000000000000000000000000000000000000000000000)
                    mstore(add(ptr, 0x4), shr(96, calldataload(184))) // tokenIn
                    mstore(add(ptr, 0x24), shr(96, outData)) // tokenOut
                    mstore(add(ptr, 0x34), gt(forkId, 191)) // isStable
                    // get pair from ramses v2 factory
                    pop(staticcall(gas(), ffFactoryAddress, ptr, 0x48, ptr, 0x20))
                    pool := mload(ptr)
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
                    pool := mload(ptr)
                    
    `},
    // Solady clone
    [DexProtocol.VELODROME_V2]: {
        [Chain.OP_MAINNET]: `
                    // get tokens
                    let tokenIn := shr(96, calldataload(184))
                    let tokenOut := shr(96, outData)

                    switch lt(tokenIn, tokenOut)
                    case 0 {
                        mstore(add(ptr, 0x14), tokenIn)
                        mstore(ptr, tokenOut)
                    }
                    default {
                        mstore(add(ptr, 0x14), tokenOut)
                        mstore(ptr, tokenIn)
                    }

                    mstore8(
                        add(ptr, 0x34),
                        gt(forkId, 191) // store isStable (id>=192)
                    )
                    let salt := keccak256(add(ptr, 0x0C), 0x29)

                    mstore(add(ptr, 0x38), VELODROME_V2_FACTORY)
                    mstore(add(ptr, 0x24), 0x5af43d82803e903d91602b57fd5bf3ff)
                    mstore(add(ptr, 0x14), VELODROME_V2_IMPLEMENTATION)
                    mstore(ptr, 0x3d602d80600a3d3981f3363d3d373d3d3d363d73)
                    mstore(add(ptr, 0x58), salt)
                    mstore(add(ptr, 0x78), keccak256(add(ptr, 0x0c), 0x37))
                    pool := keccak256(add(ptr, 0x43), 0x55)
                    
    `}
}



/** 
 * these are override snippets to be used
 * where the uni V3 type callback cannot be validated via codeHash and factory address 
 */
export const customV3ValidationSnippets: { [p: string]: { [c: string]: string } } = {
    // Solady clone
    [DexProtocol.VELODROME_V3]: {
        [Chain.OP_MAINNET]: `
                    // Compute Salt
                    switch lt(tokenIn, tokenOut)
                    case 0 {
                        mstore(ptr, tokenOut)
                        mstore(add(ptr, 32), tokenIn)
                    }
                    default {
                        mstore(ptr, tokenIn)
                        mstore(add(ptr, 32), tokenOut)
                    }
                    // this stores the fee
                    mstore(add(ptr, 64), and(UINT16_MASK, shr(72, tokenOutAndFee)))
                    let salt := keccak256(ptr, 96)

                    // get pool by using solady clone calculation
                    mstore(add(ptr, 0x38), VELODROME_V3_FACTORY)
                    mstore(add(ptr, 0x24), 0x5af43d82803e903d91602b57fd5bf3ff)
                    mstore(add(ptr, 0x14), VELODROME_V3_IMPLEMENTATION)
                    mstore(ptr, 0x3d602d80600a3d3981f3363d3d373d3d3d363d73)
                    mstore(add(ptr, 0x58), salt)
                    mstore(add(ptr, 0x78), keccak256(add(ptr, 0x0c), 0x37))
                    pool := keccak256(add(ptr, 0x43), 0x55)
                    
    `}
}