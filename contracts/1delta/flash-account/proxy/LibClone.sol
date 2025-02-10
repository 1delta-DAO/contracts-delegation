// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

/// @notice Minimal proxy library.
/// @author Solady (https://github.com/vectorized/solady/blob/main/src/utils/LibClone.sol)
/// @author Minimal proxy by 0age (https://github.com/0age)
/// @author Clones with immutable args by wighawag, zefram.eth, Saw-mon & Natalie
/// (https://github.com/Saw-mon-and-Natalie/clones-with-immutable-args)
/// @author Minimal ERC1967 proxy by jtriley-eth (https://github.com/jtriley-eth/minimum-viable-proxy)
///
/// @dev ERC1967I beacon proxy:
/// An variant of the minimal ERC1967 beacon proxy, with a special code path that activates
/// if `calldatasize() == 1`. This code path skips the delegatecall and directly returns the
/// `implementation` address. The returned implementation is guaranteed to be valid if the
/// keccak256 of the proxy's code is equal to `ERC1967I_CODE_HASH`.
///
library LibClone {
    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                         CONSTANTS                          */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @dev The keccak256 of deployed code for the clone proxy,
    /// with the implementation set to `address(0)`.
    bytes32 internal constant CLONE_CODE_HASH =
        0x48db2cfdb2853fce0b464f1f93a1996469459df3ab6c812106074c4106a1eb1f;

    /// @dev The keccak256 of deployed code for the PUSH0 proxy,
    /// with the implementation set to `address(0)`.
    bytes32 internal constant PUSH0_CLONE_CODE_HASH =
        0x67bc6bde1b84d66e267c718ba44cf3928a615d29885537955cb43d44b3e789dc;

    /// @dev The keccak256 of deployed code for the ERC-1167 CWIA proxy,
    /// with the implementation set to `address(0)`.
    bytes32 internal constant CWIA_CODE_HASH =
        0x3cf92464268225a4513da40a34d967354684c32cd0edd67b5f668dfe3550e940;

    /// @dev The keccak256 of the deployed code for the ERC1967 proxy.
    bytes32 internal constant ERC1967_CODE_HASH =
        0xaaa52c8cc8a0e3fd27ce756cc6b4e70c51423e9b597b11f32d3e49f8b1fc890d;

    /// @dev The keccak256 of the deployed code for the ERC1967I proxy.
    bytes32 internal constant ERC1967I_CODE_HASH =
        0xce700223c0d4cea4583409accfc45adac4a093b3519998a9cbbe1504dadba6f7;

    /// @dev The keccak256 of the deployed code for the ERC1967 beacon proxy.
    bytes32 internal constant ERC1967_BEACON_PROXY_CODE_HASH =
        0x14044459af17bc4f0f5aa2f658cb692add77d1302c29fe2aebab005eea9d1162;

    /// @dev The keccak256 of the deployed code for the ERC1967 beacon proxy.
    bytes32 internal constant ERC1967I_BEACON_PROXY_CODE_HASH =
        0xf8c46d2793d5aa984eb827aeaba4b63aedcab80119212fce827309788735519a;

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                       CUSTOM ERRORS                        */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @dev Unable to deploy the clone.
    error DeploymentFailed();

    /// @dev The salt must start with either the zero address or `by`.
    error SaltDoesNotStartWith();


    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*              ERC1967I BEACON PROXY OPERATIONS              */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @dev Creates a deterministic ERC1967I beacon proxy with `salt`.
    /// Note: This method is intended for use in ERC4337 factories,
    /// which are expected to NOT revert if the proxy is already deployed.
    function createDeterministicERC1967IBeaconProxy(address beacon, bytes32 salt)
        internal
        returns (bool alreadyDeployed, address instance)
    {
        return createDeterministicERC1967IBeaconProxy(0, beacon, salt);
    }

    /// @dev Creates a deterministic ERC1967I beacon proxy with `salt`.
    /// Deposits `value` ETH during deployment.
    /// Note: This method is intended for use in ERC4337 factories,
    /// which are expected to NOT revert if the proxy is already deployed.
    function createDeterministicERC1967IBeaconProxy(uint256 value, address beacon, bytes32 salt)
        internal
        returns (bool alreadyDeployed, address instance)
    {
        /// @solidity memory-safe-assembly
        assembly {
            let m := mload(0x40) // Cache the free memory pointer.
            mstore(0x60, 0x3d50545afa361460525736515af43d600060013e6052573d6001fd5b3d6001f3)
            mstore(0x40, 0x527fa3f0ad74e5423aebfd80d3ef4346578335a9a72aeaee59ff6cb3582b3513)
            mstore(0x20, 0x60195155f3363d3d373d3d363d602036600436635c60da1b60e01b36)
            mstore(0x04, or(shl(160, 0x60573d8160223d3973), shr(96, shl(96, beacon))))
            // Compute and store the bytecode hash.
            mstore(add(m, 0x35), keccak256(0x07, 0x79))
            mstore(m, shl(88, address()))
            mstore8(m, 0xff) // Write the prefix.
            mstore(add(m, 0x15), salt)
            instance := keccak256(m, 0x55)
            for {} 1 {} {
                if iszero(extcodesize(instance)) {
                    instance := create2(value, 0x07, 0x79, salt)
                    if iszero(instance) {
                        mstore(0x00, 0x30116425) // `DeploymentFailed()`.
                        revert(0x1c, 0x04)
                    }
                    break
                }
                alreadyDeployed := 1
                if iszero(value) { break }
                if iszero(call(gas(), instance, value, codesize(), 0x00, codesize(), 0x00)) {
                    mstore(0x00, 0xb12d13eb) // `ETHTransferFailed()`.
                    revert(0x1c, 0x04)
                }
                break
            }
            mstore(0x40, m) // Restore the free memory pointer.
            mstore(0x60, 0) // Restore the zero slot.
        }
    }

    /// @dev Returns the initialization code of the ERC1967I beacon proxy.
    function initCodeERC1967IBeaconProxy(address beacon) internal pure returns (bytes memory c) {
        /// @solidity memory-safe-assembly
        assembly {
            c := mload(0x40)
            mstore(add(c, 0x79), 0x3d50545afa361460525736515af43d600060013e6052573d6001fd5b3d6001f3)
            mstore(add(c, 0x59), 0x527fa3f0ad74e5423aebfd80d3ef4346578335a9a72aeaee59ff6cb3582b3513)
            mstore(add(c, 0x39), 0x60195155f3363d3d373d3d363d602036600436635c60da1b60e01b36)
            mstore(add(c, 0x1d), beacon)
            mstore(add(c, 0x09), 0x60573d8160223d3973)
            mstore(add(c, 0x99), 0)
            mstore(c, 0x79) // Store the length.
            mstore(0x40, add(c, 0xa0)) // Allocate memory.
        }
    }

    /// @dev Returns the initialization code hash of the ERC1967I beacon proxy.
    function initCodeHashERC1967IBeaconProxy(address beacon) internal pure returns (bytes32 hash) {
        /// @solidity memory-safe-assembly
        assembly {
            let m := mload(0x40) // Cache the free memory pointer.
            mstore(0x60, 0x3d50545afa361460525736515af43d600060013e6052573d6001fd5b3d6001f3)
            mstore(0x40, 0x527fa3f0ad74e5423aebfd80d3ef4346578335a9a72aeaee59ff6cb3582b3513)
            mstore(0x20, 0x60195155f3363d3d373d3d363d602036600436635c60da1b60e01b36)
            mstore(0x04, or(shl(160, 0x60573d8160223d3973), shr(96, shl(96, beacon))))
            hash := keccak256(0x07, 0x79)
            mstore(0x40, m) // Restore the free memory pointer.
            mstore(0x60, 0) // Restore the zero slot.
        }
    }

    /// @dev Returns the address of the ERC1967I beacon proxy, with `salt` by `deployer`.
    /// Note: The returned result has dirty upper 96 bits. Please clean if used in assembly.
    function predictDeterministicAddressERC1967IBeaconProxy(
        address beacon,
        bytes32 salt,
        address deployer
    ) internal pure returns (address predicted) {
        bytes32 hash = initCodeHashERC1967IBeaconProxy(beacon);
        predicted = predictDeterministicAddress(hash, salt, deployer);
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                      OTHER OPERATIONS                      */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @dev Returns `address(0)` if the implementation address cannot be determined.
    function implementationOf(address instance) internal view returns (address result) {
        /// @solidity memory-safe-assembly
        assembly {
            for { extcodecopy(instance, 0x00, 0x00, 0x57) } 1 {} {
                if mload(0x2d) {
                    // ERC1967I and ERC1967IBeaconProxy detection.
                    if or(
                        eq(keccak256(0x00, 0x52), ERC1967I_CODE_HASH),
                        eq(keccak256(0x00, 0x57), ERC1967I_BEACON_PROXY_CODE_HASH)
                    ) {
                        pop(staticcall(gas(), instance, 0x00, 0x01, 0x00, 0x20))
                        result := mload(0x0c)
                        break
                    }
                }
                // 0age clone detection.
                result := mload(0x0b)
                codecopy(0x0b, codesize(), 0x14) // Zeroize the 20 bytes for the address.
                if iszero(xor(keccak256(0x00, 0x2c), CLONE_CODE_HASH)) { break }
                mstore(0x0b, result) // Restore the zeroized memory.
                // CWIA detection.
                result := mload(0x0a)
                codecopy(0x0a, codesize(), 0x14) // Zeroize the 20 bytes for the address.
                if iszero(xor(keccak256(0x00, 0x2d), CWIA_CODE_HASH)) { break }
                mstore(0x0a, result) // Restore the zeroized memory.
                // PUSH0 clone detection.
                result := mload(0x09)
                codecopy(0x09, codesize(), 0x14) // Zeroize the 20 bytes for the address.
                result := shr(xor(keccak256(0x00, 0x2d), PUSH0_CLONE_CODE_HASH), result)
                break
            }
            result := shr(96, result)
            mstore(0x37, 0) // Restore the overwritten part of the free memory pointer.
        }
    }

    /// @dev Returns the address when a contract with initialization code hash,
    /// `hash`, is deployed with `salt`, by `deployer`.
    /// Note: The returned result has dirty upper 96 bits. Please clean if used in assembly.
    function predictDeterministicAddress(bytes32 hash, bytes32 salt, address deployer)
        internal
        pure
        returns (address predicted)
    {
        /// @solidity memory-safe-assembly
        assembly {
            // Compute and store the bytecode hash.
            mstore8(0x00, 0xff) // Write the prefix.
            mstore(0x35, hash)
            mstore(0x01, shl(96, deployer))
            mstore(0x15, salt)
            predicted := keccak256(0x00, 0x55)
            mstore(0x35, 0) // Restore the overwritten part of the free memory pointer.
        }
    }

    /// @dev Requires that `salt` starts with either the zero address or `by`.
    function checkStartsWith(bytes32 salt, address by) internal pure {
        /// @solidity memory-safe-assembly
        assembly {
            // If the salt does not start with the zero address or `by`.
            if iszero(or(iszero(shr(96, salt)), eq(shr(96, shl(96, by)), shr(96, salt)))) {
                mstore(0x00, 0x0c4549ef) // `SaltDoesNotStartWith()`.
                revert(0x1c, 0x04)
            }
        }
    }

    /// @dev Returns the `bytes32` at `offset` in `args`, without any bounds checks.
    /// To load an address, you can use `address(bytes20(argLoad(args, offset)))`.
    function argLoad(bytes memory args, uint256 offset) internal pure returns (bytes32 result) {
        /// @solidity memory-safe-assembly
        assembly {
            result := mload(add(add(args, 0x20), offset))
        }
    }
}