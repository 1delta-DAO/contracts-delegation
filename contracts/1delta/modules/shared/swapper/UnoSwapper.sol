// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.28;

import {CurveSwapper} from "./Curve.sol";
import {V2TypeSwapper} from "./V2Type.sol";
import {V3TypeSwapper} from "./V3Type.sol";

/**
 * Default swappers that should be on every chain
 */
abstract contract UnoSwapper is CurveSwapper, V2TypeSwapper, V3TypeSwapper {}
