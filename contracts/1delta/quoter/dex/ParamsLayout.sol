// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.28;

abstract contract QuoterParamsLayout {
    uint256 internal constant CL_PARAM_LENGTH = 43; // token + id + pool + fee
    uint256 internal constant V2_PARAM_LENGTH = CL_PARAM_LENGTH; // token + id + pool
    uint256 internal constant EXOTIC_PARAM_LENGTH = 41; // token + id + pool
    uint256 internal constant DODO_PARAM_LENGTH = 42; // token + id + pool + uint8
    uint256 internal constant CURVE_PARAM_LENGTH = CL_PARAM_LENGTH + 1; // token + id + pool + idIn + idOut + selectorId
    uint256 internal constant CURVE_CUSTOM_PARAM_LENGTH = 21; // no pool address provided
}
