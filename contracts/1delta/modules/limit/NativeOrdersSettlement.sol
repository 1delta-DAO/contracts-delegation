// SPDX-License-Identifier: BUSL 1.1

pragma solidity ^0.8.0;

import "./INativeOrdersEvents.sol";
import "./libraries/LibSignature.sol";
import "./libraries/LibNativeOrder.sol";
import "./libraries/LibNativeErrors.sol";
import "./libraries/Reverter.sol";
import "./NativeOrdersCancellation.sol";

/// @dev Mixin for settling limit and RFQ orders.
///      Uses custom internal error handling to pass through revert reasons
abstract contract NativeOrdersSettlement is
    INativeOrdersEvents,
    NativeOrdersCancellation
{
    error noContractOrigins();
    error fillOrKillFailedError(bytes32 hash, uint128 takerTokenFilledAmount, uint128 takerTokenFillAmount);

    /// @dev Params for `_settleOrder()`.
    struct SettleOrderInfo {
        // Order hash.
        bytes32 orderHash;
        // Maker of the order.
        address maker;
        // The address holding the taker tokens.
        address payer;
        // Recipient of the maker tokens.
        address recipient;
        // Maker token.
        address makerToken;
        // Taker token.
        address takerToken;
        // Maker token amount.
        uint128 makerAmount;
        // Taker token amount.
        uint128 takerAmount;
        // Maximum taker token amount to fill.
        uint128 takerTokenFillAmount;
        // How much taker token amount has already been filled in this order.
        uint128 takerTokenFilledAmount;
    }

    /// @dev Params for `_fillLimitOrderPrivate()`
    struct FillLimitOrderPrivateParams {
        // The limit order.
        LibNativeOrder.LimitOrder order;
        // The order signature.
        LibSignature.Signature signature;
        // Maximum taker token to fill this order with.
        uint128 takerTokenFillAmount;
        // The order taker.
        address taker;
        // The order sender.
        address sender;
    }

    /// @dev Params for `_fillRfqOrderPrivate()`
    struct FillRfqOrderPrivateParams {
        LibNativeOrder.RfqOrder order;
        // The order signature.
        LibSignature.Signature signature;
        // Maximum taker token to fill this order with.
        uint128 takerTokenFillAmount;
        // The order taker.
        address taker;
        // Whether to use the Exchange Proxy's balance
        // of taker tokens.
        bool useSelfBalance;
        // The recipient of the maker tokens.
        address recipient;
    }

    // @dev Fill results returned by `_fillLimitOrderPrivate()` and
    ///     `_fillRfqOrderPrivate()`.
    struct FillNativeOrderResults {
        uint256 ethProtocolFeePaid;
        uint128 takerTokenFilledAmount;
        uint128 makerTokenFilledAmount;
        uint128 takerTokenFeeFilledAmount;
    }

    /// @dev The protocol fee multiplier.
    uint32 public immutable PROTOCOL_FEE_MULTIPLIER;
    /// @dev The protocol collector address.
    address public immutable PROTOCOL_FEE_COLLECTOR;

    constructor(
        address protocolFeeCollector,
        uint32 protocolFeeMultiplier
    ) NativeOrdersCancellation()
    {
        PROTOCOL_FEE_MULTIPLIER = protocolFeeMultiplier;
        PROTOCOL_FEE_COLLECTOR = protocolFeeCollector;
    }

    /// @dev Fill a limit order. The taker and sender will be the caller.
    /// @param order The limit order. ETH protocol fees can be
    ///      attached to this call. Any unspent ETH will be refunded to
    ///      the caller.
    /// @param signature The order signature.
    /// @param takerTokenFillAmount Maximum taker token amount to fill this order with.
    /// @return takerTokenFilledAmount How much maker token was filled.
    /// @return makerTokenFilledAmount How much maker token was filled.
    function fillLimitOrder(
        LibNativeOrder.LimitOrder memory order,
        LibSignature.Signature memory signature,
        uint128 takerTokenFillAmount
    ) public payable returns (uint128 takerTokenFilledAmount, uint128 makerTokenFilledAmount) {
        (FillNativeOrderResults memory results, bytes memory errorData) = _fillLimitOrderPrivate(
            FillLimitOrderPrivateParams({
                order: order,
                signature: signature,
                takerTokenFillAmount: takerTokenFillAmount,
                taker: msg.sender,
                sender: msg.sender
            })
        );
        if(errorData.length > 0) Reverter.revertWithData(errorData);
        refundExcessProtocolFeeToSender(results.ethProtocolFeePaid);
        (takerTokenFilledAmount, makerTokenFilledAmount) = (
            results.takerTokenFilledAmount,
            results.makerTokenFilledAmount
        );
    }

    /// @dev Fill an RFQ order for up to `takerTokenFillAmount` taker tokens.
    ///      The taker will be the caller. ETH should be attached to pay the
    ///      protocol fee.
    /// @param order The RFQ order.
    /// @param signature The order signature.
    /// @param takerTokenFillAmount Maximum taker token amount to fill this order with.
    /// @return takerTokenFilledAmount How much maker token was filled.
    /// @return makerTokenFilledAmount How much maker token was filled.
    function fillRfqOrder(
        LibNativeOrder.RfqOrder memory order,
        LibSignature.Signature memory signature,
        uint128 takerTokenFillAmount
    ) public returns (uint128 takerTokenFilledAmount, uint128 makerTokenFilledAmount) {
        (FillNativeOrderResults memory results, bytes memory errorData) = _fillRfqOrderPrivate(
            FillRfqOrderPrivateParams({
                order: order,
                signature: signature,
                takerTokenFillAmount: takerTokenFillAmount,
                taker: msg.sender,
                useSelfBalance: false,
                recipient: msg.sender
            })
        );
        if(errorData.length > 0) Reverter.revertWithData(errorData);
        (takerTokenFilledAmount, makerTokenFilledAmount) = (
            results.takerTokenFilledAmount,
            results.makerTokenFilledAmount
        );
    }

    /// @dev Fill an RFQ order for exactly `takerTokenFillAmount` taker tokens.
    ///      The taker will be the caller. ETH protocol fees can be
    ///      attached to this call. Any unspent ETH will be refunded to
    ///      the caller.
    /// @param order The limit order.
    /// @param signature The order signature.
    /// @param takerTokenFillAmount How much taker token to fill this order with.
    /// @return makerTokenFilledAmount How much maker token was filled.
    function fillOrKillLimitOrder(
        LibNativeOrder.LimitOrder calldata order,
        LibSignature.Signature calldata signature,
        uint128 takerTokenFillAmount
    ) public payable returns (uint128 makerTokenFilledAmount) {
        (FillNativeOrderResults memory results, bytes memory errorData) = _fillLimitOrderPrivate(
            FillLimitOrderPrivateParams({
                order: order,
                signature: signature,
                takerTokenFillAmount: takerTokenFillAmount,
                taker: msg.sender,
                sender: msg.sender
            })
        );
        if(errorData.length > 0) Reverter.revertWithData(errorData);
        // Must have filled exactly the amount requested.
        if (results.takerTokenFilledAmount < takerTokenFillAmount) {
            revert fillOrKillFailedError(
                    getLimitOrderHash(order),
                    results.takerTokenFilledAmount,
                    takerTokenFillAmount
                );
        }
        refundExcessProtocolFeeToSender(results.ethProtocolFeePaid);
        makerTokenFilledAmount = results.makerTokenFilledAmount;
    }

    /// @dev Fill an RFQ order for exactly `takerTokenFillAmount` taker tokens.
    ///      The taker will be the caller. ETH protocol fees can be
    ///      attached to this call. Any unspent ETH will be refunded to
    ///      the caller.
    /// @param order The RFQ order.
    /// @param signature The order signature.
    /// @param takerTokenFillAmount How much taker token to fill this order with.
    /// @return makerTokenFilledAmount How much maker token was filled.
    function fillOrKillRfqOrder(
        LibNativeOrder.RfqOrder calldata order,
        LibSignature.Signature calldata signature,
        uint128 takerTokenFillAmount
    ) public returns (uint128 makerTokenFilledAmount) {
        (FillNativeOrderResults memory results, bytes memory errorData) = _fillRfqOrderPrivate(
            FillRfqOrderPrivateParams({
                order: order,
                signature: signature,
                takerTokenFillAmount: takerTokenFillAmount,
                taker: msg.sender,
                useSelfBalance: false,
                recipient: msg.sender
            })
        );
        if(errorData.length > 0) Reverter.revertWithData(errorData);
        // Must have filled exactly the amount requested.
        if (results.takerTokenFilledAmount < takerTokenFillAmount) {
            revert fillOrKillFailedError(
                getRfqOrderHash(order),
                results.takerTokenFilledAmount,
                takerTokenFillAmount
            );
        }
        makerTokenFilledAmount = results.makerTokenFilledAmount;
    }

    /// @dev Mark what tx.origin addresses are allowed to fill an order that
    ///      specifies the message sender as its txOrigin.
    /// @param origins An array of origin addresses to update.
    /// @param allowed True to register, false to unregister.
    function registerAllowedRfqOrigins(address[] memory origins, bool allowed) external {
        if(msg.sender != tx.origin) revert noContractOrigins();

        for (uint256 i = 0; i < origins.length; i++) {
            originRegistry[msg.sender][origins[i]] = allowed;
        }

        emit RfqOrderOriginsAllowed(msg.sender, origins, allowed);
    }

    /// @dev Fill a limit order. Private variant.
    ///      Does not refund protocol fees.
    ///      Does not revert on erros.
    /// @param params Function params.
    /// @return results Results of the fill, everything is zeroed on.
    /// @return errorData Encoded error if any.
    function _fillLimitOrderPrivate(
        FillLimitOrderPrivateParams memory params
    ) internal returns (FillNativeOrderResults memory results, bytes memory errorData) {
        LibNativeOrder.OrderInfo memory orderInfo = getLimitOrderInfo(params.order);

        // Must be fillable.
        if (orderInfo.status != LibNativeOrder.OrderStatus.FILLABLE) {
            errorData =  LibNativeErrors.orderNotFillableError(
                orderInfo.orderHash, 
                uint8(orderInfo.status)
            );
            return (results, errorData);
        }

        // Must be fillable by the taker.
        if (params.order.taker != address(0) && params.order.taker != params.taker) {
            errorData =  LibNativeErrors.orderNotFillableByTakerError(
                orderInfo.orderHash,
                params.taker,
                params.order.taker
            );
            return (results, errorData);
        }

        // Must be fillable by the sender.
        if (params.order.sender != address(0) && params.order.sender != params.sender) {
            errorData =  LibNativeErrors.orderNotFillableBySenderError(
                orderInfo.orderHash,
                params.sender,
                params.order.sender
            );
            return (results, errorData);
        }

        // Signature must be valid for the order.
        {
            address signer = LibSignature.getSignerOfHash(orderInfo.orderHash, params.signature);
            if (signer != params.order.maker && !isValidOrderSigner(params.order.maker, signer)) {
                errorData =  LibNativeErrors.orderNotSignedByMakerError(
                    orderInfo.orderHash,
                    signer,
                    params.order.maker
                );
                return (results, errorData);
            }
        }

        // Settle between the maker and taker.
        (results.takerTokenFilledAmount, results.makerTokenFilledAmount) = _settleOrder(
            SettleOrderInfo({
                orderHash: orderInfo.orderHash,
                maker: params.order.maker,
                payer: params.taker,
                recipient: params.taker,
                makerToken: params.order.makerToken,
                takerToken: params.order.takerToken,
                makerAmount: params.order.makerAmount,
                takerAmount: params.order.takerAmount,
                takerTokenFillAmount: params.takerTokenFillAmount,
                takerTokenFilledAmount: orderInfo.takerTokenFilledAmount
            })
        );

        // Pay the protocol fee.
        results.ethProtocolFeePaid = _collectProtocolFee();

        // Pay the fee recipient.
        if (params.order.takerTokenFeeAmount > 0) {
            results.takerTokenFeeFilledAmount = uint128(
                    results.takerTokenFilledAmount *
                    params.order.takerTokenFeeAmount /
                    params.order.takerAmount
            );
            _transferERC20TokensFrom(
                params.order.takerToken,
                params.taker,
                params.order.feeRecipient,
                uint256(results.takerTokenFeeFilledAmount)
            );
        }

        emit LimitOrderFilled(
            orderInfo.orderHash,
            params.order.maker,
            params.taker,
            params.order.feeRecipient,
            params.order.makerToken,
            params.order.takerToken,
            results.takerTokenFilledAmount,
            results.makerTokenFilledAmount,
            results.takerTokenFeeFilledAmount,
            results.ethProtocolFeePaid,
            params.order.pool
        );
    }

    /// @dev Fill an RFQ order. Private variant.
    ///      Does not revert on erros.
    /// @param params Function params.
    /// @return results Results of the fill.
    /// @return errorData Encoded error if any.
    function _fillRfqOrderPrivate(
        FillRfqOrderPrivateParams memory params
    ) internal returns (FillNativeOrderResults memory results, bytes memory errorData) {
        LibNativeOrder.OrderInfo memory orderInfo = getRfqOrderInfo(params.order);

        // Must be fillable.
        if (orderInfo.status != LibNativeOrder.OrderStatus.FILLABLE) {
            errorData =  LibNativeErrors.orderNotFillableError(
                orderInfo.orderHash,
                uint8(orderInfo.status)
            );
            return (results, errorData);
        }

        {

            // Must be fillable by the tx.origin.
            if (params.order.txOrigin != tx.origin && !originRegistry[params.order.txOrigin][tx.origin]) {
                errorData = LibNativeErrors.orderNotFillableByOriginError(
                    orderInfo.orderHash,
                    params.order.txOrigin
                );
                return (results, errorData);
            }
        }

        // Must be fillable by the taker.
        if (params.order.taker != address(0) && params.order.taker != params.taker) {
            errorData = LibNativeErrors.orderNotFillableByTakerError(
                orderInfo.orderHash,
                params.taker,
                params.order.taker
            );
            return (results, errorData);
        }

        // Signature must be valid for the order.
        {
            address signer = LibSignature.getSignerOfHash(orderInfo.orderHash, params.signature);
            if (signer != params.order.maker && !isValidOrderSigner(params.order.maker, signer)) {
                errorData = LibNativeErrors.orderNotSignedByMakerError(
                    orderInfo.orderHash,
                    signer,
                    params.order.maker
                );
                return (results, errorData);
            }
        }

        // Settle between the maker and taker.
        (results.takerTokenFilledAmount, results.makerTokenFilledAmount) = _settleOrder(
            SettleOrderInfo({
                orderHash: orderInfo.orderHash,
                maker: params.order.maker,
                payer: params.useSelfBalance ? address(this) : params.taker,
                recipient: params.recipient,
                makerToken: params.order.makerToken,
                takerToken: params.order.takerToken,
                makerAmount: params.order.makerAmount,
                takerAmount: params.order.takerAmount,
                takerTokenFillAmount: params.takerTokenFillAmount,
                takerTokenFilledAmount: orderInfo.takerTokenFilledAmount
            })
        );

        emit RfqOrderFilled(
            orderInfo.orderHash,
            params.order.maker,
            params.taker,
            params.order.makerToken,
            params.order.takerToken,
            results.takerTokenFilledAmount,
            results.makerTokenFilledAmount,
            params.order.pool
        );
    }

    /// @dev Settle the trade between an order's maker and taker.
    /// @param settleInfo Information needed to execute the settlement.
    /// @return takerTokenFilledAmount How much taker token was filled.
    /// @return makerTokenFilledAmount How much maker token was filled.
    function _settleOrder(
        SettleOrderInfo memory settleInfo
    ) private returns (uint128 takerTokenFilledAmount, uint128 makerTokenFilledAmount) {
        // Clamp the taker token fill amount to the fillable amount.
        takerTokenFilledAmount = min128(
            settleInfo.takerTokenFillAmount,
            settleInfo.takerAmount - settleInfo.takerTokenFilledAmount
        );
        // Compute the maker token amount.
        // This should never overflow because the values are all clamped to
        // (2^128-1).
        makerTokenFilledAmount = uint128(
            uint256(takerTokenFilledAmount) *
            uint256(settleInfo.makerAmount) / 
            uint256(settleInfo.takerAmount)
        );


        if (takerTokenFilledAmount == 0 || makerTokenFilledAmount == 0) {
            // Nothing to do.
            return (0, 0);
        }

        // Update filled state for the order.
        // solhint-disable-next-line max-line-length
        orderHashToTakerTokenFilledAmount[settleInfo.orderHash] = safeAdd128(
            settleInfo // function if the order is cancelled. // OK to overwrite the whole word because we shouldn't get to this
            .takerTokenFilledAmount,
             takerTokenFilledAmount);

        if (settleInfo.payer == address(this)) {
            // Transfer this -> maker.
            _transferERC20Tokens(settleInfo.takerToken, settleInfo.maker, takerTokenFilledAmount);
        } else {
            // Transfer taker -> maker.
            _transferERC20TokensFrom(settleInfo.takerToken, settleInfo.payer, settleInfo.maker, takerTokenFilledAmount);
        }

        // Transfer maker -> recipient.
        _transferERC20TokensFrom(settleInfo.makerToken, settleInfo.maker, settleInfo.recipient, makerTokenFilledAmount);
    }

    /// @dev register a signer who can sign on behalf of msg.sender
    /// @param signer The address from which you plan to generate signatures
    /// @param allowed True to register, false to unregister.
    function registerAllowedOrderSigner(address signer, bool allowed) external {

        orderSignerRegistry[msg.sender][signer] = allowed;

        emit OrderSignerRegistered(msg.sender, signer, allowed);
    }

    function min128(uint128 a, uint128 b) internal pure returns (uint128) {
        return a < b ? a : b;
    }

    function safeAdd128(uint128 a, uint128 b) internal pure returns (uint128) {
        uint128 c = a + b;
        if (c < a) revert uint128Overflow();
        return c;
    }


    /// @dev   Collect the specified protocol fee in ETH.
    ///        The fee is stored in a per-pool fee collector contract.
    /// @return ethProtocolFeePaid How much protocol fee was collected in ETH.
    function _collectProtocolFee() internal returns (uint256 ethProtocolFeePaid) {
        uint256 protocolFeePaid = uint256(PROTOCOL_FEE_MULTIPLIER) * tx.gasprice;
        if (protocolFeePaid == 0) {
            // Nothing to do.
            return 0;
        }
        _transferEth(PROTOCOL_FEE_COLLECTOR, protocolFeePaid);
        return protocolFeePaid;
    }


    /// @dev Refund any leftover protocol fees in `msg.value` to `msg.sender`.
    /// @param ethProtocolFeePaid How much ETH was paid in protocol fees.
    function refundExcessProtocolFeeToSender(uint256 ethProtocolFeePaid) internal {
        if (msg.value > ethProtocolFeePaid && msg.sender != address(this)) {
            uint256 refundAmount = msg.value - ethProtocolFeePaid;
            _transferEth(msg.sender, refundAmount);
        }
    }
}
