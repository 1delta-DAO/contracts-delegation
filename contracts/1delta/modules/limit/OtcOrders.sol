// SPDX-License-Identifier: BUSL 1.1

pragma solidity ^0.8.24;

import "./BatchFillNativeOrders.sol";
import "./IOtcOrdersFeature.sol";

/// @dev Feature for interacting with OTC orders.
contract OtcOrders is IOtcOrdersFeature, BatchFillNativeOrders {
    error makerTokenNotWeth();
    error takerTokenNotEth();
    /// @dev ETH pseudo-token address.
    address private constant ETH_TOKEN_ADDRESS = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;
    /// @dev The WETH token contract.
    address private immutable WETH;

    constructor(
        address weth,
        address protocolFeeCollector,
        uint32 protocolFeeMultiplier
        ) BatchFillNativeOrders(protocolFeeCollector, protocolFeeMultiplier) {
        WETH = weth;
    }


    /// @dev Fill an OTC order for up to `takerTokenFillAmount` taker tokens.
    /// @param order The OTC order.
    /// @param makerSignature The order signature from the maker.
    /// @param takerTokenFillAmount Maximum taker token amount to fill this
    ///        order with.
    /// @return takerTokenFilledAmount How much taker token was filled.
    /// @return makerTokenFilledAmount How much maker token was filled.
    function fillOtcOrder(
        LibNativeOrder.OtcOrder calldata order,
        LibSignature.Signature calldata makerSignature,
        uint128 takerTokenFillAmount
    ) public override returns (uint128 takerTokenFilledAmount, uint128 makerTokenFilledAmount) {
        LibNativeOrder.OtcOrderInfo memory orderInfo = getOtcOrderInfo(order);
        _validateOtcOrder(order, orderInfo, makerSignature, msg.sender);
        (takerTokenFilledAmount, makerTokenFilledAmount) = _settleOtcOrder(
            order,
            takerTokenFillAmount,
            msg.sender,
            msg.sender
        );

        emit OtcOrderFilled(
            orderInfo.orderHash,
            order.maker,
            msg.sender,
            address(order.makerToken),
            address(order.takerToken),
            makerTokenFilledAmount,
            takerTokenFilledAmount
        );
    }

    /// @dev Fill an OTC order for up to `takerTokenFillAmount` taker tokens.
    ///      Unwraps bought WETH into ETH. before sending it to
    ///      the taker.
    /// @param order The OTC order.
    /// @param makerSignature The order signature from the maker.
    /// @param takerTokenFillAmount Maximum taker token amount to fill this
    ///        order with.
    /// @return takerTokenFilledAmount How much taker token was filled.
    /// @return makerTokenFilledAmount How much maker token was filled.
    function fillOtcOrderForEth(
        LibNativeOrder.OtcOrder calldata order,
        LibSignature.Signature calldata makerSignature,
        uint128 takerTokenFillAmount
    ) public override returns (uint128 takerTokenFilledAmount, uint128 makerTokenFilledAmount) {
        if(order.makerToken != WETH) revert makerTokenNotWeth();
        LibNativeOrder.OtcOrderInfo memory orderInfo = getOtcOrderInfo(order);
        _validateOtcOrder(order, orderInfo, makerSignature, msg.sender);
        (takerTokenFilledAmount, makerTokenFilledAmount) = _settleOtcOrder(
            order,
            takerTokenFillAmount,
            msg.sender,
            address(this)
        );
        // Unwrap WETH
        _withdrawNative(WETH, makerTokenFilledAmount);
        // Transfer ETH to taker
        _transferEth(msg.sender, makerTokenFilledAmount);

        emit OtcOrderFilled(
            orderInfo.orderHash,
            order.maker,
            msg.sender,
            address(order.makerToken),
            address(order.takerToken),
            makerTokenFilledAmount,
            takerTokenFilledAmount
        );
    }

    /// @dev Fill an OTC order whose taker token is WETH for up
    ///      to `msg.value`.
    /// @param order The OTC order.
    /// @param makerSignature The order signature from the maker.
    /// @return takerTokenFilledAmount How much taker token was filled.
    /// @return makerTokenFilledAmount How much maker token was filled.
    function fillOtcOrderWithEth(
        LibNativeOrder.OtcOrder calldata order,
        LibSignature.Signature calldata makerSignature
    ) public payable override returns (uint128 takerTokenFilledAmount, uint128 makerTokenFilledAmount) {
        if (order.takerToken == WETH) {
            // Wrap ETH
            _depositNative(WETH, msg.value);
        } else {
            if(
                address(order.takerToken) != ETH_TOKEN_ADDRESS
            ) revert takerTokenNotEth();
        }

        LibNativeOrder.OtcOrderInfo memory orderInfo = getOtcOrderInfo(order);
        _validateOtcOrder(order, orderInfo, makerSignature, msg.sender);

        (takerTokenFilledAmount, makerTokenFilledAmount) = _settleOtcOrder(
            order,
            uint128(msg.value),
            address(this),
            msg.sender
        );
        if (takerTokenFilledAmount < msg.value) {
            uint256 refundAmount = msg.value - uint256(takerTokenFilledAmount);
            if (order.takerToken == WETH) {
                _withdrawNative(WETH, refundAmount);
            }
            // Refund unused ETH
            _transferEth(msg.sender, refundAmount);
        }

        emit OtcOrderFilled(
            orderInfo.orderHash,
            order.maker,
            msg.sender,
            order.makerToken,
            order.takerToken,
            makerTokenFilledAmount,
            takerTokenFilledAmount
        );
    }

    /// @dev Fully fill an OTC order. "Meta-transaction" variant,
    ///      requires order to be signed by both maker and taker.
    /// @param order The OTC order.
    /// @param makerSignature The order signature from the maker.
    /// @param takerSignature The order signature from the taker.
    function fillTakerSignedOtcOrder(
        LibNativeOrder.OtcOrder calldata order,
        LibSignature.Signature calldata makerSignature,
        LibSignature.Signature calldata takerSignature
    ) public override {
        LibNativeOrder.OtcOrderInfo memory orderInfo = getOtcOrderInfo(order);
        address taker = LibSignature.getSignerOfHash(orderInfo.orderHash, takerSignature);

        _validateOtcOrder(order, orderInfo, makerSignature, taker);
        _settleOtcOrder(order, order.takerAmount, taker, taker);

        emit OtcOrderFilled(
            orderInfo.orderHash,
            order.maker,
            taker,
            order.makerToken,
            order.takerToken,
            order.makerAmount,
            order.takerAmount
        );
    }

    /// @dev Fully fill an OTC order. "Meta-transaction" variant,
    ///      requires order to be signed by both maker and taker.
    ///      Unwraps bought WETH into ETH. before sending it to
    ///      the taker.
    /// @param order The OTC order.
    /// @param makerSignature The order signature from the maker.
    /// @param takerSignature The order signature from the taker.
    function fillTakerSignedOtcOrderForEth(
        LibNativeOrder.OtcOrder calldata order,
        LibSignature.Signature calldata makerSignature,
        LibSignature.Signature calldata takerSignature
    ) public override {
        if(order.makerToken != WETH) revert makerTokenNotWeth();
        LibNativeOrder.OtcOrderInfo memory orderInfo = getOtcOrderInfo(order);
        address taker = LibSignature.getSignerOfHash(orderInfo.orderHash, takerSignature);

        _validateOtcOrder(order, orderInfo, makerSignature, taker);
        _settleOtcOrder(order, order.takerAmount, taker, address(this));
        // Unwrap WETH
        _withdrawNative(WETH, order.makerAmount);
        // Transfer ETH to taker
        _transferEth(payable(taker), order.makerAmount);

        emit OtcOrderFilled(
            orderInfo.orderHash,
            order.maker,
            taker,
            order.makerToken,
            order.takerToken,
            order.makerAmount,
            order.takerAmount
        );
    }

    /// @dev Fills multiple taker-signed OTC orders.
    /// @param orders Array of OTC orders.
    /// @param makerSignatures Array of maker signatures for each order.
    /// @param takerSignatures Array of taker signatures for each order.
    /// @param unwrapWeth Array of booleans representing whether or not
    ///        to unwrap bought WETH into ETH for each order. Should be set
    ///        to false if the maker token is not WETH.
    /// @return successes Array of booleans representing whether or not
    ///         each order in `orders` was filled successfully.
    function batchFillTakerSignedOtcOrders(
        LibNativeOrder.OtcOrder[] calldata orders,
        LibSignature.Signature[] calldata makerSignatures,
        LibSignature.Signature[] calldata takerSignatures,
        bool[] memory unwrapWeth
    ) public override returns (bool[] memory successes) {
        if(
            orders.length != makerSignatures.length ||
                orders.length != takerSignatures.length ||
                orders.length != unwrapWeth.length
                ) revert mismatchedArrayLengths();
    
        successes = new bool[](orders.length);
        for (uint256 i; i != orders.length; i++) {
            bytes4 fnSelector = unwrapWeth[i]
                ? this.fillTakerSignedOtcOrderForEth.selector
                : this.fillTakerSignedOtcOrder.selector;
            // Swallow reverts
            (successes[i], ) = address(this).delegatecall(
                abi.encodeWithSelector(fnSelector, orders[i], makerSignatures[i], takerSignatures[i])
            );
        }
    }

    /// @dev Validates an OTC order, reverting if the order cannot be
    ///      filled by the given taker.
    /// @param order The OTC order.
    /// @param orderInfo Info on the order.
    /// @param makerSignature The order signature from the maker.
    /// @param taker The order taker.
    function _validateOtcOrder(
        LibNativeOrder.OtcOrder calldata order,
        LibNativeOrder.OtcOrderInfo memory orderInfo,
        LibSignature.Signature calldata makerSignature,
        address taker
    ) private view {
        // Must be fillable.
        if (orderInfo.status != LibNativeOrder.OrderStatus.FILLABLE) {
            LibNativeErrors.orderNotFillableError(orderInfo.orderHash, uint8(orderInfo.status));
        }

        // Must be a valid taker for the order.
        if (order.taker != address(0) && order.taker != taker) {
            LibNativeErrors.orderNotFillableByTakerError(orderInfo.orderHash, taker, order.taker);
        }


        // Must be fillable by the tx.origin.
        if (order.txOrigin != tx.origin && !originRegistry[order.txOrigin][tx.origin]) {
            LibNativeErrors
                .orderNotFillableByOriginError(orderInfo.orderHash, order.txOrigin);
        }

        // Maker signature must be valid for the order.
        address makerSigner = LibSignature.getSignerOfHash(orderInfo.orderHash, makerSignature);
        if (makerSigner != order.maker && !orderSignerRegistry[order.maker][makerSigner]) {
            LibNativeErrors
                .orderNotSignedByMakerError(orderInfo.orderHash, makerSigner, order.maker);
        }
    }

    /// @dev Settle the trade between an OTC order's maker and taker.
    /// @param order The OTC order.
    /// @param takerTokenFillAmount Maximum taker token amount to fill this
    ///        order with.
    /// @param payer The address holding the taker tokens.
    /// @param recipient The recipient of the maker tokens.
    /// @return takerTokenFilledAmount How much taker token was filled.
    /// @return makerTokenFilledAmount How much maker token was filled.
    function _settleOtcOrder(
        LibNativeOrder.OtcOrder memory order,
        uint128 takerTokenFillAmount,
        address payer,
        address recipient
    ) private returns (uint128 takerTokenFilledAmount, uint128 makerTokenFilledAmount) {
        {
            // Unpack nonce fields
            uint64 nonceBucket = uint64(order.expiryAndNonce >> 128);
            uint128 nonce = uint128(order.expiryAndNonce);
            // Update tx origin nonce for the order
            txOriginNonces[order.txOrigin][nonceBucket] = nonce;
        }

        if (takerTokenFillAmount == order.takerAmount) {
            takerTokenFilledAmount = order.takerAmount;
            makerTokenFilledAmount = order.makerAmount;
        } else {
            // Clamp the taker token fill amount to the fillable amount.
            takerTokenFilledAmount = min128(takerTokenFillAmount, order.takerAmount);
            // Compute the maker token amount.
            // This should never overflow because the values are all clamped to
            // (2^128-1).
            makerTokenFilledAmount = uint128(
                    uint256(takerTokenFilledAmount) *
                    uint256(order.makerAmount) /
                    uint256(order.takerAmount)
            );
        }

        if (payer == address(this)) {
            if (order.takerToken == ETH_TOKEN_ADDRESS) {
                // Transfer ETH to the maker.
                payable(order.maker).transfer(takerTokenFilledAmount);
            } else {
                // Transfer this -> maker.
                _transferERC20Tokens(order.takerToken, order.maker, takerTokenFilledAmount);
            }
        } else {
            // Transfer taker -> maker
            _transferERC20TokensFrom(order.takerToken, payer, order.maker, takerTokenFilledAmount);
        }
        // Transfer maker -> recipient.
        _transferERC20TokensFrom(order.makerToken, order.maker, recipient, makerTokenFilledAmount);
    }

    /// @dev Get the order info for an OTC order.
    /// @param order The OTC order.
    /// @return orderInfo Info about the order.
    function getOtcOrderInfo(
        LibNativeOrder.OtcOrder memory order
    ) public view override returns (LibNativeOrder.OtcOrderInfo memory orderInfo) {
        // compute order hash.
        orderInfo.orderHash = getOtcOrderHash(order);


        // Unpack expiry and nonce fields
        uint64 expiry = uint64(order.expiryAndNonce >> 192);
        uint64 nonceBucket = uint64(order.expiryAndNonce >> 128);
        uint128 nonce = uint128(order.expiryAndNonce);

        // check tx origin nonce
        uint128 lastNonce = txOriginNonces[order.txOrigin][nonceBucket];
        if (nonce <= lastNonce) {
            orderInfo.status = LibNativeOrder.OrderStatus.INVALID;
            return orderInfo;
        }

        // Check for expiration.
        if (expiry <= uint64(block.timestamp)) {
            orderInfo.status = LibNativeOrder.OrderStatus.EXPIRED;
            return orderInfo;
        }

        orderInfo.status = LibNativeOrder.OrderStatus.FILLABLE;
        return orderInfo;
    }

    /// @dev Get the canonical hash of an OTC order.
    /// @param order The OTC order.
    /// @return orderHash The order hash.
    function getOtcOrderHash(LibNativeOrder.OtcOrder memory order) public view override returns (bytes32 orderHash) {
        return _getEIP712Hash(LibNativeOrder.getOtcOrderStructHash(order));
    }

    /// @dev Get the last nonce used for a particular
    ///      tx.origin address and nonce bucket.
    /// @param txOrigin The address.
    /// @param nonceBucket The nonce bucket index.
    /// @return lastNonce The last nonce value used.
    function lastOtcTxOriginNonce(
        address txOrigin,
        uint64 nonceBucket
    ) public view override returns (uint128 lastNonce) {
        return txOriginNonces[txOrigin][nonceBucket];
    }
}
