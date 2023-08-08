// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.21;

import {IERC20} from "../../../interfaces/IERC20.sol";
import {IPool} from "../../interfaces/IAAVEV3Pool.sol";
import {WithStorage} from "../../storage/BrokerStorage.sol";
import {TokenTransfer} from "./../../libraries/TokenTransfer.sol";
import {IBalancerFlashLoans, IFlashLoanRecipient} from "../../../external-protocols/balancer/IBalancerFlashLoans.sol";
import {IERC20Balance} from "../../interfaces/IERC20Balance.sol";
import "hardhat/console.sol";

/// @notice Balancer flash do NOT loans draw the required loan plus fee from the caller
//  as such, we have to make sure that we always transer loan plus fee
//  during the flash loan call
contract BalancerFlashModule is WithStorage, TokenTransfer {
    IPool private immutable _aavePool;
    IBalancerFlashLoans private immutable _balancerFlashLoans;
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

    constructor(address _aave, address _balancer) {
        _aavePool = IPool(_aave);
        _balancerFlashLoans = IBalancerFlashLoans(_balancer);
    }

    /**
     * Excutes flash loan
     * @param asset the aset to draw the flash loan
     * @param amount the flash loan amount
     */
    function executeOnBalancer(
        IERC20 asset,
        uint256 amount,
        DeltaParams calldata deltaParams,
        bytes calldata swapCalldata
    ) external {
        IERC20[] memory tokens = new IERC20[](1);
        uint256[] memory amounts = new uint256[](1);
        tokens[0] = asset;
        amounts[0] = amount;
        gs().isOpen = 1;
        _balancerFlashLoans.flashLoan(
            IFlashLoanRecipient(address(this)),
            tokens,
            amounts,
            abi.encode(DeltaFlashParams({deltaParams: deltaParams, encodedSwapCall: swapCalldata, user: msg.sender}))
        );
    }

    /**
     * @dev When `flashLoan` is called on the Vault, it invokes the `receiveFlashLoan` hook on the recipient.
     *
     *  We never expect more than one token to be flashed
     */
    function receiveFlashLoan(
        IERC20[] memory tokens, // token to be flash borrowed
        uint256[] memory amounts, // flash amounts
        uint256[] memory feeAmounts,
        bytes memory userData
    ) external {
        // validate callback
        require(gs().isOpen == 1, "CANNOT_ENTER");
        require(msg.sender == address(_balancerFlashLoans), "VAULT_NOT_CALLER");

        // fetch flash loan parameters
        address token = address(tokens[0]);
        uint256 amountReceived = amounts[0];

        // decode delta parameters
        DeltaFlashParams memory flashParams = abi.decode(userData, (DeltaFlashParams));

        address swapTarget = flashParams.deltaParams.target;
        uint256 marginType = flashParams.deltaParams.marginTradeType;
        address user = flashParams.user;

        IPool aavePool = _aavePool;

        // validate swap router
        require(gs().isValidTarget[swapTarget], "TARGET");

        // exact in swap
        // that amount is supposed to be swapped by the target to some output amount in asset baseAsset
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
            amountReceived += feeAmounts[0];
            // in case the input of the swap was too low, we subtract the balance pre-borrow
            amountSwapped = amountReceived - IERC20(token).balanceOf(address(this));
            // borrow the required amount
            aavePool.borrow(token, amountSwapped, flashParams.deltaParams.interestRateModeIn, 0, user);
            // send flash amount plus fee to vault
            _transferERC20Tokens(token, msg.sender, amountReceived);
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
            amountReceived += feeAmounts[0];
            baseAsset = aas().aTokens[token];
            if (flashParams.deltaParams.withdrawMax) {
                // fetch user balance
                amountSwapped = IERC20(baseAsset).balanceOf(user);
                // transfer aTokens from user
                _transferERC20TokensFrom(baseAsset, user, address(this), amountSwapped);
                // withdraw the entire user balance
                aavePool.withdraw(token, amountSwapped, address(this));
                //  send required funds back to flash pool
                _transferERC20Tokens(token, msg.sender, amountReceived);
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
                aavePool.withdraw(token, amountSwapped, address(this));
                // send flash amount plus fees to vault
                _transferERC20Tokens(token, msg.sender, amountReceived);
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
            aavePool.supply(baseAsset, amountSwapped, user, 0);

            // adjust amount for flash loan fee
            amountReceived += feeAmounts[0];

            baseAsset = aas().aTokens[token];
            if (flashParams.deltaParams.withdrawMax) {
                // fetch user balance
                amountSwapped = IERC20(baseAsset).balanceOf(user);
                // transfer aTokens from user
                _transferERC20TokensFrom(baseAsset, user, address(this), amountSwapped);
                // withdraw the entire user balance
                aavePool.withdraw(token, amountSwapped, address(this));
                //  send required funds back to flash pool
                _transferERC20Tokens(token, msg.sender, amountReceived);
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
                aavePool.withdraw(token, amountSwapped, address(this));
                // send flash amount plus fees to vault
                _transferERC20Tokens(token, msg.sender, amountReceived);
            }
        }
        // debt swap
        else {
            // execute transaction on target
            (bool success, ) = swapTarget.call(flashParams.encodedSwapCall);
            require(success, "CALL_FAILED");

            address baseAsset = flashParams.deltaParams.baseAsset;
            uint256 received = IERC20(baseAsset).balanceOf(address(this));
            marginType = flashParams.deltaParams.interestRateModeOut;
            uint256 amountSwapped = getDebtBalance(baseAsset, marginType, user);
            if (amountSwapped <= received) {
                // repay the amount out - will fail if insufficiently swapped
                aavePool.repay(
                    baseAsset,
                    amountSwapped, // repay entire balance
                    marginType,
                    user
                );
                // refund excess amount if any
                amountSwapped = received - amountSwapped;
                if (amountSwapped > 0) _transferERC20Tokens(baseAsset, user, amountSwapped);
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
            amountReceived += feeAmounts[0];
            // fetch amountIn
            amountSwapped = amountReceived - IERC20(token).balanceOf(address(this));
            // borrow amount in plus flash loan fee
            aavePool.borrow(token, amountSwapped, flashParams.deltaParams.interestRateModeIn, 0, user);
            // send funds to vault
            _transferERC20Tokens(token, msg.sender, amountReceived);
        }

        gs().isOpen = 0;
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
