// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.20;

import {IERC20} from "../../../interfaces/IERC20.sol";
import {IPool} from "../../interfaces/IAAVEV3Pool.sol";
import {WithStorage} from "../../storage/BrokerStorage.sol";
import {TokenTransfer} from "./../../libraries/TokenTransfer.sol";

contract AAVEFlashModule is WithStorage, TokenTransfer {
    IPool private immutable _aavePool;
    // trade categories
    // 0 = Margin open
    // 1 = margin close
    // 2 = collateral / open
    // 3 = debt / close

    // swapType
    // 0 = exactIn
    // 1 = exactOut

    // lendingInteraction
    // 0 = supply
    // 1 = borrow
    // 2 = withdraw
    // 3 = repay

    struct DeltaParams {
        address baseAsset; // the asset paired with the flash loan
        address target; // the swap target
        uint8 swapType; // exact in or out
        uint8 marginTradeType; // open, close, collateral, debt swap
        uint8 interestRateModeIn; // aave interest mode
        uint8 interestRateModeOut; // aave interest mode
        uint256 referenceAmount; // amountOut for exactOutSwaps
    }

    struct DeltaFlashParams {
        DeltaParams deltaParams;
        bytes encodedSwapCall;
        address user;
    }

    modifier onlyManagement() {
        require(ms().isManager[msg.sender], "Only management can interact.");
        _;
    }

    constructor(address _aave) {
        _aavePool = IPool(_aave);
    }

    /**
     * Excutes flash loan
     * @param asset the aset to draw the flash loan
     * @param amount the flash loan amount
     */
    function executeOnAave(
        address asset,
        uint256 amount,
        DeltaParams calldata deltaParams,
        bytes calldata swapCalldata
    ) external {
        _aavePool.flashLoanSimple(
            address(this),
            asset,
            amount,
            abi.encode(DeltaFlashParams({deltaParams: deltaParams, encodedSwapCall: swapCalldata, user: msg.sender})),
            0
        );
    }

    /**
     * @dev When `flashLoan` is called on the Vault, it invokes the `receiveFlashLoan` hook on the recipient.
     *
     *  We never expect more than one token to be flashed
     */
    function executeOperation(
        address asset,
        uint256 amount,
        uint256 premium,
        address initiator,
        bytes calldata params
    ) external returns (bool) {
        // validate callback
        require(initiator == address(this), "CANNOT_ENTER");

        IPool aavePool = _aavePool;

        require(msg.sender == address(aavePool), "POOL_NOT_CALLER");

        // fetch flash loan parameters
        address token = asset;
        uint256 amountReceived = amount;
        // decode delta parameters
        DeltaFlashParams memory flashParams = abi.decode(params, (DeltaFlashParams));

        address swapTarget = flashParams.deltaParams.target;
        uint256 marginType = flashParams.deltaParams.marginTradeType;
        address user = flashParams.user;

        // validate swap router
        require(gs().isValidTarget[swapTarget], "TARGET");

        // exact in swap
        // that amount is supposed to be swapped by the target to some output amount in asset baseAsset
        if (flashParams.deltaParams.swapType == 0) {
            //margin open [expected to flash borrow amount]
            if (marginType == 0) {
                // execute trnsaction on target
                (bool success, ) = swapTarget.call(flashParams.encodedSwapCall);
                require(success, "CALL_FAILED");

                address baseAsset = flashParams.deltaParams.baseAsset;
                uint256 amountSwapped = IERC20(baseAsset).balanceOf(address(this));

                // supply the received amount
                aavePool.supply(baseAsset, amountSwapped, user, 0);

                // adjust amount for flash loan fee
                amountReceived += premium;

                // borrow amounts plus fee and send them back to the pool
                aavePool.borrow(token, amountReceived, flashParams.deltaParams.interestRateModeIn, 0, user);
            }
            // margin close [expected to flash withdrawal amount]
            else if (marginType == 1) {
                // execute trnsaction on target
                (bool success, ) = swapTarget.call(flashParams.encodedSwapCall);
                require(success, "CALL_FAILED");

                address baseAsset = flashParams.deltaParams.baseAsset;
                uint256 amountSwapped = IERC20(baseAsset).balanceOf(address(this));

                // repay obtained amount
                aavePool.repay(baseAsset, amountSwapped, flashParams.deltaParams.interestRateModeOut, user);

                // adjust amount for flash loan fee
                amountReceived += premium;

                // transfer aTokens from user
                _transferERC20TokensFrom(aas().aTokens[token], user, address(this), amountReceived);

                // withdraw and send funds back to flash pool
                aavePool.withdraw(token, amountReceived, address(this));
            }
            //  colateral swap
            else if (marginType == 2) {
                // execute trnsaction on target
                (bool success, ) = swapTarget.call(flashParams.encodedSwapCall);
                require(success, "CALL_FAILED");

                address baseAsset = flashParams.deltaParams.baseAsset;
                uint256 amountSwapped = IERC20(baseAsset).balanceOf(address(this));

                // supply the received amount
                aavePool.supply(flashParams.deltaParams.baseAsset, amountSwapped, user, 0);

                // adjust amount for flash loan fee
                amountReceived += premium;

                // transfer aTokens from user
                _transferERC20TokensFrom(aas().aTokens[token], user, address(this), amountReceived);

                // withdraw and send funds back to flash pool
                aavePool.withdraw(token, amountReceived, address(this));
            }
            // debt swap
            else {
                // execute trnsaction on target
                (bool success, ) = swapTarget.call(flashParams.encodedSwapCall);
                require(success, "CALL_FAILED");

                address baseAsset = flashParams.deltaParams.baseAsset;
                uint256 amountSwapped = IERC20(baseAsset).balanceOf(address(this));

                // repay obtained amount
                aavePool.repay(flashParams.deltaParams.baseAsset, amountSwapped, flashParams.deltaParams.interestRateModeOut, user);

                // adjust amount for flash loan fee
                amountReceived += premium;

                // borrow amounts plus fee and send them back to the pool
                aavePool.borrow(token, amountReceived, flashParams.deltaParams.interestRateModeIn, 0, user);
            }
        }
        // exact out swap
        else {
            //margin open [expected to flash (optimistic) supply amount]
            if (marginType == 0) {
                // swap the flashed amount
                (bool success, ) = swapTarget.call(flashParams.encodedSwapCall);
                require(success, "CALL_FAILED");
                // decode amount received - this is the amountIn
                // it has to be assured that the flash amount is larger than this such that the
                // router can draw the funds, otherwise, the swap will fail

                uint256 amountSwapped = amountReceived - IERC20(token).balanceOf(address(this));

                // supply the amount out - willl fail if insufficiently swapped
                aavePool.supply(flashParams.deltaParams.baseAsset, flashParams.deltaParams.referenceAmount, user, 0);

                uint256 fee = premium;
                // borrow amount in plus flash loan fee
                amountSwapped += fee;
                aavePool.borrow(token, amountSwapped, flashParams.deltaParams.interestRateModeIn, 0, user);

                // repay flash loan
                amountReceived += fee;
            }
            // margin close [expected to flash withdrawal amount]
            // the repay amount consists of fee + swapAmount + residual
            else if (marginType == 1) {
                // swap the flashed amount exact out
                (bool success, ) = swapTarget.call(flashParams.encodedSwapCall);
                require(success, "CALL_FAILED");
                uint256 amountSwapped = amountReceived - IERC20(token).balanceOf(address(this));

                // repay the amount out - willl fail if insufficiently swapped
                aavePool.repay(
                    flashParams.deltaParams.baseAsset,
                    flashParams.deltaParams.referenceAmount,
                    flashParams.deltaParams.interestRateModeOut,
                    user
                );
                // adjust amount for fee
                uint256 fee = premium;
                amountSwapped += fee;
                // transfer aTokens from user - we only need the swap input amount plus flash loan fee
                _transferERC20TokensFrom(aas().aTokens[token], user, address(this), amountSwapped);
                // withdraw swap amount directly to flash pool
                aavePool.withdraw(token, amountSwapped, address(this));
            }
            //  colateral swap
            else if (marginType == 2) {
                // swap the flashed amount exact out
                (bool success, ) = swapTarget.call(flashParams.encodedSwapCall);
                require(success, "CALL_FAILED");
                // fetch amountIn
                uint256 amountSwapped = amountReceived - IERC20(token).balanceOf(address(this));

                // supply the amount out - willl fail if insufficiently swapped
                aavePool.supply(flashParams.deltaParams.baseAsset, flashParams.deltaParams.referenceAmount, user, 0);

                // adjust amount for fee
                uint256 fee = premium;
                amountSwapped += fee;
                // transfer aTokens from user - we only need the swap input amount plus flash loan fee
                _transferERC20TokensFrom(aas().aTokens[token], user, address(this), amountSwapped);
                // withdraw swap amount directly to flash pool
                aavePool.withdraw(token, amountSwapped, address(this));
            }
            // debt swap
            else {
                // swap the flashed amount exact out
                (bool success, ) = swapTarget.call(flashParams.encodedSwapCall);
                require(success, "CALL_FAILED");
                // fetch amountIn
                uint256 amountSwapped = amountReceived - IERC20(token).balanceOf(address(this));

                // repay the amount out - willl fail if insufficiently swapped
                aavePool.repay(
                    flashParams.deltaParams.baseAsset,
                    flashParams.deltaParams.referenceAmount,
                    flashParams.deltaParams.interestRateModeOut,
                    user
                );
                // adjust amount for fee
                amountSwapped += premium;
                // borrow amount in plus flash loan fee
                // repay flash loan with residual funds
                aavePool.borrow(token, amountSwapped, flashParams.deltaParams.interestRateModeIn, 0, user);
            }
        }

        return true;
    }
}
