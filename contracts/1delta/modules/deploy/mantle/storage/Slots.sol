// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.26;

contract Slots {
    // lender token slots
    bytes32 internal constant EXTERNAL_CALLS_SLOT = 0x9985cdfd7652aca37435f47bfd247a768d7f8206ef9518f447bfe8914bf4c668;
    // lender token slots
    bytes32 internal constant COLLATERAL_TOKENS_SLOT = 0xff0471b67e4632a86905e3993f5377c608866007c59224eed7731408a9f3f8b3;
    bytes32 internal constant VARIABLE_DEBT_TOKENS_SLOT = 0xff0471b67e4632a86905e3993f5377c608866007c59224eed7731408a9f3f8b4;
    bytes32 internal constant STABLE_DEBT_TOKENS_SLOT = 0xff0471b67e4632a86905e3993f5377c608866007c59224eed7731408a9f3f8b5;
}
