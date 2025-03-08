// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {Test} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";
import {ComposerUtils, Commands} from "../shared/utils/ComposerUtils.sol";
import {MarketParams, IMorphoEverything} from "./utils/Morpho.sol";

import {OneDeltaComposerLight} from "../../contracts/1delta/modules/light/Composer.sol";
import {IERC20All} from "../shared/interfaces/IERC20All.sol";
import {COMPOUND_V2_DATA_42161} from "./data/COMPOUND_V2_DATA_42161.sol";

/**
 * We test all morpho blue operations
 * - supply, supplyCollateral, borrow, repay, erc4646Deposit, erc4646Withdraw
 */
contract CompoundComposerLightTest is Test, ComposerUtils, COMPOUND_V2_DATA_42161 {
    uint16 internal constant COMPOUND_V2_ID = 3000;

    OneDeltaComposerLight oneDV2;

    address internal constant user = address(984327);

    function setUp() public virtual {
        vm.createSelectFork({blockNumber: 290934482, urlOrAlias: "https://arbitrum.drpc.org"});
        oneDV2 = new OneDeltaComposerLight();
    }

    function encodeCompoundV2Deposit(address token, bool overrideAmount, uint amount, address receiver) internal view returns (bytes memory) {
        return
            abi.encodePacked(
                uint8(Commands.LENDING),
                uint8(0),
                uint16(COMPOUND_V2_ID),
                token,
                uint128(amount),
                receiver,
                VENUS_cTokens[token] //
            );
    }

    function encodeCompoundV2Borrow(address token, bool overrideAmount, uint amount, address receiver) internal view returns (bytes memory) {
        return
            abi.encodePacked(
                uint8(Commands.LENDING),
                uint8(1),
                uint16(COMPOUND_V2_ID),
                token,
                uint128(amount),
                receiver,
                VENUS_cTokens[token] //
            );
    }

    function encodeCompoundV2Repay(address token, bool overrideAmount, uint amount, address receiver) internal view returns (bytes memory) {
        return
            abi.encodePacked(
                uint8(Commands.LENDING),
                uint8(2),
                uint16(COMPOUND_V2_ID),
                token,
                uint128(amount),
                receiver,
                VENUS_cTokens[token] //
            );
    }

    function encodeCompoundV2Withdraw(address token, bool overrideAmount, uint amount, address receiver) internal view returns (bytes memory) {
        return
            abi.encodePacked(
                uint8(Commands.LENDING),
                uint8(3),
                uint16(COMPOUND_V2_ID),
                token,
                uint128(amount),
                receiver,
                VENUS_cTokens[token] //
            );
    }

    function test_light_compoundV2_deposit() external {
        vm.assume(user != address(0));

        address token = USDC;
        uint256 amount = 100.0e6;
        deal(token, user, amount);

        vm.prank(user);
        IERC20All(token).approve(address(oneDV2), type(uint).max);

        bytes memory transferTo = transferIn(
            token,
            address(oneDV2),
            amount //
        );

        bytes memory d = encodeCompoundV2Deposit(token, false, amount, user);

        vm.prank(user);
        oneDV2.deltaCompose(abi.encodePacked(transferTo, d));
    }

    function test_light_compoundV2_borrow() external {
        vm.assume(user != address(0));

        address depositToken = WETH;
        address token = USDC;
        address comptroller = VENUS_COMPTROLLER;

        uint256 amount = 1.0e18;
        deal(token, user, amount);

        depositToCompoundV2(depositToken, user, amount, comptroller);

        vm.prank(user);
        IERC20All(comptroller).updateDelegate(address(oneDV2), true);

        uint256 amountToBorrow = 10.0e6;
        bytes memory d = encodeCompoundV2Borrow(token, false, amountToBorrow, user);

        vm.prank(user);
        oneDV2.deltaCompose(d);
    }

    function test_light_compoundV2_withdraw() external {
        vm.assume(user != address(0));

        address token = USDC;
        address comptroller = VENUS_COMPTROLLER;
        uint256 amount = 100.0e6;
        deal(token, user, amount);

        depositToCompoundV2(token, user, amount, comptroller);

        vm.prank(user);
        IERC20All(VENUS_cTokens[token]).approve(address(oneDV2), type(uint).max);

        uint256 amountToBorrow = 10.0e6;
        bytes memory d = encodeCompoundV2Withdraw(token, false, amountToBorrow, user);

        vm.prank(user);
        oneDV2.deltaCompose(d);
    }

    function test_light_compoundV2_repay() external {
        vm.assume(user != address(0));

        address depositToken = WETH;
        address token = USDC;
        address comptroller = VENUS_COMPTROLLER;

        uint256 amount = 1.0e18;
        deal(token, user, amount);

        depositToCompoundV2(depositToken, user, amount, comptroller);

        uint256 amountToBorrow = 10.0e6;
        borrowFromCompoundV2(token, user, amountToBorrow, comptroller);

        vm.prank(user);
        IERC20All(token).approve(address(oneDV2), type(uint).max);

        uint256 amountToRepay = 7.0e6;

        bytes memory transferTo = transferIn(
            token,
            address(oneDV2),
            amountToRepay //
        );

        bytes memory d = encodeCompoundV2Repay(token, false, amountToRepay, user);

        vm.prank(user);
        oneDV2.deltaCompose(abi.encodePacked(transferTo, d));
    }

    function depositToCompoundV2(address token, address userAddress, uint amount, address comptroller) internal {
        deal(token, userAddress, amount);

        address[] memory cToken = new address[](1);
        cToken[0] = VENUS_cTokens[token];

        vm.prank(userAddress);
        IERC20All(comptroller).enterMarkets(cToken);

        vm.prank(userAddress);
        IERC20All(token).approve(address(oneDV2), type(uint).max);

        bytes memory transferTo = transferIn(
            token,
            address(oneDV2),
            amount //
        );

        bytes memory d = encodeCompoundV2Deposit(token, false, amount, userAddress);

        vm.prank(userAddress);
        oneDV2.deltaCompose(abi.encodePacked(transferTo, d));
    }

    function borrowFromCompoundV2(address token, address userAddress, uint amountToBorrow, address comptroller) internal {
        vm.prank(userAddress);
        IERC20All(comptroller).updateDelegate(address(oneDV2), true);

        bytes memory d = encodeCompoundV2Borrow(token, false, amountToBorrow, userAddress);

        vm.prank(userAddress);
        oneDV2.deltaCompose(d);
    }

    // 0x238d6579
    // 0000000000000000000000004200000000000000000000000000000000000006
    // 0000000000000000000000004200000000000000000000000000000000000007
    // 0000000000000000000000004200000000000000000000000000000000000008
    // 0000000000000000000000004200000000000000000000000000000000000009
    // 0000000000000000000000000000000000000000000000000bef55718ad60000
    // 0000000000000000000000000000000000000000000000000000000000084cea
    // 000000000000000000000000937ce2d6c488b361825d2db5e8a70e26d48afed5
    // 0000000000000000000000000000000000000000000000000000000000000100
    // 0000000000000000000000000000000000000000000000000000000000000038
    // 220000000000000000000000000000000000000000937ce2d6c488b361825d2d
    // b5e8a70e26d48afed5020000000000000000000000084cea0000000000000000
}
