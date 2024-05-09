// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.25;

import {IFlashLoanReceiver} from "./IFlashLoanReceiver.sol";
import {ILendingPool} from "./ILendingPool.sol";
import {BaseLending} from "./BaseLending.sol";
import {WithStorage} from "../../../storage/BrokerStorage.sol";
import {TokenTransfer} from "./../../../libraries/TokenTransfer.sol";

/// @notice Aave flash loans draw the required loan plus fee from the caller
//  as such, there is no need to transfer the funds manually back to the pool
contract LendleFlashModule is WithStorage, BaseLending, TokenTransfer, IFlashLoanReceiver {
    // immutable

    struct DeltaFlashParams {
        DeltaParams deltaParams;
        bytes encodedSwapCall;
        address user;
    }

    constructor() {}

    /**
     * Excutes flash loan
     * @param asset the aset to draw the flash loan
     * @param amount the flash loan amount
     */
    function executeOnLendle(
        address asset,
        uint256 amount,
        DeltaParams calldata deltaParams, // params are kept separate
        bytes calldata swapCalldata
    ) external payable override {
        address[] memory tokens = new address[](1);
        uint256[] memory amounts = new uint256[](1);
        uint256[] memory modes = new uint256[](1);
        tokens[0] = asset;
        amounts[0] = amount;
        modes[0] = 0;
        // ILendingPool(0x13e9761c037f382472cE765556c3dA2aF29d9EC7)
        ILendingPool(LENDLE_POOL).flashLoan(
            address(this),
            tokens,
            amounts,
            modes,
            address(this),
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
        address[] calldata assets,
        uint256[] calldata amounts,
        uint256[] calldata premiums,
        address initiator,
        bytes calldata params
    ) external override returns (bool) {
        ILendingPool lenderPool = ILendingPool(LENDLE_POOL);

        // fetch flash loan parameters
        address token = assets[0];
        uint256 amountReceived = amounts[0];

        // decode delta parameters
        DeltaFlashParams memory flashParams = abi.decode(params, (DeltaFlashParams));

        uint256 marginType = flashParams.deltaParams.marginTradeType;
        address user = flashParams.user;

        // execute transaction on target
        {
            address swapTarget = flashParams.deltaParams.target;
            // validate callback
            require(initiator == address(this), "CannotEnter()");
            // validate swap router
            require(gs().isValidTarget[swapTarget], "Target()");
            require(msg.sender == address(lenderPool), "PoolNotCaller()");

            (bool success, bytes memory swapResult) = swapTarget.call(flashParams.encodedSwapCall);
            if (!success) {
                if (swapResult.length < 68) revert();
                assembly {
                    swapResult := add(swapResult, 0x04)
                }
                revert(abi.decode(swapResult, (string)));
            }
        }

        //margin open [expected to flash borrow amount]
        if (marginType == 0) {
            address baseAsset = flashParams.deltaParams.baseAsset;
            uint256 amountSwapped = _balanceOf(baseAsset, address(this));

            // supply the received amount
            _deposit(baseAsset, user, amountSwapped);

            // adjust amount for flash loan fee
            amountReceived += premiums[0];
            // in case the input of the swap was too low, we subtract the balance pre-borrow
            amountReceived -= _balanceOf(token, address(this));

            // borrow amounts plus fee and send them back to the pool
            lenderPool.borrow(token, amountReceived, flashParams.deltaParams.interestRateModeIn, 0, user);
        }
        // margin close [expected to flash withdrawal amount]
        else if (marginType == 1) {
            address baseAsset = flashParams.deltaParams.baseAsset;
            uint256 amountSwapped = _balanceOf(baseAsset, address(this));
            marginType = flashParams.deltaParams.interestRateModeOut;
            uint256 borrowBalance = getDebtBalance(baseAsset, marginType, user);
            if (borrowBalance <= amountSwapped) {
                // repay the amount out - will fail if insufficiently swapped
                lenderPool.repay(
                    baseAsset,
                    borrowBalance, // repay entire balance
                    marginType,
                    user
                );
                // refund excess amount if any
                borrowBalance = amountSwapped - borrowBalance;
                if (borrowBalance > 0) _transferERC20Tokens(baseAsset, user, borrowBalance);
            } else {
                // repay the amount out - will fail if too much is swapped
                lenderPool.repay(
                    baseAsset,
                    amountSwapped, // repay reference amount
                    marginType,
                    user
                );
            }
            // adjust amount for flash loan fee
            amountReceived += premiums[0];
            baseAsset = aas().aTokens[token];
            if (flashParams.deltaParams.withdrawMax) {
                // fetch user balance
                amountSwapped = _balanceOf(baseAsset, user);
                // transfer aTokens from user
                _transferERC20TokensFrom(baseAsset, user, address(this), amountSwapped);
                // withdraw
                lenderPool.withdraw(
                    token,
                    amountSwapped, // withdraw entire balance
                    address(this)
                );
                // adjust funds for leftovers
                amountReceived = amountSwapped - amountReceived;
                // if funds are left, send them to the user
                if (amountReceived != 0) _transferERC20Tokens(token, user, amountReceived);
            } else {
                // calculate amount to withdraw
                amountSwapped = amountReceived - _balanceOf(token, address(this));
                // transfer aTokens from user
                _transferERC20TokensFrom(baseAsset, user, address(this), amountSwapped);
                // withdraw required funds
                lenderPool.withdraw(
                    token,
                    amountSwapped, // we withdraw the dust-adjusted amount
                    address(this)
                );
            }
        }
        //  collateral swap
        else if (marginType == 2) {
            address baseAsset = flashParams.deltaParams.baseAsset;
            uint256 amountSwapped = _balanceOf(baseAsset, address(this));

            // supply the received amount
            _deposit(flashParams.deltaParams.baseAsset, user, amountSwapped);

            // adjust amount for flash loan fee
            amountReceived += premiums[0];
            baseAsset = aas().aTokens[token];
            if (flashParams.deltaParams.withdrawMax) {
                // fetch user balance
                amountSwapped = _balanceOf(baseAsset, user);
                // transfer aTokens from user
                _transferERC20TokensFrom(baseAsset, user, address(this), amountSwapped);
                // withdraw
                lenderPool.withdraw(
                    token,
                    amountSwapped, // withdraw entire balance
                    address(this)
                );
                // adjust funds for leftovers
                amountReceived = amountSwapped - amountReceived;
                // if funds are left, send them to the user
                if (amountReceived != 0) _transferERC20Tokens(token, user, amountReceived);
            } else {
                // calculate amount to withdraw
                amountSwapped = amountReceived - _balanceOf(token, address(this));
                // transfer aTokens from user
                _transferERC20TokensFrom(baseAsset, user, address(this), amountSwapped);
                // withdraw required funds
                lenderPool.withdraw(
                    token,
                    amountSwapped, // we withdraw the dust-adjusted amount
                    address(this)
                );
            }
        }
        // debt swap
        else {
            // fetch amountIn
            amountReceived -= _balanceOf(token, address(this));

            address baseAsset = flashParams.deltaParams.baseAsset;
            uint256 received = _balanceOf(baseAsset, address(this));
            marginType = flashParams.deltaParams.interestRateModeOut;
            uint256 borrowBalance = getDebtBalance(baseAsset, marginType, user);
            if (borrowBalance <= received) {
                // repay the amount out - will fail if insufficiently swapped
                lenderPool.repay(
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
                lenderPool.repay(
                    baseAsset,
                    received, // repay ref amount
                    marginType,
                    user
                );
            }
            // adjust amount for fee
            amountReceived += premiums[0];
            // borrow amount in plus flash loan fee
            lenderPool.borrow(token, amountReceived, flashParams.deltaParams.interestRateModeIn, 0, user);
        }

        return true;
    }

    function getDebtBalance(address token, uint256 interestRateMode, address user) private view returns (uint256) {
        if (interestRateMode == 2) return _balanceOf(aas().vTokens[token], user);
        else return _balanceOf(aas().sTokens[token], user);
    }
}
