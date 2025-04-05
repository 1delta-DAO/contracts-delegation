// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import "../../../contracts/1delta/modules/light/enums/DeltaEnums.sol";
import "../../../contracts/1delta/modules/light/enums/ForwarderEnums.sol";
import "../../../contracts/1delta/modules/light/swappers/dex/DexTypeMappings.sol";
import "../../../contracts/1delta/modules/light/swappers/callbacks/DexForkMappings.sol";

library CalldataLib {
    enum SweepType {
        VALIDATE,
        BALANCE,
        AMOUNT
    }

    enum DexPayConfig {
        CALLER_PAYS,
        CONTRACT_PAYS,
        PRE_FUND,
        FLASH
    }

    enum DodoSelector {
        SELL_BASE,
        SELL_QUOTE
    }

    // PathEdge internal constant NATIVE = PathEdge(0,0);

    function nextGenDexUnlock(address singleton, uint256 id, bytes memory d) internal pure returns (bytes memory data) {
        data = abi.encodePacked(
            uint8(ComposerCommands.GEN_2025_SINGELTONS),
            uint8(Gen2025ActionIds.UNLOCK),
            singleton, // manager address
            uint8(id), // validation Id
            uint16(d.length),
            d
        ); // swaps max index for inner path
    }

    function swapHead(uint256 amount, uint256 amountOutMin, address assetIn, bool preParam) internal pure returns (bytes memory data) {
        return
            abi.encodePacked(
                uint8(ComposerCommands.SWAPS),
                generateAmountBitmap(uint128(amount), preParam, false, false),
                uint128(amountOutMin),
                assetIn //
            );
    }

    function attachBranch(bytes memory data, uint256 hops, uint256 splits, bytes memory splitsData) internal pure returns (bytes memory) {
        if (hops != 0 && splits != 0) revert("Invalid branching");
        if (splitsData.length > 0 && splits == 0) revert("No splits but split data provided");
        return
            abi.encodePacked(
                data,
                uint8(hops),
                uint8(splits), //
                splitsData
            );
    }

    function uniswapV2StyleSwap(
        address tokenOut,
        address receiver,
        uint256 forkId,
        address pool,
        uint256 feeDenom, //
        DexPayConfig cfg,
        bytes memory flashCalldata
    ) internal pure returns (bytes memory data) {
        if (uint256(cfg) < 2 && flashCalldata.length > 2) revert("Invalid config for v2 swap");
        data = abi.encodePacked(
            tokenOut,
            receiver,
            uint8(DexTypeMappings.UNISWAP_V2_ID),
            pool,
            uint16(feeDenom), // fee denom
            uint8(forkId),
            uint16(flashCalldata.length), // cll length <- user pays
            bytes(cfg == DexPayConfig.FLASH ? flashCalldata : new bytes(0))
        );
    }

    function balancerV2StyleSwap(
        bytes memory currentData,
        address tokenOut,
        address receiver,
        bytes32 poolId,
        address balancerVault,
        DexPayConfig cfg
    ) internal pure returns (bytes memory data) {
        if (cfg == DexPayConfig.FLASH) revert("Invalid config for v2 swap");
        data = abi.encodePacked(
            currentData,
            tokenOut,
            receiver,
            uint8(DexTypeMappings.BALANCER_V2_ID),
            poolId,
            balancerVault,
            uint16(uint256(cfg)) // cll length <- user pays
        );
    }

    function lbStyleSwap(
        bytes memory currentData,
        address tokenOut,
        address receiver,
        address pool,
        bool swapForY,
        DexPayConfig cfg
    ) internal pure returns (bytes memory data) {
        if (cfg == DexPayConfig.FLASH) revert("Invalid config for v2 swap");
        data = abi.encodePacked(
            currentData,
            tokenOut,
            receiver,
            uint8(DexTypeMappings.LB_ID),
            pool,
            uint8(swapForY ? 1 : 0),
            uint16(uint256(cfg)) // cll length <- user pays
        );
    }

    function syncSwapStyleSwap(
        bytes memory currentData,
        address tokenOut,
        address receiver,
        address pool,
        DexPayConfig cfg
    ) internal pure returns (bytes memory data) {
        if (cfg == DexPayConfig.FLASH) revert("Invalid config for v2 swap");
        data = abi.encodePacked(
            currentData,
            tokenOut,
            receiver,
            uint8(DexTypeMappings.SYNC_SWAP_ID),
            pool,
            uint16(uint256(cfg)) // cll length <- user pays
        );
    }

    function uniswapV3StyleSwap(
        bytes memory currentData,
        address tokenOut,
        address receiver,
        uint256 forkId,
        address pool,
        uint256 feeTier, //
        DexPayConfig cfg,
        bytes memory flashCalldata
    ) internal pure returns (bytes memory data) {
        if (uint256(cfg) < 2 && flashCalldata.length > 2) revert("Invalid config for v2 swap");
        data = abi.encodePacked(
            currentData,
            tokenOut,
            receiver,
            uint8(DexTypeMappings.UNISWAP_V3_ID),
            pool,
            uint8(forkId),
            uint16(feeTier), // fee tier to validate pool
            uint16(cfg == DexPayConfig.FLASH ? flashCalldata.length : uint256(cfg)), //
            bytes(cfg == DexPayConfig.FLASH ? flashCalldata : new bytes(0))
        );
    }

    function uniswapV4StyleSwap(
        bytes memory currentData,
        address tokenOut,
        address receiver,
        address poolManager,
        uint256 feeTier, //
        uint256 tickSpacing, //
        address hooks, //
        DexPayConfig cfg,
        bytes memory hooksData
    ) internal pure returns (bytes memory data) {
        data = abi.encodePacked(
            currentData,
            tokenOut,
            receiver,
            uint8(DexTypeMappings.UNISWAP_V4_ID), // dexId !== poolId here
            hooks,
            poolManager,
            uint24(feeTier), // fee tier to validate pool
            uint24(tickSpacing),
            uint8(cfg),
            uint16(hooksData.length), //
            bytes(hooksData)
        );
    }

    function balancerV3StyleSwap(
        bytes memory currentData,
        address tokenOut,
        address receiver,
        address balancerV3Vault,
        address pool,
        DexPayConfig cfg,
        bytes memory poolUserData
    ) internal pure returns (bytes memory data) {
        data = abi.encodePacked(
            currentData,
            tokenOut,
            receiver,
            uint8(DexTypeMappings.BALANCER_V3_ID), // dexId !== poolId here
            pool,
            balancerV3Vault,
            uint8(cfg),
            uint16(poolUserData.length), //
            poolUserData
        );
    }

    function izumiStyleSwap(
        address tokenOut,
        address receiver,
        uint256 forkId,
        address pool,
        uint256 feeTier, //
        DexPayConfig cfg,
        bytes memory flashCalldata
    ) internal pure returns (bytes memory data) {
        if (uint256(cfg) < 2 && flashCalldata.length > 2) revert("Invalid config for v2 swap");
        data = abi.encodePacked(
            tokenOut,
            receiver,
            uint8(DexTypeMappings.IZI_ID),
            pool,
            uint8(forkId),
            uint16(feeTier), // fee tier to validate pool
            uint16(cfg == DexPayConfig.FLASH ? flashCalldata.length : uint256(cfg)), //
            bytes(cfg == DexPayConfig.FLASH ? flashCalldata : new bytes(0))
        );
    }

    function dodoStyleSwap(
        bytes memory currentData,
        address tokenOut,
        address receiver,
        address pool,
        DodoSelector selector, //
        uint256 poolId,
        DexPayConfig cfg,
        bytes memory flashCalldata
    ) internal pure returns (bytes memory data) {
        data = abi.encodePacked(
            currentData,
            tokenOut,
            receiver,
            uint8(DexTypeMappings.DODO_ID),
            pool,
            uint8(selector),
            uint16(poolId),
            uint16(cfg == DexPayConfig.FLASH ? flashCalldata.length : uint256(cfg)), //
            bytes(cfg == DexPayConfig.FLASH ? flashCalldata : new bytes(0))
        );
    }

    function wooStyleSwap(
        bytes memory currentData,
        address tokenOut,
        address receiver,
        address pool,
        DexPayConfig cfg
    ) internal pure returns (bytes memory data) {
        if (cfg == DexPayConfig.FLASH) revert("No flash for Woo");
        data = abi.encodePacked(
            currentData,
            tokenOut,
            receiver,
            uint8(DexTypeMappings.WOO_FI_ID),
            pool,
            uint16(uint256(cfg)) //
        );
    }

    function gmxStyleSwap(
        bytes memory currentData,
        address tokenOut,
        address receiver,
        address pool,
        DexPayConfig cfg
    ) internal pure returns (bytes memory data) {
        if (cfg == DexPayConfig.FLASH) revert("No flash for Woo");
        data = abi.encodePacked(
            currentData,
            tokenOut,
            receiver,
            uint8(DexTypeMappings.GMX_ID),
            pool,
            uint16(uint256(cfg)) //
        );
    }

    function curveStyleSwap(
        address tokenOut,
        address receiver,
        address pool,
        uint256 indexIn, //
        uint256 indexOut, //
        uint256 selectorId, //
        DexPayConfig cfg
    ) internal pure returns (bytes memory data) {
        if (cfg == DexPayConfig.FLASH) revert("Flash not yet supported for Curve");
        data = abi.encodePacked(
            tokenOut,
            receiver,
            uint8(DexTypeMappings.CURVE_V1_STANDARD_ID),
            pool,
            uint8(indexIn),
            uint8(indexOut),
            uint8(selectorId), // fee tier to validate pool
            uint16(uint256(cfg)) //
        );
    }

    function curveNGStyleSwap(
        address tokenOut,
        address receiver,
        address pool,
        uint256 indexIn, //
        uint256 indexOut, //
        uint256 selectorId, //
        DexPayConfig cfg
    ) internal pure returns (bytes memory data) {
        if (cfg == DexPayConfig.FLASH) revert("Flash not yet supported for Curve");
        data = abi.encodePacked(
            tokenOut,
            receiver,
            uint8(DexTypeMappings.CURVE_RECEIVED_ID),
            pool,
            uint8(indexIn),
            uint8(indexOut),
            uint8(selectorId), // fee tier to validate pool
            uint16(uint256(cfg)) //
        );
    }

    function nextGenDexSettle(address singleton, uint256 nativeAmount) internal pure returns (bytes memory data) {
        data = abi.encodePacked(
            uint8(ComposerCommands.GEN_2025_SINGELTONS),
            uint8(Gen2025ActionIds.UNI_V4_SETTLE),
            singleton,
            uint128(nativeAmount) // manager address
        ); // swaps max index for inner path
    }

    function nextGenDexSettleBalancer(address singleton, address asset, uint256 amountHint) internal pure returns (bytes memory data) {
        data = abi.encodePacked(
            uint8(ComposerCommands.GEN_2025_SINGELTONS),
            uint8(Gen2025ActionIds.BAL_V3_SETTLE),
            singleton,
            asset,
            uint128(amountHint) // manager address
        ); // swaps max index for inner path
    }

    function transferIn(address asset, address receiver, uint256 amount) internal pure returns (bytes memory data) {
        data = abi.encodePacked(
            uint8(ComposerCommands.TRANSFERS),
            uint8(TransferIds.TRANSFER_FROM),
            asset,
            receiver,
            uint112(amount) //
        ); // 2 + 20 + 20 + 14 = 56 bytes
    }

    function sweep(address asset, address receiver, uint256 amount, SweepType sweepType) internal pure returns (bytes memory data) {
        data = abi.encodePacked(
            uint8(ComposerCommands.TRANSFERS),
            uint8(TransferIds.SWEEP),
            asset,
            receiver,
            sweepType,
            uint112(amount) //
        ); // 2 + 20 + 20 + 14 = 56 bytes
    }

    function wrap(uint256 amount) internal pure returns (bytes memory data) {
        data = abi.encodePacked(
            uint8(ComposerCommands.TRANSFERS),
            uint8(TransferIds.WRAP_NATIVE),
            uint112(amount) //
        ); // 14 bytes
    }

    function unwrap(address receiver, uint256 amount, SweepType sweepType) internal pure returns (bytes memory data) {
        data = abi.encodePacked(
            uint8(ComposerCommands.TRANSFERS),
            uint8(TransferIds.UNWRAP_WNATIVE),
            receiver,
            sweepType,
            uint112(amount) //
        ); // 14 bytes
    }

    function encodeFlashLoan(
        address asset,
        uint256 amount,
        address pool,
        uint8 poolType,
        uint8 poolId, //
        bytes memory data
    ) internal pure returns (bytes memory) {
        return
            abi.encodePacked(
                uint8(ComposerCommands.FLASH_LOAN),
                uint8(poolType),
                poolId,
                asset, //
                pool,
                uint112(amount),
                uint16(data.length),
                data
            );
    }

    function morphoDepositCollateral(
        bytes memory market,
        uint256 assets,
        address receiver,
        bytes memory data, //
        address morphoB
    ) internal pure returns (bytes memory) {
        return
            abi.encodePacked(
                uint8(ComposerCommands.LENDING), // 1
                uint8(LenderOps.DEPOSIT), // 1
                uint16(LenderIds.UP_TO_MORPHO), // 2
                market, // 4 * 20 + 16
                uint128(assets), // 16
                receiver,
                morphoB,
                uint16(data.length), // 2 @ 1 + 4*20
                data
            );
    }

    function morphoDeposit(
        bytes memory market,
        bool isShares, //
        uint256 assets,
        address receiver,
        bytes memory data,
        address morphoB
    ) internal pure returns (bytes memory) {
        return
            abi.encodePacked(
                uint8(ComposerCommands.LENDING), // 1
                uint8(LenderOps.DEPOSIT_LENDING_TOKEN), // 1
                uint16(LenderIds.UP_TO_MORPHO), // 2
                market, // 4 * 20 + 16
                generateAmountBitmap(uint128(assets), false, isShares, false),
                receiver,
                morphoB,
                uint16(data.length), // 2 @ 1 + 4*20
                data
            );
    }

    function erc4646Deposit(
        address asset,
        address vault,
        bool isShares, //
        uint256 assets,
        address receiver
    ) internal pure returns (bytes memory) {
        return
            abi.encodePacked(
                uint8(ComposerCommands.ERC4646), // 1
                uint8(0), // 1
                asset, // 20
                vault, // 20
                generateAmountBitmap(uint128(assets), false, isShares, false),
                receiver // 20
            );
    }

    function erc4646Withdraw(
        address vault,
        bool isShares, //
        uint256 assets,
        address receiver
    ) internal pure returns (bytes memory) {
        return
            abi.encodePacked(
                uint8(ComposerCommands.ERC4646), // 1
                uint8(1), // 1
                vault, // 20
                generateAmountBitmap(uint128(assets), false, isShares, false),
                receiver // 20
            );
    }

    function morphoWithdraw(
        bytes memory market,
        bool isShares, //
        uint256 assets,
        address receiver,
        address morphoB
    ) internal pure returns (bytes memory) {
        return
            abi.encodePacked(
                uint8(ComposerCommands.LENDING), // 1
                uint8(LenderOps.WITHDRAW_LENDING_TOKEN), // 1
                uint16(LenderIds.UP_TO_MORPHO), // 2
                market, // 4 * 20 + 16
                generateAmountBitmap(uint128(assets), false, isShares, false),
                receiver, // 20
                morphoB
            );
    }

    function morphoWithdrawCollateral(
        bytes memory market, //
        uint256 assets,
        address receiver,
        address morphoB
    ) internal pure returns (bytes memory) {
        return
            abi.encodePacked(
                uint8(ComposerCommands.LENDING), // 1
                uint8(LenderOps.WITHDRAW), // 1
                uint16(LenderIds.UP_TO_MORPHO), // 2
                market, // 4 * 20 + 16
                uint128(assets), // 16
                receiver, // 20
                morphoB
            );
    }

    function morphoBorrow(
        bytes memory market,
        bool isShares, //
        uint256 assets,
        address receiver,
        address morphoB
    ) internal pure returns (bytes memory) {
        return
            abi.encodePacked(
                uint8(ComposerCommands.LENDING), // 1
                uint8(LenderOps.BORROW), // 1
                uint16(LenderIds.UP_TO_MORPHO), // 2
                market, // 4 * 20 + 16
                generateAmountBitmap(uint128(assets), false, isShares, false),
                receiver,
                morphoB
            );
    }

    function morphoRepay(
        bytes memory market,
        bool isShares, //
        bool unsafe,
        uint256 assets,
        address receiver,
        bytes memory data,
        address morphoB
    ) internal pure returns (bytes memory) {
        return
            abi.encodePacked(
                uint8(ComposerCommands.LENDING), // 1
                uint8(LenderOps.REPAY), // 1
                uint16(LenderIds.UP_TO_MORPHO), // 2
                market, // 4 * 20 + 16
                generateAmountBitmap(uint128(assets), false, isShares, unsafe),
                receiver,
                morphoB,
                uint16(data.length), // 2 @ 1 + 4*20
                data
            );
    }

    function encodeAaveDeposit(
        address token,
        bool overrideAmount,
        uint256 amount,
        address receiver,
        address pool
    ) internal pure returns (bytes memory) {
        return
            abi.encodePacked(
                uint8(ComposerCommands.LENDING),
                uint8(LenderOps.DEPOSIT),
                uint16(LenderIds.UP_TO_AAVE_V3 - 1),
                token,
                setOverrideAmount(amount, overrideAmount),
                receiver,
                pool //
            );
    }

    function encodeAaveBorrow(
        address token,
        bool overrideAmount,
        uint256 amount,
        address receiver,
        uint256 mode,
        address pool
    ) internal pure returns (bytes memory) {
        return
            abi.encodePacked(
                uint8(ComposerCommands.LENDING),
                uint8(LenderOps.BORROW),
                uint16(LenderIds.UP_TO_AAVE_V3 - 1),
                token,
                setOverrideAmount(amount, overrideAmount),
                receiver,
                uint8(mode),
                pool //
            );
    }

    function encodeAaveRepay(
        address token,
        bool overrideAmount,
        uint256 amount,
        address receiver,
        uint256 mode,
        address dToken,
        address pool
    ) internal pure returns (bytes memory) {
        return
            abi.encodePacked(
                uint8(ComposerCommands.LENDING),
                uint8(LenderOps.REPAY),
                uint16(LenderIds.UP_TO_AAVE_V3 - 1),
                token,
                setOverrideAmount(amount, overrideAmount),
                receiver,
                uint8(mode),
                dToken,
                pool //
            );
    }

    function encodeAaveWithdraw(
        address token,
        bool overrideAmount,
        uint256 amount,
        address receiver,
        address aToken,
        address pool
    ) internal pure returns (bytes memory) {
        return
            abi.encodePacked(
                uint8(ComposerCommands.LENDING),
                uint8(LenderOps.WITHDRAW),
                uint16(LenderIds.UP_TO_AAVE_V3 - 1),
                token,
                setOverrideAmount(amount, overrideAmount),
                receiver,
                aToken,
                pool //
            );
    }

    function encodeAaveV2Deposit(
        address token,
        bool overrideAmount,
        uint256 amount,
        address receiver,
        address pool
    ) internal pure returns (bytes memory) {
        return
            abi.encodePacked(
                uint8(ComposerCommands.LENDING),
                uint8(LenderOps.DEPOSIT),
                uint16(LenderIds.UP_TO_AAVE_V2 - 1),
                token,
                setOverrideAmount(amount, overrideAmount),
                receiver,
                pool //
            );
    }

    function encodeAaveV2Borrow(
        address token,
        bool overrideAmount,
        uint256 amount,
        address receiver,
        uint256 mode,
        address pool
    ) internal pure returns (bytes memory) {
        return
            abi.encodePacked(
                uint8(ComposerCommands.LENDING),
                uint8(LenderOps.BORROW),
                uint16(LenderIds.UP_TO_AAVE_V2 - 1),
                token,
                setOverrideAmount(amount, overrideAmount),
                receiver,
                uint8(mode),
                pool //
            );
    }

    function encodeAaveV2Repay(
        address token,
        bool overrideAmount,
        uint256 amount,
        address receiver,
        uint256 mode,
        address dToken,
        address pool
    ) internal pure returns (bytes memory) {
        return
            abi.encodePacked(
                uint8(ComposerCommands.LENDING),
                uint8(LenderOps.REPAY),
                uint16(LenderIds.UP_TO_AAVE_V2 - 1),
                token,
                setOverrideAmount(amount, overrideAmount),
                receiver,
                uint8(mode),
                dToken,
                pool //
            );
    }

    function encodeAaveV2Withdraw(
        address token,
        bool overrideAmount,
        uint256 amount,
        address receiver,
        address aToken,
        address pool
    ) internal pure returns (bytes memory) {
        return
            abi.encodePacked(
                uint8(ComposerCommands.LENDING),
                uint8(LenderOps.WITHDRAW),
                uint16(LenderIds.UP_TO_AAVE_V2 - 1),
                token,
                setOverrideAmount(amount, overrideAmount),
                receiver,
                aToken,
                pool //
            );
    }

    function encodeCompoundV3Deposit(
        address token,
        bool overrideAmount,
        uint256 amount,
        address receiver,
        address comet
    ) internal pure returns (bytes memory) {
        return
            abi.encodePacked(
                uint8(ComposerCommands.LENDING),
                uint8(LenderOps.DEPOSIT),
                uint16(LenderIds.UP_TO_COMPOUND_V3 - 1),
                token,
                setOverrideAmount(amount, overrideAmount),
                receiver,
                comet //
            );
    }

    function encodeCompoundV3Borrow(
        address token,
        bool overrideAmount,
        uint256 amount,
        address receiver,
        address comet
    ) internal pure returns (bytes memory) {
        return
            abi.encodePacked(
                uint8(ComposerCommands.LENDING),
                uint8(LenderOps.BORROW),
                uint16(LenderIds.UP_TO_COMPOUND_V3 - 1),
                token,
                setOverrideAmount(amount, overrideAmount),
                receiver,
                comet //
            );
    }

    function encodeCompoundV3Repay(
        address token,
        bool overrideAmount,
        uint256 amount,
        address receiver,
        address comet
    ) internal pure returns (bytes memory) {
        return
            abi.encodePacked(
                uint8(ComposerCommands.LENDING),
                uint8(LenderOps.REPAY),
                uint16(LenderIds.UP_TO_COMPOUND_V3 - 1),
                token,
                setOverrideAmount(amount, overrideAmount),
                receiver,
                comet //
            );
    }

    function encodeCompoundV3Withdraw(
        address token,
        bool overrideAmount,
        uint256 amount,
        address receiver,
        address comet,
        bool isBase
    ) internal pure returns (bytes memory) {
        return
            abi.encodePacked(
                uint8(ComposerCommands.LENDING),
                uint8(LenderOps.WITHDRAW),
                uint16(LenderIds.UP_TO_COMPOUND_V3 - 1),
                token,
                setOverrideAmount(amount, overrideAmount),
                receiver,
                isBase ? uint8(1) : uint8(0),
                comet //
            );
    }

    function encodeCompoundV2Deposit(
        address token,
        bool overrideAmount,
        uint256 amount,
        address receiver,
        address cToken
    ) internal pure returns (bytes memory) {
        return
            abi.encodePacked(
                uint8(ComposerCommands.LENDING),
                uint8(LenderOps.DEPOSIT),
                uint16(LenderIds.UP_TO_COMPOUND_V2 - 1),
                token,
                setOverrideAmount(amount, overrideAmount),
                receiver,
                cToken //
            );
    }

    function encodeCompoundV2Borrow(
        address token,
        bool overrideAmount,
        uint256 amount,
        address receiver,
        address cToken
    ) internal pure returns (bytes memory) {
        return
            abi.encodePacked(
                uint8(ComposerCommands.LENDING),
                uint8(LenderOps.BORROW),
                uint16(LenderIds.UP_TO_COMPOUND_V2 - 1),
                token,
                setOverrideAmount(amount, overrideAmount),
                receiver,
                cToken //
            );
    }

    function encodeCompoundV2Repay(
        address token,
        bool overrideAmount,
        uint256 amount,
        address receiver,
        address cToken
    ) internal pure returns (bytes memory) {
        return
            abi.encodePacked(
                uint8(ComposerCommands.LENDING),
                uint8(LenderOps.REPAY),
                uint16(LenderIds.UP_TO_COMPOUND_V2 - 1),
                token,
                setOverrideAmount(amount, overrideAmount),
                receiver,
                cToken //
            );
    }

    function encodeCompoundV2Withdraw(
        address token,
        bool overrideAmount,
        uint256 amount,
        address receiver,
        address cToken
    ) internal pure returns (bytes memory) {
        return
            abi.encodePacked(
                uint8(ComposerCommands.LENDING),
                uint8(LenderOps.WITHDRAW),
                uint16(LenderIds.UP_TO_COMPOUND_V2 - 1),
                token,
                setOverrideAmount(amount, overrideAmount),
                receiver,
                cToken //
            );
    }

    /// @dev Mask for using the injected amount
    uint256 private constant _PRE_PARAM = 1 << 127;
    /// @dev Mask for shares
    uint256 private constant _SHARES_MASK = 1 << 126;
    /// @dev Mask for morpho using unsafe repay
    uint256 internal constant _UNSAFE_AMOUNT = 1 << 125;

    function generateAmountBitmap(uint128 amount, bool preParam, bool useShares, bool unsafe) internal pure returns (uint128 am) {
        am = amount;
        if (preParam) am = uint128((am & ~_PRE_PARAM) | _PRE_PARAM); // sets the first bit to 1
        if (useShares) am = uint128((am & ~_SHARES_MASK) | _SHARES_MASK); // sets the second bit to 1
        if (unsafe) am = uint128((am & ~_UNSAFE_AMOUNT) | _UNSAFE_AMOUNT); // sets the third bit to 1
        return am;
    }

    function setOverrideAmount(uint256 amount, bool preParam) internal pure returns (uint128 am) {
        am = uint128(amount);
        if (preParam) am = uint128((am & ~_PRE_PARAM) | (1 << 127));
        return am;
    }
}
