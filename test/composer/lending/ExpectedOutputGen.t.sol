// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {BaseTest} from "test/shared/BaseTest.sol";
import {Chains, Tokens, Lenders} from "test/data/LenderRegistry.sol";
import "contracts/utils/CalldataLib.sol";
import {IERC20All} from "test/shared/interfaces/IERC20All.sol";
import {ComposerPlugin, IComposerLike} from "plugins/ComposerPlugin.sol";
import {console} from "forge-std/console.sol";
import {IChain} from "test/shared/chains/ChainInitializer.sol";

// solhint-disable no-console

contract ExpectedOutputGen is BaseTest {
    address internal constant TEST_RECEIVER = 0x1De17a0000000000000000000000000000003333;
    uint256 internal constant TEST_AMOUNT = 1000e6;

    address internal USDC;
    address internal WETH;

    address internal AAVE_V2_POOL;
    address internal AAVE_V3_POOL;

    address internal COMPOUND_V2_CTOKEN;
    address internal COMPOUND_V3_COMET_USDC;
    address internal COMPOUND_V3_COMET_WETH;

    string internal aaveV2Lender = Lenders.AAVE_V2;
    string internal aaveV3Lender = Lenders.AAVE_V3;
    string internal compoundV2Lender = Lenders.VENUS;
    string internal compoundV3Lender_USDC = Lenders.COMPOUND_V3_USDC;
    string internal compoundV3Lender_WETH = Lenders.COMPOUND_V3_WETH;

    // Store outputs for TypeScript generation
    bytes internal aaveV2DepositData;
    bytes internal aaveV3DepositData;
    bytes internal compoundV2DepositData;
    bytes internal compoundV3DepositData;

    bytes internal aaveV2WithdrawData;
    bytes internal aaveV3WithdrawData;
    bytes internal compoundV2WithdrawData;
    bytes internal compoundV3WithdrawData;

    bytes internal aaveV2BorrowData;
    bytes internal aaveV3BorrowData;
    bytes internal compoundV2BorrowData;
    bytes internal compoundV3BorrowData;

    bytes internal aaveV2RepayData;
    bytes internal aaveV3RepayData;
    bytes internal compoundV2RepayData;
    bytes internal compoundV3RepayData;

    IChain internal polygon;
    address internal polygonUSDT;

    function setUp() public virtual {
        _init(Chains.ETHEREUM_MAINNET, 0, false);

        polygon = chainFactory.getChain(Chains.POLYGON_MAINNET);
        polygonUSDT = polygon.getTokenAddress(Tokens.USDT);

        USDC = chain.getTokenAddress(Tokens.USDC);
        WETH = chain.getTokenAddress(Tokens.WETH);

        AAVE_V2_POOL = polygon.getLendingController(aaveV2Lender);
        AAVE_V3_POOL = chain.getLendingController(aaveV3Lender);
        COMPOUND_V2_CTOKEN = chain.getLendingTokens(USDC, compoundV2Lender).collateral;
        COMPOUND_V3_COMET_USDC = chain.getLendingController(compoundV3Lender_USDC);
        COMPOUND_V3_COMET_WETH = chain.getLendingController(compoundV3Lender_WETH);
    }

    function test_unit_lending_expectedOutputs_generate_deposit() public {
        aaveV2DepositData = CalldataLib.encodeAaveV2Deposit(polygonUSDT, TEST_AMOUNT, TEST_RECEIVER, AAVE_V2_POOL);

        aaveV3DepositData = CalldataLib.encodeAaveDeposit(USDC, TEST_AMOUNT, TEST_RECEIVER, AAVE_V3_POOL);

        compoundV2DepositData =
            CalldataLib.encodeCompoundV2Deposit(USDC, TEST_AMOUNT, TEST_RECEIVER, COMPOUND_V2_CTOKEN, uint8(CompoundV2Selector.MINT_BEHALF));

        compoundV3DepositData = CalldataLib.encodeCompoundV3Deposit(USDC, TEST_AMOUNT, TEST_RECEIVER, COMPOUND_V3_COMET_WETH);
    }

    function test_unit_lending_expectedOutputs_generate_withdraw() public {
        address aaveV2DebtToken = polygon.getLendingTokens(polygonUSDT, aaveV2Lender).debt;
        address aaveV3DebtToken = chain.getLendingTokens(USDC, aaveV3Lender).debt;

        aaveV2WithdrawData = CalldataLib.encodeAaveV2Withdraw(polygonUSDT, TEST_AMOUNT, TEST_RECEIVER, aaveV2DebtToken, AAVE_V2_POOL);

        aaveV3WithdrawData = CalldataLib.encodeAaveWithdraw(USDC, TEST_AMOUNT, TEST_RECEIVER, aaveV3DebtToken, AAVE_V3_POOL);

        compoundV2WithdrawData =
            CalldataLib.encodeCompoundV2Withdraw(USDC, TEST_AMOUNT, TEST_RECEIVER, COMPOUND_V2_CTOKEN, uint8(CompoundV2Selector.REDEEM));

        compoundV3WithdrawData = CalldataLib.encodeCompoundV3Withdraw(USDC, TEST_AMOUNT, TEST_RECEIVER, COMPOUND_V3_COMET_WETH, false);
    }

    function test_unit_lending_expectedOutputs_generate_borrow() public {
        aaveV2BorrowData = CalldataLib.encodeAaveV2Borrow(
            polygonUSDT,
            TEST_AMOUNT,
            TEST_RECEIVER,
            2, // Interest rate mode
            AAVE_V2_POOL
        );

        aaveV3BorrowData = CalldataLib.encodeAaveBorrow(
            USDC,
            TEST_AMOUNT,
            TEST_RECEIVER,
            2, // Interest rate mode
            AAVE_V3_POOL
        );

        compoundV2BorrowData = CalldataLib.encodeCompoundV2Borrow(USDC, TEST_AMOUNT, TEST_RECEIVER, COMPOUND_V2_CTOKEN);

        compoundV3BorrowData = CalldataLib.encodeCompoundV3Borrow(USDC, TEST_AMOUNT, TEST_RECEIVER, COMPOUND_V3_COMET_USDC);
    }

    function test_unit_lending_expectedOutputs_generate_repay() public {
        address aaveV2DebtToken = polygon.getLendingTokens(polygonUSDT, aaveV2Lender).debt;
        address aaveV2StableDebtToken = polygon.getLendingTokens(polygonUSDT, aaveV2Lender).stableDebt;
        address aaveV3DebtToken = chain.getLendingTokens(USDC, aaveV3Lender).debt;

        aaveV2RepayData = CalldataLib.encodeAaveV2Repay(
            polygonUSDT,
            TEST_AMOUNT,
            TEST_RECEIVER,
            2, // Variable interest mode
            aaveV2DebtToken,
            AAVE_V2_POOL
        );

        aaveV3RepayData = CalldataLib.encodeAaveRepay(
            USDC,
            TEST_AMOUNT,
            TEST_RECEIVER,
            2, // Variable interest mode
            aaveV3DebtToken,
            AAVE_V3_POOL
        );

        compoundV2RepayData = CalldataLib.encodeCompoundV2Repay(USDC, TEST_AMOUNT, TEST_RECEIVER, COMPOUND_V2_CTOKEN);

        compoundV3RepayData = CalldataLib.encodeCompoundV3Repay(USDC, TEST_AMOUNT, TEST_RECEIVER, COMPOUND_V3_COMET_USDC);
    }

    function test_unit_lending_expectedOutputs_generate_typescript_structure() public {
        test_unit_lending_expectedOutputs_generate_deposit();
        test_unit_lending_expectedOutputs_generate_withdraw();
        test_unit_lending_expectedOutputs_generate_borrow();
        test_unit_lending_expectedOutputs_generate_repay();

        console.log("const expectedOutputs = {");

        console.log("  deposit: {");
        console.log("    aaveV2: '%s' as Hex,", toHexString(aaveV2DepositData));
        console.log("    aaveV3: '%s' as Hex,", toHexString(aaveV3DepositData));
        console.log("    compoundV2: '%s' as Hex,", toHexString(compoundV2DepositData));
        console.log("    compoundV3: '%s' as Hex,", toHexString(compoundV3DepositData));
        console.log("  },");

        console.log("  withdraw: {");
        console.log("    aaveV2: '%s' as Hex,", toHexString(aaveV2WithdrawData));
        console.log("    aaveV3: '%s' as Hex,", toHexString(aaveV3WithdrawData));
        console.log("    compoundV2: '%s' as Hex,", toHexString(compoundV2WithdrawData));
        console.log("    compoundV3: '%s' as Hex,", toHexString(compoundV3WithdrawData));
        console.log("  },");

        console.log("  borrow: {");
        console.log("    aaveV2: '%s' as Hex,", toHexString(aaveV2BorrowData));
        console.log("    aaveV3: '%s' as Hex,", toHexString(aaveV3BorrowData));
        console.log("    compoundV2: '%s' as Hex,", toHexString(compoundV2BorrowData));
        console.log("    compoundV3: '%s' as Hex,", toHexString(compoundV3BorrowData));
        console.log("    morphoBlue: '0x' as Hex,");
        console.log("  },");

        console.log("  repay: {");
        console.log("    aaveV2: '%s' as Hex,", toHexString(aaveV2RepayData));
        console.log("    aaveV3: '%s' as Hex,", toHexString(aaveV3RepayData));
        console.log("    compoundV2: '%s' as Hex,", toHexString(compoundV2RepayData));
        console.log("    compoundV3: '%s' as Hex,", toHexString(compoundV3RepayData));
        console.log("  },");

        console.log("}");
    }

    function toHexString(bytes memory data) internal pure returns (string memory) {
        bytes memory alphabet = "0123456789abcdef";
        bytes memory str = new bytes(2 + data.length * 2);
        str[0] = "0";
        str[1] = "x";
        for (uint256 i = 0; i < data.length; i++) {
            str[2 + i * 2] = alphabet[uint8(data[i] >> 4)];
            str[2 + 1 + i * 2] = alphabet[uint8(data[i] & 0x0f)];
        }
        return string(str);
    }
}
