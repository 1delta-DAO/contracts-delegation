// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.21;

import {IERC20} from "../../../interfaces/IERC20.sol";
import {IPool} from "../../interfaces/IAAVEV3Pool.sol";
import {IUniswapV3Pool} from "../../dex-tools/uniswap/core/IUniswapV3Pool.sol";
import {INativeWrapper} from "../../interfaces/INativeWrapper.sol";
import {BaseSwapper} from "../base/BaseSwapper.sol";
import {IERC20Balance} from "../../interfaces/IERC20Balance.sol";
import {WithStorage} from "../../storage/BrokerStorage.sol";

// solhint-disable max-line-length

/**
 * @title Money market module
 * @notice Allows users to chain a single money market transaction with a swap.
 * Direct lending pool interactions are unnecessary as the user can directly interact with the lending protocol
 * @author Achthar
 */
contract AaveMoneyMarket is BaseSwapper, WithStorage {
    uint256 private constant DEFAULT_AMOUNT_CACHED = type(uint256).max;

    IPool private immutable _aavePool;

    address private immutable networkTokenId = address(0);
    address private immutable wrappedNative;

    constructor(
        address _factoryV2,
        address _factoryV3,
        address aavePool,
        address weth
    ) BaseSwapper(_factoryV2, _factoryV3) {
        _aavePool = IPool(aavePool);
        wrappedNative = weth;
    }

    /** BASE LENDING FUNCTIONS */

    // deposit ERC20
    function deposit(address asset, address recipient) external {
        address _asset = asset;
        uint256 balance = IERC20(_asset).balanceOf(address(this));
        _aavePool.supply(_asset, balance, recipient, 0);
    }

    // borrow and transfer
    function borrow(
        address asset,
        uint256 amount,
        uint8 interestRateMode,
        address recipient
    ) external {
        address _asset = asset;
        _aavePool.borrow(_asset, amount, interestRateMode, 0, msg.sender);
        if (recipient != address(this)) _transferERC20Tokens(_asset, recipient, amount);
    }

    // wraps the repay function
    function repay(
        address asset,
        address recipient,
        uint8 interestRateMode
    ) external {
        address _asset = asset;
        uint256 _balance = IERC20(_asset).balanceOf(address(this));
        uint256 _debtBalance;
        uint256 _interestRateMode = interestRateMode;
        if (_interestRateMode == 2) _debtBalance = IERC20Balance(aas().vTokens[_asset]).balanceOf(msg.sender);
        else _debtBalance = IERC20Balance(aas().sTokens[_asset]).balanceOf(msg.sender);
        _aavePool.repay(_asset, _balance, _interestRateMode, recipient);
    }

    // wraps the withdraw
    function withdraw(address asset, address recipient) external {
        _aavePool.withdraw(asset, type(uint256).max, recipient);
    }

    /** TRANSFER FUNCTIONS */

    function transferERC20In(address asset, uint256 amount) external {
        _transferERC20TokensFrom(asset, msg.sender, address(this), amount);
    }

    // transfer balance to sender
    function sweep(address asset) external {
        address _asset = asset;
        uint256 balance = IERC20(_asset).balanceOf(address(this));
        if (balance > 0) _transferERC20Tokens(_asset, msg.sender, balance);
    }

    function validateAndSweep(address asset, uint256 amountMin) external {
        address _asset = asset;
        uint256 balance = IERC20(_asset).balanceOf(address(this));
        require(balance >= amountMin, "Insufficient Sweep");
        _transferERC20Tokens(_asset, msg.sender, balance);
    }

    /** WRAPPED NATIVE FUNCTIONS  */

    // deposit native and wrap
    function wrap() external payable {
        uint256 supplied = msg.value;
        INativeWrapper _weth = INativeWrapper(wrappedNative);
        _weth.deposit{value: supplied}();
    }

    // unwrap wrappd native and send funds to sender
    function unwrap() external {
        INativeWrapper _weth = INativeWrapper(wrappedNative);
        uint256 balance = _weth.balanceOf(address(this));
        _weth.withdraw(balance);
        // transfer eth to sender
        payable(msg.sender).transfer(balance);
    }

    // unwrap wrappd native, validate balance and send to sender
    function validateAndunwrap(uint256 amountMin) external {
        INativeWrapper _weth = INativeWrapper(wrappedNative);
        uint256 balance = _weth.balanceOf(address(this));
        require(balance >= amountMin, "Insufficient Sweep");
        _weth.withdraw(balance);
        // transfer eth to sender
        payable(msg.sender).transfer(balance);
    }

    // call an approved target
    function callTarget(address target, bytes calldata params) external {
        // exectue call
        {
            address _target = target;
            require(gs().isValidTarget[_target], "TARGET");
            (bool success, ) = _target.call(params);
            require(success, "CALL_FAILED");
        }
    }

    /** 1DELTA SWAP WRAPPERS */

    function flashExactOutStandard(uint256 amountOut, bytes calldata path) external {
        flashSwapExactOut(amountOut, path);
    }

    function swapExactInStandard(uint256 amountIn, bytes calldata path) external {
        swapExactIn(amountIn, path);
    }

    function flashAllOutStandard(uint256 interestRateMode, bytes calldata path) external {
        uint256 _debtBalance;
        uint256 _interestRateMode = interestRateMode;
        address tokenOut;
        assembly {
            tokenOut := shr(96, calldataload(path.offset))
        }
        if (_interestRateMode == 2) _debtBalance = IERC20Balance(aas().vTokens[tokenOut]).balanceOf(msg.sender);
        else _debtBalance = IERC20Balance(aas().sTokens[tokenOut]).balanceOf(msg.sender);
        flashSwapExactOut(_debtBalance, path);
    }

    function swapAllInStandard(bytes calldata path) external {
        address tokenIn;
        assembly {
            tokenIn := shr(96, calldataload(path.offset))
        }
        uint256 amountIn = IERC20(tokenIn).balanceOf(address(this));
        swapExactIn(amountIn, path);
    }

    struct DepositParameters {
        address tokenIn;
        address tokenOut;
        uint256 amountIn;
        address recipient;
        address target;
        bytes data;
    }

    // call before deposit
    function callAndDeposit(DepositParameters calldata params) external payable {
        address tokenIn = params.tokenIn;
        // if tokenIn is the network currency, wrap asset
        if (tokenIn == networkTokenId) {
            tokenIn = wrappedNative;
            require(msg.value > 0, "NO_ETHER_SENT");
            INativeWrapper(tokenIn).deposit{value: msg.value}();
        } else _transferERC20TokensFrom(tokenIn, msg.sender, address(this), params.amountIn);

        address tokenOut = params.tokenOut;
        // exectue call
        {
            address target = params.target;
            require(gs().isValidTarget[target], "TARGET");
            (bool success, ) = target.call(params.data);
            require(success, "CALL_FAILED");
        }
        uint256 received = IERC20Balance(tokenOut).balanceOf(address(this));
        // note that we wrapped the entire amount, we will therefore refund wrapped native in case of ETH in
        uint256 remaining = IERC20Balance(tokenIn).balanceOf(address(this));
        if (remaining > 0) _transferERC20Tokens(tokenIn, msg.sender, remaining);
        _aavePool.supply(tokenOut, received, params.recipient, 0);
    }

    struct RepayParameters {
        address tokenIn;
        address tokenOut;
        uint256 amountIn;
        uint8 interestRateMode;
        address recipient;
        address target;
        bytes data;
    }

    function callAndRepay(RepayParameters calldata params) external payable {
        // fetch tokenIn and transfer funds
        address tokenIn = params.tokenIn;
        // if tokenIn is the network currency, wrap asset
        if (tokenIn == networkTokenId) {
            tokenIn = wrappedNative;
            require(msg.value > 0, "NO_ETHER_SENT");
            INativeWrapper(tokenIn).deposit{value: msg.value}();
        } else _transferERC20TokensFrom(tokenIn, msg.sender, address(this), params.amountIn);

        address tokenOut = params.tokenOut;

        // exectue call
        {
            address target = params.target;
            require(gs().isValidTarget[target], "TARGET");
            (bool success, ) = target.call(params.data);
            require(success, "CALL_FAILED");
        }

        // fetch received amount
        uint256 received = IERC20Balance(tokenOut).balanceOf(address(this));
        // note that we wrapped the entire amount, we will therefore refund wrapped native in case of ETH
        uint256 remaining = IERC20Balance(tokenIn).balanceOf(address(this));
        if (remaining > 0) _transferERC20Tokens(tokenIn, msg.sender, remaining);
        // reassign variable to prevent new slot
        remaining = params.interestRateMode;
        uint256 debtBalance;
        if (remaining == 2) debtBalance = IERC20Balance(aas().vTokens[tokenOut]).balanceOf(msg.sender);
        else debtBalance = IERC20Balance(aas().sTokens[tokenOut]).balanceOf(msg.sender);

        // repay obtained amount if less than debt
        if (debtBalance >= received) _aavePool.repay(tokenOut, received, remaining, params.recipient);
        else {
            address recipient = params.recipient;
            // otherwise, repay entire debt balance and refund dust
            _aavePool.repay(tokenOut, received, remaining, recipient);
            _transferERC20Tokens(tokenOut, recipient, received - debtBalance);
        }
    }

    struct BorrowParameters {
        address tokenIn;
        address tokenOut;
        uint256 amountIn;
        uint8 interestRateMode;
        address recipient;
        address target;
        bytes data;
    }

    function borrowAndCall(BorrowParameters calldata params) external payable {
        // fetch tokenIn and transfer funds
        address tokenIn = params.tokenIn;
        _aavePool.borrow(tokenIn, params.amountIn, params.interestRateMode, 0, msg.sender); //(tokenOut, received, remaining, recipient);

        // exectue call
        (bool success, ) = params.target.call(params.data);
        require(success, "CALL_FAILED");

        address tokenOut = params.tokenOut;
        // fetch received amount
        uint256 received = IERC20Balance(tokenOut).balanceOf(address(this));
        // note that we send the funds to the user instead of repaying them
        uint256 remaining = IERC20Balance(tokenIn).balanceOf(address(this));
        if (remaining > 0) _transferERC20Tokens(tokenIn, msg.sender, remaining);
        // reassign variable to prevent new slot
        remaining = params.interestRateMode;
        uint256 debtBalance;
        if (remaining == 2) debtBalance = IERC20Balance(aas().vTokens[tokenOut]).balanceOf(msg.sender);
        else debtBalance = IERC20Balance(aas().sTokens[tokenOut]).balanceOf(msg.sender);

        // repay obtained amount if less than debt
        if (debtBalance >= received) _aavePool.repay(tokenOut, received, remaining, params.recipient);
        else {
            address recipient = params.recipient;
            // otherwise, repay entire debt balance and refund dust
            _aavePool.repay(tokenOut, received, remaining, recipient);
            _transferERC20Tokens(tokenOut, recipient, received - debtBalance);
        }

        // if tokenIn is the network currency, wrap asset
        if (tokenIn == networkTokenId) {
            tokenIn = wrappedNative;
            require(msg.value > 0, "NO_ETHER_SENT");
            INativeWrapper(tokenIn).deposit{value: msg.value}();
        } else _transferERC20TokensFrom(tokenIn, msg.sender, address(this), params.amountIn);
    }
}
