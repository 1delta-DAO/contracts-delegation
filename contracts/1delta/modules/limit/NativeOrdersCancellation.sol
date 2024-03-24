// SPDX-License-Identifier: BUSL 1.1

pragma solidity ^0.8.0;
pragma experimental ABIEncoderV2;


import "./libraries/LibSignature.sol";
import "./libraries/LibNativeOrder.sol";
import "./NativeOrdersInfo.sol";
import "./INativeOrdersEvents.sol";

/// @dev Feature for cancelling limit and RFQ orders.
abstract contract NativeOrdersCancellation is NativeOrdersInfo, INativeOrdersEvents {
    error invalidSigner(address maker, address sender);
    error onlyOrderMakerAllowed(bytes32 hash, address sender, address maker);
    error cancelSaltTooLowError(uint256 minValidSalt, uint256 oldMinValidSalt);

    /// @dev Highest bit of a uint256, used to flag cancelled orders.
    uint256 private constant HIGH_BIT = 1 << 255;

    constructor(address proxyAddress)  NativeOrdersInfo(proxyAddress) {}

    /// @dev Cancel a single limit order. The caller must be the maker or a valid order signer.
    ///      Silently succeeds if the order has already been cancelled.
    /// @param order The limit order.
    function cancelLimitOrder(LibNativeOrder.LimitOrder memory order) public {
        bytes32 orderHash = getLimitOrderHash(order);
        if (msg.sender != order.maker && !isValidOrderSigner(order.maker, msg.sender)) {
            revert onlyOrderMakerAllowed(orderHash, msg.sender, order.maker);
        }
        _cancelOrderHash(orderHash, order.maker);
    }

    /// @dev Cancel a single RFQ order. The caller must be the maker or a valid order signer.
    ///      Silently succeeds if the order has already been cancelled.
    /// @param order The RFQ order.
    function cancelRfqOrder(LibNativeOrder.RfqOrder memory order) public {
        bytes32 orderHash = getRfqOrderHash(order);
        if (msg.sender != order.maker && !isValidOrderSigner(order.maker, msg.sender)) {
            revert onlyOrderMakerAllowed(orderHash, msg.sender, order.maker);
        }
        _cancelOrderHash(orderHash, order.maker);
    }

    /// @dev Cancel multiple limit orders. The caller must be the maker or a valid order signer.
    ///      Silently succeeds if the order has already been cancelled.
    /// @param orders The limit orders.
    function batchCancelLimitOrders(LibNativeOrder.LimitOrder[] memory orders) public {
        for (uint256 i = 0; i < orders.length; ++i) {
            cancelLimitOrder(orders[i]);
        }
    }

    /// @dev Cancel multiple RFQ orders. The caller must be the maker or a valid order signer.
    ///      Silently succeeds if the order has already been cancelled.
    /// @param orders The RFQ orders.
    function batchCancelRfqOrders(LibNativeOrder.RfqOrder[] memory orders) public {
        for (uint256 i = 0; i < orders.length; ++i) {
            cancelRfqOrder(orders[i]);
        }
    }

    /// @dev Cancel all limit orders for a given maker and pair with a salt less
    ///      than the value provided. The caller must be the maker. Subsequent
    ///      calls to this function with the same caller and pair require the
    ///      new salt to be >= the old salt.
    /// @param makerToken The maker token.
    /// @param takerToken The taker token.
    /// @param minValidSalt The new minimum valid salt.
    function cancelPairLimitOrders(
        address makerToken,
        address takerToken,
        uint256 minValidSalt
    ) public {
        _cancelPairLimitOrders(msg.sender, makerToken, takerToken, minValidSalt);
    }

    /// @dev Cancel all limit orders for a given maker and pair with a salt less
    ///      than the value provided. The caller must be a signer registered to the maker.
    ///      Subsequent calls to this function with the same caller and pair require the
    ///      new salt to be >= the old salt.
    /// @param maker the maker for whom the msg.sender is the signer.
    /// @param makerToken The maker token.
    /// @param takerToken The taker token.
    /// @param minValidSalt The new minimum valid salt.
    function cancelPairLimitOrdersWithSigner(
        address maker,
        address makerToken,
        address takerToken,
        uint256 minValidSalt
    ) public {
        // verify that the signer is authorized for the maker
        if (!isValidOrderSigner(maker, msg.sender)) {
            revert invalidSigner(maker, msg.sender);
        }

        _cancelPairLimitOrders(maker, makerToken, takerToken, minValidSalt);
    }

    /// @dev Cancel all limit orders for a given maker and pair with a salt less
    ///      than the value provided. The caller must be the maker. Subsequent
    ///      calls to this function with the same caller and pair require the
    ///      new salt to be >= the old salt.
    /// @param makerTokens The maker tokens.
    /// @param takerTokens The taker tokens.
    /// @param minValidSalts The new minimum valid salts.
    function batchCancelPairLimitOrders(
        address[] memory makerTokens,
        address[] memory takerTokens,
        uint256[] memory minValidSalts
    ) public {
        require(
            makerTokens.length == takerTokens.length && makerTokens.length == minValidSalts.length,
            "NativeOrdersFeature/MISMATCHED_PAIR_ORDERS_ARRAY_LENGTHS"
        );

        for (uint256 i = 0; i < makerTokens.length; ++i) {
            _cancelPairLimitOrders(msg.sender, makerTokens[i], takerTokens[i], minValidSalts[i]);
        }
    }

    /// @dev Cancel all limit orders for a given maker and pair with a salt less
    ///      than the value provided. The caller must be a signer registered to the maker.
    ///      Subsequent calls to this function with the same caller and pair require the
    ///      new salt to be >= the old salt.
    /// @param maker the maker for whom the msg.sender is the signer.
    /// @param makerTokens The maker tokens.
    /// @param takerTokens The taker tokens.
    /// @param minValidSalts The new minimum valid salts.
    function batchCancelPairLimitOrdersWithSigner(
        address maker,
        address[] memory makerTokens,
        address[] memory takerTokens,
        uint256[] memory minValidSalts
    ) public {
        require(
            makerTokens.length == takerTokens.length && makerTokens.length == minValidSalts.length,
            "NativeOrdersFeature/MISMATCHED_PAIR_ORDERS_ARRAY_LENGTHS"
        );

        if (!isValidOrderSigner(maker, msg.sender)) {
            revert invalidSigner(maker, msg.sender);
        }

        for (uint256 i = 0; i < makerTokens.length; ++i) {
            _cancelPairLimitOrders(maker, makerTokens[i], takerTokens[i], minValidSalts[i]);
        }
    }

    /// @dev Cancel all RFQ orders for a given maker and pair with a salt less
    ///      than the value provided. The caller must be the maker. Subsequent
    ///      calls to this function with the same caller and pair require the
    ///      new salt to be >= the old salt.
    /// @param makerToken The maker token.
    /// @param takerToken The taker token.
    /// @param minValidSalt The new minimum valid salt.
    function cancelPairRfqOrders(
        address makerToken,
        address takerToken,
        uint256 minValidSalt
    ) public {
        _cancelPairRfqOrders(msg.sender, makerToken, takerToken, minValidSalt);
    }

    /// @dev Cancel all RFQ orders for a given maker and pair with a salt less
    ///      than the value provided. The caller must be a signer registered to the maker.
    ///      Subsequent calls to this function with the same caller and pair require the
    ///      new salt to be >= the old salt.
    /// @param maker the maker for whom the msg.sender is the signer.
    /// @param makerToken The maker token.
    /// @param takerToken The taker token.
    /// @param minValidSalt The new minimum valid salt.
    function cancelPairRfqOrdersWithSigner(
        address maker,
        address makerToken,
        address takerToken,
        uint256 minValidSalt
    ) public {
        if (!isValidOrderSigner(maker, msg.sender)) {
            revert invalidSigner(maker, msg.sender);
        }

        _cancelPairRfqOrders(maker, makerToken, takerToken, minValidSalt);
    }

    /// @dev Cancel all RFQ orders for a given maker and pair with a salt less
    ///      than the value provided. The caller must be the maker. Subsequent
    ///      calls to this function with the same caller and pair require the
    ///      new salt to be >= the old salt.
    /// @param makerTokens The maker tokens.
    /// @param takerTokens The taker tokens.
    /// @param minValidSalts The new minimum valid salts.
    function batchCancelPairRfqOrders(
        address[] memory makerTokens,
        address[] memory takerTokens,
        uint256[] memory minValidSalts
    ) public {
        require(
            makerTokens.length == takerTokens.length && makerTokens.length == minValidSalts.length,
            "NativeOrdersFeature/MISMATCHED_PAIR_ORDERS_ARRAY_LENGTHS"
        );

        for (uint256 i = 0; i < makerTokens.length; ++i) {
            _cancelPairRfqOrders(msg.sender, makerTokens[i], takerTokens[i], minValidSalts[i]);
        }
    }

    /// @dev Cancel all RFQ orders for a given maker and pairs with salts less
    ///      than the values provided. The caller must be a signer registered to the maker.
    ///      Subsequent calls to this function with the same caller and pair require the
    ///      new salt to be >= the old salt.
    /// @param maker the maker for whom the msg.sender is the signer.
    /// @param makerTokens The maker tokens.
    /// @param takerTokens The taker tokens.
    /// @param minValidSalts The new minimum valid salts.
    function batchCancelPairRfqOrdersWithSigner(
        address maker,
        address[] memory makerTokens,
        address[] memory takerTokens,
        uint256[] memory minValidSalts
    ) public {
        require(
            makerTokens.length == takerTokens.length && makerTokens.length == minValidSalts.length,
            "NativeOrdersFeature/MISMATCHED_PAIR_ORDERS_ARRAY_LENGTHS"
        );

        if (!isValidOrderSigner(maker, msg.sender)) {
            revert invalidSigner(maker, msg.sender);
        }

        for (uint256 i = 0; i < makerTokens.length; ++i) {
            _cancelPairRfqOrders(maker, makerTokens[i], takerTokens[i], minValidSalts[i]);
        }
    }

    /// @dev Cancel a limit or RFQ order directly by its order hash.
    /// @param orderHash The order's order hash.
    /// @param maker The order's maker.
    function _cancelOrderHash(bytes32 orderHash, address maker) private {
        OrderStorage storage stor =os();
        // Set the high bit on the raw taker token fill amount to indicate
        // a cancel. It's OK to cancel twice.
        stor.orderHashToTakerTokenFilledAmount[orderHash] |= HIGH_BIT;

        emit OrderCancelled(orderHash, maker);
    }

    /// @dev Cancel all RFQ orders for a given maker and pair with a salt less
    ///      than the value provided.
    /// @param maker The target maker address
    /// @param makerToken The maker token.
    /// @param takerToken The taker token.
    /// @param minValidSalt The new minimum valid salt.
    function _cancelPairRfqOrders(
        address maker,
        address makerToken,
        address takerToken,
        uint256 minValidSalt
    ) private {
        OrderStorage storage stor =os();

        uint256 oldMinValidSalt = stor.rfqOrdersMakerToMakerTokenToTakerTokenToMinValidOrderSalt[maker][makerToken][takerToken];

        // New min salt must >= the old one.
        if (oldMinValidSalt > minValidSalt) {
            revert cancelSaltTooLowError(minValidSalt, oldMinValidSalt);
        }

        stor.rfqOrdersMakerToMakerTokenToTakerTokenToMinValidOrderSalt[maker][address(makerToken)][address(takerToken)] = minValidSalt;

        emit PairCancelledRfqOrders(maker, address(makerToken), address(takerToken), minValidSalt);
    }

    /// @dev Cancel all limit orders for a given maker and pair with a salt less
    ///      than the value provided.
    /// @param maker The target maker address
    /// @param makerToken The maker token.
    /// @param takerToken The taker token.
    /// @param minValidSalt The new minimum valid salt.
    function _cancelPairLimitOrders(
        address maker,
        address makerToken,
        address takerToken,
        uint256 minValidSalt
    ) private {
        OrderStorage storage stor =os();

        uint256 oldMinValidSalt = stor.limitOrdersMakerToMakerTokenToTakerTokenToMinValidOrderSalt[maker][makerToken][takerToken];

        // New min salt must >= the old one.
        if (oldMinValidSalt > minValidSalt) {
            revert cancelSaltTooLowError(minValidSalt, oldMinValidSalt);
        }

        stor.limitOrdersMakerToMakerTokenToTakerTokenToMinValidOrderSalt[maker][makerToken][takerToken] = minValidSalt;

        emit PairCancelledLimitOrders(maker, makerToken, takerToken, minValidSalt);
    }
}
