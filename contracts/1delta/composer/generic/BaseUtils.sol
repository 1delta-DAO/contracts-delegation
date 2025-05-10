// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {ERC20Selectors} from "contracts/1delta/shared/selectors/ERC20Selectors.sol";
import {Masks} from "contracts/1delta/shared/masks/Masks.sol";
import {DeltaErrors} from "contracts/1delta/shared/errors/Errors.sol";

contract BaseUtils is ERC20Selectors, Masks, DeltaErrors {
    error InvalidAssetId(uint16 assetId);
    error InsufficientValue();
    error SlippageTooHigh(uint256 expected, uint256 actual);
    error ZeroBalance();
    error BridgeFailed();

    uint256 internal constant FEE_DENOMINATOR = 1e9;
    uint256 internal constant INSUFFICIENT_VALUE = 0x1101129400000000000000000000000000000000000000000000000000000000;
    uint256 internal constant ZERO_BALANCE = 0x669567ea00000000000000000000000000000000000000000000000000000000;
    uint256 internal constant BRIDGE_FAILED = 0xc3b9eede00000000000000000000000000000000000000000000000000000000;
}
