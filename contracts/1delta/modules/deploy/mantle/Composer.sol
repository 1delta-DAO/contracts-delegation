// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.26;

import {DeltaFlashAggregatorMantle} from "./FlashAggregator.sol";
import {Commands} from "./composable/Commands.sol";

contract Composer is DeltaFlashAggregatorMantle {
    bytes1 private constant ZERO = 0x0;

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
        // data encding paramters
        uint256 calldataLength;
        uint256 currentOffset;
        uint256 currentOffsetIncrement;
        assembly {
            currentOffset := data.offset
        }

        // execute ops
        while (true) {
            uint256 operation;
            // fetch op metadata
            assembly {
                operation := and(shr(248, calldataload(currentOffset)), UINT8_MASK)
                currentOffset := add(1, currentOffset)
            }
            if (operation < 0x10) {
                // exec op
                if (operation == Commands.SWAP_EXACT_IN) {
                    bytes calldata opdata;
                    uint256 amountIn;
                    address payer;
                    address receiver;
                    uint256 minimumAmountOut;
                    assembly {
                        opdata.offset := add(currentOffset, 54) // 32 +20 + 2
                        let lastparam := calldataload(add(currentOffset, 32))
                        receiver := and(ADDRESS_MASK, shr(96, lastparam))
                        calldataLength := and(shr(80, lastparam), UINT16_MASK)
                        opdata.length := and(calldataLength, UINT16_MASK)
                        calldataLength := add(54, calldataLength)
                        amountIn := calldataload(currentOffset)
                        minimumAmountOut := shr(128, and(amountIn, _UPPER_120_MASK))
                        switch and(_PAY_SELF, amountIn)
                        case 1 {
                            payer := address()
                        }
                        default {
                            payer := caller()
                        }
                        amountIn := and(UINT128_MASK, amountIn)
                        if iszero(amountIn) {
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
                            amountIn := mload(0x0)
                        }
                        currentOffset := add(currentOffset, calldataLength)
                        calldataLength := add(calldataLength, 52)
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
                    bytes calldata opdata;
                    uint256 amountOut;
                    address payer;
                    address receiver;
                    uint256 amountInMaximum;
                    assembly {
                        opdata.offset := add(currentOffset, 54) // 32 +20 + 2
                        let lastparam := calldataload(add(currentOffset, 32))
                        receiver := and(ADDRESS_MASK, shr(96, lastparam))
                        calldataLength := and(shr(80, lastparam), UINT16_MASK)
                        opdata.length := and(calldataLength, UINT16_MASK)
                        calldataLength := add(54, calldataLength)
                        amountOut := calldataload(currentOffset)
                        amountInMaximum := shr(128, and(amountOut, _UPPER_120_MASK))
                        switch and(_PAY_SELF, amountOut)
                        case 1 {
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
                        calldataLength := add(calldataLength, 52)
                    }
                    flashSwapExactOutInternal(amountOut, amountInMaximum, payer, receiver, opdata);
                }
            } else {
                if (operation == Commands.DEPOSIT) {
                    address underlying;
                    address receiver;
                    uint256 amount;
                    uint256 lenderId;
                    assembly {
                        let offset := currentOffset
                        underlying := and(ADDRESS_MASK, shr(96, calldataload(offset)))
                        receiver := and(ADDRESS_MASK, shr(96, calldataload(add(offset, 20))))
                        let lastBytes := calldataload(add(offset, 40))
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
                        calldataLength := 57
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
                        let offset := currentOffset
                        underlying := and(ADDRESS_MASK, shr(96, calldataload(offset)))
                        receiver := and(ADDRESS_MASK, shr(96, calldataload(add(offset, 20))))
                        let lastBytes := calldataload(add(offset, 40))
                        amount := and(_UINT112_MASK, shr(128, lastBytes))
                        lenderId := and(UINT8_MASK, shr(248, lastBytes))
                        mode := and(UINT8_MASK, shr(240, lastBytes))
                        user := caller()
                        calldataLength := 57
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
                        let offset := currentOffset
                        underlying := and(ADDRESS_MASK, shr(96, calldataload(offset)))
                        receiver := and(ADDRESS_MASK, shr(96, calldataload(add(offset, 20))))
                        let lastBytes := calldataload(add(offset, 40))
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
                        calldataLength := 56
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
                        let offset := currentOffset // add(data.offset, currentOffsetIncrement)
                        calldataLength := 73
                        // opdata.length := calldatalength
                        owner := caller()
                        underlying := and(ADDRESS_MASK, shr(96, calldataload(offset)))
                        receiver := and(ADDRESS_MASK, shr(96, calldataload(add(offset, 20))))
                        amount := calldataload(add(offset, 40))
                        currentOffset := add(currentOffset, 72)
                    }
                    _transferERC20TokensFrom(underlying, owner, receiver, amount);
                } else if (operation == Commands.SWEEP) {
                    // bytes calldata opdata;
                    address owner;
                    address underlying;
                    address receiver;
                    uint256 amount;
                    assembly {
                        let offset := add(data.offset, currentOffsetIncrement)
                        calldataLength := 73
                        // opdata.length := calldatalength
                        owner := caller()
                        underlying := and(ADDRESS_MASK, shr(96, calldataload(offset)))
                        receiver := and(ADDRESS_MASK, shr(96, calldataload(add(offset, 20))))
                        amount := calldataload(add(offset, 40))
                    }
                    _transferERC20Tokens(underlying, receiver, amount);
                } else revert();
            }
            // update op offset
            assembly {
                // length plus uint16 plus bytes1
                currentOffsetIncrement := add(calldataLength, currentOffsetIncrement)
            }
            // break criteria
            if (currentOffsetIncrement >= data.length) break;
        }
    }
}
