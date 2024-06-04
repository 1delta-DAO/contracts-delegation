// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.26;

import {DeltaFlashAggregatorMantle} from "./FlashAggregator.sol";
import {RawTokenTransfer} from "./composable/TokenTransfer.sol";
import {Commands} from "./composable/Commands.sol";

contract Composer is DeltaFlashAggregatorMantle, RawTokenTransfer {
    bytes1 private constant ZERO = 0x0;

    uint256 internal constant _PAY_SELF = 1 << 255;
    uint256 internal constant _USE_BALANCE = 1 << 254;
    uint256 private constant UPPER_120_MASK = 0x00ffffffffffffffffffffffffffffff00000000000000000000000000000000;

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

        bytes calldata opdata;
        // execute ops
        while (true) {
            bytes32 word;
            // fetch op metadata
            assembly {
                word := calldataload(add(data.offset, currentOffsetIncrement))
                calldatalength := and(shr(232, word), UINT16_MASK)
                operation := and(shr(248, word), UINT8_MASK)
                currentOffsetIncrement := add(3, currentOffsetIncrement)
                opdata.offset := add(data.offset, currentOffsetIncrement)
                opdata.length := calldatalength
            }
            if (operation < 0x10) {
                // exec op
                if (operation == Commands.SWAP_EXACT_IN) {
                    uint256 amountIn;
                    address payer;
                    address receiver;
                    uint256 minimumAmountOut;
                    assembly {
                        amountIn := calldataload(currentOffsetIncrement)
                        minimumAmountOut := shr(128, and(amountIn, UPPER_120_MASK))
                        switch and(_PAY_SELF, amountIn)
                        case 1 {
                            payer := address()
                        }
                        default {
                            payer := caller()
                        }
                        opdata.offset := add(32, currentOffsetIncrement)
                        if and(_USE_BALANCE, amountIn) {
                            // selector for balanceOf(address)
                            mstore(0, 0x70a0823100000000000000000000000000000000000000000000000000000000)
                            // add this address as parameter
                            mstore(0x04, payer)
                            // call to token
                            pop(
                                staticcall(
                                    gas(),
                                    calldataload(and(ADDRESS_MASK, currentOffsetIncrement)),
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
                    uint256 amountOut;
                    address payer;
                    address receiver;
                    uint256 amountInMaximum;
                    assembly {
                        currentOffsetIncrement := add(currentOffsetIncrement, 3)
                        amountOut := calldataload(currentOffsetIncrement)
                        amountInMaximum := shr(128, and(amountOut, UPPER_120_MASK))
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
                } else if (operation == 3) {
                    address underlying;
                    address receiver;
                    uint256 amount;
                    uint256 lenderId;
                    assembly {
                        underlying := and(ADDRESS_MASK, shr(96, calldataload(opdata.offset)))
                        receiver := and(ADDRESS_MASK, shr(96, calldataload(add(opdata.offset, 20))))
                        let lastBytes := calldataload(add(opdata.offset, 40))
                        amount := and(UINT128_MASK, lastBytes)
                        lenderId := and(UINT8_MASK, shr(8, lastBytes))
                    }
                    _deposit(underlying, receiver, amount, lenderId);
                }
            } else {
                if (operation == 0x11) borrow(opdata);
                else if (operation == 0x122) withdraw(opdata);
                else if (operation == 0x13) repay(opdata);
                else if (operation == 0x12) {
                    _transferERC20TokensFromInternal(opdata);
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

    ////////////////////////////////////////////////////
    // Lending
    ////////////////////////////////////////////////////

    function depo(bytes calldata data) internal {
        _deposit(address(bytes20(data)), address(bytes20(data[20:40])), uint(bytes32(data[20:52])), 0);
    }

    function borrow(bytes calldata data) internal {
        _borrow(address(bytes20(data)), address(bytes20(data[20:40])), uint(bytes32(data[20:52])), 1, 0);
    }

    function withdraw(bytes calldata data) internal {
        _withdraw(address(bytes20(data)), address(bytes20(data[20:40])), uint(bytes32(data[20:52])), 0);
    }

    function repay(bytes calldata data) internal {
        _repay(address(bytes20(data)), address(bytes20(data[20:40])), uint(bytes32(data[20:52])), 1, 0);
    }
}
