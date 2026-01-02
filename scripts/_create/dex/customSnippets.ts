import {Chain} from "@1delta/chain-registry";
import {DexProtocol} from "@1delta/dex-registry";

/**
 * these are override snippets to be used
 * where the uni V2 type callback cannot be validated via codeHash and factory address
 */
export const customV2ValidationSnippets: {[p: string]: {[c: string]: {code: string; constants?: string}}} = {
    // ramses: multiple pool contract implementations
    RAMSES_V1: {
        [Chain.ARBITRUM_ONE]: {
            code: `
                    // selector for getPair(address,address,bool)
                    mstore(ptr, 0x6801cc3000000000000000000000000000000000000000000000000000000000)
                    mstore(add(ptr, 0x4), shr(96, calldataload(184))) // tokenIn
                    mstore(add(ptr, 0x24), shr(96, outData)) // tokenOut
                    mstore(add(ptr, 0x34), gt(forkId, 191)) // isStable
                    // get pair from ramses v2 factory
                    pop(staticcall(gas(), ffFactoryAddress, ptr, 0x48, ptr, 0x20))
                    pool := mload(ptr)
                    `,
        },
    },
    // moe: uses immutable clone, can be calculated, results in bloated bytecode though
    // as this is only V2 and on a L2, we do not care to add a staticcall here
    [DexProtocol.MERCHANT_MOE]: {
        [Chain.MANTLE]: {
            code: `
                    // immutable clone creation code that includes implementation (0x08477e01A19d44C31E4C11Dc2aC86E3BBE69c28B)
                    let tokenIn := shr(96, calldataload(184))
                    let tokenOut := shr(96, outData)
                    mstore(ptr, 0x61005f3d81600a3d39f3363d3d373d3d3d3d61002a806035363936013d730847)
                    mstore(add(ptr, 0x20), 0x7e01a19d44c31e4c11dc2ac86e3bbe69c28b5af43d3d93803e603357fd5bf300)

                    switch lt(tokenIn, tokenOut)
                    case 0 {
                        mstore(add(ptr, 63), shl(96, tokenOut))
                        mstore(add(ptr, 83), shl(96, tokenIn))
                    }
                    default {
                        mstore(add(ptr, 63), shl(96, tokenIn))
                        mstore(add(ptr, 83), shl(96, tokenOut))
                    }
                    // salt are the tokens hashed
                    let salt := keccak256(add(ptr, 63), 0x28)
                    // last part (only the top 2 bytes are needed)
                    mstore(add(ptr, 103), 0x002a000000000000000000000000000000000000000000000000000000000000)
                    let _codeHash := keccak256(ptr, 105)
                    // the factory here starts with ff and puplates the next upper bytes
                    mstore(ptr, MERCHANT_MOE_FACTORY)
                    mstore(add(ptr, 0x15), salt)
                    mstore(add(ptr, 0x35), _codeHash)
                    pool := and(ADDRESS_MASK, keccak256(ptr, 0x55))     
    `,
            constants: `
            // lower byte is populated to enter the alternative validation mode
            bytes32 private constant MERCHANT_MOE_FACTORY = 0xff5bEf015CA9424A7C07B68490616a4C1F094BEdEc0000000000000000000001;`,
        },
    },
};

/**
 * these are override snippets to be used
 * where the uni V3 type callback cannot be validated via codeHash and factory address
 */
export const customV3ValidationSnippets: {[p: string]: {[c: string]: string}} = {};
