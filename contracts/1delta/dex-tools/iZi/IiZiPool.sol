// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.4;

interface IiZiSwapPool {
    function addLimOrderWithX(
        address recipient,
        int24 point,
        uint128 amountX,
        bytes calldata data
    ) external returns (uint128 orderX, uint128 acquireY);

    function addLimOrderWithY(
        address recipient,
        int24 point,
        uint128 amountY,
        bytes calldata data
    ) external returns (uint128 orderY, uint128 acquireX);

    function collectLimOrder(
        address recipient,
        int24 point,
        uint128 collectDec,
        uint128 collectEarn,
        bool isEarnY
    ) external returns (uint128 actualCollectDec, uint128 actualCollectEarn);

    function mint(
        address recipient,
        int24 leftPt,
        int24 rightPt,
        uint128 liquidDelta,
        bytes calldata data
    ) external returns (uint256 amountX, uint256 amountY);

    function burn(int24 leftPt, int24 rightPt, uint128 liquidDelta) external returns (uint256 amountX, uint256 amountY);

    function collect(
        address recipient,
        int24 leftPt,
        int24 rightPt,
        uint256 amountXLim,
        uint256 amountYLim
    ) external returns (uint256 actualAmountX, uint256 actualAmountY);

    function swapY2X(
        address recipient,
        uint128 amount,
        int24 highPt,
        bytes calldata data
    ) external returns (uint256 amountX, uint256 amountY);

    function swapY2XDesireX(
        address recipient,
        uint128 desireX,
        int24 highPt,
        bytes calldata data
    ) external returns (uint256 amountX, uint256 amountY);

    function swapX2Y(
        address recipient,
        uint128 amount,
        int24 lowPt,
        bytes calldata data
    ) external returns (uint256 amountX, uint256 amountY);

    function swapX2YDesireY(
        address recipient,
        uint128 desireY,
        int24 lowPt,
        bytes calldata data
    ) external returns (uint256 amountX, uint256 amountY);

    function sqrtRate_96() external view returns (uint160);

    function state()
        external
        view
        returns (
            uint160 sqrtPrice_96,
            int24 currentPoint,
            uint16 observationCurrentIndex,
            uint16 observationQueueLen,
            uint16 observationNextQueueLen,
            bool locked,
            uint128 liquidity,
            uint128 liquidityX
        );

    function limitOrderData(
        int24 point
    )
        external
        view
        returns (
            uint128 sellingX,
            uint128 earnY,
            uint256 accEarnY,
            uint256 legacyAccEarnY,
            uint128 legacyEarnY,
            uint128 sellingY,
            uint128 earnX,
            uint128 legacyEarnX,
            uint256 accEarnX,
            uint256 legacyAccEarnX
        );

    function orderOrEndpoint(int24 point) external returns (int24 val);

    function observations(uint256 index) external view returns (uint32 timestamp, int56 accPoint, bool init);

    function points(
        int24 point
    ) external view returns (uint128 liquidSum, int128 liquidDelta, uint256 accFeeXOut_128, uint256 accFeeYOut_128, bool isEndpt);

    function pointBitmap(int16 wordPosition) external view returns (uint256);

    function observe(uint32[] calldata secondsAgos) external view returns (int56[] memory accPoints);

    function expandObservationQueue(uint16 newNextQueueLen) external;

    function flash(address recipient, uint256 amountX, uint256 amountY, bytes calldata data) external;

    function liquiditySnapshot(int24 leftPoint, int24 rightPoint) external view returns (int128[] memory deltaLiquidities);

    struct LimitOrderStruct {
        uint128 sellingX;
        uint128 earnY;
        uint256 accEarnY;
        uint128 sellingY;
        uint128 earnX;
        uint256 accEarnX;
    }

    function limitOrderSnapshot(int24 leftPoint, int24 rightPoint) external view returns (LimitOrderStruct[] memory limitOrders);

    function totalFeeXCharged() external view returns (uint256);

    function totalFeeYCharged() external view returns (uint256);

    function feeChargePercent() external view returns (uint24);

    function collectFeeCharged() external;

    function modifyFeeChargePercent(uint24 newFeeChargePercent) external;
}
