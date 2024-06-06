// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.26;

import {DeltaFlashAggregatorMantle} from "./FlashAggregator.sol";
import {RawTokenTransfer} from "./composable/TokenTransfer.sol";
import {Commands} from "./composable/Commands.sol";

contract Composer is DeltaFlashAggregatorMantle, RawTokenTransfer {
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
        uint256 calldatalength;
        uint256 currentOffsetIncrement;
        uint256 operation;

        // execute ops
        while (true) {
            // fetch op metadata
            assembly {
                let word := calldataload(add(data.offset, currentOffsetIncrement))
                calldatalength := and(shr(232, word), UINT16_MASK)
                operation := and(shr(248, word), UINT8_MASK)
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
                        currentOffsetIncrement := add(3, currentOffsetIncrement)
                        opdata.offset := add(data.offset, currentOffsetIncrement)
                        opdata.length := calldatalength
                        amountIn := calldataload(opdata.offset)
                        minimumAmountOut := and(shr(128, amountIn), _UPPER_120_MASK)
                        receiver := and(ADDRESS_MASK, shr(96, calldataload(add(opdata.offset, 32))))
                        switch and(_PAY_SELF, amountIn)
                        case 1 {
                            payer := address()
                        }
                        default {
                            payer := caller()
                        }
                        opdata.offset := add(52, opdata.offset)
                        if iszero(amountIn) {
                            // selector for balanceOf(address)
                            mstore(0, 0x70a0823100000000000000000000000000000000000000000000000000000000)
                            // add this address as parameter
                            mstore(0x04, payer)
                            // call to token
                            pop(
                                staticcall(
                                    gas(),
                                    calldataload(and(ADDRESS_MASK, add(opdata.offset, 32))),
                                    0x0,
                                    0x24,
                                    0x0,
                                    0x20 //
                                )
                            )
                            // load the retrieved balance
                            amountIn := mload(0x0)
                        }
                    }
                    amountIn = uint128(amountIn);

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
                        currentOffsetIncrement := add(currentOffsetIncrement, 3)
                        amountOut := calldataload(currentOffsetIncrement)
                        amountInMaximum := shr(128, and(amountOut, _UPPER_120_MASK))
                        switch and(_PAY_SELF, amountOut)
                        case 1 {
                            payer := address()
                        }
                        default {
                            payer := caller()
                        }
                        opdata.offset := add(32, currentOffsetIncrement)
                        if and(_USE_BALANCE, amountOut) {
                            // selector for balanceOf(address)
                            mstore(0, 0x70a0823100000000000000000000000000000000000000000000000000000000)
                            // add this address as parameter
                            mstore(0x04, payer)
                            // call to token
                            pop(
                                staticcall(
                                    gas(),
                                    calldataload(and(ADDRESS_MASK, currentOffsetIncrement)), // token
                                    0x0,
                                    0x24,
                                    0x0,
                                    0x20
                                )
                            )
                            // load the retrieved balance
                            amountOut := mload(0x0)
                        }
                    }
                    flashSwapExactOutInternal(amountOut, amountInMaximum, msg.sender, receiver, opdata);
                }
            } else {
                if (operation == 0x13) {
                    address underlying;
                    address receiver;
                    uint256 amount;
                    uint256 lenderId;
                    assembly {
                        currentOffsetIncrement := add(3, currentOffsetIncrement)
                        let offset := add(data.offset, currentOffsetIncrement)
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
                    }
                    _deposit(underlying, receiver, amount, lenderId);
                } else if (operation == 0x11) {
                    address underlying;
                    address receiver;
                    address user;
                    uint256 amount;
                    uint256 lenderId;
                    uint256 mode;
                    assembly {
                        currentOffsetIncrement := add(3, currentOffsetIncrement)
                        let offset := add(data.offset, currentOffsetIncrement)
                        underlying := and(ADDRESS_MASK, shr(96, calldataload(offset)))
                        receiver := and(ADDRESS_MASK, shr(96, calldataload(add(offset, 20))))
                        let lastBytes := calldataload(add(offset, 40))
                        amount := and(_UINT112_MASK, shr(128, lastBytes))
                        lenderId := and(UINT8_MASK, shr(248, lastBytes))
                        mode := and(UINT8_MASK, shr(240, lastBytes))
                        user := caller()
                        calldatalength := 56
                    }
                    // borrow(opdata);
                    _borrow(underlying, user, amount, mode, lenderId);
                    if (receiver != address(this)) {
                        _transferERC20Tokens(underlying, receiver, amount);
                    }
                } else if (operation == 0x18) {
                    address underlying;
                    address receiver;
                    uint256 amount;
                    uint256 lenderId;
                    uint256 mode;
                    assembly {
                        currentOffsetIncrement := add(3, currentOffsetIncrement)
                        let offset := add(data.offset, currentOffsetIncrement)
                        underlying := and(ADDRESS_MASK, shr(96, calldataload(offset)))
                        receiver := and(ADDRESS_MASK, shr(96, calldataload(add(offset, 20))))
                        let lastBytes := calldataload(add(offset, 40))
                        amount := and(_UINT112_MASK, shr(128, lastBytes))
                        lenderId := and(UINT8_MASK, shr(248, lastBytes))
                        mode := and(UINT8_MASK, shr(240, lastBytes))
                        // calldatalength := 72
                    }
                    // borrow(opdata);
                    _repay(underlying, receiver, amount, mode, lenderId);
                } else if (operation == 0x17) {
                    address underlying;
                    address receiver;
                    uint256 amount;
                    address user;
                    uint256 lenderId;
                    assembly {
                        currentOffsetIncrement := add(3, currentOffsetIncrement)
                        let offset := add(data.offset, currentOffsetIncrement)
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
                    }
                    _preWithdraw(underlying, user, amount, lenderId);
                    _withdraw(underlying, receiver, amount, lenderId);
                } else if (operation == 0x15) {
                    // bytes calldata opdata;
                    address owner;
                    address underlying;
                    address receiver;
                    uint256 amount;
                    assembly {
                        currentOffsetIncrement := add(3, currentOffsetIncrement)
                        let offset := add(data.offset, currentOffsetIncrement)
                        calldatalength := 72
                        // opdata.length := calldatalength
                        owner := caller()
                        underlying := and(ADDRESS_MASK, shr(96, calldataload(offset)))
                        receiver := and(ADDRESS_MASK, shr(96, calldataload(add(offset, 20))))
                        amount := calldataload(add(offset, 40))
                    }
                    _transferERC20TokensFrom(underlying, owner, receiver, amount);
                } else revert();
            }
            // update op offset
            assembly {
                // length plus uint16 plus bytes1
                currentOffsetIncrement := add(calldatalength, currentOffsetIncrement)
            }
            // break criteria
            if (currentOffsetIncrement >= data.length) break;
        }
    }
}
