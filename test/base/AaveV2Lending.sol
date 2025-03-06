// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {Test} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";
import {ComposerUtils, Commands} from "../shared/utils/ComposerUtils.sol";
import {MarketParams, IMorphoEverything} from "./utils/Morpho.sol";

import {OneDeltaComposerBase} from "../../contracts/1delta/modules/base/Composer.sol";
import {OneDeltaComposerLight} from "../../contracts/1delta/modules/light/Composer.sol";
import {IERC20All} from "../shared/interfaces/IERC20All.sol";
import {GRANARY_DATA_8453} from "./GRANARY_DATA_8453.sol";

/**
 * We test all morpho blue operations
 * - supply, supplyCollateral, borrow, repay, erc4646Deposit, erc4646Withdraw
 */
contract AaveLightTest is Test, ComposerUtils, GRANARY_DATA_8453 {
    uint16 internal constant GRANARY = 1000;
    OneDeltaComposerBase oneD;
    OneDeltaComposerLight oneDV2;

    address internal constant user = address(984327);

    address internal constant LBTC = 0xecAc9C5F704e954931349Da37F60E39f515c11c1;

    function setUp() public virtual {
        vm.createSelectFork({blockNumber: 26696865, urlOrAlias: "https://mainnet.base.org"});
        oneD = new OneDeltaComposerBase();
        oneDV2 = new OneDeltaComposerLight();
    }

    function encodeAaveDeposit(address token, bool overrideAmount, uint amount, address receiver) internal pure returns (bytes memory) {
        return
            abi.encodePacked(
                uint8(Commands.LENDING),
                uint8(0),
                uint16(GRANARY),
                token,
                uint128(amount),
                receiver,
                GRANARY_POOL //
            );
    }

    function encodeAaveBorrow(address token, bool overrideAmount, uint amount, address receiver, uint256 mode) internal pure returns (bytes memory) {
        return
            abi.encodePacked(
                uint8(Commands.LENDING),
                uint8(1),
                uint16(GRANARY),
                token,
                uint128(amount),
                receiver,
                uint8(mode),
                GRANARY_POOL //
            );
    }

    function encodeAaveRepay(address token, bool overrideAmount, uint amount, address receiver, uint256 mode) internal view returns (bytes memory) {
        return
            abi.encodePacked(
                uint8(Commands.LENDING),
                uint8(2),
                uint16(GRANARY),
                token,
                uint128(amount),
                receiver,
                uint8(mode),
                lendingTokens[token].vToken,
                GRANARY_POOL //
            );
    }


    function encodeAaveWithdraw(
        address token,
        bool overrideAmount,
        uint amount,
        address receiver
    ) internal view returns (bytes memory) {
        return
            abi.encodePacked(
                uint8(Commands.LENDING),
                uint8(3),
                uint16(GRANARY),
                token,
                uint128(amount),
                receiver,
                lendingTokens[token].aToken,
                GRANARY_POOL //
            );
    }

    function test_light_granary_deposit() external {
        vm.assume(user != address(0));

        address token = USDC;
        deal(token, user, 1000.0e6);
        uint256 amount = 100.0e6;

        vm.prank(user);
        IERC20All(token).approve(address(oneDV2), type(uint).max);

        bytes memory transferTo = transferIn(
            token,
            address(oneDV2),
            amount //
        );

        bytes memory d = encodeAaveDeposit(token, false, amount, user);

        vm.prank(user);
        oneDV2.deltaCompose(abi.encodePacked(transferTo, d));
    }

    function test_light_granary_borrow() external {
        vm.assume(user != address(0));

        address token = USDC;
        deal(token, user, 1000.0e6);
        uint256 amount = 100.0e6;

        depositToAave(token, user, amount);

        vm.prank(user);
        IERC20All(lendingTokens[token].vToken).approveDelegation(address(oneDV2), type(uint).max);

        uint256 amountToBorrow = 10.0e6;
        bytes memory d = encodeAaveBorrow(token, false, amountToBorrow, user, 2);

        vm.prank(user);
        oneDV2.deltaCompose(d);
    }

    function test_light_granary_withdraw() external {
        vm.assume(user != address(0));

        address token = USDC;
        deal(token, user, 1000.0e6);
        uint256 amount = 100.0e6;

        depositToAave(token, user, amount);

        vm.prank(user);
        IERC20All(lendingTokens[token].aToken).approve(address(oneDV2), type(uint).max);

        uint256 amountToBorrow = 10.0e6;
        bytes memory d = encodeAaveWithdraw(token, false, amountToBorrow, user);

        vm.prank(user);
        oneDV2.deltaCompose(d);
    }

    function test_light_granary_repay() external {
        vm.assume(user != address(0));

        address token = USDC;
        deal(token, user, 1000.0e6);
        uint256 amount = 100.0e6;

        depositToAave(token, user, amount);

        uint256 amountToBorrow = 10.0e6;
        borrowFromAave(token, user, amountToBorrow);

        vm.prank(user);
        IERC20All(token).approve(address(oneDV2), type(uint).max);

        uint256 amountToRepay = 7.0e6;


      bytes memory transferTo = transferIn(
            token,
            address(oneDV2),
            amountToRepay //
        );


        bytes memory d = encodeAaveRepay(token, false, amountToRepay, user, 2);

        vm.prank(user);
        oneDV2.deltaCompose(abi.encodePacked(transferTo, d));
    }

    function depositToAave(address token, address userAddress, uint amount) internal {
        deal(token, userAddress, 1000.0e6);

        vm.prank(userAddress);
        IERC20All(token).approve(address(oneDV2), type(uint).max);

        bytes memory transferTo = transferIn(
            token,
            address(oneDV2),
            amount //
        );

        bytes memory d = encodeAaveDeposit(token, false, amount, userAddress);

        vm.prank(userAddress);
        oneDV2.deltaCompose(abi.encodePacked(transferTo, d));
    }

    function borrowFromAave(address token, address userAddress, uint amountToBorrow) internal {
        vm.prank(userAddress);
        IERC20All(lendingTokens[token].vToken).approveDelegation(address(oneDV2), type(uint).max);

        bytes memory d = encodeAaveBorrow(token, false, amountToBorrow, userAddress, 2);

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
