// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.28;

import {Slots} from "../shared/storage/Slots.sol";
import {ERC20Selectors} from "../shared/selectors/ERC20Selectors.sol";
import {Masks} from "../shared/masks/Masks.sol";

// solhint-disable max-line-length

/**
 * @notice Lending base contract that wraps Morpho Blue
 */
abstract contract Morpho is Slots, ERC20Selectors, Masks {
    /// @dev Mask for shares
    uint256 private constant SHARES_MASK = 0xff000000000000000000000000000000;

    /// @dev Constant MorphoB address
    address internal constant MORPHO_BLUE = 0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb;

    /// @dev  position(...)
    bytes32 private constant MORPHO_POSITION = 0x93c5206200000000000000000000000000000000000000000000000000000000;

    /// @dev  market(...)
    bytes32 private constant MORPHO_MARKET = 0x5c60e39a00000000000000000000000000000000000000000000000000000000;

    /// @dev  repay(...)
    bytes32 private constant MORPHO_REPAY = 0x20b76e8100000000000000000000000000000000000000000000000000000000;

    /// @dev  supplyCollateral(...)
    bytes32 private constant MORPHO_SUPPLY_COLLATERAL = 0x238d657900000000000000000000000000000000000000000000000000000000;

    /// @dev  supply(...)
    bytes32 private constant MORPHO_SUPPLY = 0xa99aad8900000000000000000000000000000000000000000000000000000000;

    /// @dev  borrow(...)
    bytes32 private constant MORPHO_BORROW = 0x50d8cd4b00000000000000000000000000000000000000000000000000000000;

    /// @dev  withdrawCollateral(...)
    bytes32 private constant MORPHO_WITHDRAW_COLLATERAL = 0x8720316d00000000000000000000000000000000000000000000000000000000;

    /**
     * Layout:
     * [market|amount|receiver]
     * | Offset | Length (bytes) | Description                     |
     * |--------|----------------|---------------------------------|
     * | 0      | 20             | MarketParams.loanToken          |
     * | 20     | 20             | MarketParams.collateralToken    |
     * | 40     | 20             | MarketParams.oracle             |
     * | 60     | 20             | MarketParams.irm                |
     * | 80     | 16             | MarketParams.lltv               |
     * | 96     |  1             | Assets or Shares                |
     * | 97     | 15             | Amount (borrowAm)               |
     * | 112    | 20             | Receiver                        |
     */

    /// @notice Withdraw from lender lastgiven user address and lender Id
    function _morphoBorrow(uint256 currentOffset, address callerAddress) internal returns (uint256) {
        assembly {
            // morpho should be the primary choice
            let ptr := mload(0x40)

            // borrow(...)
            mstore(ptr, MORPHO_BORROW)

            // market data
            mstore(add(ptr, 4), shr(96, calldataload(currentOffset))) // MarketParams.loanToken
            currentOffset := add(currentOffset, 20)
            mstore(add(ptr, 36), shr(96, calldataload(currentOffset))) // MarketParams.collateralToken
            currentOffset := add(currentOffset, 20)
            mstore(add(ptr, 68), shr(96, calldataload(currentOffset))) // MarketParams.oracle
            currentOffset := add(currentOffset, 20)
            mstore(add(ptr, 100), shr(96, calldataload(currentOffset))) // MarketParams.irm
            currentOffset := add(currentOffset, 20)
            let lltvAndAmount := calldataload(currentOffset)
            mstore(add(ptr, 132), shr(128, lltvAndAmount)) // MarketParams.lltv

            let borrowAm := and(UINT120_MASK, lltvAndAmount)

            /**
             * check if it is by shares or assets
             */
            switch and(SHARES_MASK, lltvAndAmount)
            case 0 {
                mstore(add(ptr, 164), borrowAm) // assets
                mstore(add(ptr, 196), 0) // shares
            }
            default {
                mstore(add(ptr, 164), 0) // assets
                mstore(add(ptr, 196), borrowAm) // shares
            }
            currentOffset := add(currentOffset, 32)

            // onbehalf
            mstore(add(ptr, 228), callerAddress) // onBehalfOf
            let lastBit := calldataload(currentOffset)
            mstore(add(ptr, 260), shr(96, lastBit)) // receiver
            currentOffset := add(currentOffset, 20)

            if iszero(
                call(
                    gas(),
                    MORPHO_BLUE,
                    0x0,
                    ptr,
                    292, // = 9 * 32 + 4
                    0x0,
                    0x0 //
                )
            ) {
                let rdlen := returndatasize()
                returndatacopy(0, 0, rdlen)
                revert(0x0, rdlen)
            }
        }

        return currentOffset;
    }

    /// @notice Deposit loanTokens to Morpho Blue - add calldata if length is nonzero
    function _encodeMorphoDeposit(uint256 currentOffset, address callerAddress) internal returns (uint256) {
        assembly {
            let ptr := mload(0x40)

            // loan token
            let token := shr(96, calldataload(currentOffset))
            /**
             * Approve MB beforehand for the depo amount
             * Slot: keccak256(MorphoBlue, keccak256(token, CALL_MANAGEMENT_APPROVALS))
             */
            mstore(0x0, token)
            mstore(0x20, CALL_MANAGEMENT_APPROVALS)
            mstore(0x20, keccak256(0x0, 0x40))
            mstore(0x0, MORPHO_BLUE)
            let key := keccak256(0x0, 0x40)
            // check if already approved
            if iszero(sload(key)) {
                // selector for approve(address,uint256)
                mstore(ptr, ERC20_APPROVE)
                mstore(add(ptr, 0x04), MORPHO_BLUE)
                mstore(add(ptr, 0x24), MAX_UINT256)

                if iszero(call(gas(), token, 0x0, ptr, 0x44, ptr, 32)) { revert(0x0, 0x0) }
                sstore(key, 1)
            }

            // supply(...)
            mstore(ptr, MORPHO_SUPPLY)
            // market data
            mstore(add(ptr, 4), token) // MarketParams.loanToken
            currentOffset := add(currentOffset, 20)
            mstore(add(ptr, 36), shr(96, calldataload(currentOffset))) // MarketParams.collateralToken
            currentOffset := add(currentOffset, 20)
            mstore(add(ptr, 68), shr(96, calldataload(currentOffset))) // MarketParams.oracle
            currentOffset := add(currentOffset, 20)
            mstore(add(ptr, 100), shr(96, calldataload(currentOffset))) // MarketParams.irm

            currentOffset := add(currentOffset, 20)
            let lltvAndAmount := calldataload(currentOffset)

            mstore(add(ptr, 132), shr(128, lltvAndAmount)) // MarketParams.lltv

            let amountToDeposit := and(UINT120_MASK, lltvAndAmount)

            /**
             * check if it is by shares or assets
             */
            switch and(SHARES_MASK, lltvAndAmount)
            case 0 {
                /**
                 * if the amount is zero, we assume that the contract balance is deposited
                 */
                if iszero(amountToDeposit) {
                    // selector for balanceOf(address)
                    mstore(0, ERC20_BALANCE_OF)
                    // add this address as parameter
                    mstore(0x04, address())
                    // call to token
                    pop(
                        staticcall(
                            gas(),
                            token, // collateral token
                            0x0,
                            0x24,
                            0x0,
                            0x20
                        )
                    )
                    // load the retrieved balance
                    amountToDeposit := mload(0x0)
                }

                mstore(add(ptr, 164), amountToDeposit) // assets
                mstore(add(ptr, 196), 0) // shares
            }
            default {
                mstore(add(ptr, 164), 0) // assets
                mstore(add(ptr, 196), amountToDeposit) // shares
            }
            // onbehalf
            mstore(add(ptr, 228), callerAddress) // onBehalfOf
            mstore(add(ptr, 260), 0x120) // offset

            currentOffset := add(currentOffset, 32)
            // get calldatalength
            let calldataLength := and(UINT16_MASK, shr(240, calldataload(currentOffset)))
            currentOffset := add(currentOffset, 2)

            // add calldata if needed
            if xor(0, calldataLength) {
                calldataLength := add(calldataLength, 20)
                mstore(add(ptr, 324), shl(96, callerAddress)) // caller
                calldatacopy(add(ptr, 344), currentOffset, calldataLength) // calldata
                currentOffset := add(currentOffset, calldataLength)
            }

            mstore(add(ptr, 292), calldataLength) // calldatalength
            if iszero(
                call(
                    gas(),
                    MORPHO_BLUE,
                    0x0,
                    ptr,
                    add(calldataLength, 324), // = 10 * 32 + 4
                    0x0,
                    0x0 //
                )
            ) {
                let rdlen := returndatasize()
                returndatacopy(0, 0, rdlen)
                revert(0x0, rdlen)
            }
        }
        return currentOffset;
    }

    /// @notice Deposit collateral to Morpho Blue - add calldata if length is nonzero
    function _encodeMorphoDepositCollateral(uint256 currentOffset, address callerAddress) internal returns (uint256) {
        assembly {
            // use two memory ranges
            let ptrBase := mload(0x40)
            let ptr := add(256, ptrBase)

            // supplyCollateral(...)
            mstore(ptr, MORPHO_SUPPLY_COLLATERAL)
            mstore(add(ptr, 4), shr(96, calldataload(currentOffset))) // MarketParams.loanToken
            currentOffset := add(currentOffset, 20)

            // get the collateral token and approve if needed
            let token := shr(96, calldataload(currentOffset))
            /**
             * Approve MB beforehand for the depo amount
             */
            mstore(0x0, token)
            mstore(0x20, CALL_MANAGEMENT_APPROVALS)
            mstore(0x20, keccak256(0x0, 0x40))
            mstore(0x0, MORPHO_BLUE)
            let key := keccak256(0x0, 0x40)
            // check if already approved
            if iszero(sload(key)) {
                // selector for approve(address,uint256)
                mstore(ptrBase, ERC20_APPROVE)
                mstore(add(ptrBase, 0x04), MORPHO_BLUE)
                mstore(add(ptrBase, 0x24), MAX_UINT256)

                if iszero(call(gas(), token, 0x0, ptrBase, 0x44, 0x0, 0x0)) { revert(0x0, 0x0) }
                sstore(key, 1)
            }

            mstore(add(ptr, 36), token) // MarketParams.collateralToken
            currentOffset := add(currentOffset, 20)
            mstore(add(ptr, 68), shr(96, calldataload(currentOffset))) // MarketParams.oracle
            currentOffset := add(currentOffset, 20)
            mstore(add(ptr, 100), shr(96, calldataload(currentOffset))) // MarketParams.irm
            currentOffset := add(currentOffset, 20)
            let lltvAndAmount := calldataload(currentOffset)
            mstore(add(ptr, 132), shr(128, lltvAndAmount)) // MarketParams.lltv

            let amountToDeposit := and(UINT128_MASK, lltvAndAmount)

            /**
             * if the amount is zero, we assume that the contract balance is deposited
             */
            if iszero(amountToDeposit) {
                // selector for balanceOf(address)
                mstore(0, ERC20_BALANCE_OF)
                // add this address as parameter
                mstore(0x04, address())
                // call to token
                pop(
                    staticcall(
                        gas(),
                        token, // collateral token
                        0x0,
                        0x24,
                        0x0,
                        0x20
                    )
                )
                // load the retrieved balance
                amountToDeposit := mload(0x0)
            }

            mstore(add(ptr, 164), amountToDeposit) // assets
            mstore(add(ptr, 196), callerAddress) // onBehalfOf
            mstore(add(ptr, 228), 0x100) // offset

            currentOffset := add(currentOffset, 32)
            // get calldatalength
            let calldataLength := and(UINT16_MASK, shr(240, calldataload(currentOffset)))
            currentOffset := add(currentOffset, 2)

            // add calldata if needed
            if xor(0, calldataLength) {
                calldataLength := add(calldataLength, 20)
                mstore(add(ptr, 292), shl(96, callerAddress)) // caller
                calldatacopy(add(ptr, 312), currentOffset, calldataLength) // calldata
                currentOffset := add(currentOffset, calldataLength)
            }

            mstore(add(ptr, 260), calldataLength) // calldatalength
            if iszero(
                call(
                    gas(),
                    MORPHO_BLUE,
                    0x0,
                    ptr,
                    add(calldataLength, 292), // = 10 * 32 + 4
                    0x0,
                    0x0 //
                )
            ) {
                let rdlen := returndatasize()
                returndatacopy(0, 0, rdlen)
                revert(0x0, rdlen)
            }
        }
        return currentOffset;
    }

    /// @notice Withdraw collateral from Morpho Blue
    function _encodeMorphoWithdrawCollateral(uint256 currentOffset, address callerAddress) internal returns (uint256) {
        assembly {
            // morpho should be the primary choice
            let ptr := mload(0x40)

            // withdrawCollateral(...)
            mstore(ptr, MORPHO_WITHDRAW_COLLATERAL)

            // market stuff

            mstore(add(ptr, 4), shr(96, calldataload(currentOffset))) // MarketParams.loanToken
            currentOffset := add(currentOffset, 20)
            mstore(add(ptr, 36), shr(96, calldataload(currentOffset))) // MarketParams.collateralToken
            currentOffset := add(currentOffset, 20)
            mstore(add(ptr, 68), shr(96, calldataload(currentOffset))) // MarketParams.oracle
            currentOffset := add(currentOffset, 20)
            mstore(add(ptr, 100), shr(96, calldataload(currentOffset))) // MarketParams.irm

            currentOffset := add(currentOffset, 20)
            let lltvAndAmount := calldataload(currentOffset)

            mstore(add(ptr, 132), shr(128, lltvAndAmount)) // MarketParams.lltv

            // amount
            mstore(add(ptr, 164), and(UINT128_MASK, lltvAndAmount)) // assets

            // onbehalf
            mstore(add(ptr, 196), callerAddress) // onBehalfOf

            currentOffset := add(currentOffset, 32)
            mstore(add(ptr, 228), shr(96, calldataload(currentOffset))) // receiver

            // skip receiver in offset
            currentOffset := add(currentOffset, 20)

            if iszero(
                call(
                    gas(),
                    MORPHO_BLUE,
                    0x0,
                    ptr,
                    260, // = 8 * 32 + 4
                    0x0,
                    0x0 //
                )
            ) {
                let rdlen := returndatasize()
                returndatacopy(0, 0, rdlen)
                revert(0x0, rdlen)
            }
        }
        return currentOffset;
    }

    /// @notice Withdraw borrowAsset from Morpho
    function _encodeMorphoWithdraw(uint256 currentOffset, address callerAddress) internal returns (uint256) {
        assembly {
            // morpho should be the primary choice
            let ptrBase := mload(0x40)
            let ptr := add(ptrBase, 256)

            // market data
            mstore(add(ptr, 4), shr(96, calldataload(currentOffset))) // MarketParams.loanToken
            currentOffset := add(currentOffset, 20)
            mstore(add(ptr, 36), shr(96, calldataload(currentOffset))) // MarketParams.collateralToken
            currentOffset := add(currentOffset, 20)
            mstore(add(ptr, 68), shr(96, calldataload(currentOffset))) // MarketParams.oracle
            currentOffset := add(currentOffset, 20)
            mstore(add(ptr, 100), shr(96, calldataload(currentOffset))) // MarketParams.irm
            currentOffset := add(currentOffset, 20)
            let lltvAndAmount := calldataload(currentOffset)
            mstore(add(ptr, 132), shr(128, lltvAndAmount)) // MarketParams.lltv

            let withdrawAm := and(UINT120_MASK, lltvAndAmount)

            /**
             * check if it is by shares or assets
             * 0 => by assets
             * 1 => by shares
             */
            switch and(SHARES_MASK, lltvAndAmount)
            case 0 {
                /**
                 * Withdraw amount variations
                 * type(uint120).max:    user supply balance
                 * other:                amount provided
                 */
                switch withdrawAm
                // maximum uint120 means withdraw everything
                case 0xffffffffffffffffffffffffffffff {
                    // we need to fetch user shares and just withdraw all shares
                    // https://docs.morpho.org/morpho/tutorials/manage-positions/#repayAll

                    let marketId := keccak256(add(ptr, 4), 160)
                    // position datas (1st slot of return data is the user shares)
                    mstore(ptrBase, MORPHO_POSITION)
                    mstore(add(ptrBase, 0x4), marketId)
                    mstore(add(ptrBase, 0x24), callerAddress)
                    if iszero(staticcall(gas(), MORPHO_BLUE, ptrBase, 0x44, ptrBase, 0x20)) { revert(0x0, 0x0) }
                    mstore(add(ptr, 164), 0) // assets
                    mstore(add(ptr, 196), mload(ptrBase)) // shares
                }
                // explicit amount
                default {
                    mstore(add(ptr, 164), withdrawAm) // assets
                    mstore(add(ptr, 196), 0) // shares
                }
            }
            default {
                mstore(add(ptr, 164), 0) // assets
                mstore(add(ptr, 196), withdrawAm) // shares
            }

            currentOffset := add(currentOffset, 32)

            mstore(add(ptr, 228), callerAddress) // onBehalfOf
            mstore(add(ptr, 260), shr(96, calldataload(currentOffset))) // receiver
            currentOffset := add(currentOffset, 20)

            // withdraw(...)
            // we have to do it like this to override the selector only in this memory position
            mstore(sub(ptr, 28), 0x5c2bea49)
            if iszero(
                call(
                    gas(),
                    MORPHO_BLUE,
                    0x0,
                    ptr,
                    292, // = 9 * 32 + 4
                    0x0,
                    0x0 //
                )
            ) {
                let rdlen := returndatasize()
                returndatacopy(0, 0, rdlen)
                revert(0x0, rdlen)
            }
        }
        return currentOffset;
    }

    /// @notice Withdraw from lender lastgiven user address and lender Id
    function _morphoRepay(uint256 currentOffset, address callerAddress) internal returns (uint256) {
        assembly {
            // morpho should be the primary choice
            let ptrBase := mload(0x40)
            let ptr := add(ptrBase, 256)

            let token := shr(96, calldataload(currentOffset))
            /**
             * Approve MB beforehand for the repay amount
             */
            mstore(0x0, token)
            mstore(0x20, CALL_MANAGEMENT_APPROVALS)
            mstore(0x20, keccak256(0x0, 0x40))
            mstore(0x0, MORPHO_BLUE)
            let key := keccak256(0x0, 0x40)
            // check if already approved
            if iszero(sload(key)) {
                // selector for approve(address,uint256)
                mstore(ptrBase, ERC20_APPROVE)
                mstore(add(ptrBase, 0x04), MORPHO_BLUE)
                mstore(add(ptrBase, 0x24), 0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff)
                if iszero(call(gas(), token, 0x0, ptrBase, 0x44, ptrBase, 0x0)) { revert(0x0, 0x0) }
                sstore(key, 1)
            }
            // market data
            mstore(add(ptr, 4), token) // MarketParams.loanToken
            currentOffset := add(currentOffset, 20)
            mstore(add(ptr, 36), shr(96, calldataload(currentOffset))) // MarketParams.collateralToken
            currentOffset := add(currentOffset, 20)
            mstore(add(ptr, 68), shr(96, calldataload(currentOffset))) // MarketParams.oracle
            currentOffset := add(currentOffset, 20)
            mstore(add(ptr, 100), shr(96, calldataload(currentOffset))) // MarketParams.irm
            currentOffset := add(currentOffset, 20)
            let lltvAndAmount := calldataload(currentOffset)
            mstore(add(ptr, 132), shr(128, lltvAndAmount)) // MarketParams.lltv

            let repayAm := and(UINT120_MASK, lltvAndAmount)

            /**
             * Logic tree
             *  if repayAmount is Max -> repay max shares
             *  else {
             *      if(repayAmount id 0): set repayAmount to contract balance
             *      if(amountFlag is 0): safe repay amount (ensures that morpho does not revert on overpaying)
             *      else if(amountFlag is 1) repay amount as shares (unsafe, determinsitic on-chain though)
             *      else repay amount unsafe
             *  }
             */
            switch repayAm
            // all or nothing
            // fails if there are not enough funds in this contract
            case 0xffffffffffffffffffffffffffffff {
                // fetch user shares and repay all shares
                // will revert if balance in contract is not enough
                let marketId := keccak256(add(ptr, 4), 160)
                // position datas
                mstore(ptrBase, MORPHO_POSITION)
                mstore(add(ptrBase, 0x4), marketId)
                mstore(add(ptrBase, 0x24), callerAddress)
                if iszero(staticcall(gas(), MORPHO_BLUE, ptrBase, 0x44, ptrBase, 0x40)) { revert(0x0, 0x0) }
                mstore(add(ptr, 164), 0) // assets
                mstore(add(ptr, 196), mload(add(ptrBase, 0x20))) // shares
            }
            default {
                let amountType := and(UINT8_MASK, shr(120, lltvAndAmount))
                // zero balance means contract balance
                // creates unexpected behavior if this amount is used for shares!
                if iszero(repayAm) {
                    // revert if shares are selected as a continuation
                    // will lead to unexpected behavior
                    if eq(amountType, 1) { revert(0x0, 0x0) }
                    // get balance
                    mstore(0x0, ERC20_BALANCE_OF)
                    mstore(0x04, address())
                    if iszero(staticcall(gas(), token, 0x0, 0x24, 0x0, 0x20)) { revert(0x0, 0x0) }
                    repayAm := mload(0x0)
                }
                /**
                 * check if it is by shares or assets
                 */
                switch amountType
                case 0 {
                    // by assets safe - will not revert if too much is repaid
                    // we need to fetch everything and acrure interest
                    // https://docs.morpho.org/morpho/tutorials/manage-positions/#repayAll

                    // accrue interest
                    // add accrueInterest (0x151c1ade)
                    mstore(sub(ptr, 28), 0x151c1ade)
                    if iszero(call(gas(), MORPHO_BLUE, 0x0, ptr, 0xA4, 0x0, 0x0)) { revert(0x0, 0x0) }

                    let marketId := keccak256(add(ptr, 4), 160)
                    mstore(0x0, MORPHO_MARKET)
                    mstore(0x4, marketId)
                    if iszero(staticcall(gas(), MORPHO_BLUE, 0x0, 0x24, ptrBase, 0x80)) { revert(0x0, 0x0) }
                    let totalBorrowAssets := mload(add(ptrBase, 0x40))
                    let totalBorrowShares := mload(add(ptrBase, 0x60))

                    // get balance
                    mstore(0x0, ERC20_BALANCE_OF)
                    mstore(0x04, address())
                    if iszero(staticcall(gas(), token, 0x0, 0x24, 0x0, 0x20)) { revert(0x0, 0x0) }
                    repayAm := mload(0x0)

                    // position datas
                    mstore(ptrBase, MORPHO_POSITION)
                    mstore(add(ptrBase, 0x4), marketId)
                    mstore(add(ptrBase, 0x24), callerAddress)
                    if iszero(staticcall(gas(), MORPHO_BLUE, ptrBase, 0x44, ptrBase, 0x40)) { revert(0x0, 0x0) }
                    let userBorrowShares := mload(add(ptrBase, 0x20))

                    // mulDivUp(shares, totalAssets + VIRTUAL_ASSETS, totalShares + VIRTUAL_SHARES);
                    let maxAssets := add(totalBorrowShares, 1000000) // VIRTUAL_SHARES=1e6
                    maxAssets :=
                        div(
                            add(
                                mul(userBorrowShares, add(totalBorrowAssets, 1)), // VIRTUAL_ASSETS=1
                                sub(maxAssets, 1) //
                            ),
                            maxAssets //
                        )

                    // if maxAssets is greater than repay amount
                    // we repay whatever is possible
                    switch gt(maxAssets, repayAm)
                    case 1 {
                        mstore(add(ptr, 164), repayAm) // assets
                        mstore(add(ptr, 196), 0) // shares
                    }
                    // otherwise, repay all shares, leaving no dust
                    default {
                        mstore(add(ptr, 164), 0) // assets
                        mstore(add(ptr, 196), userBorrowShares) // shares
                    }
                }
                case 1 {
                    // by shares
                    mstore(add(ptr, 164), 0) // assets
                    mstore(add(ptr, 196), repayAm) // shares
                }
                default {
                    // by assets unsafe
                    // reverts if repay amount is too high
                    mstore(add(ptr, 164), repayAm) // assets
                    mstore(add(ptr, 196), 0) // shares
                }
            }

            currentOffset := add(currentOffset, 32)

            // onbehalf
            mstore(add(ptr, 228), callerAddress) // onBehalfOf
            mstore(add(ptr, 260), 0x120) // offset

            // get calldatalength
            let calldataLength := and(UINT16_MASK, shr(240, calldataload(currentOffset)))
            currentOffset := add(currentOffset, 2)

            // add calldata if needed
            if xor(0, calldataLength) {
                calldataLength := add(calldataLength, 20)
                mstore(add(ptr, 324), shl(96, callerAddress)) // caller
                calldatacopy(add(ptr, 344), currentOffset, calldataLength) // calldata
                currentOffset := add(currentOffset, calldataLength)
            }

            // repay(...)
            // we have to do it like this to override the selector only in this memory position
            mstore(sub(ptr, 28), 0x20b76e81)
            mstore(add(ptr, 292), calldataLength) // calldatalength
            if iszero(
                call(
                    gas(),
                    MORPHO_BLUE,
                    0x0,
                    ptr,
                    add(calldataLength, 324), // = 10 * 32 + 4
                    0x0,
                    0x0 //
                )
            ) {
                let rdlen := returndatasize()
                returndatacopy(0, 0, rdlen)
                revert(0x0, rdlen)
            }
        }
        return currentOffset;
    }
}
