// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.28;

interface IMoeJoePair {
    function getTokenX() external view returns (address tokenX);

    function getTokenY() external view returns (address tokenY);

    function getReserves() external view returns (uint128 reserveX, uint128 reserveY);

    function getActiveId() external view returns (uint24 activeId);

    function getBin(uint24 id) external view returns (uint128 binReserveX, uint128 binReserveY);

    function getBinStep() external pure returns (uint16);

    function getNextNonEmptyBin(bool swapForY, uint24 id) external view returns (uint24 nextId);

    function getStaticFeeParameters()
        external
        view
        returns (
            uint16 baseFactor,
            uint16 filterPeriod,
            uint16 decayPeriod,
            uint16 reductionFactor,
            uint24 variableFeeControl,
            uint16 protocolShare,
            uint24 maxVolatilityAccumulator
        );

    function getVariableFeeParameters()
        external
        view
        returns (uint24 volatilityAccumulator, uint24 volatilityReference, uint24 idReference, uint40 timeOfLastUpdate); //
    function getSwapOut(
        uint128 amountIn,
        bool swapForY
    )
        external
        view
        returns (
            uint128 amountInLeft, //
            uint128 amountOut,
            uint128 fee
        );
}

// TraderJoe/Moe bin lens contract
// fetches bin data packed [uint24 binIndex | uint112 reserveX | uint112 reserveY]
contract MoeJoeLens {
    uint256 private constant MAX_UINT24 = 16777215;
    uint256 private constant UINT112_MASK_U = 0x00000000ffffffffffffffffffffffffffff0000000000000000000000000000;
    uint256 private constant UINT24_MASK_U = 0xffffff0000000000000000000000000000000000000000000000000000000000;
    uint256 private constant UINT112_MASK = 0x000000000000000000000000000000000000ffffffffffffffffffffffffffff;

    // gets the bin data for a Moe/Joe pair assuming we already know activeId
    // uses fixed size array
    function getMoeJoeBins(address pair, uint24 activeId, uint24 maxEnvX, uint24 maxEnvY) external view returns (uint256[] memory data) {
        uint256 maxIndex = maxEnvX + maxEnvY;
        data = new uint256[](maxIndex);
        uint24 currentBin = activeId;
        // populate Y direction
        for (uint256 i; i < maxEnvX; i++) {
            currentBin = IMoeJoePair(pair).getNextNonEmptyBin(false, currentBin);
            data[i] = getAndEncodeReserves(pair, currentBin);
        }
        // populate X direction
        currentBin = activeId;
        for (uint256 i = maxEnvX; i < maxIndex; i++) {
            currentBin = IMoeJoePair(pair).getNextNonEmptyBin(true, currentBin);
            data[i] = getAndEncodeReserves(pair, currentBin);
        }
    }

    // gets the bin data for a Moe/Joe pair
    // first index includes current active id with reserves data
    // from there on it continues like `getMoeJoeBins`
    function getMoeJoeBinsWithActiveId(address pair, uint24 maxEnvX, uint24 maxEnvY) external view returns (uint256[] memory data) {
        // we allocate the maximum space needed
        uint256 maxLength = maxEnvX + maxEnvY + 2;
        data = new uint256[](maxLength);

        {
            // total reserves are the first element => bin is set to 0, encoding is the same
            (uint128 binReserveX, uint128 binReserveY) = IMoeJoePair(pair).getReserves();
            data[0] = encodeReservesAndBin(binReserveX, binReserveY, 0);
        }

        // get current active
        uint24 activeId = IMoeJoePair(pair).getActiveId();
        data[1] = getAndEncodeReserves(pair, activeId);

        // then continue as above
        uint24 currentBin = activeId;

        // we track everything through a current index
        uint256 currentIndex = 2;

        maxLength = currentIndex + maxEnvX;
        // populate Y direction
        for (; currentIndex < maxLength;) {
            currentBin = IMoeJoePair(pair).getNextNonEmptyBin(false, currentBin);
            data[currentIndex] = getAndEncodeReserves(pair, currentBin);
            currentIndex++;
            if (currentBin == 0) break;
        }

        // populate X direction
        currentBin = activeId;
        // max length will be current index plus maximum desired Y entries
        maxLength = currentIndex + maxEnvY;
        for (; currentIndex < maxLength;) {
            currentBin = IMoeJoePair(pair).getNextNonEmptyBin(true, currentBin);
            data[currentIndex] = getAndEncodeReserves(pair, currentBin);
            currentIndex++;
            if (currentBin == MAX_UINT24) break;
        }

        // set length to current index as we increment before the break
        assembly {
            mstore(data, currentIndex)
        }
    }

    function getAndEncodeReserves(address pair, uint24 id) private view returns (uint256) {
        (uint128 binReserveX, uint128 binReserveY) = IMoeJoePair(pair).getBin(id);
        return encodeReservesAndBin(binReserveX, binReserveY, id);
    }

    // encode bin data into single uint
    function encodeReservesAndBin(uint256 binReserveX, uint256 binReserveY, uint24 bin) private pure returns (uint256) {
        uint256 data = uint112(binReserveY);
        data = (data & ~UINT112_MASK_U) | (uint256(binReserveX) << 112);
        data = (data & ~UINT24_MASK_U) | (uint256(bin) << 232);
        return data;
    }
}
