// SPDX-License-Identifier: BUSL 1.1

pragma solidity ^0.8.0;


import "./EIP712.sol";
import {WithStorage, OrderStorage} from"../../storage/BrokerStorage.sol";
import "./libraries/LibSignature.sol";
import "./libraries/LibNativeOrder.sol";
import {TokenTransfer} from "../../libraries/TokenTransfer.sol";

/// @dev Feature for getting info about limit and RFQ orders.
abstract contract NativeOrdersInfo is EIP712, WithStorage, TokenTransfer {
    error mismatchedArrayLengths();
    error uint128Overflow();
    
    // @dev Params for `_getActualFillableTakerTokenAmount()`.
    struct GetActualFillableTakerTokenAmountParams {
        address maker;
        address makerToken;
        uint128 orderMakerAmount;
        uint128 orderTakerAmount;
        LibNativeOrder.OrderInfo orderInfo;
    }

    /// @dev Highest bit of a uint256, used to flag cancelled orders.
    uint256 private constant HIGH_BIT = 1 << 255;

    constructor(address proxyAddress)  EIP712(proxyAddress) {}

    /// @dev Get the order info for a limit order.
    /// @param order The limit order.
    /// @return orderInfo Info about the order.
    function getLimitOrderInfo(
        LibNativeOrder.LimitOrder memory order
    ) public view returns (LibNativeOrder.OrderInfo memory orderInfo) {
        // Recover maker and compute order hash.
        orderInfo.orderHash = getLimitOrderHash(order);
        uint256 minValidSalt = os()
            .limitOrdersMakerToMakerTokenToTakerTokenToMinValidOrderSalt[order.maker][order.makerToken][
                order.takerToken
            ];
        _populateCommonOrderInfoFields(orderInfo, order.takerAmount, order.expiry, order.salt, minValidSalt);
    }

    /// @dev Get the order info for an RFQ order.
    /// @param order The RFQ order.
    /// @return orderInfo Info about the order.
    function getRfqOrderInfo(
        LibNativeOrder.RfqOrder memory order
    ) public view returns (LibNativeOrder.OrderInfo memory orderInfo) {
        // Recover maker and compute order hash.
        orderInfo.orderHash = getRfqOrderHash(order);
        uint256 minValidSalt = os()
            .rfqOrdersMakerToMakerTokenToTakerTokenToMinValidOrderSalt[order.maker][order.makerToken][
                order.takerToken
            ];
        _populateCommonOrderInfoFields(orderInfo, order.takerAmount, order.expiry, order.salt, minValidSalt);

        // Check for missing txOrigin.
        if (order.txOrigin == address(0)) {
            orderInfo.status = LibNativeOrder.OrderStatus.INVALID;
        }
    }

    /// @dev Get the canonical hash of a limit order.
    /// @param order The limit order.
    /// @return orderHash The order hash.
    function getLimitOrderHash(LibNativeOrder.LimitOrder memory order) public view returns (bytes32 orderHash) {
        return _getEIP712Hash(LibNativeOrder.getLimitOrderStructHash(order));
    }

    /// @dev Get the canonical hash of an RFQ order.
    /// @param order The RFQ order.
    /// @return orderHash The order hash.
    function getRfqOrderHash(LibNativeOrder.RfqOrder memory order) public view returns (bytes32 orderHash) {
        return _getEIP712Hash(LibNativeOrder.getRfqOrderStructHash(order));
    }

    /// @dev Get order info, fillable amount, and signature validity for a limit order.
    ///      Fillable amount is determined using balances and allowances of the maker.
    /// @param order The limit order.
    /// @param signature The order signature.
    /// @return orderInfo Info about the order.
    /// @return actualFillableTakerTokenAmount How much of the order is fillable
    ///         based on maker funds, in taker tokens.
    /// @return isSignatureValid Whether the signature is valid.
    function getLimitOrderRelevantState(
        LibNativeOrder.LimitOrder memory order,
        LibSignature.Signature calldata signature
    )
        public
        view
        returns (
            LibNativeOrder.OrderInfo memory orderInfo,
            uint128 actualFillableTakerTokenAmount,
            bool isSignatureValid
        )
    {
        orderInfo = getLimitOrderInfo(order);
        actualFillableTakerTokenAmount = _getActualFillableTakerTokenAmount(
            GetActualFillableTakerTokenAmountParams({
                maker: order.maker,
                makerToken: order.makerToken,
                orderMakerAmount: order.makerAmount,
                orderTakerAmount: order.takerAmount,
                orderInfo: orderInfo
            })
        );
        address signerOfHash = LibSignature.getSignerOfHash(orderInfo.orderHash, signature);
        isSignatureValid = (order.maker == signerOfHash) || isValidOrderSigner(order.maker, signerOfHash);
    }

    /// @dev Get order info, fillable amount, and signature validity for an RFQ order.
    ///      Fillable amount is determined using balances and allowances of the maker.
    /// @param order The RFQ order.
    /// @param signature The order signature.
    /// @return orderInfo Info about the order.
    /// @return actualFillableTakerTokenAmount How much of the order is fillable
    ///         based on maker funds, in taker tokens.
    /// @return isSignatureValid Whether the signature is valid.
    function getRfqOrderRelevantState(
        LibNativeOrder.RfqOrder memory order,
        LibSignature.Signature calldata signature
    )
        public
        view
        returns (
            LibNativeOrder.OrderInfo memory orderInfo,
            uint128 actualFillableTakerTokenAmount,
            bool isSignatureValid
        )
    {
        orderInfo = getRfqOrderInfo(order);
        actualFillableTakerTokenAmount = _getActualFillableTakerTokenAmount(
            GetActualFillableTakerTokenAmountParams({
                maker: order.maker,
                makerToken: order.makerToken,
                orderMakerAmount: order.makerAmount,
                orderTakerAmount: order.takerAmount,
                orderInfo: orderInfo
            })
        );
        address signerOfHash = LibSignature.getSignerOfHash(orderInfo.orderHash, signature);
        isSignatureValid = (order.maker == signerOfHash) || isValidOrderSigner(order.maker, signerOfHash);
    }

    /// @dev Batch version of `getLimitOrderRelevantState()`, without reverting.
    ///      Orders that would normally cause `getLimitOrderRelevantState()`
    ///      to revert will have empty results.
    /// @param orders The limit orders.
    /// @param signatures The order signatures.
    /// @return orderInfos Info about the orders.
    /// @return actualFillableTakerTokenAmounts How much of each order is fillable
    ///         based on maker funds, in taker tokens.
    /// @return isSignatureValids Whether each signature is valid for the order.
    function batchGetLimitOrderRelevantStates(
        LibNativeOrder.LimitOrder[] calldata orders,
        LibSignature.Signature[] calldata signatures
    )
        external
        view
        returns (
            LibNativeOrder.OrderInfo[] memory orderInfos,
            uint128[] memory actualFillableTakerTokenAmounts,
            bool[] memory isSignatureValids
        )
    {
        if(orders.length != signatures.length) revert mismatchedArrayLengths();
        orderInfos = new LibNativeOrder.OrderInfo[](orders.length);
        actualFillableTakerTokenAmounts = new uint128[](orders.length);
        isSignatureValids = new bool[](orders.length);
        for (uint256 i = 0; i < orders.length; ++i) {
            try this.getLimitOrderRelevantState(orders[i], signatures[i]) returns (
                LibNativeOrder.OrderInfo memory orderInfo,
                uint128 actualFillableTakerTokenAmount,
                bool isSignatureValid
            ) {
                orderInfos[i] = orderInfo;
                actualFillableTakerTokenAmounts[i] = actualFillableTakerTokenAmount;
                isSignatureValids[i] = isSignatureValid;
            } catch {}
        }
    }

    /// @dev Batch version of `getRfqOrderRelevantState()`, without reverting.
    ///      Orders that would normally cause `getRfqOrderRelevantState()`
    ///      to revert will have empty results.
    /// @param orders The RFQ orders.
    /// @param signatures The order signatures.
    /// @return orderInfos Info about the orders.
    /// @return actualFillableTakerTokenAmounts How much of each order is fillable
    ///         based on maker funds, in taker tokens.
    /// @return isSignatureValids Whether each signature is valid for the order.
    function batchGetRfqOrderRelevantStates(
        LibNativeOrder.RfqOrder[] calldata orders,
        LibSignature.Signature[] calldata signatures
    )
        external
        view
        returns (
            LibNativeOrder.OrderInfo[] memory orderInfos,
            uint128[] memory actualFillableTakerTokenAmounts,
            bool[] memory isSignatureValids
        )
    {
        if(orders.length != signatures.length) revert mismatchedArrayLengths();
        orderInfos = new LibNativeOrder.OrderInfo[](orders.length);
        actualFillableTakerTokenAmounts = new uint128[](orders.length);
        isSignatureValids = new bool[](orders.length);
        for (uint256 i = 0; i < orders.length; ++i) {
            try this.getRfqOrderRelevantState(orders[i], signatures[i]) returns (
                LibNativeOrder.OrderInfo memory orderInfo,
                uint128 actualFillableTakerTokenAmount,
                bool isSignatureValid
            ) {
                orderInfos[i] = orderInfo;
                actualFillableTakerTokenAmounts[i] = actualFillableTakerTokenAmount;
                isSignatureValids[i] = isSignatureValid;
            } catch {}
        }
    }

    /// @dev Populate `status` and `takerTokenFilledAmount` fields in
    ///      `orderInfo`, which use the same code path for both limit and
    ///      RFQ orders.
    /// @param orderInfo `OrderInfo` with `orderHash` and `maker` filled.
    /// @param takerAmount The order's taker token amount..
    /// @param expiry The order's expiry.
    /// @param salt The order's salt.
    /// @param salt The minimum valid salt for the maker and pair combination.
    function _populateCommonOrderInfoFields(
        LibNativeOrder.OrderInfo memory orderInfo,
        uint128 takerAmount,
        uint64 expiry,
        uint256 salt,
        uint256 minValidSalt
    ) private view {
        OrderStorage storage stor = os();

        // Get the filled and direct cancel state.
        {
            // The high bit of the raw taker token filled amount will be set
            // if the order was cancelled.
            uint256 rawTakerTokenFilledAmount = stor.orderHashToTakerTokenFilledAmount[orderInfo.orderHash];
            orderInfo.takerTokenFilledAmount = uint128(rawTakerTokenFilledAmount);
            if (orderInfo.takerTokenFilledAmount >= takerAmount) {
                orderInfo.status = LibNativeOrder.OrderStatus.FILLED;
                return;
            }
            if (rawTakerTokenFilledAmount & HIGH_BIT != 0) {
                orderInfo.status = LibNativeOrder.OrderStatus.CANCELLED;
                return;
            }
        }

        // Check for expiration.
        if (expiry <= uint64(block.timestamp)) {
            orderInfo.status = LibNativeOrder.OrderStatus.EXPIRED;
            return;
        }

        // Check if the order was cancelled by salt.
        if (minValidSalt > salt) {
            orderInfo.status = LibNativeOrder.OrderStatus.CANCELLED;
            return;
        }
        orderInfo.status = LibNativeOrder.OrderStatus.FILLABLE;
    }

    /// @dev Calculate the actual fillable taker token amount of an order
    ///      based on maker allowance and balances.
    function _getActualFillableTakerTokenAmount(
        GetActualFillableTakerTokenAmountParams memory params
    ) private view returns (uint128 actualFillableTakerTokenAmount) {
        if (params.orderMakerAmount == 0 || params.orderTakerAmount == 0) {
            // Empty order.
            return 0;
        }
        if (params.orderInfo.status != LibNativeOrder.OrderStatus.FILLABLE) {
            // Not fillable.
            return 0;
        }

        // Get the fillable maker amount based on the order quantities and
        // previously filled amount
        uint256 fillableMakerTokenAmount = 
            uint256(params.orderTakerAmount - params.orderInfo.takerTokenFilledAmount) *
            uint256(params.orderMakerAmount) /
            uint256(params.orderTakerAmount)
        ;
        // Clamp it to the amount of maker tokens we can spend on behalf of the
        // maker.
        fillableMakerTokenAmount = min256(
            fillableMakerTokenAmount,
            _getSpendableERC20BalanceOf(params.makerToken, params.maker)
        );
        // Convert to taker token amount.
        return safeDowncastToUint128(
            getPartialAmountCeil(
                fillableMakerTokenAmount,
                params.orderMakerAmount,
                params.orderTakerAmount
             )
        );
    }

    /// @dev checks if a given address is registered to sign on behalf of a maker address
    /// @param maker The maker address encoded in an order (can be a contract)
    /// @param signer The address that is providing a signature
    function isValidOrderSigner(address maker, address signer) public view returns (bool isValid) {
        // returns false if it the mapping doesn't exist
        return os().orderSignerRegistry[maker][signer];
    }

  function safeDowncastToUint128(uint256 a) internal pure returns (uint128) {
        if (a > type(uint128).max) {
            revert uint128Overflow();
        }
        return uint128(a);
    }

    /// @dev Calculates partial value given a numerator and denominator rounded down.
    /// @param numerator Numerator.
    /// @param denominator Denominator.
    /// @param target Value to calculate partial of.
    /// @return partialAmount Partial value of target rounded up.
    function getPartialAmountCeil(
        uint256 numerator,
        uint256 denominator,
        uint256 target
    ) internal pure returns (uint256) {
        // safeDiv computes `floor(a / b)`. We use the identity (a, b integer):
        //       ceil(a / b) = floor((a + b - 1) / b)
        // To implement `ceil(a / b)` using safeDiv.
        return (numerator * target + (denominator - 1)) / denominator;
    }

}
