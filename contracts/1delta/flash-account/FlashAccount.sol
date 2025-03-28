// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.27;

import {FlashAccountBase} from "./FlashAccountBase.sol";
import {FlashLoanExecuter} from "./FlashLoanExecuter.sol";
import {IEntryPoint} from "account-abstraction/interfaces/IEntryPoint.sol";
import {BaseLightAccount} from "./common/BaseLightAccount.sol";

contract FlashAccount is FlashAccountBase, FlashLoanExecuter {
    constructor(IEntryPoint entryPoint_) FlashAccountBase(entryPoint_) {}

    function __call(address target, uint256 value, bytes memory data) internal override {
        BaseLightAccount._call(target, value, data);
    }

    function __onlyAuthorized() internal view override {
        BaseLightAccount._onlyAuthorized();
    }
}
