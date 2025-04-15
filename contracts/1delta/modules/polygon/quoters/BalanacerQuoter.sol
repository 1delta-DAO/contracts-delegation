// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.28;

import {IVault} from "./interfaces/IVault.sol";
import "./interfaces/ICSP.sol";
import "./interfaces/IWP.sol";
import "./balancer-math/StableMath.sol";
import "./balancer-math/WeightedMath.sol";

/**
 * Balancer quoter unchecked form - will run into overflows - needs additional checks
 */
contract BalancerQuoter {
    using FixedPoint for uint256;

    address internal constant BALANCER_V2_VAULT = 0xBA12222222228d8Ba445958a75a0704d566BF2C8;

    function getAmountInCSP(bytes32 poolId, address tokenIn, address tokenOut, uint256 amountOut) external view returns (uint256) {
        (
            address[] memory tokens,
            uint256[] memory balances, //
        ) = IVault(BALANCER_V2_VAULT).getPoolTokens(poolId);

        (uint256 indexIn, uint256 indexOut) = getIndexes(tokens, tokenIn, tokenOut);
        address pool = address(uint160(uint256(poolId) >> (12 * 8)));

        return _swapGivenOutCSP(
            amountOut,
            balances,
            indexIn,
            indexOut,
            getCSPScalingFactors(pool), //
            pool
        );
    }

    function getAmountInWP(bytes32 poolId, address tokenIn, address tokenOut, uint256 amountOut) external view returns (uint256) {
        address pool = address(uint160(uint256(poolId) >> (12 * 8)));
        uint256 scalingFactorIn;
        uint256 scalingFactorOut;
        uint256 weightIn;
        uint256 weightOut;
        uint256 balanceIn;
        uint256 balanceOut;
        {
            (
                address[] memory tokens,
                uint256[] memory balances, //
            ) = IVault(BALANCER_V2_VAULT).getPoolTokens(poolId);

            (
                scalingFactorIn,
                scalingFactorOut,
                weightIn, //
                weightOut,
                balanceIn,
                balanceOut
            ) = getWPScalingFactorsWeightsAndBalances(
                tokens,
                balances, //
                tokenIn,
                tokenOut,
                pool
            );
        }

        return _swapGivenOutWP(
            balanceIn,
            weightIn,
            scalingFactorIn,
            balanceOut,
            weightOut,
            amountOut,
            scalingFactorOut, //
            pool
        );
    }

    /**
     * @dev Remove the item at `_bptIndex` from an arbitrary array (e.g., amountsIn).
     */
    function _dropBptItem(
        uint256[] memory amounts,
        uint256 bptIndex
    )
        internal
        pure
        returns (
            uint256[] memory //
        )
    {
        unchecked {
            uint256[] memory amountsWithoutBpt = new uint256[](amounts.length - 1);
            for (uint256 i; i < amountsWithoutBpt.length; i++) {
                uint256 index = i < bptIndex ? i : i + 1;
                amountsWithoutBpt[i] = amounts[index];
            }

            return amountsWithoutBpt; //, tokensWithoutBpt);
        }
    }

    function _skipBptIndex(uint256 index, uint256 bptIndex) internal pure returns (uint256) {
        return index < bptIndex ? index : index.sub(1);
    }

    function getIndexes(address[] memory tokens, address tokenIn, address tokenOut) internal pure returns (uint256 indexIn, uint256 indexOut) {
        for (uint256 i; i < tokens.length; i++) {
            address t = tokens[i];
            if (tokenIn == t) indexIn = i;
            else if (tokenOut == t) indexOut = i;
        }
    }

    function getCSPScalingFactors(address pool) internal view returns (uint256[] memory sf) {
        sf = ICSP(pool).getScalingFactors();
    }

    function getWPScalingFactorsWeightsAndBalances(
        address[] memory tokens,
        uint256[] memory balances,
        address tokenIn,
        address tokenOut,
        address pool
    )
        internal
        view
        returns (uint256 scalingFactorIn, uint256 scalingFactorOut, uint256 weightIn, uint256 weightOut, uint256 balanceIn, uint256 balanceOut)
    {
        uint256[] memory weights = IWP(pool).getNormalizedWeights();

        for (uint256 i; i < tokens.length; i++) {
            address t = tokens[i];
            if (tokenIn == t) {
                scalingFactorIn = _computeScalingFactor(t);
                weightIn = weights[i];
                balanceIn = balances[i];
            } else if (tokenOut == t) {
                scalingFactorOut = _computeScalingFactor(t);
                weightOut = weights[i];
                balanceOut = balances[i];
            }
        }
    }

    /**
     * @dev Same as `_upscale`, but for an entire array. This function does not return anything, but instead *mutates*
     * the `amounts` array.
     */
    function _upscaleArray(uint256[] memory amounts, uint256[] memory scalingFactors) internal pure {
        uint256 length = amounts.length;

        for (uint256 i; i < length; ++i) {
            amounts[i] = FixedPoint.mulDown(amounts[i], scalingFactors[i]);
        }
    }

    /**
     * @dev Same as `_downscaleDown`, but for an entire array. This function does not return anything, but instead
     * *mutates* the `amounts` array.
     */
    function _downscaleDownArray(uint256[] memory amounts, uint256[] memory scalingFactors) internal pure {
        uint256 length = amounts.length;

        for (uint256 i; i < length; ++i) {
            amounts[i] = FixedPoint.divDown(amounts[i], scalingFactors[i]);
        }
    }

    /**
     * @dev Reverses the `scalingFactor` applied to `amount`, resulting in a smaller or equal value depending on
     * whether it needed scaling or not. The result is rounded up.
     */
    function _downscaleUp(uint256 amount, uint256 scalingFactor) internal pure returns (uint256) {
        return FixedPoint.divUp(amount, scalingFactor);
    }

    function _getAmplificationParameter(address pool) internal view returns (uint256 a) {
        (a,,) = ICSP(pool).getAmplificationParameter();
    }

    /**
     * @dev Same as `_downscaleUp`, but for an entire array. This function does not return anything, but instead
     * *mutates* the `amounts` array.
     */
    function _downscaleUpArray(uint256[] memory amounts, uint256[] memory scalingFactors) internal pure {
        uint256 length = amounts.length;

        for (uint256 i; i < length; ++i) {
            amounts[i] = FixedPoint.divUp(amounts[i], scalingFactors[i]);
        }
    }

    function _computeScalingFactor(address token) internal view returns (uint256) {
        // Tokens that don't implement the `decimals` method are not supported.
        uint256 tokenDecimals = _tokenDecimals(token);

        // Tokens with more than 18 decimals are not supported.
        uint256 decimalsDifference = Math.sub(18, tokenDecimals);
        return FixedPoint.ONE * 10 ** decimalsDifference;
    }

    function _tokenDecimals(address token) internal view returns (uint256 d) {
        assembly {
            // selector for decimals()
            mstore(0, 0x313ce56700000000000000000000000000000000000000000000000000000000)
            pop(staticcall(gas(), token, 0, 0x4, 0, 0x20))
            d := mload(0)
        }
    }

    /**
     * @dev Subtracts swap fee amount from `amount`, returning a lower value.
     */
    function _subtractSwapFeeAmount(uint256 amount, address pool) internal view returns (uint256) {
        // This returns amount - fee amount, so we round up (favoring a higher fee amount).
        uint256 feeAmount = amount.mulUp(ICSP(pool).getSwapFeePercentage());
        return amount.sub(feeAmount);
    }

    /**
     * @dev Adds swap fee amount to `amount`, returning a higher value.
     */
    function _addSwapFeeAmount(uint256 amount, address pool) internal view returns (uint256) {
        // This returns amount + fee amount, so we round up (favoring a higher fee amount).
        return amount.divUp(ICSP(pool).getSwapFeePercentage().complement());
    }

    function _swapGivenOutCSP(
        uint256 amount,
        uint256[] memory balances,
        uint256 indexIn,
        uint256 indexOut,
        uint256[] memory scalingFactors,
        address pool
    )
        internal
        view
        returns (uint256)
    {
        _upscaleArray(balances, scalingFactors);
        amount = _upscale(amount, scalingFactors[indexOut]);

        uint256 amountIn = _onSwapGivenOutCSP(
            amount,
            balances,
            indexIn,
            indexOut,
            _getAmplificationParameter(pool), //
            pool
        );

        // amountIn tokens are entering the Pool, so we round up.
        amountIn = _downscaleUp(amountIn, scalingFactors[indexIn]);

        // Fees are added after scaling happens, to reduce the complexity of the rounding direction analysis.
        return _addSwapFeeAmount(amountIn, pool);
    }

    function _upscale(uint256 amount, uint256 scalingFactor) internal pure returns (uint256) {
        // Upscale rounding wouldn't necessarily always go in the same direction: in a swap for example the balance of
        // token in should be rounded up, and that of token out rounded down. This is the only place where we round in
        // the same direction for all amounts, as the impact of this rounding is expected to be minimal.
        return FixedPoint.mulDown(amount, scalingFactor);
    }

    /**
     * @dev This is called from the base class `_swapGivenOutCSP`, so at this point the amount has been adjusted
     * for swap fees, and balances have had scaling applied. This will only be called for regular (non-BPT) swaps,
     * so forward to `onRegularSwap`.
     */
    function _onSwapGivenOutCSP(
        uint256 amountGiven,
        uint256[] memory registeredBalances,
        uint256 registeredIndexIn,
        uint256 registeredIndexOut,
        uint256 currentAmp,
        address pool
    )
        internal
        view
        returns (uint256)
    {
        uint256 bptIdnex = ICSP(pool).getBptIndex();
        // Adjust indices and balances for BPT token
        registeredBalances = _dropBptItem(registeredBalances, bptIdnex);

        return StableMath._calcInGivenOut(
            currentAmp,
            registeredBalances, //
            _skipBptIndex(registeredIndexIn, bptIdnex),
            _skipBptIndex(registeredIndexOut, bptIdnex),
            amountGiven,
            StableMath._calculateInvariant(currentAmp, registeredBalances)
        );
    }

    function _swapGivenOutWP(
        uint256 balanceIn,
        uint256 weightIn,
        uint256 scalingIn,
        uint256 balanceOut,
        uint256 weightOut,
        uint256 amountOut,
        uint256 scalingOut,
        address pool
    )
        internal
        view
        returns (uint256)
    {
        uint256 amountIn = WeightedMath._calcInGivenOut(
            _upscale(balanceIn, scalingIn),
            weightIn,
            _upscale(balanceOut, scalingOut),
            weightOut,
            _upscale(amountOut, scalingOut) //
        );

        // amountIn tokens are entering the Pool, so we round up.
        amountIn = _downscaleUp(amountIn, scalingIn);

        // Fees are added after scaling happens, to reduce the complexity of the rounding direction analysis.
        return _addSwapFeeAmount(amountIn, pool);
    }
}
