// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.34;

import {AaveLending} from "./AaveLending.sol";
import {AaveV4Lending} from "./AaveV4Lending.sol";
import {CompoundV3Lending} from "./CompoundV3Lending.sol";
import {CompoundV2Lending} from "./CompoundV2Lending.sol";
import {MorphoLending} from "./MorphoLending.sol";
import {ListaBrokerLending} from "./ListaBrokerLending.sol";
import {SiloV2Lending} from "./SiloV2Lending.sol";
import {FluidLending} from "./FluidLending.sol";
import {FluidSmartLending} from "./FluidSmartLending.sol";
import {GearboxV3Lending} from "./GearboxV3Lending.sol";
import {LenderIds, LenderOps} from "../enums/DeltaEnums.sol";
import {DeltaErrors} from "contracts/1delta/shared/errors/Errors.sol";

// solhint-disable max-line-length

/**
 * @notice Merge all lending ops in one operation
 * Can inject parameters
 * - paramPush for receiving funds (e.g. receiving funds from swaps or flash loans)
 * - paramPull for being required to pay an exact amount (e.g. DEX swap payments, flash loan amounts)
 */
abstract contract UniversalLending is
    AaveLending,
    AaveV4Lending,
    CompoundV3Lending,
    CompoundV2Lending,
    MorphoLending,
    ListaBrokerLending,
    SiloV2Lending,
    FluidLending, // brings in DeltaErrors transitively
    FluidSmartLending,
    GearboxV3Lending
{
    /**
     * @notice Executes any lending operation across various lenders
     * @dev Routes to appropriate lender based on operation and lender ID
     * @param callerAddress Address of the caller
     * @param currentOffset Current position in the calldata
     * @return Updated calldata offset after processing
     * @custom:calldata-offset-table
     * | Offset | Length (bytes) | Description                     |
     * |--------|----------------|---------------------------------|
     * | 0      | 1              | lendingOperation                |
     * | 1      | 2              | lender                          |
     * | 3      | variable       | rest                            |
     */
    function _lendingOperations(
        address callerAddress,
        uint256 currentOffset // params similar to deltaComposeInternal
    )
        internal
        returns (uint256)
    {
        uint256 lendingOperation;
        uint256 lender;
        assembly {
            let slice := calldataload(currentOffset)
            lendingOperation := shr(248, slice)
            lender := and(UINT16_MASK, shr(232, slice))
            currentOffset := add(currentOffset, 3)
        }
        /**
         * Deposit collateral
         */
        if (lendingOperation == LenderOps.DEPOSIT) {
            if (lender < LenderIds.UP_TO_AAVE_V3) {
                return _depositToAaveV3(currentOffset);
            } else if (lender < LenderIds.UP_TO_AAVE_V2) {
                return _depositToAaveV2(currentOffset);
            } else if (lender < LenderIds.UP_TO_COMPOUND_V3) {
                return _depositToCompoundV3(currentOffset);
            } else if (lender < LenderIds.UP_TO_COMPOUND_V2) {
                return _depositToCompoundV2(currentOffset);
            } else if (lender < LenderIds.UP_TO_MORPHO) {
                return _encodeMorphoDepositCollateral(currentOffset, callerAddress);
            } else if (lender < LenderIds.UP_TO_SILO_V2) {
                return _depositToSiloV2(currentOffset);
            } else if (lender < LenderIds.UP_TO_AAVE_V4) {
                return _depositToAaveV4(currentOffset);
            } else if (lender >= LenderIds.UP_TO_FLUID_SMART && lender < LenderIds.UP_TO_GEARBOX_V3) {
                return _depositToGearboxV3(currentOffset, callerAddress);
            } else {
                _invalidOperation();
            }
        }
        /**
         * Borrow
         */
        else if (lendingOperation == LenderOps.BORROW) {
            if (lender < LenderIds.UP_TO_AAVE_V2) {
                return _borrowFromAave(currentOffset, callerAddress);
            } else if (lender < LenderIds.UP_TO_COMPOUND_V3) {
                return _borrowFromCompoundV3(currentOffset, callerAddress);
            } else if (lender < LenderIds.UP_TO_COMPOUND_V2) {
                return _borrowFromCompoundV2(currentOffset, callerAddress);
            } else if (lender < LenderIds.UP_TO_MORPHO) {
                return _morphoBorrow(currentOffset, callerAddress);
            } else if (lender < LenderIds.UP_TO_SILO_V2) {
                return _borrowFromSiloV2(currentOffset, callerAddress);
            } else if (lender < LenderIds.UP_TO_AAVE_V4) {
                return _borrowFromAaveV4(currentOffset, callerAddress);
            } else if (lender >= LenderIds.UP_TO_FLUID_SMART && lender < LenderIds.UP_TO_GEARBOX_V3) {
                return _borrowFromGearboxV3(currentOffset, callerAddress);
            } else {
                _invalidOperation();
            }
        }
        /**
         * Repay
         */
        else if (lendingOperation == LenderOps.REPAY) {
            if (lender < LenderIds.UP_TO_AAVE_V2) {
                return _repayToAave(currentOffset);
            } else if (lender < LenderIds.UP_TO_COMPOUND_V3) {
                return _repayToCompoundV3(currentOffset);
            } else if (lender < LenderIds.UP_TO_COMPOUND_V2) {
                return _repayToCompoundV2(currentOffset);
            } else if (lender < LenderIds.UP_TO_MORPHO) {
                return _morphoRepay(currentOffset, callerAddress);
            } else if (lender < LenderIds.UP_TO_SILO_V2) {
                return _repayToSiloV2(currentOffset);
            } else if (lender < LenderIds.UP_TO_AAVE_V4) {
                return _repayToAaveV4(currentOffset);
            } else if (lender >= LenderIds.UP_TO_FLUID_SMART && lender < LenderIds.UP_TO_GEARBOX_V3) {
                return _repayToGearboxV3(currentOffset, callerAddress);
            } else {
                _invalidOperation();
            }
        }
        /**
         * Withdraw collateral
         */
        else if (lendingOperation == LenderOps.WITHDRAW) {
            if (lender < LenderIds.UP_TO_AAVE_V2) {
                return _withdrawFromAave(currentOffset, callerAddress);
            } else if (lender < LenderIds.UP_TO_COMPOUND_V3) {
                return _withdrawFromCompoundV3(currentOffset, callerAddress);
            } else if (lender < LenderIds.UP_TO_COMPOUND_V2) {
                return _withdrawFromCompoundV2(currentOffset, callerAddress);
            } else if (lender < LenderIds.UP_TO_MORPHO) {
                return _encodeMorphoWithdrawCollateral(currentOffset, callerAddress);
            } else if (lender < LenderIds.UP_TO_SILO_V2) {
                return _withdrawFromSiloV2(currentOffset, callerAddress);
            } else if (lender < LenderIds.UP_TO_AAVE_V4) {
                return _withdrawFromAaveV4(currentOffset, callerAddress);
            } else if (lender >= LenderIds.UP_TO_FLUID_SMART && lender < LenderIds.UP_TO_GEARBOX_V3) {
                return _withdrawFromGearboxV3(currentOffset, callerAddress);
            } else {
                _invalidOperation();
            }
        }
        /**
         * deposit lendingToken
         */
        else if (lendingOperation == LenderOps.DEPOSIT_LENDING_TOKEN) {
            if (lender < LenderIds.UP_TO_MORPHO) {
                return _encodeMorphoDeposit(currentOffset, callerAddress);
            } else if (lender >= LenderIds.UP_TO_AAVE_V4 && lender < LenderIds.UP_TO_FLUID) {
                return _depositToFluidFToken(currentOffset);
            } else {
                _invalidOperation();
            }
        }
        /**
         * withdraw lendingToken
         */
        else if (lendingOperation == LenderOps.WITHDRAW_LENDING_TOKEN) {
            if (lender < LenderIds.UP_TO_MORPHO) {
                return _encodeMorphoWithdraw(currentOffset, callerAddress);
            } else if (lender >= LenderIds.UP_TO_AAVE_V4 && lender < LenderIds.UP_TO_FLUID) {
                return _withdrawFromFluidFToken(currentOffset, callerAddress);
            } else {
                _invalidOperation();
            }
        }
        /**
         * Set collateral status (Aave V4 only)
         */
        else if (lendingOperation == LenderOps.SET_COLLATERAL) {
            if (lender < LenderIds.UP_TO_AAVE_V4) {
                return _setCollateralAaveV4(currentOffset, callerAddress);
            } else {
                _invalidOperation();
            }
        }
        /**
         * Lista fixed-term broker borrow (Moolah-backed market; debt side only).
         */
        else if (lendingOperation == LenderOps.LISTA_BROKER_BORROW) {
            if (lender >= LenderIds.UP_TO_COMPOUND_V2 && lender < LenderIds.UP_TO_MORPHO) {
                return _listaBrokerBorrow(currentOffset, callerAddress);
            } else {
                _invalidOperation();
            }
        }
        /**
         * Lista fixed-term broker repay (Moolah-backed market; debt side only).
         */
        else if (lendingOperation == LenderOps.LISTA_BROKER_REPAY) {
            if (lender >= LenderIds.UP_TO_COMPOUND_V2 && lender < LenderIds.UP_TO_MORPHO) {
                return _listaBrokerRepay(currentOffset);
            } else {
                _invalidOperation();
            }
        }
        /**
         * Fluid T1 operate — dual-axis col + debt in a single op, with fresh-mint auto-sweep.
         * Supersedes the per-axis DEPOSIT/BORROW/REPAY/WITHDRAW fluid ops.
         */
        else if (lendingOperation == LenderOps.FLUID_OPERATE_T1) {
            if (lender >= LenderIds.UP_TO_AAVE_V4 && lender < LenderIds.UP_TO_FLUID) {
                return _callFluidOperate(currentOffset);
            } else {
                _invalidOperation();
            }
        }
        /**
         * Fluid smart-vault (T2/T3/T4) operate
         */
        else if (lendingOperation == LenderOps.FLUID_OPERATE) {
            if (lender >= LenderIds.UP_TO_FLUID && lender < LenderIds.UP_TO_FLUID_SMART) {
                return _fluidSmartOperate(currentOffset);
            } else {
                _invalidOperation();
            }
        }
        /**
         * Fluid smart-vault (T2/T3/T4) operatePerfect
         */
        else if (lendingOperation == LenderOps.FLUID_OPERATE_PERFECT) {
            if (lender >= LenderIds.UP_TO_FLUID && lender < LenderIds.UP_TO_FLUID_SMART) {
                return _fluidSmartOperatePerfect(currentOffset);
            } else {
                _invalidOperation();
            }
        }
        /**
         * Gearbox V3 generic multicall (botMulticall / openCreditAccount)
         */
        else if (lendingOperation == LenderOps.GEARBOX_MULTICALL) {
            if (lender >= LenderIds.UP_TO_FLUID_SMART && lender < LenderIds.UP_TO_GEARBOX_V3) {
                return _gearboxMulticall(currentOffset, callerAddress);
            } else {
                _invalidOperation();
            }
        } else {
            _invalidOperation();
        }
    }
}
