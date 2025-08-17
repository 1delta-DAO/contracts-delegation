// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Chains, Tokens, Lenders} from "test/data/LenderRegistry.sol";
import {DexTypeMappings} from "contracts/1delta/composer/swappers/dex/DexTypeMappings.sol";
import {CalldataLib} from "test/composer/utils/CalldataLib.sol";
import {DexPayConfig} from "contracts/1delta/composer/enums/MiscEnums.sol";
import {BaseTest} from "test/shared/BaseTest.sol";
import {QuoterLight} from "contracts/1delta/composer/quoter/QuoterLight.sol";
import {console} from "forge-std/console.sol";

contract CalldataTest is BaseTest {
    using CalldataLib for bytes;

    QuoterLight public quoter;
    bytes internal inputCalldata;

    /// @dev Add the test calldata to the testCalldata or pass it as an env variable with the var name of CD
    bytes internal testCalldata =
        hex"0000fd086bc7cd5c481dcc9c85ebe478a1c0b69fcbb9111111111111111111111111111111111111111101d04bc65744306a5c149414dd3cd5c984d9d3470d0026f20000";
    address internal inputToken = 0x82aF49447D8a07e3bd95BD0d56f35241523fBab1;
    uint256 internal amount = 100000000000000000;
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

    function test_calldata_recreate_uniswap_v2_failure() public {
        bytes memory testCalldataFromSwapSdk =
            hex"0000fd086bc7cd5c481dcc9c85ebe478a1c0b69fcbb9111111111111111111111111111111111111111101d04bc65744306a5c149414dd3cd5c984d9d3470d26f2000000";
        address inputTokenFromSwapSdk = 0x82aF49447D8a07e3bd95BD0d56f35241523fBab1;
        address outputTokenFromSwapSdk = 0xFd086bC7CD5C481DCC9C85ebE478A1C0b69FCbb9;
        uint256 amountFromSwapSdk = 100000000000000000;
        address receiver = 0x1111111111111111111111111111111111111111;
        address pool = 0xd04Bc65744306A5C149414dd3CD5c984D9d3470d;

        bytes memory path =
            CalldataLib.encodeUniswapV2StyleSwap(outputTokenFromSwapSdk, receiver, 0, pool, 9970, DexPayConfig.CALLER_PAYS, new bytes(0));

        console.log("path");
        console.logBytes(abi.encodePacked(uint8(0), uint8(0), path));
        console.logBytes(testCalldataFromSwapSdk);

        path = abi.encodePacked(inputTokenFromSwapSdk, uint8(0), uint8(0), path);
        // Get quote
        uint256 quotedAmountOut = quoter.quote(amountFromSwapSdk, path);
    }
}
