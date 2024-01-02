// SPDX-License-Identifier: MIT

pragma solidity ^0.8.23;

import {WithVenusStorage} from "../../storage/VenusStorage.sol";

interface IVT {
    function exchangeRateStored() external view returns (uint);
}

// assembly library for efficient compound style lending interactions
abstract contract LendingOps is WithVenusStorage {
    // Mask of the lower 20 bytes of a bytes32.
    uint256 private constant ADDRESS_MASK = 0x000000000000000000000000ffffffffffffffffffffffffffffffffffffffff;

    address internal immutable cNative;
    address internal immutable wNative;

    constructor(address _cNative, address _wNative) {
        cNative = _cNative;
        wNative = _wNative;
    }

    function getCollateralToken(address underlying) internal view returns (address token) {
        mapping(address => address) storage c_data = ls().collateralTokens;
        assembly {
            let ptr := mload(0x40)
            mstore(ptr, underlying) // pad the lender number (agnostic to uint_x)
            mstore(add(ptr, 0x20), c_data.slot) // add pointer to slot
            token := sload(keccak256(ptr, 0x40)) // acces element
        }
    }

    /**
     * @dev Converts underlying amount to collateral token amount
     */
    function calculateWithdrawCollateralAmount(address collateralToken, uint256 underlyingBalance) public view returns (uint256 res) {
        assembly {
            let params := mload(0x40)
            // Store fnSig (=bytes4(abi.encodeWithSignature("exchangeRateStored()"))) at params
            // - here we store 32 bytes : 4 bytes of fnSig and 28 bytes of RIGHT padding
            mstore(
                params,
                0x182df0f500000000000000000000000000000000000000000000000000000000 // with padding
            )
            // call to collateralToken
            let success := staticcall(
                5000,
                collateralToken,
                params,
                0x24,
                params, // store back to params
                0x20
            )
            if iszero(success) {
                revert(params, 0x40)
            }
            // load the retrieved protocol share
            let exchangeRate := mload(params)
            // calculate collateral token amount
            res := div(
                mul(underlyingBalance, 1000000000000000000), // multiply with 1e18
                exchangeRate
            )
        }
    }

    function _deposit(address underlying, uint256 amount, address receiver) internal {
        address _cNative = cNative;
        address _wNative = wNative;
        mapping(address => address) storage c_data = ls().collateralTokens;
        assembly {
            let ptr := mload(0x40)
            mstore(ptr, underlying) // pad the lender number (agnostic to uint_x)
            mstore(add(ptr, 0x20), c_data.slot) // add pointer to slot
            let _cAsset := sload(keccak256(ptr, 0x40)) // acces element

            // 1) DEPOSIT
            switch eq(_cAsset, _cNative)
            case 1 {
                // 1.1 WITHDRAW NATIVE
                // selector for withdraw(uint256) -> withdrawing ETH from WETH
                mstore(ptr, 0x2e1a7d4d00000000000000000000000000000000000000000000000000000000)
                mstore(add(ptr, 0x4), amount)

                pop(
                    call(
                        gas(),
                        and(_wNative, ADDRESS_MASK),
                        0x0, // 0 ETH
                        ptr, // input selector
                        0x24, // input size = selector plus uint256
                        0x0, // output
                        0x0 // output size = zero
                    )
                )

                // 1.2) ACTUAL DEPOSIT
                // selector for mint()
                mstore(ptr, 0x1249c58b00000000000000000000000000000000000000000000000000000000)

                let success := call(
                    gas(),
                    and(_cNative, ADDRESS_MASK),
                    amount, // amount in ETH
                    ptr, // input selector
                    0x4, // input size = selector
                    0x0, // output
                    0x0 // output size = zero
                )
                let rdsize := returndatasize()

                if iszero(success) {
                    returndatacopy(ptr, 0, rdsize)
                    revert(ptr, rdsize)
                }
            }
            default {
                // selector for mint(uint256)
                mstore(ptr, 0xa0712d6800000000000000000000000000000000000000000000000000000000)
                mstore(add(ptr, 0x4), amount)

                let success := call(
                    gas(),
                    and(_cAsset, ADDRESS_MASK),
                    0x0,
                    ptr, // input = selector and data
                    0x24, // input size = 4 + 32
                    ptr, // output
                    0x0 // output size = zero
                )
                let rdsize := returndatasize()

                if iszero(success) {
                    returndatacopy(ptr, 0, rdsize)
                    revert(ptr, rdsize)
                }
            }

            // transfer the collateral tokens

            // 2) GET BALANCE OF COLLATERAL TOKEN

            let params := mload(0x40)
            // selector for balanceOf(address)
            mstore(params, 0x70a0823100000000000000000000000000000000000000000000000000000000)
            // add this address as parameter
            mstore(add(params, 0x4), address())

            // call to collateralToken
            pop(staticcall(5000, _cAsset, params, 0x24, params, 0x20))

            // load the retrieved balance
            amount := mload(params)

            // 3) TRANSFER TOKENS TO RECEIVER

            // selector for transfer(address,uint256)
            mstore(ptr, 0xa9059cbb00000000000000000000000000000000000000000000000000000000)
            mstore(add(ptr, 0x04), and(receiver, ADDRESS_MASK))
            mstore(add(ptr, 0x24), amount)

            let success := call(gas(), and(_cAsset, ADDRESS_MASK), 0, ptr, 0x44, ptr, 32)

            let rdsize := returndatasize()

            // Check for ERC20 success. ERC20 tokens should return a boolean,
            // but some don't. We accept 0-length return data as success, or at
            // least 32 bytes that starts with a 32-byte boolean true.
            success := and(
                success, // call itself succeeded
                or(
                    iszero(rdsize), // no return data, or
                    and(
                        iszero(lt(rdsize, 32)), // at least 32 bytes
                        eq(mload(ptr), 1) // starts with uint256(1)
                    )
                )
            )

            if iszero(success) {
                returndatacopy(ptr, 0, rdsize)
                revert(ptr, rdsize)
            }
        }
    }

    function _withdraw(address underlying, uint256 amount) internal {
        address _cNative = cNative;
        address _wNative = wNative;
        mapping(address => address) storage c_data = ls().collateralTokens;
        assembly {
            let ptr := mload(0x40) // free memory pointer
            mstore(ptr, underlying) // pad the lender number (agnostic to uint_x)
            mstore(add(ptr, 0x20), c_data.slot) // add pointer to slot
            let _cAsset := sload(keccak256(ptr, 0x40)) // acces element
            switch eq(_cAsset, _cNative)
            case 1 {
                ptr := mload(0x40) // free memory pointer
                // selector for redeemUnderlying(uint256)
                mstore(ptr, 0x852a12e300000000000000000000000000000000000000000000000000000000)
                mstore(add(ptr, 0x4), amount)

                let success := call(
                    gas(),
                    and(_cNative, ADDRESS_MASK),
                    0x0,
                    ptr, // input = selector
                    0x24, // input selector + uint256
                    ptr, // output
                    0x0 // output size = zero
                )
                let rdsize := returndatasize()

                if iszero(success) {
                    returndatacopy(ptr, 0, rdsize)
                    revert(ptr, rdsize)
                }

                // selector for deposit()
                mstore(ptr, 0xd0e30db000000000000000000000000000000000000000000000000000000000)
                pop(
                    call(
                        gas(),
                        and(_wNative, ADDRESS_MASK),
                        amount, // ETH to deposit
                        ptr, // seletor for deposit()
                        0x4, // input size = selector
                        0x0, // output = empty
                        0x0 // output size = zero
                    )
                )
            }
            default {
                ptr := mload(0x40) // free memory pointer

                // selector for redeemUnderlying(uint256)
                mstore(ptr, 0x852a12e300000000000000000000000000000000000000000000000000000000)
                mstore(add(ptr, 0x4), amount)

                let success := call(
                    gas(),
                    and(_cAsset, ADDRESS_MASK),
                    0x0,
                    ptr, // input = empty for fallback
                    0x24, // input size = selector + uint256
                    ptr, // output
                    0x0 // output size = zero
                )
                let rdsize := returndatasize()

                if iszero(success) {
                    returndatacopy(ptr, 0, rdsize)
                    revert(ptr, rdsize)
                }
            }
        }
    }

    function _repay(address underlying, uint256 amount) internal {
        address _cNative = cNative;
        address _wNative = wNative;
        mapping(address => address) storage c_data = ls().collateralTokens;
        assembly {
            let ptr := mload(0x40) // free memory pointer
            mstore(ptr, underlying) // pad the lender number (agnostic to uint_x)
            mstore(add(ptr, 0x20), c_data.slot) // add pointer to slot
            let _cAsset := sload(keccak256(ptr, 0x40)) // acces element
            switch eq(_cAsset, _cNative)
            case 1 {
                ptr := mload(0x40) // free memory pointer
                // selector for withdraw(uint26)
                mstore(ptr, 0x2e1a7d4d00000000000000000000000000000000000000000000000000000000)
                mstore(add(ptr, 0x4), amount)

                pop(
                    call(
                        gas(),
                        and(_wNative, ADDRESS_MASK),
                        0x0, // 0 ETH
                        ptr, // input selector
                        0x24, // input size = selector plus uint256
                        0x0, // output
                        0x0 // output size = zero
                    )
                )
                // selector for repayBorrow()
                mstore(ptr, 0x4e4d9fea00000000000000000000000000000000000000000000000000000000)

                let success := call(
                    gas(),
                    and(_cNative, ADDRESS_MASK),
                    amount,
                    ptr, // input selector
                    0x4, // input size = selector
                    ptr, // output
                    0x0 // output size = zero
                )
                let rdsize := returndatasize()

                if iszero(success) {
                    returndatacopy(ptr, 0, rdsize)
                    revert(ptr, rdsize)
                }
            }
            default {
                ptr := mload(0x40) // free memory pointer

                // selector for repayBorrow(uint256)
                mstore(ptr, 0x0e75270200000000000000000000000000000000000000000000000000000000)
                mstore(add(ptr, 0x4), amount)

                let success := call(
                    gas(),
                    and(_cAsset, ADDRESS_MASK),
                    0x0,
                    ptr, // input = empty for fallback
                    0x24, // input size = zero
                    ptr, // output
                    0x0 // output size = zero
                )
                let rdsize := returndatasize()

                if iszero(success) {
                    returndatacopy(ptr, 0, rdsize)
                    revert(ptr, rdsize)
                }
            }
        }
    }

    function _borrow(address underlying, uint256 amount) internal {
        address _cNative = cNative;
        address _wNative = wNative;
        mapping(address => address) storage c_data = ls().collateralTokens;
        assembly {
            let ptr := mload(0x40) // free memory pointer
            mstore(ptr, underlying) // pad the lender number (agnostic to uint_x)
            mstore(add(ptr, 0x20), c_data.slot) // add pointer to slot
            let _cAsset := sload(keccak256(ptr, 0x40)) // acces element
            switch eq(_cAsset, _cNative)
            case 1 {
                ptr := mload(0x40) // free memory pointer
                // selector for borrow(uint256)
                mstore(ptr, 0xc5ebeaec00000000000000000000000000000000000000000000000000000000)
                mstore(add(ptr, 0x4), amount)

                let success := call(
                    gas(),
                    and(_cNative, ADDRESS_MASK),
                    0x0, // no ETH sent
                    ptr, // input selector
                    0x24, // input size = selector + uint256
                    ptr, // output
                    0x0 // output size = zero
                )
                let rdsize := returndatasize()

                if iszero(success) {
                    returndatacopy(ptr, 0, rdsize)
                    revert(ptr, rdsize)
                }
                // selector for deposit()
                mstore(ptr, 0xd0e30db000000000000000000000000000000000000000000000000000000000)
                pop(
                    call(
                        gas(),
                        and(_wNative, ADDRESS_MASK),
                        amount, // ETH to deposit
                        ptr, // seletor for deposit()
                        0x4, // input size = selector
                        0x0, // output = empty
                        0x0 // output size = zero
                    )
                )
            }
            default {
                ptr := mload(0x40) // free memory pointer

                // selector for borrow(uint256)
                mstore(ptr, 0xc5ebeaec00000000000000000000000000000000000000000000000000000000)
                mstore(add(ptr, 0x4), amount)

                let success := call(
                    gas(),
                    and(_cAsset, ADDRESS_MASK),
                    0x0,
                    ptr, // input = encoded data
                    0x24, // input size = selector + uint256
                    ptr, // output
                    0x0 // output size = zero
                )
                let rdsize := returndatasize()

                if iszero(success) {
                    returndatacopy(ptr, 0, rdsize)
                    revert(ptr, rdsize)
                }
            }
        }
    }
}
