// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import "./DeltaSetup.f.sol";
import "../../contracts/1delta/quoter/MoeJoeLens.sol";

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

    function setUp() public virtual override {
        vm.createSelectFork({blockNumber: 68932371, urlOrAlias: "https://mantle-mainnet.public.blastapi.io"});

        lens = new MoeJoeLens();
    }

    function test_mantle_get_bins() external view {
        uint24 fee = BIN_STEP_LOWEST;
        address pool = ILBFactory(MERCHANT_MOE_LB_FACTORY).getLBPairInformation(USDe, USDT, fee).LBPair;
        uint24 activeId = IMoeJoePair(pool).getActiveId();
        console.log("active", activeId);
        uint256[] memory data = lens.getMoeJoeBins(pool, activeId, 15, 15);

        for (uint i; i < data.length; i++) {
            uint entry = data[i];
            uint reserveY = uint112(entry);
            uint reserveX = uint112(entry >> 112);
            uint24 bin = uint24(entry >> 232);
            console.log("reserveX", reserveX);
            console.log("reserveY", reserveY);
            console.log("bin", bin);
        }
    }

    function test_mantle_get_bins_with_active() external view {
        uint24 fee = BIN_STEP_LOWEST;
        address pool = ILBFactory(MERCHANT_MOE_LB_FACTORY).getLBPairInformation(USDe, USDT, fee).LBPair;

        uint256[] memory data = lens.getMoeJoeBinsWithActiveId(pool, 15, 15);

        for (uint i; i < data.length; i++) {
            uint entry = data[i];
            uint reserveY = uint112(entry);
            uint reserveX = uint112(entry >> 112);
            uint24 bin = uint24(entry >> 232);
            console.log("reserveX", reserveX);
            console.log("reserveY", reserveY);
            console.log("bin", bin);
        }
    }


    function test_mantle_get_bins_with_active_no_bins() external view {
        address pool = POOL_WITH_NO_BINS;

        uint256[] memory data = lens.getMoeJoeBinsWithActiveId(pool, 10, 10);

        for (uint i; i < data.length; i++) {
            uint entry = data[i];
            uint reserveY = uint112(entry);
            uint reserveX = uint112(entry >> 112);
            uint24 bin = uint24(entry >> 232);
            console.log("reserveX", reserveX);
            console.log("reserveY", reserveY);
            console.log("bin", bin);
        }
    }


    function test_exp() external view {
        uint x = 340316395157630557309720944892511388277;
        int y = 1;
       uint cc = pow(x, y);
       console.log("cc", cc);
       uint mpx = 0;
       uint mpy =  340282366920938463463374607431768211456;
       (uint dd, uint ee) = _getMulProds(mpx, mpy);
       console.log("prod0, prod1", dd, ee);
       uint denominator = 74982764324320;
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

                if and(absY, 0x1) {
                    result := shr(128, mul(result, squared))
                }
                squared := shr(128, mul(squared, squared))
                if and(absY, 0x2) {
                    result := shr(128, mul(result, squared))
                }
                squared := shr(128, mul(squared, squared))
                if and(absY, 0x4) {
                    result := shr(128, mul(result, squared))
                }
                squared := shr(128, mul(squared, squared))
                if and(absY, 0x8) {
                    result := shr(128, mul(result, squared))
                }
                squared := shr(128, mul(squared, squared))
                if and(absY, 0x10) {
                    result := shr(128, mul(result, squared))
                }
                squared := shr(128, mul(squared, squared))
                if and(absY, 0x20) {
                    result := shr(128, mul(result, squared))
                }
                squared := shr(128, mul(squared, squared))
                if and(absY, 0x40) {
                    result := shr(128, mul(result, squared))
                }
                squared := shr(128, mul(squared, squared))
                if and(absY, 0x80) {
                    result := shr(128, mul(result, squared))
                }
                squared := shr(128, mul(squared, squared))
                if and(absY, 0x100) {
                    result := shr(128, mul(result, squared))
                }
                squared := shr(128, mul(squared, squared))
                if and(absY, 0x200) {
                    result := shr(128, mul(result, squared))
                }
                squared := shr(128, mul(squared, squared))
                if and(absY, 0x400) {
                    result := shr(128, mul(result, squared))
                }
                squared := shr(128, mul(squared, squared))
                if and(absY, 0x800) {
                    result := shr(128, mul(result, squared))
                }
                squared := shr(128, mul(squared, squared))
                if and(absY, 0x1000) {
                    result := shr(128, mul(result, squared))
                }
                squared := shr(128, mul(squared, squared))
                if and(absY, 0x2000) {
                    result := shr(128, mul(result, squared))
                }
                squared := shr(128, mul(squared, squared))
                if and(absY, 0x4000) {
                    result := shr(128, mul(result, squared))
                }
                squared := shr(128, mul(squared, squared))
                if and(absY, 0x8000) {
                    result := shr(128, mul(result, squared))
                }
                squared := shr(128, mul(squared, squared))
                if and(absY, 0x10000) {
                    result := shr(128, mul(result, squared))
                }
                squared := shr(128, mul(squared, squared))
                if and(absY, 0x20000) {
                    result := shr(128, mul(result, squared))
                }
                squared := shr(128, mul(squared, squared))
                if and(absY, 0x40000) {
                    result := shr(128, mul(result, squared))
                }
                squared := shr(128, mul(squared, squared))
                if and(absY, 0x80000) {
                    result := shr(128, mul(result, squared))
                }
            }
        }
uint xx;
assembly {
     xx:= not(0)
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
