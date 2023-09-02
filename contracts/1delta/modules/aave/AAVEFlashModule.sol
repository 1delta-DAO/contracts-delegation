// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.21;

import {IERC20} from "../../../interfaces/IERC20.sol";
import {IPool} from "../../interfaces/IAAVEV3Pool.sol";
import {WithStorage} from "../../storage/BrokerStorage.sol";
import {TokenTransfer} from "./../../libraries/TokenTransfer.sol";
import {IERC20Balance} from "../../interfaces/IERC20Balance.sol";

/// @notice Aave flash loans draw the required loan plus fee from the caller
//  as such, there is no need to transfer the funds manually back to the pool
contract AAVEFlashModule is WithStorage, TokenTransfer {
    IPool private immutable _aavePool;
    // marginTradeType
    // 0 = Margin open
    // 1 = margin close
    // 2 = collateral / open
    // 3 = debt / close

    struct DeltaParams {
        address baseAsset; // the asset paired with the flash loan
        address target; // the swap target
        uint8 marginTradeType; // open, close, collateral, debt swap
        uint8 interestRateModeIn; // aave interest mode
        uint8 interestRateModeOut; // aave interest mode
        bool withdrawMax; // a flag that indicates that either
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
    ) external payable {
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
            marginType = flashParams.deltaParams.interestRateModeOut;
            uint256 borrowBalance = getDebtBalance(baseAsset, marginType, user);
            if (borrowBalance <= amountSwapped) {
                // repay the amount out - will fail if insufficiently swapped
                aavePool.repay(
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
                aavePool.repay(
                    baseAsset,
                    amountSwapped, // repay reference amount
                    marginType,
                    user
                );
            }
            // adjust amount for flash loan fee
            amountReceived += premium;
            baseAsset = aas().aTokens[token];
            if (flashParams.deltaParams.withdrawMax) {
                // fetch user balance
                amountSwapped = IERC20(baseAsset).balanceOf(user);
                // transfer aTokens from user
                _transferERC20TokensFrom(baseAsset, user, address(this), amountSwapped);
                // withdraw
                aavePool.withdraw(
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
                amountSwapped = amountReceived - IERC20(token).balanceOf(address(this));
                // transfer aTokens from user
                _transferERC20TokensFrom(baseAsset, user, address(this), amountSwapped);
                // withdraw required funds
                aavePool.withdraw(
                    token,
                    amountSwapped, // we withdraw the dust-adjusted amount
                    address(this)
                );
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
            baseAsset = aas().aTokens[token];
            if (flashParams.deltaParams.withdrawMax) {
                // fetch user balance
                amountSwapped = IERC20(baseAsset).balanceOf(user);
                // transfer aTokens from user
                _transferERC20TokensFrom(baseAsset, user, address(this), amountSwapped);
                // withdraw
                aavePool.withdraw(
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
                amountSwapped = amountReceived - IERC20(token).balanceOf(address(this));
                // transfer aTokens from user
                _transferERC20TokensFrom(baseAsset, user, address(this), amountSwapped);
                // withdraw required funds
                aavePool.withdraw(
                    token,
                    amountSwapped, // we withdraw the dust-adjusted amount
                    address(this)
                );
            }
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
            uint256 borrowBalance = getDebtBalance(baseAsset, marginType, user);
            if (borrowBalance <= received) {
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
            aavePool.borrow(token, amountReceived, flashParams.deltaParams.interestRateModeIn, 0, user);
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
