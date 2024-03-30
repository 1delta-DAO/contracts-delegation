// SPDX-License-Identifier: BUSL 1.1

pragma solidity ^0.8.24;

/// @dev Encodes parametrized errors that are supposed to be forwarded and not reverted with on the spot
library LibNativeErrors {
    function protocolFeeRefundFailed(address receiver, uint256 refundAmount) internal pure returns (bytes memory) {
        return
            abi.encodeWithSelector(
                bytes4(keccak256("protocolFeeRefundFailed(address,uint256)")),
                receiver,
                refundAmount
            );
    }

    function orderNotFillableByOriginError(
        bytes32 orderHash,
        address txOrigin,
        address orderTxOrigin
    ) internal pure returns (bytes memory) {
        return
            abi.encodeWithSelector(
                bytes4(keccak256("orderNotFillableByOriginError(bytes32,address,address)")),
                orderHash,
                txOrigin,
                orderTxOrigin
            );
    }

    function orderNotFillableError(bytes32 orderHash, uint8 orderStatus) internal pure returns (bytes memory) {
        return
            abi.encodeWithSelector(bytes4(keccak256("orderNotFillableError(bytes32,uint8)")), orderHash, orderStatus);
    }

    function orderNotSignedByMakerError(
        bytes32 orderHash,
        address signer,
        address maker
    ) internal pure returns (bytes memory) {
        return
            abi.encodeWithSelector(
                bytes4(keccak256("orderNotSignedByMakerError(bytes32,address,address)")),
                orderHash,
                signer,
                maker
            );
    }

    function invalidSignerError(address maker, address signer) internal pure returns (bytes memory) {
        return abi.encodeWithSelector(bytes4(keccak256("invalidSignerError(address,address)")), maker, signer);
    }

    function orderNotFillableBySenderError(
        bytes32 orderHash,
        address sender,
        address orderSender
    ) internal pure returns (bytes memory) {
        return
            abi.encodeWithSelector(
                bytes4(keccak256("orderNotFillableBySenderError(bytes32,address,address)")),
                orderHash,
                sender,
                orderSender
            );
    }

    function orderNotFillableByTakerError(
        bytes32 orderHash,
        address taker,
        address orderTaker
    ) internal pure returns (bytes memory) {
        return
            abi.encodeWithSelector(
                bytes4(keccak256("orderNotFillableByTakerError(bytes32,address,address)")),
                orderHash,
                taker,
                orderTaker
            );
    }

    function cancelSaltTooLowError(uint256 minValidSalt, uint256 oldMinValidSalt) internal pure returns (bytes memory) {
        return
            abi.encodeWithSelector(
                bytes4(keccak256("cancelSaltTooLowError(uint256,uint256)")),
                minValidSalt,
                oldMinValidSalt
            );
    }

    function fillOrKillFailedError(
        bytes32 orderHash,
        uint256 takerTokenFilledAmount,
        uint256 takerTokenFillAmount
    ) internal pure returns (bytes memory) {
        return
            abi.encodeWithSelector(
                bytes4(keccak256("fillOrKillFailedError(bytes32,uint256,uint256)")),
                orderHash,
                takerTokenFilledAmount,
                takerTokenFillAmount
            );
    }

    function onlyOrderMakerAllowed(
        bytes32 orderHash,
        address sender,
        address maker
    ) internal pure returns (bytes memory) {
        return
            abi.encodeWithSelector(
                bytes4(keccak256("onlyOrderMakerAllowed(bytes32,address,address)")),
                orderHash,
                sender,
                maker
            );
    }

    function batchFillIncompleteError(
        bytes32 orderHash,
        uint256 takerTokenFilledAmount,
        uint256 takerTokenFillAmount
    ) internal pure returns (bytes memory) {
        return
            abi.encodeWithSelector(
                bytes4(keccak256("batchFillIncompleteError(bytes32,uint256,uint256)")),
                orderHash,
                takerTokenFilledAmount,
                takerTokenFillAmount
            );
    }
}
