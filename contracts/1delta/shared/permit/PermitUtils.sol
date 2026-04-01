// SPDX-License-Identifier: MIT
pragma solidity 0.8.34;

import {PermitConstants} from "./PermitConstants.sol";

// solhint-disable max-line-length

/// @title PermitUtils
/// @notice A contract containing utilities for Permits
abstract contract PermitUtils is PermitConstants {
    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/

    error SafePermitBadLength();

    /*//////////////////////////////////////////////////////////////
                                CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor() {}

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
     * @dev we use pop(call(...)) in calling permits, this avoids reverts if a frunrunner extracts and executes the permit before composed txn
     * if the composer does not have the required allowance, it will revert in further operations
     * @param token The address of the ERC20 token on which to call the permit function.
     * @param permitOffset The off-chain permit data, containing different fields depending on the type of permit function.
     * @param permitLength Length of the permit calldata.
     */
    function _tryPermit(address token, uint256 permitOffset, uint256 permitLength, address callerAddress) internal {
        assembly {
            // solhint-disable-line no-inline-assembly
            let ptr := mload(0x40)
            // Switch case for different permit lengths, indicating different permit standards
            switch permitLength
            // Compact IERC20Permit
            case 100 {
                mstore(ptr, ERC20_PERMIT) // store selector
                mstore(add(ptr, 0x04), callerAddress) // store owner
                mstore(add(ptr, 0x24), address()) // store spender

                // Compact IERC20Permit.permit(uint256 value, uint32 deadline, uint256 r, uint256 vs)
                {
                    // stack too deep
                    let deadline := shr(224, calldataload(add(permitOffset, 0x20))) // loads permitOffset 0x20..0x23
                    let vs := calldataload(add(permitOffset, 0x44)) // loads permitOffset 0x44..0x63

                    calldatacopy(add(ptr, 0x44), permitOffset, 0x20) // store value     = copy permitOffset 0x00..0x19
                    mstore(add(ptr, 0x64), sub(deadline, 1)) // store deadline  = deadline - 1
                    mstore(add(ptr, 0x84), add(27, shr(255, vs))) // store v         = most significant bit of vs + 27 (27 or 28)
                    calldatacopy(add(ptr, 0xa4), add(permitOffset, 0x24), 0x20) // store r         = copy permitOffset 0x24..0x43
                    mstore(add(ptr, 0xc4), shr(1, shl(1, vs))) // store s         = vs without most significant bit
                }
                // IERC20Permit.permit(address owner, address spender, uint256 value, uint256 deadline, uint8 v, bytes32 r, bytes32 s)
                pop(call(gas(), token, 0, ptr, 0xe4, 0, 0))
            }
            // Compact IDaiLikePermit
            case 72 {
                mstore(ptr, DAI_PERMIT) // store selector
                mstore(add(ptr, 0x04), callerAddress) // store owner
                mstore(add(ptr, 0x24), address()) // store spender

                // Compact IDaiLikePermit.permit(uint32 nonce, uint32 expiry, uint256 r, uint256 vs)
                {
                    // stack too deep
                    let expiry := shr(224, calldataload(add(permitOffset, 0x04))) // loads permitOffset 0x04..0x07
                    let vs := calldataload(add(permitOffset, 0x28)) // loads permitOffset 0x28..0x47

                    mstore(add(ptr, 0x44), shr(224, calldataload(permitOffset))) // store nonce   = copy permitOffset 0x00..0x03
                    mstore(add(ptr, 0x64), sub(expiry, 1)) // store expiry  = expiry - 1
                    mstore(add(ptr, 0x84), true) // store allowed = true
                    mstore(add(ptr, 0xa4), add(27, shr(255, vs))) // store v       = most significant bit of vs + 27 (27 or 28)
                    calldatacopy(add(ptr, 0xc4), add(permitOffset, 0x08), 0x20) // store r       = copy permitOffset 0x08..0x27
                    mstore(add(ptr, 0xe4), shr(1, shl(1, vs))) // store s       = vs without most significant bit
                }
                // IDaiLikePermit.permit(address holder, address spender, uint256 nonce, uint256 expiry, bool allowed, uint8 v, bytes32 r, bytes32 s)
                pop(call(gas(), token, 0, ptr, 0x104, 0, 0))
            }
            // Compact IPermit2
            case 96 {
                // Compact IPermit2.permit(uint160 amount, uint32 expiration, uint32 nonce, uint32 sigDeadline, uint256 r, uint256 vs)
                mstore(ptr, PERMIT2_PERMIT) // store selector
                mstore(add(ptr, 0x04), callerAddress) // store owner
                mstore(add(ptr, 0x24), token) // store token

                calldatacopy(add(ptr, 0x50), permitOffset, 0x14) // store amount = copy permitOffset 0x00..0x13
                // and(0xffffffffffff, ...) - conversion to uint48
                mstore(add(ptr, 0x64), and(0xffffffffffff, sub(shr(224, calldataload(add(permitOffset, 0x14))), 1))) // store expiration = ((permitOffset 0x14..0x17 - 1) & 0xffffffffffff)
                mstore(add(ptr, 0x84), shr(224, calldataload(add(permitOffset, 0x18)))) // store nonce = copy permitOffset 0x18..0x1b
                mstore(add(ptr, 0xa4), address()) // store spender
                // and(0xffffffffffff, ...) - conversion to uint48
                mstore(add(ptr, 0xc4), and(0xffffffffffff, sub(shr(224, calldataload(add(permitOffset, 0x1c))), 1))) // store sigDeadline = ((permitOffset 0x1c..0x1f - 1) & 0xffffffffffff)
                mstore(add(ptr, 0xe4), 0x100) // store offset = 256
                mstore(add(ptr, 0x104), 65) // store length = 64
                let vs := calldataload(add(permitOffset, 0x40)) // copy permitOffset 0x40..0x5f
                calldatacopy(add(ptr, 0x124), add(permitOffset, 0x20), 0x20) // store r      = copy permitOffset 0x20..0x3f
                mstore(add(ptr, 0x144), shr(1, shl(1, vs))) // store s     = vs without most significant bit
                mstore8(add(ptr, 0x164), add(27, shr(255, vs))) // store v     = copy permitOffset 0x40..0x5f
                // IPermit2.permit(address owner, PermitSingle calldata permitSingle, bytes calldata signature)
                pop(call(gas(), PERMIT2, 0, ptr, 0x165, 0, 0))
            }
            // Unknown
            default {
                mstore(ptr, _PERMIT_LENGTH_ERROR)
                revert(ptr, 4)
            }
        }
    }

    /**
     * Executes credit delegation on given tokens / lenders
     * Note that for lenders like Aave V3, the token needs to
     * be the respective debt token and NOT the underlying
     * Others like compound will not use it at all.
     * @param token asset to permit / delegate
     * @param permitOffset calldata
     */
    function _tryCreditPermit(address token, uint256 permitOffset, uint256 permitLength, address callerAddress) internal {
        assembly {
            let ptr := mload(0x40)
            switch permitLength
            // Compact ICreditPermit
            case 100 {
                mstore(ptr, CREDIT_PERMIT) // store selector
                mstore(add(ptr, 0x04), callerAddress) // store owner
                mstore(add(ptr, 0x24), address()) // store spender

                // Compact ICreditPermit.delegationWithSig(uint256 value, uint32 deadline, uint256 r, uint256 vs)
                {
                    // stack too deep
                    let deadline := shr(224, calldataload(add(permitOffset, 0x20))) // loads permitOffset 0x20..0x23
                    let vs := calldataload(add(permitOffset, 0x44)) // loads permitOffset 0x44..0x63

                    calldatacopy(add(ptr, 0x44), permitOffset, 0x20) // store value     = copy permitOffset 0x00..0x19
                    mstore(add(ptr, 0x64), sub(deadline, 1)) // store deadline  = deadline - 1
                    mstore(add(ptr, 0x84), add(27, shr(255, vs))) // store v         = most significant bit of vs + 27 (27 or 28)
                    calldatacopy(add(ptr, 0xa4), add(permitOffset, 0x24), 0x20) // store r         = copy permitOffset 0x24..0x43
                    mstore(add(ptr, 0xc4), shr(1, shl(1, vs))) // store s         = vs without most significant bit
                }
                // ICreditPermit.delegationWithSig(address owner, address spender, uint256 value, uint256 deadline, uint8 v, bytes32 r, bytes32 s)
                if iszero(call(gas(), token, 0, ptr, 0xe4, 0, 0)) {
                    returndatacopy(0, 0, returndatasize())
                    revert(0, returndatasize())
                }
            }
            // Unknown
            default {
                mstore(ptr, _PERMIT_LENGTH_ERROR)
                revert(ptr, 4)
            }
        }
    }

    /**
     * Executes compound or morpho permit.
     * @param target target address to permit / delegate
     * @param permitOffset calldata
     * @param permitLength calldata
     */
    function _tryFlagBasedLendingPermit(
        address target,
        uint256 permitOffset,
        uint256 permitLength,
        address callerAddress
    )
        internal
    {
        assembly {
            let ptr := mload(0x40)
            switch permitLength
            // Compact ICreditPermit
            case 100 {
                let allowedAndNonce := calldataload(permitOffset) // load [allowed nonce] 2 single bits and number
                // mopho blue and CompoundV3 are similarly parametrized
                // if the second high bit is set, use Morpho
                switch and(SECOND_HIGH_BIT, allowedAndNonce)
                case 0 { mstore(ptr, COMPOUND_V3_CREDIT_PERMIT) }
                // store selector
                default { mstore(ptr, MORPHO_CREDIT_PERMIT) }

                mstore(add(ptr, 0x04), callerAddress) // store owner
                mstore(add(ptr, 0x24), address()) // store manager

                // Compact ICreditPermit.allowBySig(uint256 isAllowedAndNonce, uint32 expiry, uint256 r, uint256 vs)
                {
                    // stack too deep
                    let expiry := shr(224, calldataload(add(permitOffset, 0x20))) // loads permitOffset 0x20..0x23
                    let vs := calldataload(add(permitOffset, 0x44)) // loads permitOffset 0x44..0x63
                    // check if high bit is pupulated
                    mstore(add(ptr, 0x44), iszero(iszero(and(HIGH_BIT, allowedAndNonce))))
                    mstore(add(ptr, 0x64), and(LOWER_BITS, allowedAndNonce)) // nonce
                    mstore(add(ptr, 0x84), sub(expiry, 1)) // store expiry  = expiry - 1
                    mstore(add(ptr, 0xA4), add(27, shr(255, vs))) // store v         = most significant bit of vs + 27 (27 or 28)
                    calldatacopy(add(ptr, 0xC4), add(permitOffset, 0x24), 0x20) // store r         = copy permitOffset 0x24..0x43
                    mstore(add(ptr, 0xE4), shr(1, shl(1, vs))) // store s         = vs without most significant bit
                }
                // ICreditPermit.allowBySig(address owner, address manager, bool isAllowed, uint256 value, uint256 expiry, uint8 v, bytes32 r, bytes32 s)
                if iszero(call(gas(), target, 0, ptr, 0x104, 0, 0)) {
                    returndatacopy(0, 0, returndatasize())
                    revert(0, returndatasize())
                }
            }
            // Unknown
            default {
                mstore(ptr, _PERMIT_LENGTH_ERROR)
                revert(ptr, 4)
            }
        }
    }

    /**
     * @notice Calls PositionManagerBase.setSelfAsUserPositionManagerWithSig on a single PM.
     * @dev Compact calldata: spoke(20) | approve(1) | nonce(32) | deadline+1(4) | r(32) | vs(32) = 121 bytes
     * @param target The PM address (GiverPM, TakerPM, or ConfigPM)
     */
    function _tryAaveV4PmSetup(address target, uint256 permitOffset, uint256 permitLength, address callerAddress) internal {
        assembly {
            let ptr := mload(0x40)
            switch permitLength
            case 121 {
                let spoke := shr(96, calldataload(permitOffset))
                let approve := shr(248, calldataload(add(permitOffset, 0x14)))
                let nonce := calldataload(add(permitOffset, 0x15))
                let deadline := sub(shr(224, calldataload(add(permitOffset, 0x35))), 1)
                let r := calldataload(add(permitOffset, 0x39))
                let vs := calldataload(add(permitOffset, 0x59))

                // setSelfAsUserPositionManagerWithSig(address,address,bool,uint256,uint256,bytes)
                mstore(ptr, AAVE_V4_SET_SELF_AS_PM_WITH_SIG)
                mstore(add(ptr, 0x04), spoke)
                mstore(add(ptr, 0x24), callerAddress)
                mstore(add(ptr, 0x44), approve)
                mstore(add(ptr, 0x64), nonce)
                mstore(add(ptr, 0x84), deadline)
                mstore(add(ptr, 0xa4), 0xc0) // offset to signature bytes
                mstore(add(ptr, 0xc4), 65) // signature length (r + s + v)
                mstore(add(ptr, 0xe4), r)
                mstore(add(ptr, 0x104), shr(1, shl(1, vs))) // s = vs without MSB
                mstore(add(ptr, 0x124), shl(248, add(27, shr(255, vs)))) // v byte left-aligned
                if iszero(call(gas(), target, 0, ptr, 0x144, 0, 0)) {
                    returndatacopy(0, 0, returndatasize())
                    revert(0, returndatasize())
                }
            }
            default {
                mstore(ptr, _PERMIT_LENGTH_ERROR)
                revert(ptr, 4)
            }
        }
    }

    /**
     * @notice Calls TakerPM.approveBorrowWithSig with a compact permit.
     * @dev Compact calldata: spoke(20) | reserveId(32) | amount(32) | nonce(32) | deadline+1(4) | r(32) | vs(32) = 184 bytes
     * @param target The TakerPositionManager address
     */
    function _tryAaveV4BorrowPermit(address target, uint256 permitOffset, uint256 permitLength, address callerAddress) internal {
        assembly {
            let ptr := mload(0x40)
            switch permitLength
            case 184 {
                let spoke := shr(96, calldataload(permitOffset))
                let reserveId := calldataload(add(permitOffset, 0x14))
                let amount := calldataload(add(permitOffset, 0x34))
                let nonce := calldataload(add(permitOffset, 0x54))
                let deadline := sub(shr(224, calldataload(add(permitOffset, 0x74))), 1)
                let r := calldataload(add(permitOffset, 0x78))
                let vs := calldataload(add(permitOffset, 0x98))

                // approveBorrowWithSig((address,uint256,address,address,uint256,uint256,uint256),bytes)
                mstore(ptr, AAVE_V4_APPROVE_BORROW_WITH_SIG)
                mstore(add(ptr, 0x04), spoke)
                mstore(add(ptr, 0x24), reserveId)
                mstore(add(ptr, 0x44), callerAddress) // owner
                mstore(add(ptr, 0x64), address()) // spender = composer
                mstore(add(ptr, 0x84), amount)
                mstore(add(ptr, 0xa4), nonce)
                mstore(add(ptr, 0xc4), deadline)
                mstore(add(ptr, 0xe4), 0x100) // offset to signature bytes
                mstore(add(ptr, 0x104), 65) // signature length (r + s + v)
                mstore(add(ptr, 0x124), r)
                mstore(add(ptr, 0x144), shr(1, shl(1, vs))) // s = vs without MSB
                mstore(add(ptr, 0x164), shl(248, add(27, shr(255, vs)))) // v byte left-aligned
                if iszero(call(gas(), target, 0, ptr, 0x184, 0, 0)) {
                    returndatacopy(0, 0, returndatasize())
                    revert(0, returndatasize())
                }
            }
            default {
                mstore(ptr, _PERMIT_LENGTH_ERROR)
                revert(ptr, 4)
            }
        }
    }

    /**
     * @notice Calls TakerPM.approveWithdrawWithSig with a compact permit.
     * @dev Compact calldata: spoke(20) | reserveId(32) | amount(32) | nonce(32) | deadline+1(4) | r(32) | vs(32) = 184 bytes
     * @param target The TakerPositionManager address
     */
    function _tryAaveV4WithdrawPermit(address target, uint256 permitOffset, uint256 permitLength, address callerAddress) internal {
        assembly {
            let ptr := mload(0x40)
            switch permitLength
            case 184 {
                let spoke := shr(96, calldataload(permitOffset))
                let reserveId := calldataload(add(permitOffset, 0x14))
                let amount := calldataload(add(permitOffset, 0x34))
                let nonce := calldataload(add(permitOffset, 0x54))
                let deadline := sub(shr(224, calldataload(add(permitOffset, 0x74))), 1)
                let r := calldataload(add(permitOffset, 0x78))
                let vs := calldataload(add(permitOffset, 0x98))

                // approveWithdrawWithSig((address,uint256,address,address,uint256,uint256,uint256),bytes)
                mstore(ptr, AAVE_V4_APPROVE_WITHDRAW_WITH_SIG)
                mstore(add(ptr, 0x04), spoke)
                mstore(add(ptr, 0x24), reserveId)
                mstore(add(ptr, 0x44), callerAddress) // owner
                mstore(add(ptr, 0x64), address()) // spender = composer
                mstore(add(ptr, 0x84), amount)
                mstore(add(ptr, 0xa4), nonce)
                mstore(add(ptr, 0xc4), deadline)
                mstore(add(ptr, 0xe4), 0x100) // offset to signature bytes
                mstore(add(ptr, 0x104), 65) // signature length (r + s + v)
                mstore(add(ptr, 0x124), r)
                mstore(add(ptr, 0x144), shr(1, shl(1, vs))) // s = vs without MSB
                mstore(add(ptr, 0x164), shl(248, add(27, shr(255, vs)))) // v byte left-aligned
                if iszero(call(gas(), target, 0, ptr, 0x184, 0, 0)) {
                    returndatacopy(0, 0, returndatasize())
                    revert(0, returndatasize())
                }
            }
            default {
                mstore(ptr, _PERMIT_LENGTH_ERROR)
                revert(ptr, 4)
            }
        }
    }

    /**
     * @notice Calls ConfigPM.setCanSetUsingAsCollateralPermissionWithSig with a compact permit.
     * @dev Compact calldata: spoke(20) | status(1) | nonce(32) | deadline+1(4) | r(32) | vs(32) = 121 bytes
     * @param target The ConfigPositionManager address
     */
    function _tryAaveV4ConfigPermit(address target, uint256 permitOffset, uint256 permitLength, address callerAddress) internal {
        assembly {
            let ptr := mload(0x40)
            switch permitLength
            case 121 {
                let spoke := shr(96, calldataload(permitOffset))
                let status := shr(248, calldataload(add(permitOffset, 0x14)))
                let nonce := calldataload(add(permitOffset, 0x15))
                let deadline := sub(shr(224, calldataload(add(permitOffset, 0x35))), 1)
                let r := calldataload(add(permitOffset, 0x39))
                let vs := calldataload(add(permitOffset, 0x59))

                // setCanSetUsingAsCollateralPermissionWithSig((address,address,address,bool,uint256,uint256),bytes)
                mstore(ptr, AAVE_V4_CONFIG_COLLATERAL_PERM_WITH_SIG)
                mstore(add(ptr, 0x04), spoke)
                mstore(add(ptr, 0x24), callerAddress) // delegator
                mstore(add(ptr, 0x44), address()) // delegatee = composer
                mstore(add(ptr, 0x64), status)
                mstore(add(ptr, 0x84), nonce)
                mstore(add(ptr, 0xa4), deadline)
                mstore(add(ptr, 0xc4), 0xe0) // offset to signature bytes
                mstore(add(ptr, 0xe4), 65) // signature length (r + s + v)
                mstore(add(ptr, 0x104), r)
                mstore(add(ptr, 0x124), shr(1, shl(1, vs))) // s = vs without MSB
                mstore(add(ptr, 0x144), shl(248, add(27, shr(255, vs)))) // v byte left-aligned
                if iszero(call(gas(), target, 0, ptr, 0x164, 0, 0)) {
                    returndatacopy(0, 0, returndatasize())
                    revert(0, returndatasize())
                }
            }
            default {
                mstore(ptr, _PERMIT_LENGTH_ERROR)
                revert(ptr, 4)
            }
        }
    }

    /**
     * @notice Calls PositionManagerBase.permitReserveUnderlying (ERC20 permit routed through the PM).
     * @dev Compact calldata: spoke(20) | reserveId(32) | value(32) | deadline+1(4) | r(32) | vs(32) = 152 bytes
     * @param target The PM address (typically GiverPM)
     */
    function _tryAaveV4UnderlyingPermit(address target, uint256 permitOffset, uint256 permitLength, address callerAddress) internal {
        assembly {
            let ptr := mload(0x40)
            switch permitLength
            case 152 {
                let spoke := shr(96, calldataload(permitOffset))
                let reserveId := calldataload(add(permitOffset, 0x14))
                let value := calldataload(add(permitOffset, 0x34))
                let deadline := sub(shr(224, calldataload(add(permitOffset, 0x54))), 1)
                let r := calldataload(add(permitOffset, 0x58))
                let vs := calldataload(add(permitOffset, 0x78))

                // permitReserveUnderlying(address,uint256,address,uint256,uint256,uint8,bytes32,bytes32)
                mstore(ptr, AAVE_V4_PERMIT_RESERVE_UNDERLYING)
                mstore(add(ptr, 0x04), spoke)
                mstore(add(ptr, 0x24), reserveId)
                mstore(add(ptr, 0x44), callerAddress) // onBehalfOf
                mstore(add(ptr, 0x64), value)
                mstore(add(ptr, 0x84), deadline)
                mstore(add(ptr, 0xa4), add(27, shr(255, vs))) // v
                mstore(add(ptr, 0xc4), r)
                mstore(add(ptr, 0xe4), shr(1, shl(1, vs))) // s = vs without MSB
                // PM internally does try/catch on the ERC20 permit — frontrun tolerant
                pop(call(gas(), target, 0, ptr, 0x104, 0, 0))
            }
            default {
                mstore(ptr, _PERMIT_LENGTH_ERROR)
                revert(ptr, 4)
            }
        }
    }

    /// @notice transferERC20from version using permit2
    function _transferFromPermit2(address token, address to, uint256 amount, address callerAddress) internal {
        assembly {
            let ptr := mload(0x40)
            ////////////////////////////////////////////////////
            // transferFrom through permit2
            ////////////////////////////////////////////////////
            mstore(ptr, PERMIT2_TRANSFER_FROM)
            mstore(add(ptr, 0x04), callerAddress)
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
