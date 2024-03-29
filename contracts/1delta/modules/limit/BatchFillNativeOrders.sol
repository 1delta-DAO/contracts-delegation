// SPDX-License-Identifier: BUSL 1.1

pragma solidity ^0.8.24;

import "./NativeOrdersSettlement.sol";

/// @dev Feature for batch/market filling limit and RFQ orders.
contract BatchFillNativeOrders is NativeOrdersSettlement {
    error batchFillIncompleteError(bytes32 hash, uint128 takerTokenFilledAmounts, uint128 takerTokenFillAmounts);

    constructor(
        address proxyAddress,
        address protocolFeeCollector,
        uint32 protocolFeeMultiplier
    ) NativeOrdersSettlement(proxyAddress,protocolFeeCollector, protocolFeeMultiplier) {}


    /// @dev Fills multiple limit orders.
    /// @param orders Array of limit orders.
    /// @param signatures Array of signatures corresponding to each order.
    /// @param takerTokenFillAmounts Array of desired amounts to fill each order.
    /// @param revertIfIncomplete If true, reverts if this function fails to
    ///        fill the full fill amount for any individual order.
    /// @return takerTokenFilledAmounts Array of amounts filled, in taker token.
    /// @return makerTokenFilledAmounts Array of amounts filled, in maker token.
    function batchFillLimitOrders(
        LibNativeOrder.LimitOrder[] calldata orders,
        LibSignature.Signature[] calldata signatures,
        uint128[] calldata takerTokenFillAmounts,
        bool revertIfIncomplete
    )
        external
        payable

        returns (uint128[] memory takerTokenFilledAmounts, uint128[] memory makerTokenFilledAmounts)
    {
        if(
            orders.length != signatures.length || orders.length != takerTokenFillAmounts.length
            ) revert mismatchedArrayLengths();

        takerTokenFilledAmounts = new uint128[](orders.length);
        makerTokenFilledAmounts = new uint128[](orders.length);

        uint256 ethProtocolFeePaid;
        for (uint256 i; i != orders.length; i++) {
            (FillNativeOrderResults memory results, bytes memory errorData) = _fillLimitOrderPrivate(
                FillLimitOrderPrivateParams({
                    order: orders[i],
                    signature: signatures[i],
                    takerTokenFillAmount: takerTokenFillAmounts[i],
                    taker: msg.sender,
                    sender: msg.sender
                })
            );
            
            (takerTokenFilledAmounts[i], makerTokenFilledAmounts[i]) = (
                results.takerTokenFilledAmount,
                results.makerTokenFilledAmount
            );
            
            ethProtocolFeePaid += results.ethProtocolFeePaid;

            if (revertIfIncomplete) {
                // general errors
                if(errorData.length > 0) Reverter.revertWithData(errorData);
                // insuffiecient amount filled
                if(takerTokenFilledAmounts[i] < takerTokenFillAmounts[i]){
                    bytes32 orderHash = _getEIP712Hash(LibNativeOrder.getLimitOrderStructHash(orders[i]));
                    // Did not fill the amount requested.
                    revert batchFillIncompleteError(orderHash, takerTokenFilledAmounts[i], takerTokenFillAmounts[i]);
                }
            }
        }
        LibNativeOrder.refundExcessProtocolFeeToSender(ethProtocolFeePaid);
    }

    /// @dev Fills multiple RFQ orders.
    /// @param orders Array of RFQ orders.
    /// @param signatures Array of signatures corresponding to each order.
    /// @param takerTokenFillAmounts Array of desired amounts to fill each order.
    /// @param revertIfIncomplete If true, reverts if this function fails to
    ///        fill the full fill amount for any individual order.
    /// @return takerTokenFilledAmounts Array of amounts filled, in taker token.
    /// @return makerTokenFilledAmounts Array of amounts filled, in maker token.
    function batchFillRfqOrders(
        LibNativeOrder.RfqOrder[] calldata orders,
        LibSignature.Signature[] calldata signatures,
        uint128[] calldata takerTokenFillAmounts,
        bool revertIfIncomplete
    ) external returns (uint128[] memory takerTokenFilledAmounts, uint128[] memory makerTokenFilledAmounts) {
        if(
            orders.length != signatures.length || orders.length != takerTokenFillAmounts.length
            ) revert mismatchedArrayLengths();

        takerTokenFilledAmounts = new uint128[](orders.length);
        makerTokenFilledAmounts = new uint128[](orders.length);
        for (uint256 i; i != orders.length; i++) {
            (FillNativeOrderResults memory results, bytes memory errorData) = _fillRfqOrderPrivate(
                FillRfqOrderPrivateParams({
                    order: orders[i],
                    signature: signatures[i],
                    takerTokenFillAmount: takerTokenFillAmounts[i],
                    taker: msg.sender,
                    useSelfBalance: false,
                    recipient: msg.sender
                })
            );

            (takerTokenFilledAmounts[i], makerTokenFilledAmounts[i]) = (
                results.takerTokenFilledAmount,
                results.makerTokenFilledAmount
            );
            
            // revert cases
            if(revertIfIncomplete) {
                // general error
                if(errorData.length > 0) Reverter.revertWithData(errorData);

                // incomplete fill
                if (takerTokenFilledAmounts[i] < takerTokenFillAmounts[i]) {
                    // Did not fill the amount requested.
                    bytes32 orderHash = _getEIP712Hash(LibNativeOrder.getRfqOrderStructHash(orders[i]));
                    revert batchFillIncompleteError(orderHash, takerTokenFilledAmounts[i], takerTokenFillAmounts[i]);
                }
            }
        }
    }
}
