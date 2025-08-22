// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

import {BaseTest} from "test/shared/BaseTest.sol";
import {Test} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Chains, Tokens} from "test/data/LenderRegistry.sol";
import {BridgeMulticallHandler} from "contracts/1delta/shared/BridgeMulticallHandler.sol";

// solhint-disable max-line-length

contract BridgeMulticallHandlerTest is BaseTest {
    using CalldataLib for bytes;

    uint256 internal constant forkBlock = 1;

    uint256 public BRIDGE_AMOUNT = 1 * 1e15; // 0.001 ETH

    // Contract instances
    BridgeMulticallHandler private multicallHandler;

    function setUp() public {
        string memory chainName = Chains.ARBITRUM_ONE;

        _init(chainName, forkBlock, true);

        multicallHandler = new BridgeMulticallHandler();

        _fundUserWithNative(BRIDGE_AMOUNT);

        vm.label(address(multicallHandler), "multicallHandler");
        vm.label(user, "User");
    }

    function test_across_bridge_token_balance() public {

    }
}