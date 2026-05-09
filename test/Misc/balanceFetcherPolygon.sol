// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "forge-std/Test.sol";
import "../../contracts/external-protocols/misc/BalanceFetcher.sol";

interface IBal {
    function bal(bytes calldata data) external view returns (bytes memory);
}

// Reproduces the asset list returned by the Polygon balance API for a user wallet.
// The API contained seven legit tokens and ten "tokens" that were actually EOAs —
// pre-fix the BalanceFetcher leaked the user's address (truncated to uint112) as a
// fake balance for each EOA. This test pins those exact addresses so future regressions
// in the staticcall / returndatasize handling are caught.
contract BalanceFetcherPolygonTest is Test {
    IBal public fetcher;

    address public constant USER = 0x000000000000000000000000ffFFFfFfFFFFFffe;

    // Legit Polygon assets (have on-chain code and a real balanceOf).
    address constant POL_USDT = 0xc2132D05D31c914a87C6611C10748AEb04B58e8F;
    address constant POL_WPOL = 0x0d500B1d8E8eF31E21C99d1Db9A6444d3ADf1270;
    address constant POL_WETH = 0x7ceB23fD6bC0adD59E62ac25578270cFf1b9f619;
    address constant POL_DAI = 0x8f3Cf7ad23Cd3CaDbD9735AFf958023239c6A063;
    address constant POL_USDC = 0x3c499c542cEF5E3811e1192ce70d8cC03d5c3359;
    address constant POL_MATICX = 0xfa68FB4628DFF1028CFEc22b4162FCcd0d45efb6;

    // Spam "tokens" surfaced by the balance API. Confirmed to be plain EOAs at
    // the time of writing — so balanceOf staticcall succeeds with 0 returndata.
    address[] public SPAM_TOKENS = [
        0x110229CAc00aD30D89b75F5a01afd3C97288A3a9,
        0x2111908D75CF2F13ccCEDDb76f45c73D9C6B3F45,
        0x2faaa34f387e6485671FaeDA7C021EE6aF961d35,
        0x365ab7828ea541C1D6e30472A1a1e7d07600A6Bd,
        0x4E16eBe75b962D84c374bb16b55e1645DB86cE55,
        0x57130714686d84Ca401C495eA9B3F932eD368C93,
        0x88B643e40200cb730392606B5686562dEB582263,
        0x8a874eb137D99415baD95C5d4399BC691849d02F,
        0xB098E5031aD75F2cbFb319c3ad8745b9256081D7,
        0xfaa57780efCAF4F6bC057B1aB1DB9e7eDf93841A
    ];

    function setUp() public {
        vm.createSelectFork("https://polygon.drpc.org");
        fetcher = IBal(address(new BalanceFetcher()));
    }

    function test_polygon_balance_fetcher_full_asset_list() public {
        // Pre-condition: every spam address must currently be an EOA.
        // If Polygon ever deploys code at one of these the test will surface that
        // and the assertion below should be revisited.
        for (uint256 i = 0; i < SPAM_TOKENS.length; i++) {
            assertEq(SPAM_TOKENS[i].code.length, 0, "spam token unexpectedly has code");
        }

        // Snapshot raw balances from the API, used to seed the synthetic user.
        uint256 polAmount = 4520963828527683672; // 4.52 POL
        uint256 usdtAmount = 32838; // 0.032838 USDT
        uint256 wpolAmount = 282727825090734807;
        uint256 wethAmount = 8273335221904;
        uint256 daiAmount = 1237218291790172;
        uint256 usdcAmount = 355;
        uint256 maticxAmount = 956868519369920;

        vm.deal(USER, polAmount);
        deal(POL_USDT, USER, usdtAmount);
        deal(POL_WPOL, USER, wpolAmount);
        deal(POL_WETH, USER, wethAmount);
        deal(POL_DAI, USER, daiAmount);
        deal(POL_USDC, USER, usdcAmount);
        deal(POL_MATICX, USER, maticxAmount);

        // Token list mirrors the API order: native, six legit ERC20s, ten spam EOAs.
        address[] memory tokens = new address[](7 + SPAM_TOKENS.length);
        tokens[0] = address(0);
        tokens[1] = POL_USDT;
        tokens[2] = POL_WPOL;
        tokens[3] = POL_WETH;
        tokens[4] = POL_DAI;
        tokens[5] = POL_USDC;
        tokens[6] = POL_MATICX;
        for (uint256 i = 0; i < SPAM_TOKENS.length; i++) {
            tokens[7 + i] = SPAM_TOKENS[i];
        }

        bytes memory tokenBlob;
        for (uint256 i = 0; i < tokens.length; i++) {
            tokenBlob = bytes.concat(tokenBlob, abi.encodePacked(tokens[i]));
        }

        bytes memory input = abi.encodePacked(
            uint16(tokens.length), // numTokens
            uint16(1), // numAddresses
            abi.encodePacked(USER),
            tokenBlob
        );

        bytes memory data = fetcher.bal(input);

        uint256 offset = 8; // skip 8-byte block number prefix
        uint16 userIndex;
        uint16 count;
        assembly {
            let userData := mload(add(data, add(32, offset)))
            userIndex := shr(240, userData)
            count := and(shr(224, userData), 0xffff)
        }
        assertEq(userIndex, 0, "user index");

        bool[] memory reported = new bool[](tokens.length);
        offset += 4;
        for (uint256 i = 0; i < count; i++) {
            uint16 idx;
            uint112 bal;
            assembly {
                let w := mload(add(data, add(32, offset)))
                idx := shr(240, w)
                bal := and(shr(128, w), 0xffffffffffffffffffffffffffff)
            }
            assertLt(idx, tokens.length, "token index out of range");

            uint256 actual;
            if (tokens[idx] == address(0)) {
                actual = USER.balance;
            } else {
                (bool ok, bytes memory ret) = tokens[idx].staticcall(abi.encodeWithSignature("balanceOf(address)", USER));
                require(ok && ret.length >= 32, "legit token balanceOf failed");
                actual = abi.decode(ret, (uint256));
            }
            assertEq(uint256(bal), actual, "fetcher balance != on-chain balance");

            reported[idx] = true;
            offset += 16;
        }

        // Native POL was funded via vm.deal, so it must always show up regardless of
        // whether StdCheats.deal happened to find the right slot for the ERC20s.
        assertTrue(reported[0], "native POL must be reported");

        // Each of the ten EOA spam tokens must be filtered.
        for (uint256 i = 7; i < tokens.length; i++) {
            assertTrue(!reported[i], "spam EOA token leaked into output");
        }
    }
}
