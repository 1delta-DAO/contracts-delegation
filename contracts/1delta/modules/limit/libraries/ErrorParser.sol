// SPDX-License-Identifier: BUSL 1.1

pragma solidity ^0.8.24;

contract ErrorParser {
    error protocolFeeRefundFailed(address receiver, uint256 refundAmount);
    error orderNotFillableByOriginError(bytes32 orderHash, address txOrigin, address orderTxOrigin);
    error orderNotFillableError(bytes32 orderHash, uint8 orderStatus);

    error orderNotSignedByMakerError(bytes32 orderHash, address signer, address maker);
    error invalidSignerError(address maker, address signer);

    error orderNotFillableBySenderError(bytes32 orderHash, address sender, address orderSender);

    error orderNotFillableByTakerError(bytes32 orderHash, address taker, address orderTaker);

    error cancelSaltTooLowError(uint256 minValidSalt, uint256 oldMinValidSalt);

    error fillOrKillFailedError(bytes32 hash, uint128 takerTokenFilledAmount, uint128 takerTokenFillAmount);

    error onlyOrderMakerAllowed(bytes32 orderHash, address sender, address maker);

    error batchFillIncompleteError(bytes32 orderHash, uint128 takerTokenFilledAmount, uint128 takerTokenFillAmount);

    // direct

    error invalidSigner(address maker, address sender);
    error mismatchedArrayLengths();
    error uint128Overflow();

    error noContractOrigins();

    error makerTokenNotWeth();
    error takerTokenNotEth();
}
