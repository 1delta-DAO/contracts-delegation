// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.28;

import {BaseComposerValidator} from "./BaseComposerValidator.sol";
import {AddressWhitelistManager} from "./AddressWhitelistManager.sol";
import {
    TransferIds,
    LenderIds,
    LenderOps,
    FlashLoanIds,
    ERC4626Ids,
    Gen2025ActionIds,
    PermitIds,
    ComposerCommands,
    BridgeIds
} from "../enums/DeltaEnums.sol";
import {Masks} from "../../shared/masks/Masks.sol";

enum AaveVersion {
    AAVE_V2,
    AAVE_V3
}

contract ComposerValidator is BaseComposerValidator, Masks {
    AddressWhitelistManager public immutable whitelistManager;

    uint256 public constant MAX_CALLDATA_LENGTH = 10000;
    uint256 public constant MAX_AMOUNT = type(uint112).max;

    constructor(address _whitelistManager) {
        whitelistManager = AddressWhitelistManager(_whitelistManager);
    }

    function _validateExternalCall(uint256 currentOffset)
        internal
        view
        override
        returns (bool isValid, string memory errorMessage, uint256 newOffset)
    {
        address target;
        uint256 calldataLength;

        assembly {
            target := shr(96, calldataload(currentOffset))
            calldataLength := shr(240, calldataload(add(currentOffset, 36)))
            currentOffset := add(currentOffset, 38)
        }

        // Validate calldata length
        if (calldataLength > MAX_CALLDATA_LENGTH) {
            return (false, "Calldata too long", currentOffset);
        }

        (bool callForwarderValid, string memory callForwarderError, uint256 validatedOffset) =
            _validateCallForwarderCalldata(currentOffset, calldataLength);

        if (!callForwarderValid) {
            return (false, callForwarderError, validatedOffset);
        }

        // Skip calldata
        newOffset = currentOffset + calldataLength;
        return (true, "", newOffset);
    }

    function _validateCallForwarderCalldata(
        uint256 calldataStart,
        uint256 calldataLength
    )
        internal
        view
        returns (bool isValid, string memory errorMessage, uint256 newOffset)
    {
        uint256 currentOffset = calldataStart;
        uint256 endOffset = calldataStart + calldataLength;

        // Parse through CallForwarder operations
        while (currentOffset < endOffset) {
            uint256 operation;
            assembly {
                operation := shr(248, calldataload(currentOffset))
                currentOffset := add(1, currentOffset)
            }

            if (operation == ComposerCommands.EXT_CALL) {
                (bool valid, string memory error, uint256 offset) = _validateCallForwarderExternalCall(currentOffset);
                if (!valid) {
                    return (false, error, offset);
                }
                currentOffset = offset;
            } else if (operation == ComposerCommands.EXT_TRY_CALL) {
                (bool valid, string memory error, uint256 offset) = _validateCallForwarderTryCall(currentOffset);
                if (!valid) {
                    return (false, error, offset);
                }
                currentOffset = offset;
            } else if (operation == ComposerCommands.TRANSFERS) {
                (bool valid, string memory error, uint256 offset) = _validateTransfers(currentOffset);
                if (!valid) {
                    return (false, error, offset);
                }
                currentOffset = offset;
            } else if (operation == ComposerCommands.BRIDGING) {
                (bool valid, string memory error, uint256 offset) = _validateBridging(currentOffset);
                if (!valid) {
                    return (false, error, offset);
                }
                currentOffset = offset;
            } else {
                return (false, "Invalid CallForwarder operation", currentOffset);
            }
        }

        // check if all the calldata is processed
        if (currentOffset != endOffset) {
            return (false, "CallForwarder calldata length mismatch", currentOffset);
        }

        return (true, "", endOffset);
    }

    function _validateCallForwarderExternalCall(uint256 currentOffset)
        internal
        view
        returns (bool isValid, string memory errorMessage, uint256 newOffset)
    {
        address target;
        uint256 callValue;
        uint256 dataLength;

        assembly {
            target := shr(96, calldataload(currentOffset))
            currentOffset := add(20, currentOffset)
            callValue := shr(128, calldataload(currentOffset))
            currentOffset := add(16, currentOffset)
            dataLength := shr(240, calldataload(currentOffset))
            currentOffset := add(2, currentOffset)
        }

        // Validate the target is not Permit2 (same check as in ExternalCallsGeneric)
        if (target == 0x000000000022D473030F116dDEE9F6B43aC78BA3) {
            return (false, "Permit2 calls forbidden", currentOffset);
        }

        // Validate calldata length
        if (dataLength > MAX_CALLDATA_LENGTH) {
            return (false, "External call data too long", currentOffset);
        }

        // Check for forbidden selectors (transferFrom)
        if (dataLength >= 4) {
            bytes4 selector;
            assembly {
                selector := shr(224, calldataload(currentOffset))
            }
            if (selector == 0x23b872dd) {
                // transferFrom selector
                return (false, "transferFrom calls forbidden", currentOffset);
            }
        }

        // Skip the calldata
        newOffset = currentOffset + dataLength;
        return (true, "", newOffset);
    }

    function _validateCallForwarderTryCall(uint256 currentOffset)
        internal
        view
        returns (bool isValid, string memory errorMessage, uint256 newOffset)
    {
        // Validate the externalCall part
        (bool valid, string memory error, uint256 offset) = _validateCallForwarderExternalCall(currentOffset);
        if (!valid) {
            return (false, error, offset);
        }
        currentOffset = offset;

        // Validate catch handling
        uint256 catchHandling;
        uint256 catchDataLength;
        assembly {
            let nextSlice := calldataload(currentOffset)
            catchHandling := shr(248, nextSlice)
            catchDataLength := and(UINT16_MASK, shr(232, nextSlice))
            currentOffset := add(currentOffset, 3)
        }

        // Validate catch handling flag (0 or 1)
        if (catchHandling > 1) {
            return (false, "Invalid catch handling flag", currentOffset);
        }
        if (catchHandling == 0 && catchDataLength > 0) {
            return (false, "Catch data is not allowed when catchHandling is 0", currentOffset);
        }

        if (catchHandling == 1 && catchDataLength > 0) {
            (bool valid, string memory error, uint256 offset) = _validateComposeInternal(currentOffset, catchDataLength);
            if (!valid) {
                return (false, error, offset);
            }
            // we update the newOffset later for all cases,  so if this is calldata is valid, simply continue
        }

        // Skip catch data
        newOffset = currentOffset + catchDataLength;
        return (true, "", newOffset);
    }

    function _validateBridging(uint256 currentOffset) internal view returns (bool isValid, string memory errorMessage, uint256 newOffset) {
        uint256 bridgeOperation;
        assembly {
            bridgeOperation := shr(248, calldataload(currentOffset))
            currentOffset := add(currentOffset, 1)
        }

        if (bridgeOperation == BridgeIds.STARGATE_V2) {
            return _validateStargateV2(currentOffset);
        } else if (bridgeOperation == BridgeIds.ACROSS) {
            return _validateAcross(currentOffset);
        } else {
            return (false, "Invalid bridge operation", currentOffset);
        }
    }

    function _validateStargateV2(uint256 currentOffset) internal view returns (bool isValid, string memory errorMessage, uint256 newOffset) {
        address tokenAddress;
        address stargatePool;
        uint256 dstEid;
        uint256 amount;
        uint256 slippage;
        uint256 fee;
        uint256 composeMsgLength;
        uint256 extraOptionsLength;

        address receiver;

        assembly {
            tokenAddress := shr(96, calldataload(currentOffset))
            currentOffset := add(currentOffset, 20)

            stargatePool := shr(96, calldataload(currentOffset))
            currentOffset := add(currentOffset, 20)

            dstEid := shr(224, calldataload(currentOffset))
            currentOffset := add(currentOffset, 4)

            receiver := shr(96, calldataload(currentOffset))
            currentOffset := add(currentOffset, 32)

            // skip refundReceiver and amount
            currentOffset := add(currentOffset, 36)

            slippage := shr(224, calldataload(currentOffset))
            currentOffset := add(currentOffset, 4)

            fee := shr(128, calldataload(currentOffset))
            currentOffset := add(currentOffset, 16)

            // skip isBusMode
            currentOffset := add(currentOffset, 1)

            composeMsgLength := shr(240, calldataload(currentOffset))
            currentOffset := add(currentOffset, 2)

            extraOptionsLength := shr(240, calldataload(currentOffset))
            currentOffset := add(currentOffset, 2)
        }

        if (receiver == address(0)) {
            return (false, "Bridge receiver is zero address", currentOffset);
        }

        if (dstEid == 0) {
            return (false, "Invalid endpointID", currentOffset);
        }

        // Validate slippage - 50%, can be removed or changed
        if (slippage > 5000) {
            return (false, "Slippage too high", currentOffset);
        }

        if (composeMsgLength > MAX_CALLDATA_LENGTH || extraOptionsLength > MAX_CALLDATA_LENGTH) {
            return (false, "Message too long", currentOffset);
        }

        // Skip data length
        newOffset = currentOffset + composeMsgLength + extraOptionsLength;
        return (true, "", newOffset);
    }

    function _validateAcross(uint256 currentOffset) internal view returns (bool isValid, string memory errorMessage, uint256 newOffset) {
        address spokePool;
        address depositor;
        address inputTokenAddress;
        uint256 amount;
        uint256 feePercentage;
        uint256 destinationChainId;
        uint256 messageLength;

        assembly {
            spokePool := shr(96, calldataload(currentOffset))
            currentOffset := add(currentOffset, 20)

            depositor := shr(96, calldataload(currentOffset))
            currentOffset := add(currentOffset, 20)

            inputTokenAddress := shr(96, calldataload(currentOffset))
            currentOffset := add(currentOffset, 20)

            // skip receivingAssetId, amount and FixedFee
            currentOffset := add(currentOffset, 64)

            feePercentage := shr(224, calldataload(currentOffset))
            currentOffset := add(currentOffset, 4)

            destinationChainId := shr(224, calldataload(currentOffset))
            currentOffset := add(currentOffset, 4)

            // skip receiver
            currentOffset := add(currentOffset, 32)

            messageLength := shr(240, calldataload(currentOffset))
            currentOffset := add(currentOffset, 2)
        }

        if (spokePool == address(0)) {
            return (false, "Invalid spoke pool address", currentOffset);
        }

        if (depositor == address(0)) {
            return (false, "Invalid depositor address", currentOffset);
        }

        if (destinationChainId == 0) {
            return (false, "Invalid destination chain ID", currentOffset);
        }

        // Validate fee percentage - 50%
        if (feePercentage > 5000) {
            return (false, "Fee percentage too high", currentOffset);
        }

        // Validate message length
        if (messageLength > MAX_CALLDATA_LENGTH) {
            return (false, "Message too long", currentOffset);
        }

        // Skip message data
        newOffset = currentOffset + messageLength;
        return (true, "", newOffset);
    }

    function _validateLendingOperations(uint256 currentOffset)
        internal
        view
        override
        returns (bool isValid, string memory errorMessage, uint256 newOffset)
    {
        uint256 lendingOperation;
        uint256 lenderId;

        assembly {
            let firstSlice := calldataload(currentOffset)
            lendingOperation := shr(248, firstSlice)
            lenderId := and(UINT16_MASK, shr(232, firstSlice))
            currentOffset := add(currentOffset, 3)
        }

        // Validate lending operation type
        if (lendingOperation > LenderOps.WITHDRAW_LENDING_TOKEN) {
            return (false, "Invalid lending operation", currentOffset);
        }

        // Validate lender ID
        if (lenderId >= LenderIds.UP_TO_MORPHO) {
            return (false, "Invalid lender ID", currentOffset);
        }

        /**
         * Deposit collateral
         */
        if (lendingOperation == LenderOps.DEPOSIT) {
            if (lenderId < LenderIds.UP_TO_AAVE_V3) {
                return _validateAaveV3Deposit(currentOffset);
            } else if (lenderId < LenderIds.UP_TO_AAVE_V2) {
                return _validateAaveV2Deposit(currentOffset);
            } else if (lenderId < LenderIds.UP_TO_COMPOUND_V3) {
                return _validateCompoundV3Deposit(currentOffset);
            } else if (lenderId < LenderIds.UP_TO_COMPOUND_V2) {
                return _validateCompoundV2Deposit(currentOffset);
            } else {
                return _validateMorphoDepositCollateral(currentOffset);
            }
        }
        /**
         * Borrow
         */
        else if (lendingOperation == LenderOps.BORROW) {
            if (lenderId < LenderIds.UP_TO_AAVE_V2) {
                return _validateAaveBorrow(currentOffset);
            } else if (lenderId < LenderIds.UP_TO_COMPOUND_V3) {
                return _validateCompoundV3Borrow(currentOffset);
            } else if (lenderId < LenderIds.UP_TO_COMPOUND_V2) {
                return _validateCompoundV2Borrow(currentOffset);
            } else {
                return _validateMorphoBorrow(currentOffset);
            }
        }
        /**
         * Repay
         */
        else if (lendingOperation == LenderOps.REPAY) {
            if (lenderId < LenderIds.UP_TO_AAVE_V2) {
                return _validateAaveRepay(currentOffset);
            } else if (lenderId < LenderIds.UP_TO_COMPOUND_V3) {
                return _validateCompoundV3Repay(currentOffset);
            } else if (lenderId < LenderIds.UP_TO_COMPOUND_V2) {
                return _validateCompoundV2Repay(currentOffset);
            } else {
                return _validateMorphoRepay(currentOffset);
            }
        }
        /**
         * Withdraw collateral
         */
        else if (lendingOperation == LenderOps.WITHDRAW) {
            if (lenderId < LenderIds.UP_TO_AAVE_V2) {
                return _validateAaveWithdraw(currentOffset);
            } else if (lenderId < LenderIds.UP_TO_COMPOUND_V3) {
                return _validateCompoundV3Withdraw(currentOffset);
            } else if (lenderId < LenderIds.UP_TO_COMPOUND_V2) {
                return _validateCompoundV2Withdraw(currentOffset);
            } else {
                return _validateMorphoWithdrawCollateral(currentOffset);
            }
        }
        /**
         * deposit lendingToken
         */
        else if (lendingOperation == LenderOps.DEPOSIT_LENDING_TOKEN) {
            return _validateMorphoDeposit(currentOffset);
        }
        /**
         * withdraw lendingToken
         */
        else if (lendingOperation == LenderOps.WITHDRAW_LENDING_TOKEN) {
            return _validateMorphoWithdraw(currentOffset);
        } else {
            return (false, "Unknown lending operation", currentOffset);
        }
    }

    function _validateAaveV3Deposit(uint256 currentOffset) internal view returns (bool, string memory, uint256) {
        return _validateAaveDeposit(currentOffset, AaveVersion.AAVE_V3);
    }

    function _validateAaveV2Deposit(uint256 currentOffset) internal view returns (bool, string memory, uint256) {
        return _validateAaveDeposit(currentOffset, AaveVersion.AAVE_V2);
    }

    function _validateAaveDeposit(uint256 currentOffset, AaveVersion aaveVersion) internal view returns (bool, string memory, uint256) {
        address underlying;
        address receiver;
        address pool;

        // todo: add pool whitelist check

        assembly {
            underlying := shr(96, calldataload(currentOffset))
            currentOffset := add(currentOffset, 36) // skip underlying(20) + amount(16)
            receiver := shr(96, calldataload(currentOffset))
            currentOffset := add(currentOffset, 20)
            pool := shr(96, calldataload(currentOffset))
            currentOffset := add(currentOffset, 20)
        }

        if (underlying == address(0)) return (false, "Invalid underlying address", currentOffset);
        if (receiver == address(0)) return (false, "Invalid receiver address", currentOffset);
        if (pool == address(0)) return (false, "Invalid pool address", currentOffset);

        return (true, "", currentOffset);
    }

    function _validateAaveBorrow(uint256 currentOffset) internal view returns (bool, string memory, uint256) {
        address underlying;
        address receiver;
        address pool;

        assembly {
            underlying := shr(96, calldataload(currentOffset))
            currentOffset := add(currentOffset, 36) // skip underlying(20) + amount(16)
            receiver := shr(96, calldataload(currentOffset))
            currentOffset := add(currentOffset, 21) // skip receiver(20) + mode(1)
            pool := shr(96, calldataload(currentOffset))
            currentOffset := add(currentOffset, 20)
        }

        if (underlying == address(0)) return (false, "Invalid underlying address", currentOffset);
        if (receiver == address(0)) return (false, "Invalid receiver address", currentOffset);
        if (pool == address(0)) return (false, "Invalid pool address", currentOffset);

        return (true, "", currentOffset);
    }

    function _validateAaveRepay(uint256 currentOffset) internal view returns (bool, string memory, uint256) {
        address underlying;
        address receiver;
        address debtToken;
        address pool;

        assembly {
            underlying := shr(96, calldataload(currentOffset))
            currentOffset := add(currentOffset, 36) // skip underlying(20) + amount(16)
            receiver := shr(96, calldataload(currentOffset))
            currentOffset := add(currentOffset, 21) // skip receiver(20) + mode(1)
            debtToken := shr(96, calldataload(currentOffset))
            currentOffset := add(currentOffset, 20)
            pool := shr(96, calldataload(currentOffset))
            currentOffset := add(currentOffset, 20)
        }

        if (underlying == address(0)) return (false, "Invalid underlying address", currentOffset);
        if (receiver == address(0)) return (false, "Invalid receiver address", currentOffset);
        if (debtToken == address(0)) return (false, "Invalid debt token address", currentOffset);
        if (pool == address(0)) return (false, "Invalid pool address", currentOffset);

        return (true, "", currentOffset);
    }

    function _validateAaveWithdraw(uint256 currentOffset) internal view returns (bool, string memory, uint256) {
        address underlying;
        address receiver;
        address aToken;
        address pool;

        assembly {
            underlying := shr(96, calldataload(currentOffset))
            currentOffset := add(currentOffset, 36) // skip underlying(20) + amount(16)
            receiver := shr(96, calldataload(currentOffset))
            currentOffset := add(currentOffset, 20)
            aToken := shr(96, calldataload(currentOffset))
            currentOffset := add(currentOffset, 20)
            pool := shr(96, calldataload(currentOffset))
            currentOffset := add(currentOffset, 20)
        }

        if (underlying == address(0)) return (false, "Invalid underlying address", currentOffset);
        if (receiver == address(0)) return (false, "Invalid receiver address", currentOffset);
        if (aToken == address(0)) return (false, "Invalid aToken address", currentOffset);
        if (pool == address(0)) return (false, "Invalid pool address", currentOffset);

        return (true, "", currentOffset);
    }

    function _validateCompoundV3Deposit(uint256 currentOffset) internal view returns (bool, string memory, uint256) {
        return _validateCompoundV3Basic(currentOffset);
    }

    function _validateCompoundV3Borrow(uint256 currentOffset) internal view returns (bool, string memory, uint256) {
        return _validateCompoundV3Basic(currentOffset);
    }

    function _validateCompoundV3Repay(uint256 currentOffset) internal view returns (bool, string memory, uint256) {
        return _validateCompoundV3Basic(currentOffset);
    }

    function _validateCompoundV3Basic(uint256 currentOffset) internal view returns (bool, string memory, uint256) {
        address underlying;
        address receiver;
        address comet;

        assembly {
            underlying := shr(96, calldataload(currentOffset))
            currentOffset := add(currentOffset, 36) // skip underlying(20) + amount(16)
            receiver := shr(96, calldataload(currentOffset))
            currentOffset := add(currentOffset, 20)
            comet := shr(96, calldataload(currentOffset))
            currentOffset := add(currentOffset, 20)
        }

        if (underlying == address(0)) return (false, "Invalid underlying address", currentOffset);
        if (receiver == address(0)) return (false, "Invalid receiver address", currentOffset);
        if (comet == address(0)) return (false, "Invalid comet address", currentOffset);

        return (true, "", currentOffset);
    }

    function _validateCompoundV3Withdraw(uint256 currentOffset) internal view returns (bool, string memory, uint256) {
        address underlying;
        address receiver;
        address comet;

        assembly {
            underlying := shr(96, calldataload(currentOffset))
            currentOffset := add(currentOffset, 36) // skip underlying(20) + amount(16)
            receiver := shr(96, calldataload(currentOffset))
            currentOffset := add(currentOffset, 21) // skip receiver(20) + isBase(1)
            comet := shr(96, calldataload(currentOffset))
            currentOffset := add(currentOffset, 20)
        }

        if (underlying == address(0)) return (false, "Invalid underlying address", currentOffset);
        if (receiver == address(0)) return (false, "Invalid receiver address", currentOffset);
        if (comet == address(0)) return (false, "Invalid comet address", currentOffset);

        return (true, "", currentOffset);
    }

    function _validateCompoundV2Deposit(uint256 currentOffset) internal view returns (bool, string memory, uint256) {
        return _validateCompoundV2Basic(currentOffset);
    }

    function _validateCompoundV2Borrow(uint256 currentOffset) internal view returns (bool, string memory, uint256) {
        return _validateCompoundV2Basic(currentOffset);
    }

    function _validateCompoundV2Withdraw(uint256 currentOffset) internal view returns (bool, string memory, uint256) {
        return _validateCompoundV2Basic(currentOffset);
    }

    function _validateCompoundV2Repay(uint256 currentOffset) internal view returns (bool, string memory, uint256) {
        return _validateCompoundV2Basic(currentOffset);
    }

    function _validateCompoundV2Basic(uint256 currentOffset) internal view returns (bool, string memory, uint256) {
        address underlying;
        address receiver;
        address cToken;

        assembly {
            underlying := shr(96, calldataload(currentOffset))
            currentOffset := add(currentOffset, 36) // skip underlying(20) + amount(16)
            receiver := shr(96, calldataload(currentOffset))
            currentOffset := add(currentOffset, 20)
            cToken := shr(96, calldataload(currentOffset))
            currentOffset := add(currentOffset, 20)
        }

        if (receiver == address(0)) return (false, "Invalid receiver address", currentOffset);
        if (cToken == address(0)) return (false, "Invalid cToken address", currentOffset);

        return (true, "", currentOffset);
    }

    function _validateMorphoBorrow(uint256 currentOffset) internal view returns (bool, string memory, uint256) {
        return _validateMorphoBasic(currentOffset, 152);
    }

    function _validateMorphoRepay(uint256 currentOffset) internal view returns (bool, string memory, uint256) {
        return _validateMorphoBasic(currentOffset, 152);
    }

    function _validateMorphoDepositCollateral(uint256 currentOffset) internal view returns (bool, string memory, uint256) {
        (bool isValid, string memory errorMessage, uint256 newOffset) = _validateMorphoBasic(currentOffset, 154);
        if (!isValid) return (false, errorMessage, newOffset);

        uint256 calldataLength;
        assembly {
            calldataLength := and(UINT16_MASK, shr(240, calldataload(sub(newOffset, 2))))
        }

        return (true, "", newOffset + calldataLength);
    }

    function _validateMorphoWithdrawCollateral(uint256 currentOffset) internal view returns (bool, string memory, uint256) {
        return _validateMorphoBasic(currentOffset, 152);
    }

    function _validateMorphoDeposit(uint256 currentOffset) internal view returns (bool, string memory, uint256) {
        (bool isValid, string memory errorMessage, uint256 newOffset) = _validateMorphoBasic(currentOffset, 154);
        if (!isValid) return (false, errorMessage, newOffset);

        uint256 calldataLength;
        assembly {
            calldataLength := and(UINT16_MASK, shr(240, calldataload(sub(newOffset, 2))))
        }

        return (true, "", newOffset + calldataLength);
    }

    function _validateMorphoWithdraw(uint256 currentOffset) internal view returns (bool, string memory, uint256) {
        (bool isValid, string memory errorMessage, uint256 newOffset) = _validateMorphoBasic(currentOffset, 154);
        if (!isValid) return (false, errorMessage, newOffset);

        uint256 calldataLength;
        assembly {
            calldataLength := and(UINT16_MASK, shr(240, calldataload(sub(newOffset, 2))))
        }

        return (true, "", newOffset + calldataLength);
    }

    function _validateMorphoBasic(uint256 currentOffset, uint256 totalLength) internal view returns (bool, string memory, uint256) {
        address loanToken;
        address collateralToken;
        address oracle;
        address irm;
        address receiver;
        address morpho;

        assembly {
            loanToken := shr(96, calldataload(currentOffset))
            currentOffset := add(currentOffset, 20)
            collateralToken := shr(96, calldataload(currentOffset))
            currentOffset := add(currentOffset, 20)
            oracle := shr(96, calldataload(currentOffset))
            currentOffset := add(currentOffset, 20)
            irm := shr(96, calldataload(currentOffset))
            currentOffset := add(currentOffset, 20)
            // skip lltv(16) + amount(16)
            currentOffset := add(currentOffset, 32)
            receiver := shr(96, calldataload(currentOffset))
            currentOffset := add(currentOffset, 20)
            morpho := shr(96, calldataload(currentOffset))
        }

        if (loanToken == address(0)) return (false, "Invalid loan token address", currentOffset);
        if (collateralToken == address(0)) return (false, "Invalid collateral token address", currentOffset);
        if (oracle == address(0)) return (false, "Invalid oracle address", currentOffset);
        if (irm == address(0)) return (false, "Invalid IRM address", currentOffset);
        if (receiver == address(0)) return (false, "Invalid receiver address", currentOffset);
        if (morpho == address(0)) return (false, "Invalid morpho address", currentOffset);

        return (true, "", currentOffset - 152 + totalLength);
    }

    function _validateTransfers(uint256 currentOffset) internal view override returns (bool isValid, string memory errorMessage, uint256 newOffset) {
        uint256 transferOperation;
        assembly {
            transferOperation := shr(248, calldataload(currentOffset))
            currentOffset := add(currentOffset, 1)
        }

        if (transferOperation == TransferIds.TRANSFER_FROM) {
            return _validateTransferFrom(currentOffset);
        } else if (transferOperation == TransferIds.SWEEP) {
            return _validateSweep(currentOffset);
        } else if (transferOperation == TransferIds.UNWRAP_WNATIVE) {
            return _validateUnwrapWNative(currentOffset);
        } else if (transferOperation == TransferIds.PERMIT2_TRANSFER_FROM) {
            return _validatePermit2Transfer(currentOffset);
        } else if (transferOperation == TransferIds.APPROVE) {
            return _validateApprove(currentOffset);
        } else {
            return (false, "Invalid transfer operation", currentOffset);
        }
    }

    function _validatePermit(uint256 currentOffset) internal view override returns (bool isValid, string memory errorMessage, uint256 newOffset) {
        uint256 permitOperation;
        address permitTarget;
        uint256 permitLength;

        assembly {
            let firstSlice := calldataload(currentOffset)
            permitOperation := shr(248, firstSlice)
            permitTarget := and(ADDRESS_MASK, shr(88, firstSlice))
            permitLength := and(UINT16_MASK, shr(72, firstSlice))
            currentOffset := add(currentOffset, 23)
        }

        // Validate permit operation
        if (permitOperation > PermitIds.ALLOW_CREDIT_PERMIT) {
            return (false, "Invalid permit operation", currentOffset);
        }

        // Skip permit data
        newOffset = currentOffset + permitLength;
        return (true, "", newOffset);
    }

    function _validateFlashLoan(uint256 currentOffset) internal view override returns (bool isValid, string memory errorMessage, uint256 newOffset) {
        uint256 flashLoanType;
        assembly {
            flashLoanType := shr(248, calldataload(currentOffset))
            currentOffset := add(currentOffset, 1)
        }

        if (flashLoanType > FlashLoanIds.AAVE_V2) {
            return (false, "Invalid flash loan type", currentOffset);
        }

        // todo: add flash loan validator for each flash loan type

        currentOffset += 100; // dummy value
        return (true, "", currentOffset);
    }

    function _validateTransferFrom(uint256 currentOffset) internal view returns (bool, string memory, uint256) {
        address token;
        address receiver;
        uint256 amount;

        assembly {
            token := shr(96, calldataload(currentOffset))
            currentOffset := add(currentOffset, 20)
        }
        if (token == address(0)) {
            return (false, "Invalid token address", currentOffset);
        }
        assembly {
            receiver := shr(96, calldataload(currentOffset))
            currentOffset := add(currentOffset, 20)
        }
        if (receiver == address(0)) {
            return (false, "Invalid receiver address", currentOffset);
        }

        return (true, "", currentOffset + 16); // + skip amount
    }

    function _validateSweep(uint256 currentOffset) internal view returns (bool, string memory, uint256) {
        return (true, "", currentOffset + 57);
    }

    function _validateApprove(uint256 currentOffset) internal view returns (bool, string memory, uint256) {
        address underlying;
        address target;
        assembly {
            underlying := shr(96, calldataload(currentOffset))
            currentOffset := add(currentOffset, 20)
        }
        if (underlying == address(0)) {
            return (false, "Invalid underlying address", currentOffset);
        }
        assembly {
            target := shr(96, calldataload(add(currentOffset, 20)))
            currentOffset := add(currentOffset, 20)
        }
        if (target == address(0)) {
            return (false, "Invalid target address", currentOffset);
        }
        return (true, "", currentOffset);
    }

    function _validateUnwrapWNative(uint256 currentOffset) internal view returns (bool, string memory, uint256) {
        return (true, "", currentOffset + 57);
    }

    function _validatePermit2Transfer(uint256 currentOffset) internal view returns (bool, string memory, uint256) {
        return (true, "", currentOffset + 56);
    }

    // not implemented
    function _validateSwap(uint256 currentOffset) internal view override returns (bool, string memory, uint256) {
        revert();
    }

    function _validateERC4626Operations(uint256 currentOffset) internal view override returns (bool, string memory, uint256) {
        revert();
    }

    function _validateGen2025DexActions(uint256 currentOffset) internal view override returns (bool, string memory, uint256) {
        revert();
    }
}
