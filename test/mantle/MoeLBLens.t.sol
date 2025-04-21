// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import "./DeltaSetup.f.sol";
import "../../contracts/1delta/quoter/lens/MoeJoeLens.sol";

interface ILBFactory {
    struct LBPairInformation {
        uint16 binStep;
        address LBPair;
        bool createdByOwner;
        bool ignoredForRouting;
    }

    function getLBPairInformation(address tokenX, address tokenY, uint256 binStep) external view returns (LBPairInformation memory);
}

/**
 * Tests Merchant Moe's LB Quoting for exact out to make sure that incomplete swaps
 * revert.
 */
contract MoeLBQuotingTest is DeltaSetup {
    uint256 DEFAULT_IR_MODE = 2; // variable
    MoeJoeLens lens;
    address POOL_WITH_NO_BINS = 0x37Ce36DB1d4DA489E4c95eAd59D9018CCDb21698;
    address POOL_WETH_METH = 0x3b6c029E6409f2868769871F9Ed6825b15BDca15;
    address POOL_WMNT_METH = 0xF59c79b91877c2B5909E703117Beab9B4B5df0D6;

    function setUp() public virtual override {
        vm.createSelectFork({blockNumber: 68973787, urlOrAlias: "https://mantle-mainnet.public.blastapi.io"});

        lens = new MoeJoeLens();
    }

    function test_moe_swap_out() external view {
        uint128 amountIn = 100000000000000000000000;
        uint24 aid = IMoeJoePair(POOL_WMNT_METH).getActiveId();
        console.log("AID", aid);
        (uint128 binReserveX, uint128 binReserveY) = IMoeJoePair(POOL_WMNT_METH).getBin(aid);
        console.log("binReserveX, binReserveY", binReserveX, binReserveY);
        uint256[] memory data = lens.getMoeJoeBinsWithActiveId(POOL_WMNT_METH, 15, 15);
        printData(data);
        console.log("ssss", uint112(11106836584428029669388));
        (, uint128 amountOut,) = IMoeJoePair(POOL_WMNT_METH).getSwapOut(amountIn, true);
        console.log("amount out", amountOut);
    }

    function test_mantle_get_fees() external view {
        console.log("bt", block.timestamp);
        console.log("WETHMET", IMoeJoePair(POOL_WETH_METH).getTokenX(), TokensMantle.WETH < TokensMantle.METH ? TokensMantle.WETH : TokensMantle.METH);
        {
            (
                uint16 baseFactor,
                uint16 filterPeriod,
                uint16 decayPeriod,
                uint16 reductionFactor,
                uint24 variableFeeControl,
                uint16 protocolShare,
                uint24 maxVolatilityAccumulator
            ) = IMoeJoePair(POOL_WMNT_METH).getStaticFeeParameters();
            console.log("baseFactor", baseFactor);
            console.log("filterPeriod", filterPeriod);
            console.log("decayPeriod", decayPeriod);
            console.log("reductionFactor", reductionFactor);
            console.log("variableFeeControl", variableFeeControl);
            console.log("protocolShare", protocolShare);
            console.log("maxVolatilityAccumulator", maxVolatilityAccumulator);
        }

        {
            (uint24 volatilityAccumulator, uint24 volatilityReference, uint24 idReference, uint40 timeOfLastUpdate) =
                IMoeJoePair(POOL_WMNT_METH).getVariableFeeParameters();
            console.log("volatilityAccumulator", volatilityAccumulator);
            console.log("volatilityReference", volatilityReference);
            console.log("idReference", idReference);
            console.log("timeOfLastUpdate", timeOfLastUpdate);
        }

        {
            uint24 binStep = IMoeJoePair(POOL_WMNT_METH).getBinStep();
            console.log("binStep", binStep);
        }
    }

    function test_mantle_get_bins() external view {
        uint24 fee = BIN_STEP_LOWEST;
        address pool = ILBFactory(MERCHANT_MOE_LB_FACTORY).getLBPairInformation(TokensMantle.USDe, TokensMantle.USDT, fee).LBPair;
        uint24 activeId = IMoeJoePair(pool).getActiveId();
        console.log("active", activeId);
        uint256[] memory data = lens.getMoeJoeBins(pool, activeId, 15, 15);

        printData(data);
    }

    function printData(uint256[] memory data) internal view {
        for (uint256 i = 0; i < data.length; i++) {
            uint256 entry = data[i];
            uint256 reserveY = uint112(entry);
            uint256 reserveX = uint112(entry >> 112);
            uint24 bin = uint24(entry >> 232);
            console.log("reserveX", reserveX);
            console.log("reserveY", reserveY);
            console.log("bin", bin);
        }
    }

    function test_mantle_get_bins_with_active() external view {
        uint24 fee = BIN_STEP_LOWEST;
        address pool = ILBFactory(MERCHANT_MOE_LB_FACTORY).getLBPairInformation(TokensMantle.USDe, TokensMantle.USDT, fee).LBPair;

        uint256[] memory data = lens.getMoeJoeBinsWithActiveId(pool, 15, 15);

        printData(data);
    }

    function test_mantle_get_bins_with_active_no_bins() external view {
        address pool = POOL_WITH_NO_BINS;

        uint256[] memory data = lens.getMoeJoeBinsWithActiveId(pool, 10, 10);

        for (uint256 i; i < data.length; i++) {
            uint256 entry = data[i];
            uint256 reserveY = uint112(entry);
            uint256 reserveX = uint112(entry >> 112);
            uint24 bin = uint24(entry >> 232);
            console.log("reserveX", reserveX);
            console.log("reserveY", reserveY);
            console.log("bin", bin);
        }
    }

    function test_base() external view {
        uint24 id = 8380219;
        uint16 bs = 10;

        console.log("base", getBase(bs));
        int256 e = getExponent(id);
        console.log("exponent", e > 0, e > 0 ? uint256(e) : uint256(-e));
    }

    /**
     * @dev Calculates the base from the bin step, which is `1 + binStep / BASIS_POINT_MAX`
     * @param binStep The bin step
     * @return base The base
     */
    function getBase(uint16 binStep) internal pure returns (uint256) {
        unchecked {
            return Constants.SCALE + (uint256(binStep) << Constants.SCALE_OFFSET) / Constants.BASIS_POINT_MAX;
        }
    }

    /**
     * @dev Calculates the exponent from the id, which is `id - REAL_ID_SHIFT`
     * @param id The id
     * @return exponent The exponent
     */
    function getExponent(uint24 id) internal pure returns (int256) {
        unchecked {
            return int256(uint256(id)) - REAL_ID_SHIFT;
        }
    }

    int256 private constant REAL_ID_SHIFT = 1 << 23;

    function test_exp() external view {
        uint256 x = 340622649287859401926837982039199979667;
        int256 y = -8389;
        uint256 cc = pow(x, y);
        console.log("cc", cc);
        uint256 mpx = 0;
        uint256 mpy = 340282366920938463463374607431768211456;
        (uint256 dd, uint256 ee) = _getMulProds(mpx, mpy);
        console.log("prod0, prod1", dd, ee);
        uint256 denominator = 74982764324320;
        console.log("uint256 lpotdod = denominator & (~denominator + 1);", denominator & (~denominator + 1));
    }

    uint8 internal constant SCALE_OFFSET = 128;
    uint256 internal constant SCALE = 1 << SCALE_OFFSET;

    /**
     * @notice Returns the value of x^y. It calculates `1 / x^abs(y)` if x is bigger than 2^128.
     * At the end of the operations, we invert the result if needed.
     * @param x The unsigned 128.128-binary fixed-point number for which to calculate the power
     * @param y A relative number without any decimals, needs to be between ]-2^21; 2^21[
     */
    function pow(uint256 x, int256 y) internal view returns (uint256 result) {
        bool invert;
        uint256 absY;

        if (y == 0) return SCALE;

        assembly {
            absY := y
            if slt(absY, 0) {
                absY := sub(0, absY)
                invert := iszero(invert)
            }
        }

        if (absY < 0x100000) {
            result = SCALE;
            assembly {
                let squared := x
                if gt(x, 0xffffffffffffffffffffffffffffffff) {
                    squared := div(not(0), squared)
                    invert := iszero(invert)
                }

                if and(absY, 0x1) { result := shr(128, mul(result, squared)) }
                squared := shr(128, mul(squared, squared))
                if and(absY, 0x2) { result := shr(128, mul(result, squared)) }
                squared := shr(128, mul(squared, squared))
                if and(absY, 0x4) { result := shr(128, mul(result, squared)) }
                squared := shr(128, mul(squared, squared))
                if and(absY, 0x8) { result := shr(128, mul(result, squared)) }
                squared := shr(128, mul(squared, squared))
                if and(absY, 0x10) { result := shr(128, mul(result, squared)) }
                squared := shr(128, mul(squared, squared))
                if and(absY, 0x20) { result := shr(128, mul(result, squared)) }
                squared := shr(128, mul(squared, squared))
                if and(absY, 0x40) { result := shr(128, mul(result, squared)) }
                squared := shr(128, mul(squared, squared))
                if and(absY, 0x80) { result := shr(128, mul(result, squared)) }
                squared := shr(128, mul(squared, squared))
                if and(absY, 0x100) { result := shr(128, mul(result, squared)) }
                squared := shr(128, mul(squared, squared))
                if and(absY, 0x200) { result := shr(128, mul(result, squared)) }
                squared := shr(128, mul(squared, squared))
                if and(absY, 0x400) { result := shr(128, mul(result, squared)) }
                squared := shr(128, mul(squared, squared))
                if and(absY, 0x800) { result := shr(128, mul(result, squared)) }
                squared := shr(128, mul(squared, squared))
                if and(absY, 0x1000) { result := shr(128, mul(result, squared)) }
                squared := shr(128, mul(squared, squared))
                if and(absY, 0x2000) { result := shr(128, mul(result, squared)) }
                squared := shr(128, mul(squared, squared))
                if and(absY, 0x4000) { result := shr(128, mul(result, squared)) }
                squared := shr(128, mul(squared, squared))
                if and(absY, 0x8000) { result := shr(128, mul(result, squared)) }
                squared := shr(128, mul(squared, squared))
                if and(absY, 0x10000) { result := shr(128, mul(result, squared)) }
                squared := shr(128, mul(squared, squared))
                if and(absY, 0x20000) { result := shr(128, mul(result, squared)) }
                squared := shr(128, mul(squared, squared))
                if and(absY, 0x40000) { result := shr(128, mul(result, squared)) }
                squared := shr(128, mul(squared, squared))
                if and(absY, 0x80000) { result := shr(128, mul(result, squared)) }
            }
        }
        uint256 xx;
        assembly {
            xx := not(0)
        }

        console.log("result", result, xx);
        // revert if y is too big or if x^y underflowed
        if (result == 0) revert Uint128x128Math__PowUnderflow(x, y);

        return invert ? type(uint256).max / result : result;
    }

    function _getMulProds(uint256 x, uint256 y) private pure returns (uint256 prod0, uint256 prod1) {
        // 512-bit multiply [prod1 prod0] = x * y. Compute the product mod 2^256 and mod 2^256 - 1, then use
        // use the Chinese Remainder Theorem to reconstruct the 512 bit result. The result is stored in two 256
        // variables such that product = prod1 * 2^256 + prod0.
        assembly {
            let mm := mulmod(x, y, not(0))
            prod0 := mul(x, y)
            prod1 := sub(sub(mm, prod0), lt(mm, prod0))
        }
    }

    error Uint128x128Math__PowUnderflow(uint256 x, int256 y);
}

library Constants {
    uint8 internal constant SCALE_OFFSET = 128;
    uint256 internal constant SCALE = 1 << SCALE_OFFSET;

    uint256 internal constant PRECISION = 1e18;
    uint256 internal constant SQUARED_PRECISION = PRECISION * PRECISION;

    uint256 internal constant MAX_FEE = 0.1e18; // 10%
    uint256 internal constant MAX_PROTOCOL_SHARE = 2_500; // 25% of the fee

    uint256 internal constant BASIS_POINT_MAX = 10_000;

    // (2^256 - 1) / (2 * log(2**128) / log(1.0001))
    uint256 internal constant MAX_LIQUIDITY_PER_BIN = 65251743116719673010965625540244653191619923014385985379600384103134737;

    /// @dev The expected return after a successful flash loan
    bytes32 internal constant CALLBACK_SUCCESS = keccak256("LBPair.onFlashLoan");
}
