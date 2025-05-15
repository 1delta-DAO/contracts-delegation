// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "../data/LenderRegistry.sol";
import {BaseTest} from "test/shared/BaseTest.sol";
import {QuoterLight} from "contracts/1delta/composer/quoter/QuoterLight.sol";
import {console} from "forge-std/console.sol";

contract CalldataTest is BaseTest {
    QuoterLight public quoter;
    bytes internal inputCalldata;

    /// @dev Add the test calldata to the testCalldata or pass it as an env variable with the var name of CD
    bytes internal testCalldata =
        hex"00002f2a2543b76a4166549f7aab2e75bef0aefc5b0f1111111111111111111111111111111111111111002f5e87c9312fa29aed5c179e456625d79015299c0001f40000";
    address internal inputToken = 0x82aF49447D8a07e3bd95BD0d56f35241523fBab1;
    uint256 internal amount = 1000000000000000000;
    // --------------------------------------------------------------- //

    function setUp() public {
        _init(Chains.ARBITRUM_ONE, 0, true);
        quoter = new QuoterLight();
        // get the calldata from cli
        inputCalldata = vm.envOr("CD", bytes(testCalldata));
    }

    /// @dev assumes that the input bytes can directly be called on the quoter (with function selector and the amountIn)
    function test_calldata_1() public {
        address(quoter).call(inputCalldata);
    }

    /// @dev assumes that the input bytes is the swaps path calldata, this requires inputToken and amount to be set
    function test_calldata_2() public {
        quoter.quote(amount, abi.encodePacked(inputToken, inputCalldata));
    }
}
