// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

/// @title PermitUtils
/// @notice A contract containing common utilities for Permit2
abstract contract PermitUtils {
    
    bytes32 private constant ERC20_PERMIT = 0xd505accf00000000000000000000000000000000000000000000000000000000;
    bytes32 private constant DAI_PERMIT = 0x8fcbaf0c00000000000000000000000000000000000000000000000000000000;
    bytes32 private constant PERMIT2_PERMIT = 0x2b67b57000000000000000000000000000000000000000000000000000000000;
    bytes32 private constant CREDIT_PERMIT = 0x0b52d55800000000000000000000000000000000000000000000000000000000;
    bytes32 private constant PERMIT2_TRANSFER_FROM = 0x36c7851600000000000000000000000000000000000000000000000000000000;

    bytes4 private constant _PERMIT_LENGTH_ERROR = 0x68275857;  // SafePermitBadLength.selector
    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/

    error SafePermitBadLength();

    /*//////////////////////////////////////////////////////////////
                                CONSTANTS
    //////////////////////////////////////////////////////////////*/

    /// @dev Permit2 address on mantle
    address internal constant PERMIT2 = 0x9b13cf0C98315b6e85E28630417050093A7086Aa; // solhint-disable-line var-name-mixedcase

    /*//////////////////////////////////////////////////////////////
                                CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor() { }

    /**
     * @notice The function attempts to call the permit function on a given ERC20 token.
     * @dev The function is designed to support a variety of permit functions, namely: IERC20Permit, IDaiLikePermit, and IPermit2.
     * It accommodates both Compact and Full formats of these permit types.
     * Please note, it is expected that the `expiration` parameter for the compact Permit2 and the `deadline` parameter
     * for the compact Permit are to be incremented by one before invoking this function. This approach is motivated by
     * gas efficiency considerations; as the unlimited expiration period is likely to be the most common scenario, and
     * zeros are cheaper to pass in terms of gas cost. Thus, callers should increment the expiration or deadline by one
     * before invocation for optimized performance.
     * Note that the implementation does not perform dirty bits cleaning, so it is the responsibility of
     * the caller to make sure that the higher 96 bits of the `owner` and `spender` parameters are clean.
     * @param token The address of the ERC20 token on which to call the permit function.
     * @param permit The off-chain permit data, containing different fields depending on the type of permit function.
     */
    function _tryPermit(address token, bytes calldata permit) internal {
        assembly ("memory-safe") { // solhint-disable-line no-inline-assembly
            let ptr := mload(0x40)
            let success
            // Switch case for different permit lengths, indicating different permit standards
            switch permit.length
            // Compact IERC20Permit
            case 100 {
                mstore(ptr, ERC20_PERMIT)     // store selector
                mstore(add(ptr, 0x04), caller())   // store owner
                mstore(add(ptr, 0x24), address()) // store spender

                // Compact IERC20Permit.permit(uint256 value, uint32 deadline, uint256 r, uint256 vs)
                {  // stack too deep
                    let deadline := shr(224, calldataload(add(permit.offset, 0x20))) // loads permit.offset 0x20..0x23
                    let vs := calldataload(add(permit.offset, 0x44))                 // loads permit.offset 0x44..0x63

                    calldatacopy(add(ptr, 0x44), permit.offset, 0x20)            // store value     = copy permit.offset 0x00..0x19
                    mstore(add(ptr, 0x64), sub(deadline, 1))                     // store deadline  = deadline - 1
                    mstore(add(ptr, 0x84), add(27, shr(255, vs)))                // store v         = most significant bit of vs + 27 (27 or 28)
                    calldatacopy(add(ptr, 0xa4), add(permit.offset, 0x24), 0x20) // store r         = copy permit.offset 0x24..0x43
                    mstore(add(ptr, 0xc4), shr(1, shl(1, vs)))                   // store s         = vs without most significant bit
                }
                // IERC20Permit.permit(address owner, address spender, uint256 value, uint256 deadline, uint8 v, bytes32 r, bytes32 s)
                success := call(gas(), token, 0, ptr, 0xe4, 0, 0)
            }
            // Compact IDaiLikePermit
            case 72 {
                mstore(ptr, DAI_PERMIT)  // store selector
                mstore(add(ptr, 0x04), caller())   // store owner
                mstore(add(ptr, 0x24), address()) // store spender

                // Compact IDaiLikePermit.permit(uint32 nonce, uint32 expiry, uint256 r, uint256 vs)
                {  // stack too deep
                    let expiry := shr(224, calldataload(add(permit.offset, 0x04))) // loads permit.offset 0x04..0x07
                    let vs := calldataload(add(permit.offset, 0x28))               // loads permit.offset 0x28..0x47

                    mstore(add(ptr, 0x44), shr(224, calldataload(permit.offset))) // store nonce   = copy permit.offset 0x00..0x03
                    mstore(add(ptr, 0x64), sub(expiry, 1))                        // store expiry  = expiry - 1
                    mstore(add(ptr, 0x84), true)                                  // store allowed = true
                    mstore(add(ptr, 0xa4), add(27, shr(255, vs)))                 // store v       = most significant bit of vs + 27 (27 or 28)
                    calldatacopy(add(ptr, 0xc4), add(permit.offset, 0x08), 0x20)  // store r       = copy permit.offset 0x08..0x27
                    mstore(add(ptr, 0xe4), shr(1, shl(1, vs)))                    // store s       = vs without most significant bit
                }
                // IDaiLikePermit.permit(address holder, address spender, uint256 nonce, uint256 expiry, bool allowed, uint8 v, bytes32 r, bytes32 s)
                success := call(gas(), token, 0, ptr, 0x104, 0, 0)
            }
            // IERC20Permit
            case 224 {
                mstore(ptr, ERC20_PERMIT)
                calldatacopy(add(ptr, 0x04), permit.offset, permit.length) // copy permit calldata
                // IERC20Permit.permit(address owner, address spender, uint256 value, uint256 deadline, uint8 v, bytes32 r, bytes32 s)
                success := call(gas(), token, 0, ptr, 0xe4, 0, 0)
            }
            // IDaiLikePermit
            case 256 {
                mstore(ptr, DAI_PERMIT)
                calldatacopy(add(ptr, 0x04), permit.offset, permit.length) // copy permit calldata
                // IDaiLikePermit.permit(address holder, address spender, uint256 nonce, uint256 expiry, bool allowed, uint8 v, bytes32 r, bytes32 s)
                success := call(gas(), token, 0, ptr, 0x104, 0, 0)
            }
            // Compact IPermit2
            case 96 {
                // Compact IPermit2.permit(uint160 amount, uint32 expiration, uint32 nonce, uint32 sigDeadline, uint256 r, uint256 vs)
                mstore(ptr, PERMIT2_PERMIT)  // store selector
                mstore(add(ptr, 0x04), caller()) // store owner
                mstore(add(ptr, 0x24), token) // store token

                calldatacopy(add(ptr, 0x50), permit.offset, 0x14)             // store amount = copy permit.offset 0x00..0x13
                // and(0xffffffffffff, ...) - conversion to uint48
                mstore(add(ptr, 0x64), and(0xffffffffffff, sub(shr(224, calldataload(add(permit.offset, 0x14))), 1))) // store expiration = ((permit.offset 0x14..0x17 - 1) & 0xffffffffffff)
                mstore(add(ptr, 0x84), shr(224, calldataload(add(permit.offset, 0x18)))) // store nonce = copy permit.offset 0x18..0x1b
                mstore(add(ptr, 0xa4), address())                               // store spender
                // and(0xffffffffffff, ...) - conversion to uint48
                mstore(add(ptr, 0xc4), and(0xffffffffffff, sub(shr(224, calldataload(add(permit.offset, 0x1c))), 1))) // store sigDeadline = ((permit.offset 0x1c..0x1f - 1) & 0xffffffffffff)
                mstore(add(ptr, 0xe4), 0x100)                                 // store offset = 256
                mstore(add(ptr, 0x104), 0x40)                                 // store length = 64
                calldatacopy(add(ptr, 0x124), add(permit.offset, 0x20), 0x20) // store r      = copy permit.offset 0x20..0x3f
                calldatacopy(add(ptr, 0x144), add(permit.offset, 0x40), 0x20) // store vs     = copy permit.offset 0x40..0x5f
                // IPermit2.permit(address owner, PermitSingle calldata permitSingle, bytes calldata signature)
                success := call(gas(), PERMIT2, 0, ptr, 0x164, 0, 0)
            }
            // IPermit2
            case 352 {
                mstore(ptr, PERMIT2_PERMIT)
                calldatacopy(add(ptr, 0x04), permit.offset, permit.length) // copy permit calldata
                // IPermit2.permit(address owner, PermitSingle calldata permitSingle, bytes calldata signature)
                success := call(gas(), PERMIT2, 0, ptr, 0x164, 0, 0)
            }
            // Unknown
            default {
                mstore(ptr, _PERMIT_LENGTH_ERROR)
                revert(ptr, 4)
            }

            // revert if not successful
            if iszero(success) {
                returndatacopy(0, 0, returndatasize())
                revert(0, returndatasize())
            }
        }
    }

    /**
     * Executes credit delegation on given tokens / lenders
     * Note that for lenders like Aave V3, the token needs to
     * be the respective debt token and NOT the underlying
     * Others like compound will not use it at all.
     * @param token asset to permit / delegate
     * @param permit calldata
     */
    function _tryCreditPermit(address token, bytes calldata permit) internal {
        assembly {
            let success
            let ptr := mload(0x40)
            switch permit.length
            // Compact IERC20Permit
            case 100 {
                mstore(ptr, CREDIT_PERMIT)     // store selector
                mstore(add(ptr, 0x04), caller())   // store owner
                mstore(add(ptr, 0x24), address()) // store spender

                // Compact ICreditPermit.delegationWithSig(uint256 value, uint32 deadline, uint256 r, uint256 vs)
                {  // stack too deep
                    let deadline := shr(224, calldataload(add(permit.offset, 0x20))) // loads permit.offset 0x20..0x23
                    let vs := calldataload(add(permit.offset, 0x44))                 // loads permit.offset 0x44..0x63

                    calldatacopy(add(ptr, 0x44), permit.offset, 0x20)            // store value     = copy permit.offset 0x00..0x19
                    mstore(add(ptr, 0x64), sub(deadline, 1))                     // store deadline  = deadline - 1
                    mstore(add(ptr, 0x84), add(27, shr(255, vs)))                // store v         = most significant bit of vs + 27 (27 or 28)
                    calldatacopy(add(ptr, 0xa4), add(permit.offset, 0x24), 0x20) // store r         = copy permit.offset 0x24..0x43
                    mstore(add(ptr, 0xc4), shr(1, shl(1, vs)))                   // store s         = vs without most significant bit
                }
                // ICreditPermit.delegationWithSig(address owner, address spender, uint256 value, uint256 deadline, uint8 v, bytes32 r, bytes32 s)
                success := call(gas(), token, 0, ptr, 0xe4, 0, 0)
            }
                        // ICreditPermit
            case 224 {
                mstore(ptr, CREDIT_PERMIT)
                calldatacopy(add(ptr, 0x04), permit.offset, permit.length) // copy permit calldata
                // ICreditPermit.delegationWithSig(address owner, address spender, uint256 value, uint256 deadline, uint8 v, bytes32 r, bytes32 s)
                success := call(gas(), token, 0, ptr, 0xe4, 0, 0)
            }
            // Unknown
            default {
                mstore(ptr, _PERMIT_LENGTH_ERROR)
                revert(ptr, 4)
            }

            // revert if not successful
            if iszero(success) {
                returndatacopy(0, 0, returndatasize())
                revert(0, returndatasize())
            }
        }
     }

    /// @notice transferERC20from version using permit2
    function _transferFromPermit2(address token, address owner, address to, uint256 amount) internal {
        assembly {
            let ptr := mload(0x40)
            ////////////////////////////////////////////////////
            // transferFrom through permit2
            ////////////////////////////////////////////////////
            mstore(ptr, PERMIT2_TRANSFER_FROM)
            mstore(add(ptr, 0x04), owner)
            mstore(add(ptr, 0x24), to)
            mstore(add(ptr, 0x44), amount)
            mstore(add(ptr, 0x64), token)
            if iszero(call(gas(), PERMIT2, 0, ptr, 0x84, 0x0, 0x0)) {
                returndatacopy(0, 0, returndatasize())
                revert(0, returndatasize())
            }
        }
    }
}
