// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.27;

import {FlashAccountBase} from "./FlashAccountBase.sol";
import {IEntryPoint} from "account-abstraction/interfaces/IEntryPoint.sol";
import {ILendingProvider} from "@flash-account/interfaces/ILendingProvider.sol";
import {Benqi} from "./Lenders/Benqi/Benqi.sol";
contract FlashAccount is FlashAccountBase, Benqi {
    constructor(IEntryPoint entryPoint_) FlashAccountBase(entryPoint_) {}

    /**
     * @dev Explicit flash loan callback functions
     * All of them are locked through the execution lock to prevent access outside
     * of the `execute` functions
     */

    /**
     * Aave simple flash loan
     */
    function executeOperation(
        address,
        uint256,
        uint256,
        address,
        bytes calldata params // user params
    ) external requireInExecution returns (bool) {
        // forward execution
        _decodeAndExecute(params);

        return true;
    }

    /**
     * Balancer flash loan
     */
    function receiveFlashLoan(
        address[] calldata,
        uint256[] calldata,
        uint256[] calldata,
        bytes calldata params //
    ) external requireInExecution {
        // execute furhter operations
        _decodeAndExecute(params);
    }

    /**
     * Morpho flash loan
     */
    function onMorphoFlashLoan(uint256 assets, bytes calldata params) external requireInExecution {
        // execute furhter operations
        _decodeAndExecute(params);
    }

    function supply(ILendingProvider.LendingParams calldata params) external requireInExecution {
        if (params.lender == BENQI_COMPTROLLER) {
            _supplyBenqi(params);
        }
    }

    function withdraw(ILendingProvider.LendingParams calldata params) external requireInExecution {
        if (params.lender == BENQI_COMPTROLLER) {
            _withdrawBenqi(params);
        }
    }

    function borrow(ILendingProvider.LendingParams calldata params) external requireInExecution {
        if (params.lender == BENQI_COMPTROLLER) {
            _borrowBenqi(params);
        }
    }

    function repay(ILendingProvider.LendingParams calldata params) external requireInExecution {
        if (params.lender == BENQI_COMPTROLLER) {
            _repayBenqi(params);
        }
    }
}
