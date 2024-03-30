// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;


/// @dev EIP712 helpers for features.
abstract contract EIP712 {
    /// @dev The domain hash separator for this contract.
    bytes32 public immutable EIP712_DOMAIN_SEPARATOR;

    constructor()  {
        // Compute `EIP712_DOMAIN_SEPARATOR`
        {
            uint256 chainId;
            assembly {
                chainId := chainid()
            }
            EIP712_DOMAIN_SEPARATOR = keccak256(
                abi.encode(
                    0x8b73c3c69bb8fe3d512ecc4cf759cc79239f7b179b0ffacaa9a75d522b39400f,
                    // keccak256(
                    //     "EIP712Domain("
                    //     "string name,"
                    //     "string version,"
                    //     "uint256 chainId,"
                    //     "address verifyingContract"
                    //     ")" // standard EIP712
                    // ),
                    keccak256("1delta"),
                    keccak256("1.0.0"),
                    chainId,
                    address(this)
                )
            );
        }
    }

    function _getEIP712Hash(bytes32 structHash) internal view returns (bytes32 eip712Hash) {
        return keccak256(abi.encodePacked(hex"1901", EIP712_DOMAIN_SEPARATOR, structHash));
    }
}
