// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.26;

import {MarginTrading} from "./MarginTrading.sol";
import {Commands} from "./composable/Commands.sol";
import {PermitUtils} from "./permit/PermitUtils.sol";

/**
 * @title Flash aggregator contract.
 *        Allows spot and margin swap aggregation
 *        Efficient baching through compact calldata usage.
 *        Single route swap functions exposed to allower lower gas const for L1s
 * @author 1delta Labs
 */
contract Composer is MarginTrading, PermitUtils {
    /// @dev the highest bit signals whether the swap is internal (the payer is this contract)
    uint256 private constant _PAY_SELF = 1 << 255;
    /// @dev the second bit signals whether  the input token is a FOT token
    uint256 private constant _FEE_ON_TRANSFER = 1 << 254;
    /// @dev we use uint112-encoded ammounts to typically fit one bit flag, one path length (uint16)
    ///      ad 2 amounts (2xuint112) into 32bytes, as such we use this mask for extractinng those
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
        // `currentOffset` represents the current byte at which we
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
                // data.offset := currentOffset
            }
            if (operation < 0x10) {
                // exec op
                if (operation == Commands.SWAP_EXACT_IN) {
                    ////////////////////////////////////////////////////
                    // Encoded parameters for the swap
                    // | receiver | amount | pathLength | path |
                    // | address  | uint240|   uint16   | bytes|
                    // where amount is provided as
                    // pay self         (bool)      in the upper bit if true, payer is this contract
                    // fot              (bool)      2nd bit, if true, assume fee-on-transfer as input
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
                    bool noFOT;
                    assembly {
                        // the path starts after the path length
                        opdata.offset := add(currentOffset, 52) // 20 + 32 (address + amountBitmap)
                        // the first 20 bytes are the receiver address
                        receiver := and(ADDRESS_MASK, shr(96, calldataload(currentOffset)))
                        // assign the entire 32 bytes of amounts data
                        amountIn := calldataload(add(currentOffset, 20))
                        // this is the path data length
                        let calldataLength := and(amountIn, UINT16_MASK)
                        opdata.length := calldataLength
                        // add the length to 52 (=32+20)
                        calldataLength := add(52, calldataLength)
                        // validation amount starts at bit 128 from the right
                        minimumAmountOut := and(_UINT112_MASK, shr(128, amountIn))
                        // check whether the swap is internal by the highest bit
                        switch iszero(and(_PAY_SELF, amountIn))
                        case 0 {
                            payer := address()
                        }
                        default {
                            payer := caller()
                        }
                        noFOT := iszero(and(_FEE_ON_TRANSFER, amountIn))
                        // mask input amount
                        amountIn := and(_UINT112_MASK, shr(16, amountIn))
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
                    // swap execution
                    if (noFOT) amountIn = swapExactIn(amountIn, dexId, payer, receiver, opdata);
                    else amountIn = swapExactInFOT(amountIn, dexId, receiver, opdata);

                    // slippage check
                    assembly {
                        if lt(amountIn, minimumAmountOut) {
                            mstore(0, SLIPPAGE)
                            revert(0, 0x4)
                        }
                    }
                } else if (operation == Commands.SWAP_EXACT_OUT) {
                    ////////////////////////////////////////////////////
                    // Always uses a flash swap when possible
                    // Encoded parameters for the swap
                    // | receiver | amount  | pathLength | path |
                    // | address  | uint240 | uint16     | bytes|
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
                        opdata.offset := add(currentOffset, 52) // 20 + 32 (address + amountBitmap)
                        receiver := and(ADDRESS_MASK, shr(96, calldataload(currentOffset)))
                        // get the number parameters
                        amountOut := calldataload(add(currentOffset, 20))
                        // we get the calldatalength of the path
                        let calldataLength := and(amountOut, UINT16_MASK)
                        opdata.length := calldataLength
                        // we increment the calldatalength
                        calldataLength := add(52, calldataLength)
                        // validation amount starts at bit 128 from the right
                        amountInMaximum := add(_UINT112_MASK, shr(128, amountOut))
                        // check the upper bit as to whether it is a internal swap
                        switch iszero(and(_PAY_SELF, amountOut))
                        case 0 {
                            payer := address()
                        }
                        default {
                            payer := caller()
                        }
                        // rigth shigt by pathlength size and masking yields
                        // the final amout out
                        amountOut := and(_UINT112_MASK, shr(16, amountOut))
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
                    swapExactOutInternal(amountOut, amountInMaximum, payer, receiver, opdata);
                } else if (operation == Commands.FLASH_SWAP_EXACT_IN) {
                    ////////////////////////////////////////////////////
                    // Encoded parameters for the swap
                    // | amount | pathLength | path |
                    // | uint240|  uint16    | bytes|
                    // where amount is provided as
                    // pay self         (bool)      in the upper bit
                    //                              if true, payer is this contract
                    //                              the following bits are empty
                    // minimumAmountOut (uint112)   in the bytes starting at bit 128
                    //                              from the right
                    // amountIn         (uint112)   in the lowest bytes
                    //                              zero is for paying with the balance of
                    //                              payer (self or caller)
                    ////////////////////////////////////////////////////
                    bytes calldata opdata;
                    uint256 amountIn;
                    address payer;
                    uint256 minimumAmountOut;
                    // all but balance fetch same as for SWAP_EXACT_IN
                    assembly {
                        // the path starts after the path length
                        opdata.offset := add(currentOffset, 32) // 32
                        // lastparam includes receiver address and pathlength
                        let firstParam := calldataload(currentOffset)
                        // this is the path data length
                        // included in lowest 2 bytes
                        let calldataLength := and(firstParam, UINT16_MASK)
                        opdata.length := calldataLength
                        // add the length to 32
                        calldataLength := add(32, calldataLength)
                        // extract lowr 112 bits shifted by 16
                        minimumAmountOut := and(_UINT112_MASK, shr(128, firstParam))

                        // upper but signals whether to pay with full balance
                        switch iszero(and(_PAY_SELF, firstParam))
                        case 0 {
                            payer := address()
                        }
                        default {
                            payer := caller()
                        }
                        // mask input amount
                        amountIn := and(_UINT112_MASK, shr(16, firstParam))
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
                    flashSwapExactInInternal(amountIn, minimumAmountOut, payer, opdata);
                } else if (operation == Commands.FLASH_SWAP_EXACT_OUT) {
                    ////////////////////////////////////////////////////
                    // Always uses a flash swap when possible
                    // Encoded parameters for the swap
                    // | amount | pathLength | path |
                    // | uint240|  uint16    | bytes|
                    // where amount is provided as
                    // pay self         (bool)      in the upper bit
                    //                              if true, payer is this contract
                    //                              The ext 7 bits are empty
                    // maximumAmountIn  (uint112)   in the bytes starting at bit 128
                    //                              from the right
                    // amountOut        (uint112)   in the lowest bytes
                    //                              zero is for paying with the balance of
                    //                              payer (self or caller)
                    ////////////////////////////////////////////////////
                    bytes calldata opdata;
                    uint256 amountOut;
                    address payer;
                    uint256 amountInMaximum;
                    assembly {
                        opdata.offset := add(currentOffset, 32) // 32
                        let firstParam := calldataload(currentOffset)

                        // we get the calldatalength of the path
                        // these are populated in the lower two bytes
                        let calldataLength := and(firstParam, UINT16_MASK)
                        opdata.length := calldataLength
                        calldataLength := add(32, calldataLength)
                        // check amount strats at bit 128 from the right (within first 32 )
                        amountInMaximum := and(shr(128, firstParam), _UINT112_MASK)
                        // check highest bit
                        switch iszero(and(_PAY_SELF, firstParam))
                        case 0 {
                            payer := address()
                        }
                        default {
                            payer := caller()
                        }
                        amountOut := and(_UINT112_MASK, shr(16, firstParam))
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
                    flashSwapExactOutInternal(amountOut, amountInMaximum, payer, opdata);
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
                        currentOffset := add(currentOffset, 55)
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
                        currentOffset := add(currentOffset, 56)
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
                        currentOffset := add(currentOffset, 56)
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
                        currentOffset := add(currentOffset, 55)
                    }

                    _preWithdraw(underlying, user, amount, lenderId);
                    _withdraw(underlying, receiver, amount, lenderId);
                } else if (operation == Commands.TRANSFER_FROM) {
                    ////////////////////////////////////////////////////
                    // Transfers tokens froom caller to this address
                    // zero amount flags that the entire balance is sent
                    ////////////////////////////////////////////////////
                    assembly {
                        let owner := caller()
                        let underlying := and(ADDRESS_MASK, shr(96, calldataload(currentOffset)))
                        let receiver := and(ADDRESS_MASK, shr(96, calldataload(add(currentOffset, 20))))
                        let amount := and(_UINT112_MASK, calldataload(add(currentOffset, 22)))
                        // when entering 0 as amount, use the callwe balance
                        if iszero(amount) {
                            // selector for balanceOf(address)
                            mstore(0, 0x70a0823100000000000000000000000000000000000000000000000000000000)
                            // add this address as parameter
                            mstore(0x04, owner)
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
                        let ptr := mload(0x40) // free memory pointer

                        // selector for transferFrom(address,address,uint256)
                        mstore(ptr, 0x23b872dd00000000000000000000000000000000000000000000000000000000)
                        mstore(add(ptr, 0x04), owner)
                        mstore(add(ptr, 0x24), receiver)
                        mstore(add(ptr, 0x44), amount)

                        let success := call(gas(), underlying, 0, ptr, 0x64, ptr, 32)

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
                        currentOffset := add(currentOffset, 54)
                    }
                } else if (operation == Commands.SWEEP) {
                    ////////////////////////////////////////////////////
                    // Transfers either token or native balance from this
                    // contract to receiver. Reverts if minAmount is
                    // less than the contract balance
                    // native asset is flagge via address(0) as parameter
                    ////////////////////////////////////////////////////
                    assembly {
                        let underlying := and(ADDRESS_MASK, shr(96, calldataload(currentOffset)))
                        let receiver := and(ADDRESS_MASK, shr(96, calldataload(add(currentOffset, 20))))

                        let amountMin := and(_UINT112_MASK, calldataload(add(currentOffset, 22)))

                        switch iszero(underlying)
                        ////////////////////////////////////////////////////
                        // Transfer token
                        ////////////////////////////////////////////////////
                        case 0 {
                            // selector for balanceOf(address)
                            mstore(0, 0x70a0823100000000000000000000000000000000000000000000000000000000)
                            // add this address as parameter
                            mstore(0x04, address())
                            // call to token
                            pop(
                                staticcall(
                                    gas(),
                                    underlying,
                                    0x0,
                                    0x24,
                                    0x0,
                                    0x20 //
                                )
                            )
                            // load the retrieved balance
                            let tokenBalance := mload(0x0)
                            // revert if balance is not enough
                            if lt(tokenBalance, amountMin) {
                                mstore(0, SLIPPAGE)
                                revert(0, 0x4)
                            }
                            let ptr := mload(0x40) // free memory pointer

                            // selector for transfer(address,uint256)
                            mstore(ptr, 0xa9059cbb00000000000000000000000000000000000000000000000000000000)
                            mstore(add(ptr, 0x04), receiver)
                            mstore(add(ptr, 0x24), tokenBalance)

                            let success := call(gas(), underlying, 0, ptr, 0x44, ptr, 32)

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
                        ////////////////////////////////////////////////////
                        // Transfer native
                        ////////////////////////////////////////////////////
                        default {
                            let nativeBalance := selfbalance()
                            // revert if balance is not enough
                            if lt(nativeBalance, amountMin) {
                                mstore(0, SLIPPAGE)
                                revert(0, 0x4)
                            }

                            if iszero(
                                call(
                                    gas(),
                                    receiver,
                                    nativeBalance,
                                    0x0, // input = empty for fallback
                                    0x0, // input size = zero
                                    0x0, // output = empty
                                    0x0 // output size = zero
                                )
                            ) {
                                revert(0, 0) // revert when native transfer fails
                            }
                        }
                        currentOffset := add(currentOffset, 72)
                    }
                } else if (operation == Commands.WRAP_NATIVE) {
                    ////////////////////////////////////////////////////
                    // Wrap native, only uses amount as uint112
                    ////////////////////////////////////////////////////
                    assembly {
                        let amount := and(_UINT112_MASK, shr(144, calldataload(currentOffset)))
                        if iszero(
                            call(
                                gas(),
                                WRAPPED_NATIVE,
                                amount, // ETH to deposit
                                0x0, // no input
                                0x0, // input size = zero
                                0x0, // output = empty
                                0x0 // output size = zero
                            )
                        ) {
                            // revert when native transfer fails
                            mstore(0, WRAP)
                            revert(0, 0x4)
                        }
                        currentOffset := add(currentOffset, 14)
                    }
                } else if (operation == Commands.UNWRAP_WNATIVE) {
                    ////////////////////////////////////////////////////
                    // Transfers either token or native balance from this
                    // contract to receiver. Reverts if minAmount is
                    // less than the contract balance
                    // native asset is flagge via address(0) as parameter
                    ////////////////////////////////////////////////////
                    assembly {
                        let receiver := and(ADDRESS_MASK, shr(96, calldataload(currentOffset)))
                        let amount := and(_UINT112_MASK, shr(144, calldataload(add(currentOffset, 20))))
                        // selector for balanceOf(address)
                        mstore(0x0, 0x70a0823100000000000000000000000000000000000000000000000000000000)
                        // add this address as parameter
                        mstore(0x4, address())

                        // call to underlying
                        pop(staticcall(gas(), WRAPPED_NATIVE, 0x0, 0x24, 0x0, 0x20))

                        let thisBalance := mload(0x0)
                        if lt(thisBalance, amount) {
                            mstore(0, SLIPPAGE)
                            revert(0, 0x4)
                        }

                        // selector for withdraw(uint256)
                        mstore(0x0, 0x2e1a7d4d00000000000000000000000000000000000000000000000000000000)
                        mstore(0x4, thisBalance)
                        // should not fail since WRAPPED_NATIVE is immutable
                        pop(
                            call(
                                gas(),
                                WRAPPED_NATIVE,
                                0x0, // no ETH
                                0x0, // start of data
                                0x24, // input size = zero
                                0x0, // output = empty
                                0x0 // output size = zero
                            )
                        )

                        // transfer native to receiver
                        if iszero(
                            call(
                                gas(),
                                receiver,
                                thisBalance,
                                0x0, // input = empty for fallback
                                0x0, // input size = zero
                                0x0, // output = empty
                                0x0 // output size = zero
                            )
                        ) {
                            // should only revert if receiver cannot receive native
                            mstore(0, NATIVE_TRANSFER)
                            revert(0, 0x4)
                        }
                        currentOffset := add(currentOffset, 34)
                    }
                } else if (operation == Commands.EXEC_PERMIT) {
                    ////////////////////////////////////////////////////
                    // Execute normal transfer permit (Dai, ERC20Permit, P2).
                    // The specific permit type is executed based 
                    // on the permit length (credits to 1inch for the implementation)
                    // Data layout:
                    //      bytes 0-20:                  token
                    //      bytes 20-22:                 permit length
                    //      bytes 22-(22+permit length): permit data 
                    ////////////////////////////////////////////////////
                    bytes calldata permitData;
                    address token;
                    assembly {
                        token := calldataload(currentOffset)
                        let permitLength := and(UINT16_MASK, shr(80, token))
                        token := and(ADDRESS_MASK, shr(96, token))
                        permitData.offset := add(currentOffset, 22)
                        permitData.length := permitLength
                        permitLength := add(22, permitLength)
                        currentOffset := add(currentOffset, permitLength)
                    }
                    _tryPermit(token, permitData);
                } else revert();
            }
            // break criteria - we shifted to the end of the calldata
            if (currentOffset >= maxIndex) break;
        }
    }
}
