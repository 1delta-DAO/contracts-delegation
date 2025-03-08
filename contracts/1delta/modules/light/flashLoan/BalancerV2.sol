// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.28;

import {Slots} from "../../shared/storage/Slots.sol";
import {ERC20Selectors} from "../../shared/selectors/ERC20Selectors.sol";
import {Masks} from "../../shared/masks/Masks.sol";

/**
 * Flash loaning through BalancerV2
 */
contract BalancerV2FlashLoans is Slots, ERC20Selectors, Masks {
    // InvalidCaller()
    bytes4 private constant INVALID_CALLER = 0x48f5c3ed;

    // InvalidFlashLoan()
    bytes4 private constant INVALID_FLASH_LOAN = 0xbafe1c53;

    // Balancer V2 vault
    address private constant BALANCER_V2_VAULT = 0xBA12222222228d8Ba445958a75a0704d566BF2C8;

    /*
     * | Offset | Length (bytes) | Description                     |
     * |--------|----------------|---------------------------------|
     * | 0      | 20             | asset                           |
     * | 20     | 14             | amount                          |
     * | 34     | 2              | paramsLength                    |
     * | 36     | paramsLength   | params                          |
     */
    function balancerV2FlashLoan(uint256 currentOffset, address callerAddress, uint256 poolId) internal returns (uint256) {
        assembly {
            // get token to loan
            let token := shr(96, calldataload(currentOffset))
            currentOffset := add(currentOffset, 20)
            let pool := shr(96, calldataload(currentOffset))
            currentOffset := add(currentOffset, 20)
            // second calldata slice including amount annd params length
            let slice := calldataload(currentOffset)
            let amount := shr(144, slice) // shr will already mask uint112 here
            // length of params
            let calldataLength := and(UINT16_MASK, shr(128, slice))

            currentOffset := add(currentOffset, 16)
            // balancer should be the secondary choice
            let ptr := mload(0x40)
            // flashLoan(...)
            mstore(ptr, 0x5c38449e00000000000000000000000000000000000000000000000000000000)
            mstore(add(ptr, 4), address())
            mstore(add(ptr, 36), 0x80) // offset assets
            mstore(add(ptr, 68), 0xc0) // offset amounts
            mstore(add(ptr, 100), 0x100) // offset calldata
            mstore(add(ptr, 132), 1) // length assets
            mstore(add(ptr, 164), token) // asset
            mstore(add(ptr, 196), 1) // length amounts
            mstore(add(ptr, 228), amount) // amount
            mstore(add(ptr, 260), add(21, calldataLength)) // length calldata
            mstore8(add(ptr, 292), poolId) // source id
            // caller at the beginning
            mstore(add(ptr, 293), shl(96, callerAddress))
            // caller at the beginning
            currentOffset := add(currentOffset, 37)
            calldatacopy(add(ptr, 313), currentOffset, calldataLength) // calldata
            // set entry flag
            sstore(FLASH_LOAN_GATEWAY_SLOT, 2)
            if iszero(
                call(
                    gas(),
                    BALANCER_V2_VAULT,
                    0x0,
                    ptr,
                    add(calldataLength, 345), // = 10 * 32 + 4
                    0x0,
                    0x0 //
                )
            ) {
                let rdlen := returndatasize()
                returndatacopy(0, 0, rdlen)
                revert(0x0, rdlen)
            }
            // unset entry flasg
            sstore(FLASH_LOAN_GATEWAY_SLOT, 1)
            // increment offset
            currentOffset := add(currentOffset, calldataLength)
        }
        return currentOffset;
    }

    /**
     * @dev Balancer flash loan call
     * Gated via flash loan gateway flag to prevent calls from sources other than this contract
     */
    function receiveFlashLoan(
        address[] calldata,
        uint256[] calldata,
        uint256[] calldata,
        bytes calldata params //
    ) external {
        address origCaller;
        uint256 calldataOffset;
        uint256 calldataLength;
        assembly {
            calldataOffset := params.offset
            calldataLength := params.length
            // we expect at least an address
            // and a sourceId (uint8)
            // invalid params will lead to errors in the
            // compose at the bottom
            if lt(calldataLength, 21) {
                mstore(0, INVALID_FLASH_LOAN)
                revert(0, 0x4)
            }
            // validate caller
            // - extract id from params
            let firstWord := calldataload(calldataOffset)
            // needs no uint8 masking as we shift 248 bits
            let source := shr(248, firstWord)

            // Validate the caller
            // We check that the caller is one of the lending pools
            // This is a crucial check since this makes
            // the `initiator` paramter the caller of `flashLoan`
            switch source
            case 0xff {
                if xor(caller(), BALANCER_V2_VAULT) {
                    mstore(0, INVALID_FLASH_LOAN)
                    revert(0, 0x4)
                }
            }
            // We revert on any other id
            default {
                mstore(0, INVALID_FLASH_LOAN)
                revert(0, 0x4)
            }
            // check that the entry flag is
            if iszero(eq(2, sload(FLASH_LOAN_GATEWAY_SLOT))) {
                mstore(0, INVALID_CALLER)
                revert(0, 0x4)
            }
            // Slice the original caller off the beginnig of the calldata
            // From here on we have validated that the `origCaller`
            // was attached in the deltaCompose function
            // Otherwise, this would be a vulnerability
            origCaller := and(ADDRESS_MASK, shr(88, firstWord))
            // shift / slice params
            calldataOffset := add(calldataOffset, 21)
            calldataLength := sub(calldataLength, 21)
        }
        // within the flash loan, any compose operation
        // can be executed
        _deltaComposeInternal(origCaller, 0, 0, calldataOffset, calldataLength);
    }

    function _deltaComposeInternal(address callerAddress, uint256 paramPull, uint256 paramPush, uint256 offset, uint256 length) internal virtual {}
}
