// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.25;

/******************************************************************************\
* Author: Achthar | 1delta 
/******************************************************************************/

import {IERC20Balance} from "../../interfaces/IERC20Balance.sol";
import {MarginTrading, IUniswapV2Pair} from "./MarginTrading.sol";
import {WrappedNativeHandler} from "../base/WrappedNativeHandler.sol";
import {SelfPermit} from "../base/SelfPermit.sol";

// solhint-disable max-line-length

/**
 * @title FlashAggregator
 * @notice Adds money market and default transfer functions to margin trading
 */
contract FlashAggregator is MarginTrading, WrappedNativeHandler, SelfPermit {
    // constants
    uint256 private constant DEFAULT_AMOUNT_CACHED = type(uint256).max;
    address private constant DEFAULT_ADDRESS_CACHED = address(0);

    constructor(
        address _factoryV2,
        address _factoryV3,
        address aavePool,
        address weth
    ) MarginTrading(_factoryV2, _factoryV3, aavePool) WrappedNativeHandler(weth) {}

    /** BASE LENDING FUNCTIONS */

    // deposit ERC20 to Aave on behalf of recipient
    function deposit(address asset, address recipient) external payable {
        address _asset = asset;
        uint256 balance = IERC20Balance(_asset).balanceOf(address(this));
        _aavePool.supply(_asset, balance, recipient, 0);
    }

    // borrow on sender's behalf
    function borrow(
        address asset,
        uint256 amount,
        uint256 interestRateMode
    ) external payable {
        _aavePool.borrow(asset, amount, interestRateMode, 0, msg.sender);
    }

    // wraps the repay function
    function repay(
        address asset,
        address recipient,
        uint256 interestRateMode
    ) external payable {
        address _asset = asset;
        uint256 _balance = IERC20Balance(_asset).balanceOf(address(this));
        uint256 _debtBalance;
        uint256 _interestRateMode = interestRateMode;
        if (_interestRateMode == 2) _debtBalance = IERC20Balance(aas().vTokens[_asset]).balanceOf(msg.sender);
        else _debtBalance = IERC20Balance(aas().sTokens[_asset]).balanceOf(msg.sender);
        // if the amount lower higher than the balance, repay the amount
        if (_debtBalance >= _balance) {
            _aavePool.repay(_asset, _balance, _interestRateMode, recipient);
        } else {
            // otherwise, repay all - make sure to call sweep afterwards
            _aavePool.repay(_asset, _debtBalance, _interestRateMode, recipient);
        }
    }

    // wraps the withdraw
    function withdraw(address asset, address recipient) external payable {
        _aavePool.withdraw(asset, type(uint256).max, recipient);
    }

    /** TRANSFER FUNCTIONS */

    /** @notice transfer an ERC20token in */
    function transferERC20In(address asset, uint256 amount) external payable {
        _transferERC20TokensFrom(asset, msg.sender, address(this), amount);
    }

    /** @notice transfer all ERC20tokens in - only required for aTokens */
    function transferERC20AllIn(address asset) external payable {
        address _asset = asset;

        _transferERC20TokensFrom(
            _asset,
            msg.sender,
            address(this),
            IERC20Balance(_asset).balanceOf(msg.sender) // transfer entire balance
        );
    }

    /** @notice transfer an a balance to the sender */
    function sweep(address asset) external payable {
        address _asset = asset;
        uint256 balance = IERC20Balance(_asset).balanceOf(address(this));
        if (balance > 0) _transferERC20Tokens(_asset, msg.sender, balance);
    }

    /** @notice transfer an a balance to the recipient */
    function sweepTo(address asset, address recipient) external payable {
        address _asset = asset;
        uint256 balance = IERC20Balance(_asset).balanceOf(address(this));
        if (balance > 0) _transferERC20Tokens(_asset, recipient, balance);
    }

    function refundNative() external payable {
        uint256 balance = address(this).balance;
        if (balance > 0) _transferEth(msg.sender, balance);
    }

    /** GENERIC CALL WRAPPER FOR APPROVED CALLS */

    // call an approved target (can also be the contract itself)
    function callTarget(address target, bytes calldata params) external payable {
        address _target = target;
        require(gs().isValidTarget[_target], "Target()");
        (bool success, ) = _target.call(params);
        require(success, "CallFailed()");
    }

    /** 1DELTA SWAP WRAPPERS */

    /**
     * @notice This flash swap allows either a direct withdrawal or borrow, or can just be paid by the user
     * Has to be batch-called togehter with a sweep, deposit or repay function.
     * The flash swap will pull the funds directly from the user
     */
    function swapExactOutSpot(
        uint256 amountOut,
        uint256 maximumAmountIn,
        bytes calldata path
    ) external payable {
        acs().cachedAddress = msg.sender;
        flashSwapExactOutInternal(amountOut, address(this), path);
        if (maximumAmountIn < ncs().amount) revert Slippage();
        ncs().amount = DEFAULT_AMOUNT_CACHED;
        acs().cachedAddress = DEFAULT_ADDRESS_CACHED;
    }

    /**
     * @notice Same as swapExactOutSpot, except that the payer is this contract.
     */
    function swapExactOutSpotSelf(
        uint256 amountOut,
        uint256 maximumAmountIn,
        bytes calldata path
    ) external payable {
        flashSwapExactOutInternal(amountOut, address(this), path);
        if (maximumAmountIn < ncs().amount) revert Slippage();
        ncs().amount = DEFAULT_AMOUNT_CACHED;
    }

    /**
     * @notice A simple exact input spot swap using internal callbacks.
     * Has to be batch-called with transfer in / sweep functions
     * Requires that the funds already have been transferred to this contract
     */
    function swapExactInSpot(
        uint256 amountIn,
        uint256 minimumAmountOut,
        bytes calldata path
    ) external payable {
        uint256 amountOut = swapExactIn(amountIn, path);
        if (minimumAmountOut > amountOut) revert Slippage();
    }

    /**
     * @notice The same as swapExactOutSpot, except that we snipe the debt balance
     * This ensures that no borrow dust will be left. The next step in the batch has to the repay function.
     */
    function swapAllOutSpot(
        uint256 maximumAmountIn,
        uint256 interestRateMode,
        bytes calldata path
    ) external payable {
        acs().cachedAddress = msg.sender;
        uint256 _debtBalance;
        uint256 _interestRateMode = interestRateMode;
        address tokenOut;
        assembly {
            tokenOut := shr(96, calldataload(path.offset))
        }
        if (_interestRateMode == 2) _debtBalance = IERC20Balance(aas().vTokens[tokenOut]).balanceOf(msg.sender);
        else _debtBalance = IERC20Balance(aas().sTokens[tokenOut]).balanceOf(msg.sender);
        if (_debtBalance == 0) revert NoBalance(); // revert if amount is zero

        flashSwapExactOutInternal(_debtBalance, address(this), path);
        if (maximumAmountIn < ncs().amount) revert Slippage();
        ncs().amount = DEFAULT_AMOUNT_CACHED;
        acs().cachedAddress = DEFAULT_ADDRESS_CACHED;
    }

    /**
     * @notice The same as swapAllOutSpot, except that the payer is this contract - used when wrapping ETH before calling
     */
    function swapAllOutSpotSelf(
        uint256 maximumAmountIn,
        uint256 interestRateMode,
        bytes calldata path
    ) external payable {
        uint256 _debtBalance;
        uint256 _interestRateMode = interestRateMode;
        address tokenOut;
        assembly {
            tokenOut := shr(96, calldataload(path.offset))
        }
        if (_interestRateMode == 2) _debtBalance = IERC20Balance(aas().vTokens[tokenOut]).balanceOf(msg.sender);
        else _debtBalance = IERC20Balance(aas().sTokens[tokenOut]).balanceOf(msg.sender);
        if (_debtBalance == 0) revert NoBalance(); // revert if amount is zero

        flashSwapExactOutInternal(_debtBalance, address(this), path);
        if (maximumAmountIn < ncs().amount) revert Slippage();
        ncs().amount = DEFAULT_AMOUNT_CACHED;
    }

    /**
     * @notice The same as swapExactInSpot, except that we swap the entire balance
     * This function can be used after a withdrawal - to make sure that no dust is left
     */
    function swapAllInSpot(uint256 minimumAmountOut, bytes calldata path) external payable {
        address tokenIn;
        assembly {
            tokenIn := shr(96, calldataload(path.offset))
        }
        uint256 amountIn = IERC20Balance(tokenIn).balanceOf(address(this));
        if (amountIn == 0) revert NoBalance(); // revert if amount is zero
        uint256 amountOut = swapExactIn(amountIn, path);
        if (minimumAmountOut > amountOut) revert Slippage();
    }
}
