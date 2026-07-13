/**
 * Template for the per-chain Uniswap-V3-style flash-loan callback.
 *
 * `flash()` on a V3-style pool calls back `msg.sender` (this contract), so the callback is only
 * ever reached when WE initiated the flash (see UniswapV3.sol). It additionally recomputes the
 * pool's CREATE2 address from (factory, token0, token1[, fee]) and rejects any caller that is not
 * the deterministic pool. `forkId` (packed into the data by the initiator) selects the
 * factory/codeHash *within a family*; the family (Classic / Pancake / Algebra) is determined by
 * which flash-callback entrypoint the pool invoked, so registry forkIds that collide across
 * families (e.g. UNISWAP_V3=0 vs PANCAKESWAP_V3=0) stay disjoint. Algebra forks omit the fee from
 * the pool salt (flagged via the low bytes of the ff-factory constant, `FF_ADDRESS_COMPLEMENT`).
 *
 * `families` selects which flash-callback entrypoints to expose (only the fork families present on
 * the chain). Family ids: Classic=0, Pancake=1, Algebra=2 — matched by `switchCaseContent`.
 */
export const templateUniV3FlashLoan = (
    ffFactoryConstants: string,
    switchCaseContent: string,
    families: {classic: boolean; pancake: boolean; algebra: boolean}
) => {
    const entrypoint = (name: string, familyId: number) => `
    function ${name}(uint256, uint256, bytes calldata) external {
        _onUniV3FlashCallback(${familyId});
    }
`;
    let entrypoints = "";
    if (families.classic) entrypoints += entrypoint("uniswapV3FlashCallback", 0);
    if (families.pancake) entrypoints += entrypoint("pancakeV3FlashCallback", 1);
    if (families.algebra) entrypoints += entrypoint("algebraFlashCallback", 2);

    return `// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.34;

import {Masks} from "../../../../../shared/masks/Masks.sol";
import {DeltaErrors} from "../../../../../shared/errors/Errors.sol";

/**
 * @title Uniswap V3-style flash loan callback
 * @notice Trusts any immutable factory-deployed pool via CREATE2 re-derivation. \`flash()\` calls
 *         back \`msg.sender\`, so reaching this callback already proves self-initiation.
 * @custom:calldata-offset-table (the \`data\` blob echoed by the pool, starting at calldata 132)
 * | Offset | Length (bytes) | Description                  |
 * |--------|----------------|------------------------------|
 * | 132    | 20             | origCaller                   |
 * | 152    | 20             | tokenIn                      |
 * | 172    | 20             | tokenOut                     |
 * | 192    | 1              | forkId                       |
 * | 193    | 2              | fee (ignored for Algebra)    |
 * | 195    | 2              | composeLength                |
 * | 197    | composeLength  | composeOperations            |
 */
contract UniV3FlashLoanCallback is Masks, DeltaErrors {
    // ff-factory + init-code-hash constants (Algebra forks carry the FF complement in the low bytes)
    ${ffFactoryConstants}
${entrypoints}
    /**
     * @notice Shared handler for all V3-style flash callbacks.
     * @dev \`family\` (Classic=0 / Pancake=1 / Algebra=2) namespaces the forkId switch; the handler
     *      recomputes the pool address from the selected factory, the token pair and the fee, and
     *      reverts unless \`caller()\` is exactly that pool.
     */
    function _onUniV3FlashCallback(uint256 family) internal {
        address callerAddress;
        uint256 calldataLength;
        assembly {
            let ffFactoryAddress
            let codeHash
            // select the fork: outer switch on family, inner on the forkId byte (calldata 192)
            ${switchCaseContent}

            let tokenIn := shr(96, calldataload(152))
            let tokenOutAndFee := calldataload(172)
            let tokenOut := shr(96, tokenOutAndFee)

            let s := mload(0x40)
            mstore(s, ffFactoryAddress)
            let p := add(s, 21)
            // sort the pair for the pool salt
            switch lt(tokenIn, tokenOut)
            case 0 {
                mstore(p, tokenOut)
                mstore(add(p, 32), tokenIn)
            }
            default {
                mstore(p, tokenIn)
                mstore(add(p, 32), tokenOut)
            }
            switch and(FF_ADDRESS_COMPLEMENT, ffFactoryAddress)
            case 0 {
                // classic/pancake: fee is part of the salt
                mstore(add(p, 64), and(UINT16_MASK, shr(72, tokenOutAndFee)))
                mstore(p, keccak256(p, 96))
            }
            default {
                // algebra: no fee in the salt
                mstore(p, keccak256(p, 64))
            }
            p := add(p, 32)
            mstore(p, codeHash)

            // reject any caller that is not the deterministic pool
            if xor(caller(), and(ADDRESS_MASK, keccak256(s, 85))) {
                mstore(0x0, BAD_POOL)
                revert(0x0, 0x4)
            }

            calldataLength := and(UINT16_MASK, shr(56, tokenOutAndFee))
            callerAddress := shr(96, calldataload(132))
        }
        // continue the batch; the compose ops repay principal + fee to the pool
        _deltaComposeInternal(
            callerAddress,
            197, // 132 data start + 65 header (20+20+20+1+2+2)
            calldataLength
        );
        assembly {
            return(0, 0)
        }
    }

    /**
     * @notice Override point for flash loan callbacks to execute compose operations
     */
    function _deltaComposeInternal(address callerAddress, uint256 offset, uint256 length) internal virtual {}
}

`;
};
