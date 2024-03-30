// SPDX-License-Identifier: BUSL 1.1

pragma solidity ^0.8.24;

/// @dev Encodes parametrized errors that are supposed to be forwarded and not reverted with on the spot
library LibNativeErrors {
    function protocolFeeRefundFailed(address receiver, uint256 refundAmount) internal pure returns (bytes memory) {
        return
            abi.encodeWithSelector(
                0x7395a68e, // bytes4(keccak256("protocolFeeRefundFailed(address,uint256)")),
                receiver,
                refundAmount
            );
    }

    function orderNotFillableByOriginError(
        bytes32 orderHash,
        address txOrigin,
        address orderTxOrigin
    ) internal pure returns (bytes memory data) {
        // return
        //     abi.encodeWithSelector(
        //         0xb5620cf4, // bytes4(keccak256("orderNotFillableByOriginError(bytes32,address,address)")),
        //         orderHash,
        //         txOrigin,
        //         orderTxOrigin
        //     );
        assembly {
            mstore(data, 0x64)                      // data length (100) @ 0
            mstore(add(data, 0x20), 0xb5620cf400000000000000000000000000000000000000000000000000000000)     // selector @ 32
            mstore(add(data, 0x24), orderHash)      // data @ 32 + 4
            mstore(add(data, 0x44), txOrigin)       // data @ 32 + 4 + 32 
            mstore(add(data, 0x44), orderTxOrigin)  // data @ 32 + 4 + 32 + 32
            mstore(0x40, add(data, 0x84))           // update free memory pointer
        }
        return data;
    }

    function orderNotFillableError(bytes32 orderHash, uint8 orderStatus) internal pure returns (bytes memory data) {
        // return
        //     abi.encodeWithSelector(
        //         0xcf6bb548, // bytes4(keccak256("orderNotFillableError(bytes32,uint8)")),
        //         orderHash,
        //         orderStatus
        //     );
        assembly {
            mstore(data, 0x44)                      // data length (68) @ 0
            mstore(add(data, 0x20), 0xcf6bb54800000000000000000000000000000000000000000000000000000000)     // selector @ 32
            mstore(add(data, 0x24), orderHash)      // data @ 32 + 4
            mstore(add(data, 0x44), orderStatus)    // data @ 32 + 4 + 32 
            mstore(0x40, add(data, 0x64))           // update free memory pointer
        }
        return data;
    }

    function orderNotSignedByMakerError(
        bytes32 orderHash,
        address signer,
        address maker
    ) internal pure returns (bytes memory data) {
        // return
        //     abi.encodeWithSelector(
        //         0xb9ae9aa3, // bytes4(keccak256("orderNotSignedByMakerError(bytes32,address,address)")),
        //         orderHash,
        //         signer,
        //         maker
        //     );
        assembly {
            mstore(data, 0x64)                      // data length (100) @ 0
            mstore(add(data, 0x20), 0xb9ae9aa300000000000000000000000000000000000000000000000000000000)     // selector @ 32
            mstore(add(data, 0x24), orderHash)      // data @ 32 + 4
            mstore(add(data, 0x44), signer)         // data @ 32 + 4 + 32 
            mstore(add(data, 0x44), maker)          // data @ 32 + 4 + 32 + 32
            mstore(0x40, add(data, 0x84))           // update free memory pointer
        }
        return data;
    }

    // function invalidSignerError(address maker, address signer) internal pure returns (bytes memory) {

    // }

    function invalidSignerError(address maker, address signer) internal pure returns (bytes memory data) {
        //     return abi.encodeWithSelector(
        //         0xee01de37, //bytes4(keccak256("invalidSignerError(address,address)")),
        //         maker,
        //         signer
        //     );
        assembly {
            mstore(data, 0x44)                      // data length (68) @ 0
            mstore(add(data, 0x20), 0xee01de3700000000000000000000000000000000000000000000000000000000)     // selector @ 32
            mstore(add(data, 0x24), maker)          // data @ 32 + 4
            mstore(add(data, 0x44), signer)         // data @ 32 + 4 + 32 
            mstore(0x40, add(data, 0x64))           // update free memory pointer
        }
        return data;
    }

    function orderNotFillableBySenderError(
        bytes32 orderHash,
        address sender,
        address orderSender
    ) internal pure returns (bytes memory data) {
        // return
        //     abi.encodeWithSelector(
        //         0x3b718d65, // bytes4(keccak256("orderNotFillableBySenderError(bytes32,address,address)")),
        //         orderHash,
        //         sender,
        //         orderSender
        //     );
        assembly {
            mstore(data, 0x64)                      // data length (100) @ 0
            mstore(add(data, 0x20), 0x3b718d6500000000000000000000000000000000000000000000000000000000)     // selector @ 32
            mstore(add(data, 0x24), orderHash)      // data @ 32 + 4
            mstore(add(data, 0x44), sender)         // data @ 32 + 4 + 32 
            mstore(add(data, 0x64), orderSender)    // data @ 32 + 4 + 32 + 32
            mstore(0x40, add(data, 0x84))           // update free memory pointer
        }
        return data;
    }

    function orderNotFillableByTakerError(
        bytes32 orderHash,
        address taker,
        address orderTaker
    ) internal pure returns (bytes memory data) {
        // return
        //     abi.encodeWithSelector(
        //         0x5ad1544f, // bytes4(keccak256("orderNotFillableByTakerError(bytes32,address,address)")),
        //         orderHash,
        //         taker,
        //         orderTaker
        //     );
        assembly {
            mstore(data, 0x64)                      // data length (100) @ 0
            mstore(add(data, 0x20), 0x5ad1544f00000000000000000000000000000000000000000000000000000000)     // selector @ 32
            mstore(add(data, 0x24), orderHash)      // data @ 32 + 4
            mstore(add(data, 0x44), taker)          // data @ 32 + 4 + 32 
            mstore(add(data, 0x64), orderTaker)     // data @ 32 + 4 + 32 + 32
            mstore(0x40, add(data, 0x84))           // update free memory pointer
        }
        return data;
    }

    function cancelSaltTooLowError(uint256 minValidSalt, uint256 oldMinValidSalt) internal pure returns (bytes memory) {
        return
            abi.encodeWithSelector(
                0xbe79a2b6, // bytes4(keccak256("cancelSaltTooLowError(uint256,uint256)")),
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
                0xf11bc1a9, // bytes4(keccak256("fillOrKillFailedError(bytes32,uint256,uint256)")),
                orderHash,
                takerTokenFilledAmount,
                takerTokenFillAmount
            );
    }

    function onlyOrderMakerAllowed(
        bytes32 orderHash,
        address sender,
        address maker
    ) internal pure returns (bytes memory data) {
        // return
        //     abi.encodeWithSelector(
        //         0x105b08f3, // bytes4(keccak256("onlyOrderMakerAllowed(bytes32,address,address)")),
        //         orderHash,
        //         sender,
        //         maker
        //     );
        assembly {
            mstore(data, 0x64)                      // data length (100) @ 0
            mstore(add(data, 0x20), 0x105b08f300000000000000000000000000000000000000000000000000000000)     // selector @ 32
            mstore(add(data, 0x24), orderHash)      // data @ 32 + 4
            mstore(add(data, 0x44), sender)         // data @ 32 + 4 + 32 
            mstore(add(data, 0x44), maker)          // data @ 32 + 4 + 32 + 32
            mstore(0x40, add(data, 0x84))           // update free memory pointer
        }
        return data;
    }

    function batchFillIncompleteError(
        bytes32 orderHash,
        uint256 takerTokenFilledAmount,
        uint256 takerTokenFillAmount
    ) internal pure returns (bytes memory) {
        return
            abi.encodeWithSelector(
                0xcb620b9b, // bytes4(keccak256("batchFillIncompleteError(bytes32,uint256,uint256)")),
                orderHash,
                takerTokenFilledAmount,
                takerTokenFillAmount
            );
    }
}
