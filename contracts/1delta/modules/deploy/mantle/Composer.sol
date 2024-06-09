// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.26;

import {DeltaFlashAggregatorMantle} from "./FlashAggregator.sol";
import {Commands} from "./composable/Commands.sol";

/**
 * @title Flash aggregator contract.
 *        Allows spot and margin swap aggregation
 *        Efficient baching through compact calldata usage.
 *        Single route swap functions exposed to allower lower gas const for L1s
 * @author 1delta Labs
 */
contract Composer is DeltaFlashAggregatorMantle {
    uint256 internal constant _PAY_SELF = 1 << 255;
    uint256 internal constant _USE_BALANCE = 1 << 254;
    uint256 private constant _UPPER_120_MASK = 0x00ffffffffffffffffffffffffffffff00000000000000000000000000000000;
    uint256 private constant _UINT112_MASK = 0x000000000000000000000000000000000000ffffffffffffffffffffffffffff;

    /**
     * Execute a set op packed operations
     * @param data packed ops array
     * | op0 | length0 | data0 | op1 | length1 | ...
     * | 1   |    16   | ...   |  1  |    16   | ...
     */
    function deltaCompose(bytes calldata data) external payable {
        // data loop paramters
        uint256 currentOffset;
        uint256 maxIndex;
        assembly {
            maxIndex := add(data.length, data.offset)
            currentOffset := data.offset
        }

        ////////////////////////////////////////////////////
        // Progressively loop through the calldata
        // The first byte defines the operation
        // From there on, we read the data based on the
        // what the operation expects, e.g. read the next 32 bytes as uint256.
        //
        // `currentOffset` represents the current bytes at which we
        //            are in the calldata
        // `maxIndex` is used as break criteria, this means that if
        //            currentOffset >= maxIndex, we iterated through
        //            the entire calldata.
        ////////////////////////////////////////////////////
        while (true) {
            uint256 operation;
            // fetch op metadata
            assembly {
                operation := and(shr(248, calldataload(currentOffset)), UINT8_MASK)
                // we increment the current offset to skip the operation
                currentOffset := add(1, currentOffset)
            }
            if (operation < 0x10) {
                // exec op
                if (operation == Commands.SWAP_EXACT_IN) {
                    ////////////////////////////////////////////////////
                    // Encoded parameters for the swap
                    // | amount | receiver | pathLength | path |
                    // | uint256| address  |  uint16    | bytes|
                    // where amount is provided as
                    // pay self         (bool)      in the upper bit
                    //                              if true, payer is this contract
                    // minimumAmountOut (uint120)   in the bytes starting at bit 128
                    //                              from the right
                    // amountIn         (uint128)   in the lowest bytes
                    //                              zero is for paying withn the balance of
                    //                              payer (self or caller)
                    ////////////////////////////////////////////////////
                    bytes calldata opdata;
                    uint256 amountIn;
                    address payer;
                    address receiver;
                    uint256 minimumAmountOut;
                    assembly {
                        // the path starts after the path length
                        opdata.offset := add(currentOffset, 54) // 32 +20 + 2
                        // lastparam includes receiver address and pathlength
                        let lastparam := calldataload(add(currentOffset, 32))
                        receiver := and(ADDRESS_MASK, shr(96, lastparam))
                        // this is the path data length
                        let calldataLength := and(shr(80, lastparam), UINT16_MASK)
                        opdata.length := calldataLength
                        // add the length to 54 (=32+20+2)
                        calldataLength := add(54, calldataLength)
                        // these are the entire first 32 bytes
                        amountIn := calldataload(currentOffset)
                        // extract the upper 120 bits
                        minimumAmountOut := shr(128, and(amountIn, _UPPER_120_MASK))
                        // upper but signals whether to pay with full balance
                        switch iszero(and(_PAY_SELF, amountIn))
                        case 0 {
                            payer := address()
                        }
                        default {
                            payer := caller()
                        }
                        // mask input amount
                        amountIn := and(UINT128_MASK, amountIn)
                        // fetch balance if needed
                        if iszero(amountIn) {
                            // selector for balanceOf(address)
                            mstore(0, 0x70a0823100000000000000000000000000000000000000000000000000000000)
                            // add this address as parameter
                            mstore(0x04, payer)
                            // call to token
                            pop(
                                staticcall(
                                    gas(),
                                    calldataload(and(ADDRESS_MASK, opdata.offset)),
                                    0x0,
                                    0x24,
                                    0x0,
                                    0x20 //
                                )
                            )
                            // load the retrieved balance
                            amountIn := mload(0x0)
                        }
                        currentOffset := add(currentOffset, calldataLength)
                    }
                    uint256 dexId = _preFundTrade(payer, amountIn, opdata);
                    amountIn = swapExactIn(amountIn, dexId, payer, receiver, opdata);
                    // slippage check
                    assembly {
                        if lt(amountIn, minimumAmountOut) {
                            mstore(0, SLIPPAGE)
                            revert(0, 0x4)
                        }
                    }
                } else if (operation == Commands.SWAP_EXACT_OUT) {
                    ////////////////////////////////////////////////////
                    // Encoded parameters for the swap
                    // | amount | receiver | pathLength | path |
                    // | uint256| address  |  uint16    | bytes|
                    // where amount is provided as
                    // pay self         (bool)      in the upper bit
                    //                              if true, payer is this contract
                    // maximumAmountIn  (uint120)   in the bytes starting at bit 128
                    //                              from the right
                    // amountOut        (uint128)   in the lowest bytes
                    //                              zero is for paying withn the balance of
                    //                              payer (self or caller)
                    ////////////////////////////////////////////////////
                    bytes calldata opdata;
                    uint256 amountOut;
                    address payer;
                    address receiver;
                    uint256 amountInMaximum;
                    assembly {
                        opdata.offset := add(currentOffset, 54) // 32 +20 + 2
                        let lastparam := calldataload(add(currentOffset, 32))
                        receiver := and(ADDRESS_MASK, shr(96, lastparam))
                        // we get the calldatalength of the path
                        let calldataLength := and(shr(80, lastparam), UINT16_MASK)
                        opdata.length := and(calldataLength, UINT16_MASK)

                        calldataLength := add(54, calldataLength)
                        amountOut := calldataload(currentOffset)
                        amountInMaximum := shr(128, and(amountOut, _UPPER_120_MASK))
                        switch iszero(and(_PAY_SELF, amountOut))
                        case 0 {
                            payer := address()
                        }
                        default {
                            payer := caller()
                        }
                        amountOut := and(UINT128_MASK, amountOut)
                        if iszero(amountOut) {
                            // selector for balanceOf(address)
                            mstore(0, 0x70a0823100000000000000000000000000000000000000000000000000000000)
                            // add this address as parameter
                            mstore(0x04, payer)
                            // call to token
                            pop(
                                staticcall(
                                    gas(),
                                    calldataload(and(ADDRESS_MASK, add(currentOffset, 32))),
                                    0x0,
                                    0x24,
                                    0x0,
                                    0x20 //
                                )
                            )
                            // load the retrieved balance
                            amountOut := mload(0x0)
                        }
                        currentOffset := add(currentOffset, calldataLength)
                    }
                    flashSwapExactOutInternal(amountOut, amountInMaximum, payer, receiver, opdata);
                } else if (operation == Commands.FLASH_SWAP_EXACT_IN) {
                    ////////////////////////////////////////////////////
                    // Parameter encoding is the same as for SWAP_EXACT_IN
                    // The difference is that we potentially need to add
                    // a read of the user collateral balance
                    // Note that conventional (non lending) flash swaps
                    // send the output funds to the caller
                    // As such, the sweep function should be added to
                    // the batch
                    ////////////////////////////////////////////////////
                    bytes calldata opdata;
                    uint256 amountIn;
                    address payer;
                    address receiver;
                    uint256 minimumAmountOut;
                    // all but balance fetch same as for SWAP_EXACT_IN
                    assembly {
                        // the path starts after the path length
                        opdata.offset := add(currentOffset, 54) // 32 +20 + 2
                        // lastparam includes receiver address and pathlength
                        let lastparam := calldataload(add(currentOffset, 32))
                        receiver := and(ADDRESS_MASK, shr(96, lastparam))
                        // this is the path data length
                        let calldataLength := and(shr(80, lastparam), UINT16_MASK)
                        opdata.length := calldataLength
                        // add the length to 54 (=32+20+2)
                        calldataLength := add(54, calldataLength)
                        // these are the entire first 32 bytes
                        amountIn := calldataload(currentOffset)
                        // extract the upper 120 bits
                        minimumAmountOut := shr(128, and(amountIn, _UPPER_120_MASK))
                        // upper but signals whether to pay with full balance
                        switch iszero(and(_PAY_SELF, amountIn))
                        case 0 {
                            payer := address()
                        }
                        default {
                            payer := caller()
                        }
                        // mask input amount
                        amountIn := and(UINT128_MASK, amountIn)
                        ////////////////////////////////////////////////////
                        // Fetching the balance here is a bit trickier here
                        // We have to fetch the lender-specific collateral
                        // balance
                        // `tokenIn`    is at the beginning of the path; and
                        // `lenderId`   is at the end of the path
                        ////////////////////////////////////////////////////
                        if iszero(amountIn) {
                            let tokenIn := and(ADDRESS_MASK, shr(96, calldataload(opdata.offset)))
                            let lenderId := and(
                                shr(
                                    8,
                                    calldataload(
                                        sub(
                                            add(opdata.length, opdata.offset), //
                                            32
                                        )
                                    )
                                ),
                                UINT8_MASK
                            )
                            mstore(0x0, tokenIn)
                            mstore8(0x0, lenderId)
                            mstore(0x20, COLLATERAL_TOKENS_SLOT)
                            let collateralToken := sload(keccak256(0x0, 0x40))
                            // selector for balanceOf(address)
                            mstore(0x0, 0x70a0823100000000000000000000000000000000000000000000000000000000)
                            // add caller address as parameter
                            mstore(add(0x0, 0x4), caller())
                            // call to collateralToken
                            pop(staticcall(gas(), collateralToken, 0x0, 0x24, 0x0, 0x20))
                            // load the retrieved balance
                            amountIn := mload(0x0)
                        }
                        currentOffset := add(currentOffset, calldataLength)
                    }
                    flashSwapExactInInternal(amountIn, minimumAmountOut, opdata);
                }
            } else {
                if (operation == Commands.DEPOSIT) {
                    address underlying;
                    address receiver;
                    uint256 amount;
                    uint256 lenderId;
                    assembly {
                        underlying := and(ADDRESS_MASK, shr(96, calldataload(currentOffset)))
                        receiver := and(ADDRESS_MASK, shr(96, calldataload(add(currentOffset, 20))))
                        let lastBytes := calldataload(add(currentOffset, 40))
                        amount := and(_UINT112_MASK, shr(136, lastBytes))
                        lenderId := and(UINT8_MASK, shr(248, lastBytes))
                        if iszero(amount) {
                            // selector for balanceOf(address)
                            mstore(0, 0x70a0823100000000000000000000000000000000000000000000000000000000)
                            // add this address as parameter
                            mstore(0x04, address())
                            // call to token
                            pop(
                                staticcall(
                                    gas(),
                                    underlying, // token
                                    0x0,
                                    0x24,
                                    0x0,
                                    0x20
                                )
                            )
                            // load the retrieved balance
                            amount := mload(0x0)
                        }
                        currentOffset := add(currentOffset, 73)
                    }
                    _deposit(underlying, receiver, amount, lenderId);
                } else if (operation == Commands.BORROW) {
                    address underlying;
                    address receiver;
                    address user;
                    uint256 amount;
                    uint256 lenderId;
                    uint256 mode;
                    assembly {
                        underlying := and(ADDRESS_MASK, shr(96, calldataload(currentOffset)))
                        receiver := and(ADDRESS_MASK, shr(96, calldataload(add(currentOffset, 20))))
                        let lastBytes := calldataload(add(currentOffset, 40))
                        amount := and(_UINT112_MASK, shr(128, lastBytes))
                        lenderId := and(UINT8_MASK, shr(248, lastBytes))
                        mode := and(UINT8_MASK, shr(240, lastBytes))
                        user := caller()
                        currentOffset := add(currentOffset, 57)
                    }
                    // borrow(opdata);
                    _borrow(underlying, user, amount, mode, lenderId);
                    if (receiver != address(this)) {
                        _transferERC20Tokens(underlying, receiver, amount);
                    }
                } else if (operation == Commands.REPAY) {
                    address underlying;
                    address receiver;
                    uint256 amount;
                    uint256 lenderId;
                    uint256 mode;
                    assembly {
                        let offset := currentOffset
                        underlying := and(ADDRESS_MASK, shr(96, calldataload(offset)))
                        receiver := and(ADDRESS_MASK, shr(96, calldataload(add(offset, 20))))
                        let lastBytes := calldataload(add(offset, 40))
                        amount := and(_UINT112_MASK, shr(128, lastBytes))
                        lenderId := and(UINT8_MASK, shr(248, lastBytes))
                        mode := and(UINT8_MASK, shr(240, lastBytes))
                        currentOffset := add(currentOffset, 57)
                    }
                    _repay(underlying, receiver, amount, mode, lenderId);
                } else if (operation == Commands.WITHDRAW) {
                    address underlying;
                    address receiver;
                    uint256 amount;
                    address user;
                    uint256 lenderId;
                    assembly {
                        underlying := and(ADDRESS_MASK, shr(96, calldataload(currentOffset)))
                        receiver := and(ADDRESS_MASK, shr(96, calldataload(add(currentOffset, 20))))
                        let lastBytes := calldataload(add(currentOffset, 40))
                        amount := and(_UINT112_MASK, shr(136, lastBytes))
                        lenderId := and(UINT8_MASK, shr(248, lastBytes))
                        user := caller()
                        if iszero(amount) {
                            // selector for balanceOf(address)
                            mstore(0, 0x70a0823100000000000000000000000000000000000000000000000000000000)
                            // add this address as parameter
                            mstore(0x04, address())
                            // call to token
                            pop(
                                staticcall(
                                    gas(),
                                    underlying, // token
                                    0x0,
                                    0x24,
                                    0x0,
                                    0x20
                                )
                            )
                            // load the retrieved balance
                            amount := mload(0x0)
                        }
                        currentOffset := add(currentOffset, 56)
                    }

                    _preWithdraw(underlying, user, amount, lenderId);
                    _withdraw(underlying, receiver, amount, lenderId);
                } else if (operation == Commands.TRANSFER_FROM) {
                    // bytes calldata opdata;
                    address owner;
                    address underlying;
                    address receiver;
                    uint256 amount;
                    assembly {
                        owner := caller()
                        underlying := and(ADDRESS_MASK, shr(96, calldataload(currentOffset)))
                        receiver := and(ADDRESS_MASK, shr(96, calldataload(add(currentOffset, 20))))
                        amount := and(_UINT112_MASK, calldataload(add(currentOffset, 22)))
                        currentOffset := add(currentOffset, 54)
                    }
                    _transferERC20TokensFrom(underlying, owner, receiver, amount);
                } else if (operation == Commands.SWEEP) {
                    // bytes calldata opdata;
                    address owner;
                    address underlying;
                    address receiver;
                    uint256 amount;
                    assembly {
                        owner := caller()
                        underlying := and(ADDRESS_MASK, shr(96, calldataload(currentOffset)))
                        receiver := and(ADDRESS_MASK, shr(96, calldataload(add(currentOffset, 20))))
                        amount := calldataload(add(currentOffset, 40))
                        currentOffset := add(currentOffset, 72)
                    }
                    _transferERC20Tokens(underlying, receiver, amount);
                } else revert();
            }
            // break criteria
            if (currentOffset >= maxIndex) break;
        }
    }
}
