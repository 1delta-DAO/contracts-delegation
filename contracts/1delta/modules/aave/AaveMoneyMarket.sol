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
    // errors
    error Slippage();
    error NoBalance();

    // constants
    uint256 private constant DEFAULT_AMOUNT_CACHED = type(uint256).max;
    address private constant DEFAULT_ADDRESS_CACHED = address(0);

    // immutables
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

    // deposit ERC20 to Aave on behalf of recipient
    function deposit(address asset, address recipient) external {
        address _asset = asset;
        uint256 balance = IERC20(_asset).balanceOf(address(this));
        _aavePool.supply(_asset, balance, recipient, 0);
    }

    // borrow on sender's behalf
    function borrow(
        address asset,
        uint256 amount,
        uint8 interestRateMode
    ) external {
        _aavePool.borrow(asset, amount, interestRateMode, 0, msg.sender);
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

    /** @notice transfer an ERC20token in */
    function transferERC20In(address asset, uint256 amount) external {
        _transferERC20TokensFrom(asset, msg.sender, address(this), amount);
    }

    /** @notice transfer an a balance to the sender */
    function sweep(address asset) external {
        address _asset = asset;
        uint256 balance = IERC20(_asset).balanceOf(address(this));
        if (balance > 0) _transferERC20Tokens(_asset, msg.sender, balance);
    }

    /** @notice transfer an a balance to the and validate that the amount is larger than a provided value */
    function validateAndSweep(address asset, uint256 amountMin) external {
        address _asset = asset;
        uint256 balance = IERC20(_asset).balanceOf(address(this));
        if (balance < amountMin) revert Slippage();
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
    function validateAndUnwrap(uint256 amountMin) external {
        INativeWrapper _weth = INativeWrapper(wrappedNative);
        uint256 balance = _weth.balanceOf(address(this));
        require(balance >= amountMin, "Insufficient Sweep");
        _weth.withdraw(balance);
        // transfer eth to sender
        payable(msg.sender).transfer(balance);
    }

    // call an approved target (can also be the contract itself)
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

    /**
     * @notice This flash swap allows either a direct withdrawal or borrow, or can just be paid by the user
     * Has to be batch-called togehter with a sweep, deposit or repay function.
     * The flash swap will pull the funds directly from the user, as such there is no need f
     */
    function swapExactOutSpot(
        uint256 amountOut,
        uint256 maximumAmountIn,
        bytes calldata path
    ) external {
        acs().cachedAddress = msg.sender;
        flashSwapExactOut(amountOut, path);
        if (maximumAmountIn < ncs().amount) revert Slippage();
        ncs().amount = DEFAULT_AMOUNT_CACHED;
        acs().cachedAddress = DEFAULT_ADDRESS_CACHED;
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
    ) external {
        uint256 amountOut = swapExactIn(amountIn, path);
        if (minimumAmountOut > amountOut) revert Slippage();
    }

    /**
     * @notice The same as swapExactOutSpot, except that we snipe the debt balance
     * This ensures that no borrow dust will be left. The next step in the batch has to the repay function.
     */
    function swapAllOutSpot(
        uint256 interestRateMode,
        uint256 maximumAmountIn,
        bytes calldata path
    ) external {
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

        flashSwapExactOut(_debtBalance, path);
        if (maximumAmountIn < ncs().amount) revert Slippage();
        ncs().amount = DEFAULT_AMOUNT_CACHED;
        acs().cachedAddress = DEFAULT_ADDRESS_CACHED;
    }

    /**
     * @notice The same as swapExactInSpot, except that we swap the entire balance
     * This function can be used after a withdrawal - to make sure that no dust is left
     */
    function swapAllInSpot(bytes calldata path) external {
        address tokenIn;
        assembly {
            tokenIn := shr(96, calldataload(path.offset))
        }
        uint256 amountIn = IERC20(tokenIn).balanceOf(address(this));
        if (amountIn == 0) revert NoBalance(); // revert if amount is zero
        swapExactIn(amountIn, path);
    }
}
