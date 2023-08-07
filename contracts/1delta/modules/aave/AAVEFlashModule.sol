// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.21;

import {IERC20} from "../../../interfaces/IERC20.sol";
import {IPool} from "../../interfaces/IAAVEV3Pool.sol";
import {WithStorage} from "../../storage/BrokerStorage.sol";
import {TokenTransfer} from "./../../libraries/TokenTransfer.sol";
import {IERC20Balance} from "../../interfaces/IERC20Balance.sol";

contract AAVEFlashModule is WithStorage, TokenTransfer {
    IPool private immutable _aavePool;
    // marginTradeType
    // 0 = Margin open
    // 1 = margin close
    // 2 = collateral / open
    // 3 = debt / close

    // swapType
    // 0 = exactIn
    // 1 = exactOut

    struct DeltaParams {
        address baseAsset; // the asset paired with the flash loan
        address target; // the swap target
        uint8 swapType; // exact in or out
        uint8 marginTradeType; // open, close, collateral, debt swap
        uint8 interestRateModeIn; // aave interest mode
        uint8 interestRateModeOut; // aave interest mode
        bool max; // a flag that indicates that either
        // 1) the entire balance is withdrawn (for exactIn); or
        // 2) the entire debt is repaid (for exactOut) - the referenceAmount must be larger than the debt
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
     * @dev When `flashLoanSimple` is called on the the Aave pool, it invokes the `executeOperation` hook on the recipient.
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
                // execute transaction on target
                (bool success, ) = swapTarget.call(flashParams.encodedSwapCall);
                require(success, "CALL_FAILED");

                address baseAsset = flashParams.deltaParams.baseAsset;
                uint256 amountSwapped = IERC20(baseAsset).balanceOf(address(this));

                // supply the received amount
                aavePool.supply(baseAsset, amountSwapped, user, 0);

                // adjust amount for flash loan fee
                amountReceived += premium;
                // in case the input of the swap was too low, we subtract the balance pre-borrow
                amountReceived -= IERC20(token).balanceOf(address(this));
                // borrow amounts plus fee and send them back to the pool
                aavePool.borrow(token, amountReceived, flashParams.deltaParams.interestRateModeIn, 0, user);
            }
            // margin close [expected to flash withdrawal amount]
            else if (marginType == 1) {
                // execute transaction on target
                (bool success, ) = swapTarget.call(flashParams.encodedSwapCall);
                require(success, "CALL_FAILED");

                address baseAsset = flashParams.deltaParams.baseAsset;
                uint256 amountSwapped = IERC20(baseAsset).balanceOf(address(this));

                // repay obtained amount
                aavePool.repay(baseAsset, amountSwapped, flashParams.deltaParams.interestRateModeOut, user);

                // adjust amount for flash loan fee
                amountReceived += premium;
                // if the input is lower than flash loan plus fee, we only withdraw the input
                // the balance itself represents flashLoanAmount - swapInputAmount
                amountReceived -= IERC20(token).balanceOf(address(this));

                baseAsset = aas().aTokens[token];
                if (flashParams.deltaParams.max) {
                    // fetch user balance
                    amountSwapped = IERC20(baseAsset).balanceOf(user);
                    // transfer aTokens from user
                    _transferERC20TokensFrom(baseAsset, user, address(this), amountSwapped);
                    // withdraw the entire user balance
                    aavePool.withdraw(token, amountSwapped, address(this));
                    // adjust funds for leftovers
                    amountReceived = amountSwapped - amountReceived;
                    // if funds are left, send them to the user
                    if (amountReceived != 0) _transferERC20Tokens(token, user, amountReceived);
                } else {
                    // transfer aTokens from user
                    _transferERC20TokensFrom(baseAsset, user, address(this), amountReceived);
                    // withdraw and send funds back to flash pool
                    aavePool.withdraw(token, amountReceived, address(this));
                }
            }
            //  collateral swap
            else if (marginType == 2) {
                // execute transaction on target
                (bool success, ) = swapTarget.call(flashParams.encodedSwapCall);
                require(success, "CALL_FAILED");

                address baseAsset = flashParams.deltaParams.baseAsset;
                uint256 amountSwapped = IERC20(baseAsset).balanceOf(address(this));

                // supply the received amount
                aavePool.supply(flashParams.deltaParams.baseAsset, amountSwapped, user, 0);

                // adjust amount for flash loan fee
                amountReceived += premium;
                // if the input is lower than flash loan plus fee, we only withdraw the input
                // the balance itself represents flashLoanAmount - swapInputAmount
                amountReceived -= IERC20(token).balanceOf(address(this));

                baseAsset = aas().aTokens[token];
                if (flashParams.deltaParams.max) {
                    // fetch user balance
                    amountSwapped = IERC20(baseAsset).balanceOf(user);
                    // transfer aTokens from user
                    _transferERC20TokensFrom(baseAsset, user, address(this), amountSwapped);
                    // withdraw the entire user balance
                    aavePool.withdraw(token, amountSwapped, address(this));
                    // adjust funds for leftovers
                    amountReceived = amountSwapped - amountReceived;
                    // if funds are left, send them to the user
                    if (amountReceived != 0) _transferERC20Tokens(token, user, amountReceived);
                } else {
                    // transfer aTokens from user
                    _transferERC20TokensFrom(baseAsset, user, address(this), amountReceived);
                    // withdraw and send funds back to flash pool
                    aavePool.withdraw(token, amountReceived, address(this));
                }
            }
            // debt swap
            else {
                // execute transaction on target
                (bool success, ) = swapTarget.call(flashParams.encodedSwapCall);
                require(success, "CALL_FAILED");

                address baseAsset = flashParams.deltaParams.baseAsset;
                uint256 amountSwapped = IERC20(baseAsset).balanceOf(address(this));

                // repay obtained amount
                aavePool.repay(baseAsset, amountSwapped, flashParams.deltaParams.interestRateModeOut, user);

                // adjust amount for flash loan fee
                amountReceived += premium;
                // in case the input of the swap was too low, we subtract the balance pre-borrow
                amountReceived -= IERC20(token).balanceOf(address(this));
                // borrow amounts plus fee and send them back to the pool
                aavePool.borrow(
                    token,
                    amountReceived, // borrow leftovers
                    flashParams.deltaParams.interestRateModeIn,
                    0,
                    user
                );
            }
        }
        // exact out swap
        else {
            //margin open [expected to flash (optimistic) supply amount]
            if (marginType == 0) {
                // swap the flashed amount

                (bool success, ) = swapTarget.call(flashParams.encodedSwapCall);
                require(success, "CALL_FAILED");

                address baseAsset = flashParams.deltaParams.baseAsset;
                uint256 received = IERC20(baseAsset).balanceOf(address(this));
                // supply the amount out - willl fail if insufficiently swapped
                aavePool.supply(baseAsset, received, user, 0);
                // adjust amountReceived
                amountReceived -= IERC20(token).balanceOf(address(this));
                // borrow amount in plus flash loan fee
                amountReceived += premium;
                aavePool.borrow(
                    token,
                    amountReceived, // the amountSwapped already respects dust
                    flashParams.deltaParams.interestRateModeIn,
                    0,
                    user
                );
            }
            // margin close [expected to flash withdrawal amount]
            // the repay amount consists of fee + swapAmount + residual
            else if (marginType == 1) {
                // swap the flashed amount exact out
                (bool success, ) = swapTarget.call(flashParams.encodedSwapCall);
                require(success, "CALL_FAILED");

                amountReceived -= IERC20(token).balanceOf(address(this));
                address baseAsset = flashParams.deltaParams.baseAsset;
                uint256 received = IERC20(baseAsset).balanceOf(address(this));
                marginType = flashParams.deltaParams.interestRateModeOut;
                if (flashParams.deltaParams.max) {
                    uint256 borrowBalance = getDebtBalance(baseAsset, marginType, user);
                    require(borrowBalance <= received, "Insufficient swapped");
                    // repay the amount out - will fail if insufficiently swapped
                    aavePool.repay(
                        baseAsset,
                        borrowBalance, // repay entire balance
                        marginType,
                        user
                    );
                    // refund excess amount if any
                    borrowBalance = received - borrowBalance;
                    if (borrowBalance > 0) _transferERC20Tokens(baseAsset, user, borrowBalance);
                } else {
                    // repay the amount out - will fail if too much is swapped
                    aavePool.repay(
                        baseAsset,
                        received, // repay reference amount
                        marginType,
                        user
                    );
                }
                // adjust amount for fee
                amountReceived += premium;
                // transfer aTokens from user - we only need the swap input amount plus flash loan fee
                _transferERC20TokensFrom(aas().aTokens[token], user, address(this), amountReceived);
                // withdraw swap amount directly to flash pool
                aavePool.withdraw(token, amountReceived, address(this));
            }
            //  collateral swap
            else if (marginType == 2) {
                // swap the flashed amount exact out
                (bool success, ) = swapTarget.call(flashParams.encodedSwapCall);
                require(success, "CALL_FAILED");

                address baseAsset = flashParams.deltaParams.baseAsset;
                uint256 received = IERC20(baseAsset).balanceOf(address(this));
                // supply the amount out - willl fail if insufficiently swapped
                aavePool.supply(baseAsset, received, user, 0);
                // adjust amountReceived
                amountReceived -= IERC20(token).balanceOf(address(this));
                // adjust amount for fee
                amountReceived += premium;
                // transfer aTokens from user - we only need the swap input amount plus flash loan fee
                _transferERC20TokensFrom(aas().aTokens[token], user, address(this), amountReceived);
                // withdraw swap amount directly to flash pool
                aavePool.withdraw(token, amountReceived, address(this));
            }
            // debt swap
            else {
                // swap the flashed amount exact out
                (bool success, ) = swapTarget.call(flashParams.encodedSwapCall);
                require(success, "CALL_FAILED");
                // fetch amountIn
                amountReceived -= IERC20(token).balanceOf(address(this));

                address baseAsset = flashParams.deltaParams.baseAsset;
                uint256 received = IERC20(baseAsset).balanceOf(address(this));
                marginType = flashParams.deltaParams.interestRateModeOut;
                if (flashParams.deltaParams.max) {
                    uint256 borrowBalance = getDebtBalance(baseAsset, marginType, user);
                    require(borrowBalance <= received, "Insufficient swapped");
                    // repay the amount out - will fail if insufficiently swapped
                    aavePool.repay(
                        baseAsset,
                        borrowBalance, // repay entire balance
                        marginType,
                        user
                    );
                    // refund excess amount if any
                    borrowBalance = received - borrowBalance;
                    if (borrowBalance > 0) _transferERC20Tokens(baseAsset, user, borrowBalance);
                } else {
                    // repay the amount out - will fail if too much is swapped
                    aavePool.repay(
                        baseAsset,
                        received, // repay ref amount
                        marginType,
                        user
                    );
                }
                // adjust amount for fee
                amountReceived += premium;
                // borrow amount in plus flash loan fee
                // repay flash loan with residual funds
                aavePool.borrow(token, amountReceived, flashParams.deltaParams.interestRateModeIn, 0, user);
            }
        }

        return true;
    }

    function getDebtBalance(
        address token,
        uint256 interestRateMode,
        address user
    ) private view returns (uint256) {
        if (interestRateMode == 2) return IERC20Balance(aas().vTokens[token]).balanceOf(user);
        else return IERC20Balance(aas().sTokens[token]).balanceOf(user);
    }
}
