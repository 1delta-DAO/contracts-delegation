// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {ERC20Selectors} from "contracts/1delta/shared/selectors/ERC20Selectors.sol";
import {Masks} from "contracts/1delta/shared/masks/Masks.sol";
import {DeltaErrors} from "contracts/1delta/shared/errors/Errors.sol";

contract BaseUtils is ERC20Selectors, Masks, DeltaErrors {}
