// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {IERC20All} from "test/shared/interfaces/IERC20All.sol";
import {BaseTest} from "test/shared/BaseTest.sol";
import {Chains, Tokens, Lenders} from "test/data/LenderRegistry.sol";
import "contracts/utils/CalldataLib.sol";
import "contracts/1delta/composer/quoter/QuoterLight.sol";
import {console} from "forge-std/console.sol";
import {ComposerPlugin, IComposerLike} from "plugins/ComposerPlugin.sol";

contract ForkTest is BaseTest {
    QuoterLight quoter;

    uint256 internal constant forkBlock = 0;

    function setUp() public virtual {
        // initialize the chain
        string memory chainName = Chains.TAIKO_ALETHIA;

        _init(chainName, forkBlock, true);

        quoter = new QuoterLight();
    }

    function test_fork_quote_raw() external {
        uint256 quo = quoter.quote(0x38d7ea4c68000, getData());
        console.log("quote", quo);
    }

    function getData() internal pure returns (bytes memory d) {
        d =
            hex"a51894664a773981c6c112c43ce576f315d5b1b60100000007d83526730c7438048d55a4fc0b850e2aab6f0b0000000000000000000000000000000000000000a0ef4a016f3e54c4520220ade7a496842ecbf83e090000002def195713cf4a606b49d07e520e22c17899a736000000000000000000000000000000000000000001a6b01b0e04acc62aba14c02afc0e4c59dab7c05a270e840000";
    }
}
