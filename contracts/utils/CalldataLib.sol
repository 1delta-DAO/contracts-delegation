// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.34;

import "contracts/1delta/composer/enums/DeltaEnums.sol";
import {SweepType} from "contracts/1delta/composer/enums/MiscEnums.sol";

// solhint-disable max-line-length

/**
 * Calldatalib do and don't:
 * - Don't nest abi.encodePacked calls, create a helper function to encode the inner encode call
 * - Return the encoded data directly (return abi.encodePacked(...)), don't assign to a variable
 * - Don't use structs
 * - Add enums in separate files (e.g DeltaEnums, ForwarderEnums, ...)
 * - use if condition to revert (no require statements)
 */
library CalldataLib {
    function encodeExternalCall(
        address target,
        uint256 value,
        bool useSelfBalance,
        bytes memory data
    )
        internal
        pure
        returns (bytes memory)
    {
        return abi.encodePacked(
            uint8(ComposerCommands.EXT_CALL),
            target,
            generateAmountBitmap(uint128(value), false, useSelfBalance),
            uint16(data.length),
            data
        );
    }

    function encodeTryExternalCall(
        address target,
        uint256 value,
        bool useSelfBalance,
        bool rOnFailure,
        bytes memory data,
        bytes memory catchData
    )
        internal
        pure
        returns (bytes memory)
    {
        return abi.encodePacked(
            uint8(ComposerCommands.EXT_TRY_CALL),
            target,
            generateAmountBitmap(uint128(value), false, useSelfBalance),
            uint16(data.length),
            data,
            uint8(rOnFailure ? 0 : 1),
            uint16(catchData.length),
            catchData
        );
    }

    function encodeExternalCallWithReplace(
        address target,
        uint256 value,
        bool useSelfBalance,
        address token,
        uint16 replaceOffset,
        bytes memory data
    )
        internal
        pure
        returns (bytes memory)
    {
        return abi.encodePacked(
            uint8(ComposerCommands.EXT_CALL_WITH_REPLACE),
            target,
            generateAmountBitmap(uint128(value), false, useSelfBalance),
            token,
            replaceOffset,
            uint16(data.length),
            data
        );
    }

    function encodeTryExternalCallWithReplace(
        address target,
        uint256 value,
        bool useSelfBalance,
        address token,
        uint16 replaceOffset,
        bytes memory data,
        bool rOnFailure,
        bytes memory catchData
    )
        internal
        pure
        returns (bytes memory)
    {
        return abi.encodePacked(
            uint8(ComposerCommands.EXT_TRY_CALL_WITH_REPLACE),
            target,
            generateAmountBitmap(uint128(value), false, useSelfBalance),
            token,
            replaceOffset,
            uint16(data.length),
            uint8(rOnFailure ? 0 : 1),
            uint16(catchData.length),
            data,
            catchData
        );
    }
    // StargateV2 bridging

    function encodeStargateV2Bridge(
        address asset,
        address stargatePool,
        uint32 dstEid,
        bytes32 receiver,
        address refundReceiver,
        uint256 amount,
        uint32 slippage,
        uint256 fee,
        bool isBusMode,
        bool isNative,
        bytes memory composeMsg,
        bytes memory extraOptions
    )
        internal
        pure
        returns (bytes memory)
    {
        bytes memory partialData = encodeStargateV2BridgePartial(
            amount,
            slippage, //
            fee,
            isBusMode,
            isNative,
            composeMsg,
            extraOptions
        );
        return abi.encodePacked(
            uint8(ComposerCommands.BRIDGING),
            uint8(BridgeIds.STARGATE_V2),
            asset,
            stargatePool,
            dstEid,
            receiver,
            refundReceiver,
            partialData
        );
    }

    function encodePermit(uint256 permitId, address target, bytes memory data) internal pure returns (bytes memory) {
        return abi.encodePacked(uint8(ComposerCommands.PERMIT), uint8(permitId), target, uint16(data.length), data);
    }

    function encodeStargateV2BridgePartial(
        uint256 amount,
        uint32 slippage,
        uint256 fee,
        bool isBusMode,
        bool isNative,
        bytes memory composeMsg,
        bytes memory extraOptions
    )
        internal
        pure
        returns (bytes memory)
    {
        return abi.encodePacked(
            generateAmountBitmap(uint128(amount), false, isNative),
            slippage,
            uint128(fee),
            uint8(isBusMode ? 1 : 0),
            uint16(composeMsg.length),
            uint16(extraOptions.length), //
            composeMsg,
            extraOptions
        );
    }

    function encodeStargateV2BridgeSimpleTaxi(
        address asset,
        address stargatePool,
        uint32 dstEid,
        bytes32 receiver,
        address refundReceiver,
        uint256 amount,
        bool isNative,
        uint32 slippage,
        uint256 fee
    )
        internal
        pure
        returns (bytes memory)
    {
        return encodeStargateV2Bridge(
            asset,
            stargatePool,
            dstEid,
            receiver,
            refundReceiver,
            amount,
            slippage,
            fee,
            false, // taxi mode
            isNative,
            new bytes(0), // no compose message
            new bytes(0) // no extra options
        );
    }

    function encodeStargateV2BridgeSimpleBus(
        address asset,
        address stargatePool,
        uint32 dstEid,
        bytes32 receiver,
        address refundReceiver,
        uint256 amount,
        bool isNative,
        uint32 slippage,
        uint256 fee
    )
        internal
        pure
        returns (bytes memory)
    {
        return encodeStargateV2Bridge(
            asset,
            stargatePool,
            dstEid,
            receiver,
            refundReceiver,
            amount,
            slippage,
            fee,
            true, // bus mode
            isNative,
            new bytes(0), // no compose message
            new bytes(0) // no extra options
        );
    }

    // Across
    function encodeAcrossBridgeToken(
        address spokePool,
        address depositor,
        address sendingAssetId,
        bytes32 receivingAssetId,
        uint256 amount,
        uint128 fixedFee,
        uint32 feePercentage,
        uint32 destinationChainId,
        uint8 fromTokenDecimals,
        uint8 toTokenDecimals,
        bytes32 receiver,
        uint32 deadline,
        bytes memory message
    )
        internal
        pure
        returns (bytes memory)
    {
        return abi.encodePacked(
            encodeAcrossHeader(spokePool, depositor, sendingAssetId, receivingAssetId, amount, false),
            encodeAcrossParams(
                fixedFee, feePercentage, destinationChainId, fromTokenDecimals, toTokenDecimals, receiver, deadline, message
            )
        );
    }

    function encodeAcrossBridgeNative(
        address spokePool,
        address depositor,
        address sendingAssetId,
        bytes32 receivingAssetId,
        uint256 amount,
        uint128 fixedFee,
        uint32 feePercentage,
        uint32 destinationChainId,
        uint8 fromTokenDecimals,
        uint8 toTokenDecimals,
        bytes32 receiver,
        uint32 deadline,
        bytes memory message
    )
        internal
        pure
        returns (bytes memory)
    {
        return abi.encodePacked(
            encodeAcrossHeader(spokePool, depositor, sendingAssetId, receivingAssetId, amount, true),
            encodeAcrossParams(
                fixedFee, feePercentage, destinationChainId, fromTokenDecimals, toTokenDecimals, receiver, deadline, message
            )
        );
    }

    function encodeAcrossHeader(
        address spokePool,
        address depositor,
        address sendingAssetId,
        bytes32 receivingAssetId,
        uint256 amount,
        bool isNative
    )
        internal
        pure
        returns (bytes memory)
    {
        return abi.encodePacked(
            uint8(ComposerCommands.BRIDGING),
            uint8(BridgeIds.ACROSS),
            spokePool,
            depositor,
            sendingAssetId,
            receivingAssetId,
            generateAmountBitmap(uint128(amount), false, isNative)
        );
    }

    function encodeAcrossParams(
        uint128 fixedFee,
        uint32 feePercentage,
        uint32 destinationChainId,
        uint8 fromTokenDecimals,
        uint8 toTokenDecimals,
        bytes32 receiver,
        uint32 deadline,
        bytes memory message
    )
        internal
        pure
        returns (bytes memory)
    {
        return abi.encodePacked(
            fixedFee,
            feePercentage,
            destinationChainId,
            fromTokenDecimals,
            toTokenDecimals,
            receiver,
            deadline,
            uint16(message.length),
            message
        );
    }

    function encodeSquidRouterCall(
        address asset,
        address gateway,
        bytes memory bridgedTokenSymbol,
        uint256 amount,
        bytes memory destinationChain,
        bytes memory destinationAddress,
        bytes memory payload,
        address gasRefundRecipient,
        bool enableExpress,
        uint256 nativeAmount
    )
        internal
        pure
        returns (bytes memory)
    {
        bytes memory partialData = encodeSquidRouterCallPartial(
            asset, gateway, bridgedTokenSymbol, amount, destinationChain, destinationAddress, payload
        );
        return abi.encodePacked(
            partialData,
            uint128(nativeAmount),
            gasRefundRecipient,
            uint8(enableExpress ? 1 : 0),
            bridgedTokenSymbol,
            destinationChain,
            destinationAddress,
            payload
        );
    }

    function encodeSquidRouterCallPartial(
        address asset,
        address gateway,
        bytes memory bridgedTokenSymbol,
        uint256 amount,
        bytes memory destinationChain,
        bytes memory destinationAddress,
        bytes memory payload
    )
        internal
        pure
        returns (bytes memory)
    {
        return abi.encodePacked(
            uint8(ComposerCommands.BRIDGING),
            uint8(BridgeIds.SQUID_ROUTER),
            gateway,
            asset,
            uint16(bridgedTokenSymbol.length),
            uint16(destinationChain.length),
            uint16(destinationAddress.length),
            uint16(payload.length),
            uint128(amount)
        );
    }

    function encodeGasZipBridge(
        address gasZipRouter,
        bytes32 receiver,
        uint256 amount,
        uint256 destinationChainId
    )
        internal
        pure
        returns (bytes memory)
    {
        return abi.encodePacked(
            uint8(ComposerCommands.BRIDGING), uint8(BridgeIds.GASZIP), gasZipRouter, receiver, uint128(amount), destinationChainId
        );
    }

    function encodeGasZipEvmBridge(
        address gasZipRouter,
        address receiver,
        uint256 amount,
        uint256 destinationChainId
    )
        internal
        pure
        returns (bytes memory)
    {
        return abi.encodePacked(
            uint8(ComposerCommands.BRIDGING),
            uint8(BridgeIds.GASZIP),
            gasZipRouter,
            rightPadZero(receiver),
            uint128(amount),
            destinationChainId
        );
    }

    //
    function encodePermit2TransferFrom(address token, address receiver, uint256 amount) internal pure returns (bytes memory) {
        return abi.encodePacked(
            uint8(ComposerCommands.TRANSFERS), uint8(TransferIds.PERMIT2_TRANSFER_FROM), token, receiver, uint128(amount)
        );
    }

    // PathEdge internal constant NATIVE = PathEdge(0,0);

    function encodeNextGenDexUnlock(address singleton, uint256 id, bytes memory d) internal pure returns (bytes memory) {
        return abi.encodePacked(
            uint8(ComposerCommands.GEN_2025_SINGELTONS),
            uint8(Gen2025ActionIds.UNLOCK),
            singleton, // manager address
            uint16(d.length + 1),
            uint8(id),
            d
        ); // swaps max index for inner path
    }

    function encodeBalancerV3FlashLoan(
        address singleton,
        uint256 poolId,
        address asset,
        address receiver,
        uint256 amount, //
        bytes memory flashData
    )
        internal
        pure
        returns (bytes memory)
    {
        bytes memory take = encodeBalancerV3Take(singleton, asset, receiver, amount);
        bytes memory settle = encodeNextGenDexSettleBalancer(singleton, asset, amount);
        return encodeNextGenDexUnlock(singleton, poolId, encodeBalancerV3FlashLoanData(take, flashData, settle));
    }

    function encodeBalancerV3FlashLoanData(
        bytes memory take,
        bytes memory flashData,
        bytes memory settle
    )
        internal
        pure
        returns (bytes memory)
    {
        return abi.encodePacked(take, flashData, settle);
    }

    function encodeUniswapV4FlashLoan(
        address singleton,
        uint256 poolId,
        address asset,
        address receiver,
        uint256 amount, //
        bytes memory flashData
    )
        internal
        pure
        returns (bytes memory)
    {
        bytes memory take = encodeUniswapV4Take(singleton, asset, receiver, amount);
        bytes memory settle = encodeNextGenDexSettle(singleton, asset == address(0) ? amount : 0);
        bytes memory sync = encodeUniswapV4Sync(singleton, asset);
        return encodeNextGenDexUnlock(singleton, poolId, encodeUniswapV4FlashLoanData(take, sync, flashData, settle));
    }

    function encodeUniswapV4FlashLoanData(
        bytes memory take,
        bytes memory sync,
        bytes memory flashData,
        bytes memory settle
    )
        internal
        pure
        returns (bytes memory)
    {
        return abi.encodePacked(
            take,
            sync, // sync after taking is needed
            flashData,
            settle
        );
    }

    function encodeBalancerV3Take(
        address singleton,
        address asset,
        address receiver,
        uint256 amount
    )
        internal
        pure
        returns (bytes memory)
    {
        return abi.encodePacked(
            uint8(ComposerCommands.GEN_2025_SINGELTONS),
            uint8(Gen2025ActionIds.BAL_V3_TAKE),
            singleton, // manager address
            asset, // validation Id
            receiver, //
            uint128(amount)
        ); // swaps max index for inner path
    }

    function encodeUniswapV4Sync(address singleton, address asset) internal pure returns (bytes memory) {
        if (asset == address(0)) return new bytes(0);
        return abi.encodePacked(
            uint8(ComposerCommands.GEN_2025_SINGELTONS),
            uint8(Gen2025ActionIds.UNI_V4_SYNC),
            singleton, // manager address
            asset // validation Id
        ); // swaps max index for inner path
    }

    function encodeUniswapV4Take(
        address singleton,
        address asset,
        address receiver,
        uint256 amount
    )
        internal
        pure
        returns (bytes memory)
    {
        return abi.encodePacked(
            uint8(ComposerCommands.GEN_2025_SINGELTONS),
            uint8(Gen2025ActionIds.UNI_V4_TAKE),
            singleton, // manager address
            asset, // validation Id
            receiver, //
            uint128(amount)
        ); // swaps max index for inner path
    }

    function encodeNextGenDexSettle(address singleton, uint256 nativeAmount) internal pure returns (bytes memory) {
        return abi.encodePacked(
            uint8(ComposerCommands.GEN_2025_SINGELTONS),
            uint8(Gen2025ActionIds.UNI_V4_SETTLE),
            singleton,
            uint128(nativeAmount) // manager address
        ); // swaps max index for inner path
    }

    function encodeNextGenDexSettleBalancer(
        address singleton,
        address asset,
        uint256 amountHint
    )
        internal
        pure
        returns (bytes memory)
    {
        return abi.encodePacked(
            uint8(ComposerCommands.GEN_2025_SINGELTONS),
            uint8(Gen2025ActionIds.BAL_V3_SETTLE),
            singleton,
            asset,
            uint128(amountHint >= type(uint120).max ? type(uint120).max : amountHint) // manager address
        ); // swaps max index for inner path
    }

    function encodeTransferIn(address asset, address receiver, uint256 amount) internal pure returns (bytes memory) {
        return abi.encodePacked(
            uint8(ComposerCommands.TRANSFERS),
            uint8(TransferIds.TRANSFER_FROM),
            asset,
            receiver,
            uint128(amount) //
        ); // 2 + 20 + 20 + 14 = 56 bytes
    }

    function encodeSweep(
        address asset,
        address receiver,
        uint256 amount,
        SweepType sweepType
    )
        internal
        pure
        returns (bytes memory)
    {
        return abi.encodePacked(
            uint8(ComposerCommands.TRANSFERS),
            uint8(TransferIds.SWEEP),
            asset,
            receiver,
            sweepType,
            uint128(amount) //
        ); // 2 + 20 + 20 + 14 = 56 bytes
    }

    // this just uses sweep with config "AMOUNT" so that it mimics the prior behavior
    function encodeWrap(uint256 amount, address wrapTarget) internal pure returns (bytes memory) {
        return abi.encodePacked(
            uint8(ComposerCommands.TRANSFERS),
            uint8(TransferIds.SWEEP),
            address(0), // signals native asset
            wrapTarget,
            uint8(SweepType.AMOUNT), // sweep type = AMOUNT
            uint128(amount) //
        ); // 14 bytes
    }

    function encodeWrapWithReceiver(uint256 amount, address weth, address receiver) internal pure returns (bytes memory) {
        return abi.encodePacked(uint8(ComposerCommands.TRANSFERS), uint8(TransferIds.WRAP), weth, receiver, uint128(amount));
    }

    function encodeApprove(address asset, address target) internal pure returns (bytes memory) {
        return abi.encodePacked(
            uint8(ComposerCommands.TRANSFERS),
            uint8(TransferIds.APPROVE),
            asset,
            target //
        ); // 14 bytes
    }

    /// @notice Transfer a single `tokenId` of `collection` held by the composer to `receiver`.
    /// @dev Caller must know `tokenId` up front. For Fluid, predict via `VaultFactory.totalSupply() + 1`
    ///      when opening a fresh position with `nftId == 0`.
    function encodeSweepNft(address collection, address receiver, uint256 tokenId) internal pure returns (bytes memory) {
        return abi.encodePacked(uint8(ComposerCommands.TRANSFERS), uint8(TransferIds.SWEEP_NFT), collection, receiver, tokenId);
    }

    function encodeUnwrap(
        address target,
        address receiver,
        uint256 amount,
        SweepType sweepType
    )
        internal
        pure
        returns (bytes memory)
    {
        return abi.encodePacked(
            uint8(ComposerCommands.TRANSFERS),
            uint8(TransferIds.UNWRAP_WNATIVE),
            target,
            receiver,
            sweepType,
            uint128(amount) //
        ); // 14 bytes
    }

    function encodeBalancerV2FlashLoan(
        address asset,
        uint256 amount,
        uint8 poolId, //
        bytes memory data
    )
        internal
        pure
        returns (bytes memory)
    {
        return abi.encodePacked(
            uint8(ComposerCommands.FLASH_LOAN),
            uint8(FlashLoanIds.BALANCER_V2),
            asset, //
            uint128(amount),
            uint16(data.length + 1),
            encodeUint8AndBytes(poolId, data)
        );
    }

    function encodeFlashLoan(
        address asset,
        uint256 amount,
        address pool,
        uint8 poolType,
        uint8 poolId, //
        bytes memory data
    )
        internal
        pure
        returns (bytes memory)
    {
        return abi.encodePacked(
            encodeApprove(asset, pool), // always approve
            uint8(ComposerCommands.FLASH_LOAN),
            poolType,
            asset, //
            pool,
            uint128(amount),
            uint16(data.length + 1),
            encodeUint8AndBytes(poolId, data)
        );
    }

    function encodeUint8AndBytes(uint8 poolId, bytes memory data) internal pure returns (bytes memory) {
        return abi.encodePacked(uint8(poolId), data);
    }

    function encodeMorphoMarket(
        address loanToken,
        address collateralToken,
        address oracle,
        address irm,
        uint256 lltv
    )
        internal
        pure
        returns (bytes memory)
    {
        return abi.encodePacked(loanToken, collateralToken, oracle, irm, uint128(lltv));
    }

    function encodeMorphoDepositCollateral(
        bytes memory market,
        uint256 assets,
        address receiver,
        bytes memory data, //
        address morphoB,
        uint256 pId
    )
        internal
        pure
        returns (bytes memory)
    {
        return abi.encodePacked(
            encodeApprove(getMorphoCollateral(market), morphoB), // always approve
            uint8(ComposerCommands.LENDING), // 1
            uint8(LenderOps.DEPOSIT), // 1
            uint16(LenderIds.UP_TO_MORPHO - 1), // 2
            market, // 4 * 20 + 16
            uint128(assets), // 16
            receiver,
            morphoB,
            uint16(data.length > 0 ? data.length + 1 : 0), // 2 @ 1 + 4*20
            data.length == 0 ? new bytes(0) : encodeUint8AndBytes(uint8(pId), data)
        );
    }

    function encodeListaSupplyCollateralViaProvider(
        bytes memory market,
        uint256 assets,
        address receiver,
        bytes memory data,
        address provider,
        uint256 pId
    )
        internal
        pure
        returns (bytes memory)
    {
        return abi.encodePacked(
            uint8(ComposerCommands.LENDING),
            uint8(LenderOps.DEPOSIT),
            uint16(LenderIds.UP_TO_MORPHO - 1),
            market,
            generateAmountBitmap(uint128(assets), false, true),
            receiver,
            provider,
            uint16(data.length > 0 ? data.length + 1 : 0),
            data.length == 0 ? new bytes(0) : encodeUint8AndBytes(uint8(pId), data)
        );
    }

    function encodeMorphoDeposit(
        bytes memory market,
        bool isShares, //
        uint256 assets,
        address receiver,
        bytes memory data,
        address morphoB,
        uint256 pId
    )
        internal
        pure
        returns (bytes memory)
    {
        return abi.encodePacked(
            encodeApprove(getMorphoLoanAsset(market), morphoB), // always approve
            uint8(ComposerCommands.LENDING), // 1
            uint8(LenderOps.DEPOSIT_LENDING_TOKEN), // 1
            uint16(LenderIds.UP_TO_MORPHO - 1), // 2
            market, // 4 * 20 + 16
            generateAmountBitmap(uint128(assets), isShares, false),
            receiver,
            morphoB,
            uint16(data.length > 0 ? data.length + 1 : 0), // 2 @ 1 + 4*20
            data.length == 0 ? new bytes(0) : encodeUint8AndBytes(uint8(pId), data)
        );
    }

    function encodeErc4626Deposit(
        address asset,
        address vault,
        bool isShares, //
        uint256 assets,
        address receiver
    )
        internal
        pure
        returns (bytes memory)
    {
        return abi.encodePacked(
            encodeApprove(asset, vault), // always approve
            uint8(ComposerCommands.ERC4626), // 1
            uint8(0), // 1
            asset, // 20
            vault, // 20
            generateAmountBitmap(uint128(assets), isShares, false),
            receiver // 20
        );
    }

    function encodeErc4646Withdraw(
        address vault,
        bool isShares, //
        uint256 assets,
        address receiver
    )
        internal
        pure
        returns (bytes memory)
    {
        return abi.encodePacked(
            uint8(ComposerCommands.ERC4626), // 1
            uint8(1), // 1
            vault, // 20
            generateAmountBitmap(uint128(assets), isShares, false),
            receiver // 20
        );
    }

    function encodeMorphoWithdraw(
        bytes memory market,
        bool isShares, //
        uint256 assets,
        address receiver,
        address morphoB
    )
        internal
        pure
        returns (bytes memory)
    {
        return abi.encodePacked(
            uint8(ComposerCommands.LENDING), // 1
            uint8(LenderOps.WITHDRAW_LENDING_TOKEN), // 1
            uint16(LenderIds.UP_TO_MORPHO - 1), // 2
            market, // 4 * 20 + 16
            generateAmountBitmap(uint128(assets), isShares, false),
            receiver, // 20
            morphoB
        );
    }

    function encodeMorphoWithdrawCollateral(
        bytes memory market, //
        uint256 assets,
        address receiver,
        address morphoB
    )
        internal
        pure
        returns (bytes memory)
    {
        return abi.encodePacked(
            uint8(ComposerCommands.LENDING), // 1
            uint8(LenderOps.WITHDRAW), // 1
            uint16(LenderIds.UP_TO_MORPHO - 1), // 2
            market, // 4 * 20 + 16
            uint128(assets), // 16
            receiver, // 20
            morphoB
        );
    }

    function encodeListaWithdrawCollateralViaProvider(
        bytes memory market, //
        uint256 assets,
        address receiver,
        address provider
    )
        internal
        pure
        returns (bytes memory)
    {
        return abi.encodePacked(
            uint8(ComposerCommands.LENDING), // 1
            uint8(LenderOps.WITHDRAW), // 1
            uint16(LenderIds.UP_TO_MORPHO - 1), // 2
            market, // 4 * 20 + 16
            generateAmountBitmap(uint128(assets), false, true), // native flag set
            receiver, // 20
            provider
        );
    }

    function encodeMorphoBorrow(
        bytes memory market,
        bool isShares, //
        uint256 assets,
        address receiver,
        address morphoB
    )
        internal
        pure
        returns (bytes memory)
    {
        return abi.encodePacked(
            uint8(ComposerCommands.LENDING), // 1
            uint8(LenderOps.BORROW), // 1
            uint16(LenderIds.UP_TO_MORPHO - 1), // 2
            market, // 4 * 20 + 16
            generateAmountBitmap(uint128(assets), isShares, false),
            receiver,
            morphoB
        );
    }

    function encodeMorphoRepay(
        bytes memory market,
        bool isShares, //
        uint256 assets,
        address receiver,
        bytes memory data,
        address morphoB,
        uint256 pId
    )
        internal
        pure
        returns (bytes memory)
    {
        return abi.encodePacked(
            encodeApprove(getMorphoLoanAsset(market), morphoB), // always approve
            uint8(ComposerCommands.LENDING), // 1
            uint8(LenderOps.REPAY), // 1
            uint16(LenderIds.UP_TO_MORPHO - 1), // 2
            market, // 4 * 20 + 16
            generateAmountBitmap(uint128(assets), isShares, false),
            receiver,
            morphoB,
            uint16(data.length > 0 ? data.length + 1 : 0), // 2 @ 1 + 4*20
            data.length == 0 ? new bytes(0) : encodeUint8AndBytes(uint8(pId), data)
        );
    }

    function encodeListaRepayViaProvider(
        bytes memory market,
        bool isShares, //
        uint256 assets,
        address receiver,
        bytes memory data,
        address morphoB,
        uint256 pId
    )
        internal
        pure
        returns (bytes memory)
    {
        return abi.encodePacked(
            // no approve for native
            uint8(ComposerCommands.LENDING), // 1
            uint8(LenderOps.REPAY), // 1
            uint16(LenderIds.UP_TO_MORPHO - 1), // 2
            market, // 4 * 20 + 16
            generateAmountBitmap(uint128(assets), isShares, true), // set native flag
            receiver,
            morphoB,
            uint16(data.length > 0 ? data.length + 1 : 0), // 2 @ 1 + 4*20
            data.length == 0 ? new bytes(0) : encodeUint8AndBytes(uint8(pId), data)
        );
    }

    function encodeAaveDeposit(
        address token,
        uint256 amount,
        address receiver,
        address pool
    )
        internal
        pure
        returns (bytes memory)
    {
        return abi.encodePacked(
            encodeApprove(token, pool),
            uint8(ComposerCommands.LENDING),
            uint8(LenderOps.DEPOSIT),
            uint16(LenderIds.UP_TO_AAVE_V3 - 1),
            token,
            uint128(amount),
            receiver,
            pool //
        );
    }

    function encodeAaveBorrow(
        address token,
        uint256 amount,
        address receiver,
        uint256 mode,
        address pool
    )
        internal
        pure
        returns (bytes memory)
    {
        return abi.encodePacked(
            uint8(ComposerCommands.LENDING),
            uint8(LenderOps.BORROW),
            uint16(LenderIds.UP_TO_AAVE_V3 - 1),
            token,
            uint128(amount),
            receiver,
            uint8(mode),
            pool //
        );
    }

    function encodeAaveRepay(
        address token,
        uint256 amount,
        address receiver,
        uint256 mode,
        address dToken,
        address pool
    )
        internal
        pure
        returns (bytes memory)
    {
        return abi.encodePacked(
            encodeApprove(token, pool),
            uint8(ComposerCommands.LENDING),
            uint8(LenderOps.REPAY),
            uint16(LenderIds.UP_TO_AAVE_V3 - 1),
            token,
            uint128(amount),
            receiver,
            uint8(mode),
            dToken,
            pool //
        );
    }

    function encodeAaveWithdraw(
        address token,
        uint256 amount,
        address receiver,
        address aToken,
        address pool
    )
        internal
        pure
        returns (bytes memory)
    {
        return abi.encodePacked(
            uint8(ComposerCommands.LENDING),
            uint8(LenderOps.WITHDRAW),
            uint16(LenderIds.UP_TO_AAVE_V3 - 1),
            token,
            uint128(amount),
            receiver,
            aToken,
            pool //
        );
    }

    function encodeAaveV2Deposit(
        address token,
        uint256 amount,
        address receiver,
        address pool
    )
        internal
        pure
        returns (bytes memory)
    {
        return abi.encodePacked(
            encodeApprove(token, pool),
            uint8(ComposerCommands.LENDING),
            uint8(LenderOps.DEPOSIT),
            uint16(LenderIds.UP_TO_AAVE_V2 - 1),
            token,
            uint128(amount),
            receiver,
            pool //
        );
    }

    function encodeAaveV2Borrow(
        address token,
        uint256 amount,
        address receiver,
        uint256 mode,
        address pool
    )
        internal
        pure
        returns (bytes memory)
    {
        return abi.encodePacked(
            uint8(ComposerCommands.LENDING),
            uint8(LenderOps.BORROW),
            uint16(LenderIds.UP_TO_AAVE_V2 - 1),
            token,
            uint128(amount),
            receiver,
            uint8(mode),
            pool //
        );
    }

    function encodeAaveV2Repay(
        address token,
        uint256 amount,
        address receiver,
        uint256 mode,
        address dToken,
        address pool
    )
        internal
        pure
        returns (bytes memory)
    {
        return abi.encodePacked(
            encodeApprove(token, pool),
            uint8(ComposerCommands.LENDING),
            uint8(LenderOps.REPAY),
            uint16(LenderIds.UP_TO_AAVE_V2 - 1),
            token,
            uint128(amount),
            receiver,
            uint8(mode),
            dToken,
            pool //
        );
    }

    function encodeAaveV2Withdraw(
        address token,
        uint256 amount,
        address receiver,
        address aToken,
        address pool
    )
        internal
        pure
        returns (bytes memory)
    {
        return abi.encodePacked(
            uint8(ComposerCommands.LENDING),
            uint8(LenderOps.WITHDRAW),
            uint16(LenderIds.UP_TO_AAVE_V2 - 1),
            token,
            uint128(amount),
            receiver,
            aToken,
            pool //
        );
    }

    function encodeCompoundV3Deposit(
        address token,
        uint256 amount,
        address receiver,
        address comet
    )
        internal
        pure
        returns (bytes memory)
    {
        return abi.encodePacked(
            encodeApprove(token, comet),
            uint8(ComposerCommands.LENDING),
            uint8(LenderOps.DEPOSIT),
            uint16(LenderIds.UP_TO_COMPOUND_V3 - 1),
            token,
            uint128(amount),
            receiver,
            comet //
        );
    }

    function encodeCompoundV3Borrow(
        address token,
        uint256 amount,
        address receiver,
        address comet
    )
        internal
        pure
        returns (bytes memory)
    {
        return abi.encodePacked(
            uint8(ComposerCommands.LENDING),
            uint8(LenderOps.BORROW),
            uint16(LenderIds.UP_TO_COMPOUND_V3 - 1),
            token,
            uint128(amount),
            receiver,
            comet //
        );
    }

    function encodeCompoundV3Repay(
        address token,
        uint256 amount,
        address receiver,
        address comet
    )
        internal
        pure
        returns (bytes memory)
    {
        return abi.encodePacked(
            encodeApprove(token, comet),
            uint8(ComposerCommands.LENDING),
            uint8(LenderOps.REPAY),
            uint16(LenderIds.UP_TO_COMPOUND_V3 - 1),
            token,
            uint128(amount),
            receiver,
            comet //
        );
    }

    function encodeCompoundV3Withdraw(
        address token,
        uint256 amount,
        address receiver,
        address comet,
        bool isBase
    )
        internal
        pure
        returns (bytes memory)
    {
        return abi.encodePacked(
            uint8(ComposerCommands.LENDING),
            uint8(LenderOps.WITHDRAW),
            uint16(LenderIds.UP_TO_COMPOUND_V3 - 1),
            token,
            uint128(amount),
            receiver,
            isBase ? uint8(1) : uint8(0),
            comet //
        );
    }

    function encodeCompoundV2Deposit(
        address token,
        uint256 amount,
        address receiver,
        address cToken,
        uint8 selectorId
    )
        internal
        pure
        returns (bytes memory)
    {
        return abi.encodePacked(
            // no approves for native
            token == address(0) ? new bytes(0) : encodeApprove(token, cToken),
            uint8(ComposerCommands.LENDING),
            uint8(LenderOps.DEPOSIT),
            uint16(LenderIds.UP_TO_COMPOUND_V2 - 1),
            token,
            encodeCompoundV2SelectorId(uint128(amount), selectorId),
            receiver,
            cToken //
        );
    }

    function encodeSiloV2Deposit(
        address token,
        uint256 amount,
        address receiver,
        address silo,
        uint8 collateralMode
    )
        internal
        pure
        returns (bytes memory)
    {
        return abi.encodePacked(
            // no approves for native
            token == address(0) ? new bytes(0) : encodeApprove(token, silo),
            uint8(ComposerCommands.LENDING),
            uint8(LenderOps.DEPOSIT),
            uint16(LenderIds.UP_TO_SILO_V2 - 1),
            token,
            encodeSiloV2CollateralMode(uint128(amount), collateralMode),
            receiver,
            silo //
        );
    }

    function encodeSiloV2Borrow(uint256 amount, address receiver, address silo) internal pure returns (bytes memory) {
        return abi.encodePacked(
            uint8(ComposerCommands.LENDING),
            uint8(LenderOps.BORROW),
            uint16(LenderIds.UP_TO_SILO_V2 - 1),
            uint128(amount),
            receiver,
            silo //
        );
    }

    function encodeCompoundV2Borrow(
        address token,
        uint256 amount,
        address receiver,
        address cToken
    )
        internal
        pure
        returns (bytes memory)
    {
        return abi.encodePacked(
            uint8(ComposerCommands.LENDING),
            uint8(LenderOps.BORROW),
            uint16(LenderIds.UP_TO_COMPOUND_V2 - 1),
            token,
            uint128(amount),
            receiver,
            cToken //
        );
    }

    function encodeCompoundV2Repay(
        address token,
        uint256 amount,
        address receiver,
        address cToken
    )
        internal
        pure
        returns (bytes memory)
    {
        return abi.encodePacked(
            // no approves for native
            token == address(0) ? new bytes(0) : encodeApprove(token, cToken),
            uint8(ComposerCommands.LENDING),
            uint8(LenderOps.REPAY),
            uint16(LenderIds.UP_TO_COMPOUND_V2 - 1),
            token,
            uint128(amount),
            receiver,
            cToken //
        );
    }

    function encodeCompoundV2Withdraw(
        address token,
        uint256 amount,
        address receiver,
        address cToken,
        uint8 selectorId
    )
        internal
        pure
        returns (bytes memory)
    {
        return abi.encodePacked(
            uint8(ComposerCommands.LENDING),
            uint8(LenderOps.WITHDRAW),
            uint16(LenderIds.UP_TO_COMPOUND_V2 - 1),
            token,
            encodeCompoundV2SelectorId(uint128(amount), selectorId),
            receiver,
            cToken //
        );
    }

    function encodeSiloV2Withdraw(
        uint256 amount,
        address receiver,
        address silo,
        uint8 collateralMode
    )
        internal
        pure
        returns (bytes memory)
    {
        return abi.encodePacked(
            uint8(ComposerCommands.LENDING),
            uint8(LenderOps.WITHDRAW),
            uint16(LenderIds.UP_TO_SILO_V2 - 1),
            encodeSiloV2CollateralMode(uint128(amount), collateralMode),
            receiver,
            silo //
        );
    }

    function encodeSiloV2Repay(
        address token,
        uint256 amount,
        address receiver,
        address silo
    )
        internal
        pure
        returns (bytes memory)
    {
        return abi.encodePacked(
            // no approves for native
            token == address(0) ? new bytes(0) : encodeApprove(token, silo),
            uint8(ComposerCommands.LENDING),
            uint8(LenderOps.REPAY),
            uint16(LenderIds.UP_TO_SILO_V2 - 1),
            token,
            uint128(amount),
            receiver,
            silo //
        );
    }

    /**
     * get the collateral asset from a packed Morpho market
     */
    function getMorphoCollateral(bytes memory market) private pure returns (address collat) {
        assembly {
            collat := shr(96, mload(add(market, 52)))
        }
    }

    /**
     * get the loab asset from a packed Morpho market
     */
    function getMorphoLoanAsset(bytes memory market) private pure returns (address collat) {
        assembly {
            collat := shr(96, mload(add(market, 32)))
        }
    }

    /// @dev Mask for using the injected amount
    uint128 private constant NATIVE_FLAG = 1 << 127;
    /// @dev Mask for shares
    uint128 private constant USE_SHARES_FLAG = 1 << 126;

    function generateAmountBitmap(uint128 amount, bool useShares, bool native) internal pure returns (uint128 am) {
        am = amount;
        if (native) am = uint128((am & ~NATIVE_FLAG) | NATIVE_FLAG); // sets the first bit to 1
        if (useShares) am = uint128((am & ~USE_SHARES_FLAG) | USE_SHARES_FLAG); // sets the second bit to 1
        return am;
    }

    function rightPadZero(address addr) internal pure returns (bytes32 a) {
        assembly {
            a := shl(96, addr)
        }
    }

    uint256 private constant UPPER_128BITS = 120;

    function encodeCompoundV2SelectorId(uint128 amount, uint8 selectorId) internal pure returns (uint128 am) {
        am = amount | (uint128(selectorId) << UPPER_128BITS);
    }

    function encodeSiloV2CollateralMode(uint128 amount, uint8 mode) internal pure returns (uint128 am) {
        am = amount | (uint128(mode) << UPPER_128BITS);
    }

    // ══════════════════════════════════════════════════════
    // Aave V4 encoding functions
    // ══════════════════════════════════════════════════════
    //
    // ─── deadline+1 convention (used by all Aave V4 permit encoders below) ───
    // Deadlines are packed as uint32 (4 bytes) in calldata. The encoder MUST add 1
    // before truncating (`uint32(deadline + 1)`); the decoder subtracts 1.
    // Rationale: reserves the zero slot as "unset" sentinel while still allowing
    // deadline = 0 in the signed EIP-712 struct. Max deadline ≈ Feb 2106.
    // Forgetting the +1 causes signature digest mismatch (clean revert, no corruption).
    // The +1 only exists in calldata — the signed EIP-712 struct uses the raw deadline.
    //
    // ─── compact signature (`vs`) — EIP-2098 ───
    // vs = (uint256(v - 27) << 255) | uint256(s)   — caller constructs this.
    // On-chain: v = 27 + (vs >> 255), s = vs & (2^255 - 1).

    function encodeAaveV4Deposit(
        address underlying,
        uint256 amount,
        address receiver,
        uint256 reserveId,
        address spoke,
        address positionManager
    )
        internal
        pure
        returns (bytes memory)
    {
        return abi.encodePacked(
            encodeApprove(underlying, positionManager),
            uint8(ComposerCommands.LENDING),
            uint8(LenderOps.DEPOSIT),
            uint16(LenderIds.UP_TO_AAVE_V4 - 1),
            underlying,
            uint128(amount),
            receiver,
            reserveId,
            spoke,
            positionManager //
        );
    }

    function encodeAaveV4Borrow(
        address underlying,
        uint256 amount,
        address receiver,
        uint256 reserveId,
        address spoke,
        address positionManager
    )
        internal
        pure
        returns (bytes memory)
    {
        return abi.encodePacked(
            uint8(ComposerCommands.LENDING),
            uint8(LenderOps.BORROW),
            uint16(LenderIds.UP_TO_AAVE_V4 - 1),
            underlying,
            uint128(amount),
            receiver,
            reserveId,
            spoke,
            positionManager //
        );
    }

    function encodeAaveV4Repay(
        address underlying,
        uint256 amount,
        address receiver,
        uint256 reserveId,
        address spoke,
        address positionManager
    )
        internal
        pure
        returns (bytes memory)
    {
        return abi.encodePacked(
            encodeApprove(underlying, positionManager),
            uint8(ComposerCommands.LENDING),
            uint8(LenderOps.REPAY),
            uint16(LenderIds.UP_TO_AAVE_V4 - 1),
            underlying,
            uint128(amount),
            receiver,
            reserveId,
            spoke,
            positionManager //
        );
    }

    function encodeAaveV4Withdraw(
        address underlying,
        uint256 amount,
        address receiver,
        uint256 reserveId,
        address spoke,
        address positionManager
    )
        internal
        pure
        returns (bytes memory)
    {
        return abi.encodePacked(
            uint8(ComposerCommands.LENDING),
            uint8(LenderOps.WITHDRAW),
            uint16(LenderIds.UP_TO_AAVE_V4 - 1),
            underlying,
            uint128(amount),
            receiver,
            reserveId,
            spoke,
            positionManager //
        );
    }

    function encodeAaveV4SetCollateral(
        uint256 reserveId,
        bool enable,
        address spoke,
        address configPositionManager
    )
        internal
        pure
        returns (bytes memory)
    {
        return abi.encodePacked(
            uint8(ComposerCommands.LENDING),
            uint8(LenderOps.SET_COLLATERAL),
            uint16(LenderIds.UP_TO_AAVE_V4 - 1),
            reserveId,
            uint8(enable ? 1 : 0),
            spoke,
            configPositionManager
        );
    }

    function encodeAaveV4BorrowPermit(
        address takerPM,
        address spoke,
        uint256 reserveId,
        uint256 amount,
        uint256 nonce,
        uint32 deadlinePlusOne,
        bytes32 r,
        bytes32 vs
    )
        internal
        pure
        returns (bytes memory)
    {
        bytes memory data = abi.encodePacked(spoke, reserveId, amount, nonce, deadlinePlusOne, r, vs);
        return encodePermit(PermitIds.AAVE_V4_BORROW_PERMIT, takerPM, data);
    }

    function encodeAaveV4WithdrawPermit(
        address takerPM,
        address spoke,
        uint256 reserveId,
        uint256 amount,
        uint256 nonce,
        uint32 deadlinePlusOne,
        bytes32 r,
        bytes32 vs
    )
        internal
        pure
        returns (bytes memory)
    {
        bytes memory data = abi.encodePacked(spoke, reserveId, amount, nonce, deadlinePlusOne, r, vs);
        return encodePermit(PermitIds.AAVE_V4_WITHDRAW_PERMIT, takerPM, data);
    }

    function encodeAaveV4ConfigPermit(
        address configPM,
        address spoke,
        bool status,
        uint256 nonce,
        uint32 deadlinePlusOne,
        bytes32 r,
        bytes32 vs
    )
        internal
        pure
        returns (bytes memory)
    {
        bytes memory data = abi.encodePacked(spoke, uint8(status ? 1 : 0), nonce, deadlinePlusOne, r, vs);
        return encodePermit(PermitIds.AAVE_V4_CONFIG_PERMIT, configPM, data);
    }

    /**
     * @notice Encodes a batch PM setup permit calling ISpoke.setUserPositionManagersWithSig.
     * @dev Calls the spoke directly (not a PM) to register multiple PMs in a single signature.
     *      Saves N-1 signatures on first-time setup vs. the per-PM variant.
     *      Compact layout: count(1) | count * (pm(20) | approve(1)) | nonce(32) | deadline+1(4) | r(32) | vs(32)
     * @param spoke The Spoke address — the signature is verified on the Spoke.
     * @param pms Array of position manager addresses.
     * @param approvals Array of matching approve/revoke flags.
     * @param nonce The user's keyed-nonce for the spoke.
     * @param deadlinePlusOne Deadline + 1 encoded in 4 bytes (see deadline+1 convention above).
     * @param r Signature r.
     * @param vs EIP-2098 compact signature (top bit = v_parity, lower 255 bits = s).
     */
    function encodeAaveV4PmsBatchPermit(
        address spoke,
        address[] memory pms,
        bool[] memory approvals,
        uint256 nonce,
        uint32 deadlinePlusOne,
        bytes32 r,
        bytes32 vs
    )
        internal
        pure
        returns (bytes memory)
    {
        require(pms.length == approvals.length, "CL: length mismatch");
        require(pms.length > 0 && pms.length < 256, "CL: invalid count");

        bytes memory updates;
        for (uint256 i = 0; i < pms.length; i++) {
            updates = abi.encodePacked(updates, pms[i], uint8(approvals[i] ? 1 : 0));
        }

        bytes memory data = abi.encodePacked(uint8(pms.length), updates, nonce, deadlinePlusOne, r, vs);
        return encodePermit(PermitIds.AAVE_V4_PMS_BATCH_PERMIT, spoke, data);
    }

    // ─────────────────────────────────────────────────────────────────────────────
    // Fluid (T1 vault + fToken)
    // ─────────────────────────────────────────────────────────────────────────────

    /// @dev Sentinel for "Fluid-all" on a T1 operate axis — translates to type(int256).min
    ///      on the wire. Pass on `colAmount` for withdraw-all, on `debtAmount` for repay-all.
    int128 internal constant FLUID_ALL = type(int128).min;

    /// @dev Sentinel for "use composer balance" on a T1 operate axis (positive direction only).
    ///      Pass on `colAmount` to deposit the composer's entire balance of `colUnderlying`.
    int128 internal constant FLUID_USE_BALANCE = type(int128).max;

    /// @notice Encode a single `FLUID_OPERATE_T1` op wrapping `vault.operate(...)` with both axes
    ///         parameterized. When `nftId == 0` a fresh position is opened; if `nftReceiver != 0`
    ///         the composer ships the returned NFT to `nftReceiver` in the same call.
    /// @param colUnderlying   address(0) for native collateral
    /// @param debtUnderlying  address(0) for native debt
    /// @param colAmount       int128 — 0 skip, +N deposit, -N withdraw, FLUID_ALL withdraw-all, FLUID_USE_BALANCE deposit-balance
    /// @param debtAmount      int128 — 0 skip, +N borrow, -N repay, FLUID_ALL repay-all
    /// @param nftId           0 = open new position
    /// @param receiver        vault's `to_` — recipient of any out-flow (native or tokens)
    /// @param nftReceiver     0 = keep NFT in composer; non-zero = auto-sweep minted NFT to this address
    /// @param vault           target Fluid T1 vault
    /// @dev Auto-prepends APPROVE ops for any positive-direction ERC20 side so Fluid can pull funds.
    function encodeFluidT1Operate(
        address colUnderlying,
        address debtUnderlying,
        int128 colAmount,
        int128 debtAmount,
        uint256 nftId,
        address receiver,
        address nftReceiver,
        address vault
    )
        internal
        pure
        returns (bytes memory)
    {
        bytes memory approvals;
        // Positive col-direction on an ERC20 collateral → Fluid pulls tokens → needs approve.
        if (colUnderlying != address(0) && _fluidIsDepositAmount(colAmount)) {
            approvals = abi.encodePacked(approvals, encodeApprove(colUnderlying, vault));
        }
        // Negative debt-direction on an ERC20 debt → Fluid pulls tokens for repay → needs approve.
        if (debtUnderlying != address(0) && _fluidIsRepayAmount(debtAmount)) {
            approvals = abi.encodePacked(approvals, encodeApprove(debtUnderlying, vault));
        }

        bytes memory body = abi.encodePacked(
            colUnderlying,
            debtUnderlying,
            colAmount, // 16 bytes signed (int128)
            debtAmount, // 16 bytes signed (int128)
            nftId, // 32 bytes
            receiver,
            nftReceiver,
            vault
        );

        return abi.encodePacked(
            approvals,
            uint8(ComposerCommands.LENDING),
            uint8(LenderOps.FLUID_OPERATE_T1),
            uint16(LenderIds.UP_TO_FLUID - 1),
            body
        );
    }

    /// @dev Positive signed int128 (deposit/borrow direction); `FLUID_USE_BALANCE` also counts as a
    ///      deposit (pulls from the composer's balance). Zero and the all-sentinel don't pull.
    function _fluidIsDepositAmount(int128 a) private pure returns (bool) {
        return a > 0; // includes FLUID_USE_BALANCE (type(int128).max)
    }

    /// @dev Negative signed int128 (withdraw/repay direction); `FLUID_ALL` also counts as a repay.
    function _fluidIsRepayAmount(int128 a) private pure returns (bool) {
        return a < 0; // includes FLUID_ALL (type(int128).min)
    }

    // ─────────────────────────────────────────────────────────────────────────────
    // Single-axis convenience wrappers around `encodeFluidT1Operate`.
    //
    // These match the historical DEPOSIT / BORROW / REPAY / WITHDRAW signatures so callers that
    // only touch one axis don't have to spell out the other side. Each one delegates to the
    // dual-axis primitive with the unused axis pinned to 0. The sentinel mapping matches the
    // old behavior:
    //   encodeFluidDeposit:  amount == 0                  → FLUID_USE_BALANCE (deposit balance)
    //   encodeFluidRepay:    amount == 0 | FLUID_MAX_AMT  → FLUID_ALL         (repay-all)
    //   encodeFluidWithdraw: amount == FLUID_MAX_AMT      → FLUID_ALL         (withdraw-all)
    //   encodeFluidBorrow:   amount is always literal
    // ─────────────────────────────────────────────────────────────────────────────

    /// @dev Historical sentinel for "max" on T1 repay/withdraw — UINT112_MASK. Preserved for
    ///      callers still using the old per-axis encoders.
    uint128 internal constant FLUID_MAX_AMOUNT = type(uint112).max;

    /// @notice Deposit-only convenience wrapper. `amount == 0` means "deposit composer's balance".
    function encodeFluidDeposit(
        address underlying,
        uint128 amount,
        uint256 nftId,
        address receiver,
        address vault
    )
        internal
        pure
        returns (bytes memory)
    {
        int128 colAmount = amount == 0 ? FLUID_USE_BALANCE : int128(amount);
        return encodeFluidT1Operate(underlying, address(0), colAmount, 0, nftId, receiver, address(0), vault);
    }

    /// @notice Borrow-only convenience wrapper. Amount is always literal.
    function encodeFluidBorrow(
        address underlying,
        uint128 amount,
        uint256 nftId,
        address receiver,
        address vault
    )
        internal
        pure
        returns (bytes memory)
    {
        return encodeFluidT1Operate(address(0), underlying, 0, int128(amount), nftId, receiver, address(0), vault);
    }

    /// @notice Repay-only convenience wrapper. `amount == 0` and `amount == FLUID_MAX_AMOUNT` both
    ///         mean "repay-all" (maps to `type(int256).min` on the wire).
    function encodeFluidRepay(
        address underlying,
        uint128 amount,
        uint256 nftId,
        address receiver,
        address vault
    )
        internal
        pure
        returns (bytes memory)
    {
        int128 debtAmount = (amount == 0 || amount == FLUID_MAX_AMOUNT) ? FLUID_ALL : -int128(amount);
        return encodeFluidT1Operate(address(0), underlying, 0, debtAmount, nftId, receiver, address(0), vault);
    }

    /// @notice Withdraw-only convenience wrapper. `amount == FLUID_MAX_AMOUNT` means "withdraw-all".
    function encodeFluidWithdraw(
        address underlying,
        uint128 amount,
        uint256 nftId,
        address receiver,
        address vault
    )
        internal
        pure
        returns (bytes memory)
    {
        int128 colAmount = amount == FLUID_MAX_AMOUNT ? FLUID_ALL : -int128(amount);
        return encodeFluidT1Operate(underlying, address(0), colAmount, 0, nftId, receiver, address(0), vault);
    }

    /// @dev Sentinel matching FluidSmartLending's `FLUID_SMART_USE_BALANCE`. Place into an int256
    ///      amount slot on a smart-vault op to have the composer resolve it from balanceOf(this)
    ///      (or selfbalance() when the parallel token slot is `address(0)`).
    int256 internal constant FLUID_SMART_USE_BALANCE = type(int256).max;

    function _fluidSmartHeader(
        uint8 vaultType,
        uint128 callValue,
        uint256 nftId,
        address receiver,
        address nftReceiver,
        address vault,
        bool isPerfect
    )
        private
        pure
        returns (bytes memory)
    {
        return abi.encodePacked(
            uint8(ComposerCommands.LENDING),
            isPerfect ? uint8(LenderOps.FLUID_OPERATE_PERFECT) : uint8(LenderOps.FLUID_OPERATE),
            uint16(LenderIds.UP_TO_FLUID_SMART - 1),
            vaultType,
            callValue,
            nftId,
            receiver,
            nftReceiver,
            vault
        );
    }

    function _fluidSmartTokens4(address[4] memory t) private pure returns (bytes memory) {
        return abi.encodePacked(t[0], t[1], t[2], t[3]);
    }

    function _fluidSmartTokens6(address[6] memory t) private pure returns (bytes memory) {
        return abi.encodePacked(t[0], t[1], t[2], t[3], t[4], t[5]);
    }

    function _fluidSmartAmounts4(int256[4] memory a) private pure returns (bytes memory) {
        return abi.encodePacked(a[0], a[1], a[2], a[3]);
    }

    function _fluidSmartAmounts6(int256[6] memory a) private pure returns (bytes memory) {
        return abi.encodePacked(a[0], a[1], a[2], a[3], a[4], a[5]);
    }

    /// @notice Encode a `FluidSmartLending.FLUID_OPERATE` call against a T2 vault.
    /// @param amounts [newColToken0, newColToken1, colSharesMinMax, newDebt]
    /// @param tokens  per-slot token address; use `address(0)` on slots that don't use the
    ///                balance sentinel, or the actual ERC20 / `address(0)` for native when they do
    /// @param nftReceiver 0 = keep NFT in composer; non-zero = auto-sweep freshly-minted NFT there
    function encodeFluidSmartOperateT2(
        uint128 callValue,
        uint256 nftId,
        address receiver,
        address nftReceiver,
        address vault,
        address[4] memory tokens,
        int256[4] memory amounts
    )
        internal
        pure
        returns (bytes memory)
    {
        return abi.encodePacked(
            _fluidSmartHeader(2, callValue, nftId, receiver, nftReceiver, vault, false),
            _fluidSmartTokens4(tokens),
            _fluidSmartAmounts4(amounts)
        );
    }

    /// @notice Encode a `FluidSmartLending.FLUID_OPERATE` call against a T3 vault.
    /// @param amounts [newCol, newDebtToken0, newDebtToken1, debtSharesMinMax]
    function encodeFluidSmartOperateT3(
        uint128 callValue,
        uint256 nftId,
        address receiver,
        address nftReceiver,
        address vault,
        address[4] memory tokens,
        int256[4] memory amounts
    )
        internal
        pure
        returns (bytes memory)
    {
        return abi.encodePacked(
            _fluidSmartHeader(3, callValue, nftId, receiver, nftReceiver, vault, false),
            _fluidSmartTokens4(tokens),
            _fluidSmartAmounts4(amounts)
        );
    }

    /// @notice Encode a `FluidSmartLending.FLUID_OPERATE` call against a T4 vault.
    /// @param amounts [newColToken0, newColToken1, colSharesMinMax, newDebtToken0, newDebtToken1, debtSharesMinMax]
    function encodeFluidSmartOperateT4(
        uint128 callValue,
        uint256 nftId,
        address receiver,
        address nftReceiver,
        address vault,
        address[6] memory tokens,
        int256[6] memory amounts
    )
        internal
        pure
        returns (bytes memory)
    {
        return abi.encodePacked(
            _fluidSmartHeader(4, callValue, nftId, receiver, nftReceiver, vault, false),
            _fluidSmartTokens6(tokens),
            _fluidSmartAmounts6(amounts)
        );
    }

    /// @notice Encode a `FluidSmartLending.FLUID_OPERATE_PERFECT` call against a T2 vault.
    /// @param amounts [perfectColShares, colToken0MinMax, colToken1MinMax, newDebt]
    function encodeFluidSmartOperatePerfectT2(
        uint128 callValue,
        uint256 nftId,
        address receiver,
        address nftReceiver,
        address vault,
        address[4] memory tokens,
        int256[4] memory amounts
    )
        internal
        pure
        returns (bytes memory)
    {
        return abi.encodePacked(
            _fluidSmartHeader(2, callValue, nftId, receiver, nftReceiver, vault, true),
            _fluidSmartTokens4(tokens),
            _fluidSmartAmounts4(amounts)
        );
    }

    /// @notice Encode a `FluidSmartLending.FLUID_OPERATE_PERFECT` call against a T3 vault.
    /// @param amounts [newCol, perfectDebtShares, debtToken0MinMax, debtToken1MinMax]
    function encodeFluidSmartOperatePerfectT3(
        uint128 callValue,
        uint256 nftId,
        address receiver,
        address nftReceiver,
        address vault,
        address[4] memory tokens,
        int256[4] memory amounts
    )
        internal
        pure
        returns (bytes memory)
    {
        return abi.encodePacked(
            _fluidSmartHeader(3, callValue, nftId, receiver, nftReceiver, vault, true),
            _fluidSmartTokens4(tokens),
            _fluidSmartAmounts4(amounts)
        );
    }

    /// @notice Encode a `FluidSmartLending.FLUID_OPERATE_PERFECT` call against a T4 vault.
    /// @param amounts [perfectColShares, colToken0MinMax, colToken1MinMax, perfectDebtShares, debtToken0MinMax, debtToken1MinMax]
    function encodeFluidSmartOperatePerfectT4(
        uint128 callValue,
        uint256 nftId,
        address receiver,
        address nftReceiver,
        address vault,
        address[6] memory tokens,
        int256[6] memory amounts
    )
        internal
        pure
        returns (bytes memory)
    {
        return abi.encodePacked(
            _fluidSmartHeader(4, callValue, nftId, receiver, nftReceiver, vault, true),
            _fluidSmartTokens6(tokens),
            _fluidSmartAmounts6(amounts)
        );
    }

    function encodeFluidFTokenDeposit(
        address underlying,
        uint128 amount,
        address receiver,
        address fToken
    )
        internal
        pure
        returns (bytes memory)
    {
        return abi.encodePacked(
            encodeApprove(underlying, fToken),
            uint8(ComposerCommands.LENDING),
            uint8(LenderOps.DEPOSIT_LENDING_TOKEN),
            uint16(LenderIds.UP_TO_FLUID - 1),
            underlying,
            amount,
            receiver,
            fToken
        );
    }

    function encodeFluidFTokenWithdraw(
        address underlying,
        uint128 amount,
        address receiver,
        address fToken
    )
        internal
        pure
        returns (bytes memory)
    {
        return abi.encodePacked(
            uint8(ComposerCommands.LENDING),
            uint8(LenderOps.WITHDRAW_LENDING_TOKEN),
            uint16(LenderIds.UP_TO_FLUID - 1),
            underlying,
            amount,
            receiver,
            fToken
        );
    }

    // ─────────────────────────────────────────────────────────────────────────────
    // Gearbox V3 — see GEARBOX.md for the full flow, permission UX, and dust-safe
    // full-repay pattern.
    // ─────────────────────────────────────────────────────────────────────────────

    /// @dev Sentinel that matches the composer's full-repay branch — UINT112_MASK.
    uint128 internal constant GEARBOX_REPAY_ALL = type(uint112).max;

    /// @dev Sentinel that maps to Gearbox's `withdrawCollateral(token, uint256.max, to)` "sweep
    ///      full balance" — used for full-withdraw flows.
    uint128 internal constant GEARBOX_WITHDRAW_ALL = type(uint112).max;

    /// @dev Gearbox permission bitmask (see `gearbox-interfaces/GearboxTypes.sol`). Re-exposed
    ///      here so encoder-side UI helpers can refer to them by symbolic name.
    uint192 internal constant GEARBOX_ADD_COLLATERAL_PERMISSION = 1 << 0;
    uint192 internal constant GEARBOX_INCREASE_DEBT_PERMISSION = 1 << 1;
    uint192 internal constant GEARBOX_DECREASE_DEBT_PERMISSION = 1 << 2;
    uint192 internal constant GEARBOX_WITHDRAW_COLLATERAL_PERMISSION = 1 << 5;
    uint192 internal constant GEARBOX_UPDATE_QUOTA_PERMISSION = 1 << 6;

    /**
     * @notice Encode a Gearbox V3 deposit-collateral op. Prepends an `APPROVE(token, cm)`.
     * @dev See GEARBOX.md §3.1. `minHF` may be 0 to skip the trailing `setFullCheckParams`.
     */
    function encodeGearboxV3Supply(
        address token,
        uint128 amount,
        address creditAccount,
        address creditFacade,
        address creditManager
    )
        internal
        pure
        returns (bytes memory)
    {
        // `creditManager` is only used to emit the `APPROVE(token, cm)` hop; the composer
        // derives the CM at auth time from `creditFacade.creditManager()`, so it is not
        // packed into the op body.
        return abi.encodePacked(
            encodeApprove(token, creditManager),
            uint8(ComposerCommands.LENDING),
            uint8(LenderOps.DEPOSIT),
            uint16(LenderIds.UP_TO_GEARBOX_V3 - 1),
            token,
            amount,
            creditAccount,
            creditFacade
        );
    }

    /**
     * @notice Encode a Gearbox V3 borrow op (increaseDebt + withdrawCollateral + HF check).
     * @dev The composer authenticates the caller as the CA's borrower at dispatch time, deriving
     *      the CM from `creditFacade.creditManager()` (immutable on CreditFacadeV3). No separate
     *      `creditManager` parameter is needed.
     */
    function encodeGearboxV3Borrow(
        address underlying,
        uint128 amount,
        address receiver,
        address creditAccount,
        address creditFacade
    )
        internal
        pure
        returns (bytes memory)
    {
        return abi.encodePacked(
            uint8(ComposerCommands.LENDING),
            uint8(LenderOps.BORROW),
            uint16(LenderIds.UP_TO_GEARBOX_V3 - 1),
            underlying,
            amount,
            receiver,
            creditAccount,
            creditFacade
        );
    }

    /**
     * @notice Encode a Gearbox V3 partial-repay op.
     * @dev `amount` must be > 0 and < `GEARBOX_REPAY_ALL` — zero-means-balance is rejected on
     *      this primitive (would risk stranding residue on the CA). The composer does not
     *      enforce that the post-repay debt stays above the pool's `minDebt`; if it would
     *      land in `(0, minDebt)`, the facade reverts. For full exit, use `encodeGearboxV3RepayAll`.
     *      Caller must have pre-funded the composer via a `TRANSFER_FROM` op (not prepended
     *      here — keep it explicit so callers can batch).
     */
    function encodeGearboxV3RepayPartial(
        address underlying,
        uint128 amount,
        address creditAccount,
        address creditFacade,
        address creditManager
    )
        internal
        pure
        returns (bytes memory)
    {
        if (amount == 0 || amount == GEARBOX_REPAY_ALL) revert("CL: gearbox partial repay needs literal amount");

        // `creditManager` is only used for the prepended `APPROVE(underlying, cm)`; the composer
        // derives the CM for auth from `creditFacade.creditManager()`.
        return abi.encodePacked(
            encodeApprove(underlying, creditManager),
            uint8(ComposerCommands.LENDING),
            uint8(LenderOps.REPAY),
            uint16(LenderIds.UP_TO_GEARBOX_V3 - 1),
            underlying,
            amount,
            creditAccount,
            creditFacade,
            uint8(0) // numQuotedTokens must be 0 for partial
        );
    }

    /**
     * @notice Encode a Gearbox V3 repay that closes the position when funds permit, and
     *         degrades to a partial otherwise.
     * @dev The composer reads `maxRepayment` on-chain via `calcDebtAndCollateral(DEBT_ONLY)` and
     *      computes `amt = min(balanceOf(composer), maxRepayment)`:
     *        - `amt == maxRepayment` AND `quotedTokens.length > 0`: close-out — emit
     *          `[updateQuota × N, addCollateral(underlying, maxRepayment), decreaseDebt(max)]`.
     *          Exact deposit, no trailing `withdrawCollateral` sweep. Surplus stays on composer
     *          for explicit sweep (integrates cleanly with flash-close flows).
     *        - otherwise: partial — `[addCollateral(amt), decreaseDebt(amt)]`. The caller's
     *          quotedTokens list is ignored when funds are short; the primitive prefers
     *          executing a partial over reverting. This is the "repay 99.9k of a 100k debt
     *          when 100 wei short" behavior — no funding arithmetic reverts.
     *
     *      Funding: emit a `TRANSFER_FROM` op upfront to move `underlying` from the user to the
     *      composer. For a guaranteed close-out, transfer at least `maxRepayment`; otherwise the
     *      primitive will partial-pay whatever is delivered. An `APPROVE(underlying,
     *      creditManager)` is prepended automatically.
     *
     *      Dispatched through `LenderOps.REPAY` with amount = `UINT112_MASK`.
     *
     * @param quotedTokens Currently-enabled quoted collateral tokens on `creditAccount` — used
     *                     only for the close-out branch. Enumerate off-chain via
     *                     `CreditManagerV3.enabledTokensMask(ca) & CreditManagerV3.quotedTokensMask()`
     *                     and walk the bits. Empty is legal (CA with no quotas enabled, or if
     *                     the caller accepts only a partial path).
     */
    function encodeGearboxV3RepayAll(
        address underlying,
        address creditAccount,
        address creditFacade,
        address creditManager,
        address[] memory quotedTokens
    )
        internal
        pure
        returns (bytes memory)
    {
        if (quotedTokens.length > 255) revert("CL: gearbox too many quoted tokens");

        bytes memory quotedBlob;
        for (uint256 i = 0; i < quotedTokens.length; i++) {
            quotedBlob = abi.encodePacked(quotedBlob, quotedTokens[i]);
        }

        // `creditManager` is only used for the prepended `APPROVE(underlying, cm)`; the composer
        // derives the CM for auth from `creditFacade.creditManager()`.
        return abi.encodePacked(
            encodeApprove(underlying, creditManager),
            uint8(ComposerCommands.LENDING),
            uint8(LenderOps.REPAY),
            uint16(LenderIds.UP_TO_GEARBOX_V3 - 1),
            underlying,
            GEARBOX_REPAY_ALL,
            creditAccount,
            creditFacade,
            uint8(quotedTokens.length),
            quotedBlob
        );
    }

    /**
     * @notice Encode a Gearbox V3 **safe-max partial** repay — "repay as much as possible
     *         without closing". The composer reads `maxRepay` on-chain, computes `amt =
     *         min(balanceOf(composer), maxRepay)`, and emits `addCollateral + decreaseDebt(amt)`.
     *         Purpose-built for liquidation-prevention flows that need to execute even when the
     *         caller delivered less than the full debt.
     *
     * @dev Dispatched through `LenderOps.REPAY` with `amount = UINT112_MASK` (the "safe-max"
     *      sentinel) and `numQuoted = 0`. With no quoted-tokens list, the composer never
     *      attempts a close-out — if `bal >= maxRepay` the partial pays exactly `maxRepay`
     *      which takes debt to zero; if the CA has enabled quotas at that point, Gearbox's
     *      `DebtToZeroWithActiveQuotasException` reverts (caller error — should have used
     *      `encodeGearboxV3RepayAll` with the quoted list). `creditManager` is only used for
     *      the prepended `APPROVE(underlying, cm)`; the composer derives its own CM for auth
     *      and on-chain reads from `creditFacade.creditManager()`.
     */
    function encodeGearboxV3RepayPartialMax(
        address underlying,
        address creditAccount,
        address creditFacade,
        address creditManager
    )
        internal
        pure
        returns (bytes memory)
    {
        return abi.encodePacked(
            encodeApprove(underlying, creditManager),
            uint8(ComposerCommands.LENDING),
            uint8(LenderOps.REPAY),
            uint16(LenderIds.UP_TO_GEARBOX_V3 - 1),
            underlying,
            GEARBOX_REPAY_ALL, // UINT112_MASK → safe-max sentinel
            creditAccount,
            creditFacade,
            uint8(0) // numQuotedTokens — 0 means "never close", always degrade to partial
        );
    }

    /**
     * @notice Encode a Gearbox V3 withdraw-collateral op.
     * @dev `amount == GEARBOX_WITHDRAW_ALL` translates to Gearbox's own "sweep full balance"
     *      sentinel on `withdrawCollateral`.
     */
    function encodeGearboxV3Withdraw(
        address token,
        uint128 amount,
        address receiver,
        address creditAccount,
        address creditFacade
    )
        internal
        pure
        returns (bytes memory)
    {
        return abi.encodePacked(
            uint8(ComposerCommands.LENDING),
            uint8(LenderOps.WITHDRAW),
            uint16(LenderIds.UP_TO_GEARBOX_V3 - 1),
            token,
            amount,
            receiver,
            creditAccount,
            creditFacade
        );
    }

    /// @dev Pack a single facade-inner call for the generic `GEARBOX_MULTICALL` op.
    ///      Every `GEARBOX_MULTICALL` sub-call targets the facade (no adapters) — the encoder
    ///      doesn't supply a target here, just the inner `callData` bytes.
    function encodeGearboxV3FacadeCall(bytes memory innerCallData) internal pure returns (bytes memory) {
        if (innerCallData.length > type(uint16).max) revert("CL: gearbox sub-call too long");
        return abi.encodePacked(uint16(innerCallData.length), innerCallData);
    }

    /**
     * @notice Encode a `botMulticall(creditAccount, calls)` via the generic Gearbox relay.
     * @dev `calls` is the concatenation of `encodeGearboxV3FacadeCall(…)` outputs. `numCalls`
     *      is implicit in the blob — callers must pass the explicit count so the composer
     *      can iterate without a length scan.
     */
    function encodeGearboxV3BotMulticall(
        address creditFacade,
        address creditAccount,
        uint16 numCalls,
        bytes memory calls
    )
        internal
        pure
        returns (bytes memory)
    {
        return abi.encodePacked(
            uint8(ComposerCommands.LENDING),
            uint8(LenderOps.GEARBOX_MULTICALL),
            uint16(LenderIds.UP_TO_GEARBOX_V3 - 1),
            uint8(0), // kind = botMulticall
            creditFacade,
            creditAccount,
            bytes32(0), // referralCode placeholder
            numCalls,
            calls
        );
    }

    /**
     * @notice Encode an `openCreditAccount(onBehalfOf=composerCaller, calls, referralCode)` via
     *         the generic Gearbox relay.
     * @dev `onBehalfOf` is hard-coded at dispatch to the authenticated deltaCompose caller —
     *      the encoder cannot spoof it. See GEARBOX.md §3.2.
     */
    function encodeGearboxV3OpenCreditAccount(
        address creditFacade,
        uint256 referralCode,
        uint16 numCalls,
        bytes memory calls
    )
        internal
        pure
        returns (bytes memory)
    {
        return abi.encodePacked(
            uint8(ComposerCommands.LENDING),
            uint8(LenderOps.GEARBOX_MULTICALL),
            uint16(LenderIds.UP_TO_GEARBOX_V3 - 1),
            uint8(1), // kind = openCreditAccount
            creditFacade,
            address(0), // creditAccount slot unused for open
            referralCode,
            numCalls,
            calls
        );
    }
}
