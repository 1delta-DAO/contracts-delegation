// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.28;

import {WithVenusStorage} from "../../../storage/VenusStorage.sol";

interface IVT {
    function exchangeRateStored() external view returns (uint);

    function balanceOfUnderlying(address a) external returns (uint);

    function redeemUnderlying(uint redeemAmount) external returns (uint);

    function redeem(uint redeemAmount) external returns (uint);

    function borrowBalanceCurrent(address account) external returns (uint);
}

/**
 * @dev Interface of the ERC20 standard as defined in the EIP.
 */
interface IERC20 {
    function totalSupply() external view returns (uint256);

    function balanceOf(address account) external view returns (uint256);

    function transfer(address to, uint256 amount) external returns (bool);

    function allowance(address owner, address spender) external view returns (uint256);

    function approve(address spender, uint256 amount) external returns (bool);

    function transferFrom(address from, address to, uint256 amount) external returns (bool);
}

// assembly library for efficient compound style lending interactions
abstract contract LendingOps is WithVenusStorage {
    // Mask of the lower 20 bytes of a bytes32.
    uint256 private constant ADDRESS_MASK = 0x000000000000000000000000ffffffffffffffffffffffffffffffffffffffff;

    address internal constant V_NATIVE = 0xA07c5b74C9B40447a954e1466938b865b6BBea36;
    address internal constant WRAPPED_NATIVE = 0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c;

    constructor() {}

    /**
     * @notice Approach
     * 1) deposit asset (for wNative, wrap first)
     * 2) read collateral token balance
     * 3) transfer balance to receiver
     */
    function _deposit(address underlying, uint256 amount, address receiver) internal {
        mapping(address => address) storage c_data = ls().collateralTokens;
        assembly {
            let ptr := mload(0x40)
            mstore(ptr, underlying) // pad the lender number (agnostic to uint_x)
            mstore(add(ptr, 0x20), c_data.slot) // add pointer to slot
            let _cAsset := and(sload(keccak256(ptr, 0x40)), ADDRESS_MASK) // acces element

            // 1) DEPOSIT
            switch eq(_cAsset, V_NATIVE)
            case 1 {
                // 1.1 WITHDRAW NATIVE
                // selector for withdraw(uint256) -> withdrawing ETH from WETH
                mstore(ptr, 0x2e1a7d4d00000000000000000000000000000000000000000000000000000000)
                mstore(add(ptr, 0x4), amount)

                pop(
                    call(
                        gas(),
                        WRAPPED_NATIVE,
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
                    V_NATIVE,
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
                    _cAsset,
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

            // selector for balanceOf(address)
            mstore(ptr, 0x70a0823100000000000000000000000000000000000000000000000000000000)
            // add this address as parameter
            mstore(add(ptr, 0x4), address())

            // call to collateralToken
            pop(staticcall(5000, _cAsset, ptr, 0x24, ptr, 0x20))

            // load the retrieved balance
            amount := mload(ptr)

            // 3) TRANSFER TOKENS TO RECEIVER

            // selector for transfer(address,uint256)
            mstore(ptr, 0xa9059cbb00000000000000000000000000000000000000000000000000000000)
            mstore(add(ptr, 0x04), receiver)
            mstore(add(ptr, 0x24), amount)

            let success := call(gas(), _cAsset, 0, ptr, 0x44, ptr, 32)

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

    /**
     * @notice Withdrawal from Venus, delegated from user
     * 1) calculate vToken amount to transfer
     *  -> note that we have to round up here since we MUST make sure that we receive amount
        -> as such, we have to fetch the user balance and see whether the rounding overflows the balance
     * 2) transfer vTokens from user
     * 3) withdraw / redeem underlying
     * 4) send funds to recever
     */
    function _withdraw(address underlying, uint256 amount, address user, address to) internal {
        mapping(address => address) storage c_data = ls().collateralTokens;
        assembly {
            let ptr := mload(0x40) // free memory pointer
            mstore(ptr, underlying) // pad the lender number (agnostic to uint_x)
            mstore(add(ptr, 0x20), c_data.slot) // add pointer to slot
            let _cAsset := and(sload(keccak256(ptr, 0x40)), ADDRESS_MASK) // access element

            // 1) CALCULTAE TRANSFER AMOUNT
            // Store fnSig (=bytes4(abi.encodeWithSignature("exchangeRateCurrent()"))) at params
            // - here we store 32 bytes : 4 bytes of fnSig and 28 bytes of RIGHT padding
            mstore(
                ptr,
                0xbd6d894d00000000000000000000000000000000000000000000000000000000 // with padding
            )
            // call to collateralToken
            // accrues interest. No real risk of failure.
            pop(
                call(
                    gas(),
                    _cAsset,
                    0x0,
                    ptr,
                    0x24,
                    ptr, // store back to ptr
                    0x20
                )
            )

            // load the retrieved protocol share
            let refAmount := mload(ptr)

            // calculate collateral token amount, rounding up
            let transferAmount := add(
                div(
                    mul(amount, 1000000000000000000), // multiply with 1e18
                    refAmount // divide by rate
                ),
                1
            )
            // FETCH BALANCE
            // selector for balanceOf(address)
            mstore(ptr, 0x70a0823100000000000000000000000000000000000000000000000000000000)
            // add this address as parameter
            mstore(add(ptr, 0x4), user)

            // call to collateralToken
            pop(staticcall(5000, _cAsset, ptr, 0x24, ptr, 0x20))

            // load the retrieved balance
            refAmount := mload(ptr)

            // floor to the balance
            if gt(transferAmount, refAmount) {
                transferAmount := refAmount
            }

            // 2) TRANSFER VTOKENS

            // selector for transferFrom(address,address,uint256)
            mstore(ptr, 0x23b872dd00000000000000000000000000000000000000000000000000000000)
            mstore(add(ptr, 0x04), user) // from user
            mstore(add(ptr, 0x24), address()) // to this address
            mstore(add(ptr, 0x44), transferAmount)

            let success := call(gas(), _cAsset, 0, ptr, 0x64, ptr, 32)

            let rdsize := returndatasize()

            if iszero(success) {
                returndatacopy(ptr, 0, rdsize)
                revert(ptr, rdsize)
            }

            // 3) REDEEM
            // selector for redeem(uint256)
            mstore(ptr, 0xdb006a7500000000000000000000000000000000000000000000000000000000)
            mstore(add(ptr, 0x4), transferAmount)

            success := call(
                gas(),
                _cAsset,
                0x0,
                ptr, // input = selector
                0x24, // input selector + uint256
                ptr, // output
                0x0 // output size = zero
            )
            rdsize := returndatasize()

            if iszero(success) {
                returndatacopy(ptr, 0, rdsize)
                revert(ptr, rdsize)
            }

            // case native
            if eq(_cAsset, V_NATIVE) {
                // if it is native, we convert to WETH
                // selector for deposit() (deposit ETH to WETH)
                mstore(ptr, 0xd0e30db000000000000000000000000000000000000000000000000000000000)
                pop(
                    call(
                        gas(),
                        WRAPPED_NATIVE,
                        amount, // ETH to deposit
                        ptr, // seletor for deposit()
                        0x4, // input size = selector
                        0x0, // output = empty
                        0x0 // output size = zero
                    )
                )
            }
            // 4) TRANSFER TO RECIPIENT
            // selector for transfer(address,uint256)
            mstore(ptr, 0xa9059cbb00000000000000000000000000000000000000000000000000000000)
            mstore(add(ptr, 0x04), and(to, ADDRESS_MASK))
            mstore(add(ptr, 0x24), amount)

            success := call(gas(), and(underlying, ADDRESS_MASK), 0, ptr, 0x44, ptr, 32)

            rdsize := returndatasize()

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

    /**
     * @notice repay an ERC20 asset
     * - vBNB not supported since it is an immutable deployment
     */
    function _repay(address underlying, uint256 amount, address onBehalfOf) internal {
        mapping(address => address) storage c_data = ls().collateralTokens;
        assembly {
            let ptr := mload(0x40) // free memory pointer
            mstore(ptr, underlying) // pad the lender number (agnostic to uint_x)
            mstore(add(ptr, 0x20), c_data.slot) // add pointer to slot
            let _cAsset := sload(keccak256(ptr, 0x40)) // acces element

            // selector for repayBorrowBehalf(address,uint256)
            mstore(ptr, 0x2608f81800000000000000000000000000000000000000000000000000000000)
            mstore(add(ptr, 0x4), onBehalfOf) // user
            mstore(add(ptr, 0x24), amount) // to this address

            let success := call(
                gas(),
                _cAsset,
                0x0,
                ptr, // input = empty for fallback
                0x44, // input size = selector + address + uint256
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

    /**
     * @notice borrow an ERC20 asset
     * - vBNB not supported since it is an immutable deployment
     */
    function _borrow(address underlying, uint256 amount, address onBehalfOf, address to) internal {
        mapping(address => address) storage c_data = ls().collateralTokens;
        assembly {
            let ptr := mload(0x40) // free memory pointer
            mstore(ptr, underlying) // pad the lender number (agnostic to uint_x)
            mstore(add(ptr, 0x20), c_data.slot) // add pointer to slot
            let _cAsset := sload(keccak256(ptr, 0x40)) // acces element
            // selector for borrowBehlaf(address,uint256)
            mstore(ptr, 0x856e5bb300000000000000000000000000000000000000000000000000000000)
            mstore(add(ptr, 0x4), onBehalfOf) // user
            mstore(add(ptr, 0x24), amount) // to this address

            let success := call(
                gas(),
                _cAsset,
                0x0, // no ETH sent
                ptr, // input selector
                0x44, // input size = selector + address + uint256
                ptr, // output
                0x0 // output size = zero
            )
            let rdsize := returndatasize()

            if iszero(success) {
                returndatacopy(ptr, 0, rdsize)
                revert(ptr, rdsize)
            }

            // 4) TRANSFER TO RECIPIENT
            // selector for transfer(address,uint256)
            mstore(ptr, 0xa9059cbb00000000000000000000000000000000000000000000000000000000)
            mstore(add(ptr, 0x04), and(to, ADDRESS_MASK))
            mstore(add(ptr, 0x24), amount)

            success := call(gas(), and(underlying, ADDRESS_MASK), 0, ptr, 0x44, ptr, 32)

            rdsize := returndatasize()

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
}
