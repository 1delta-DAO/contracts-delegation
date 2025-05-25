// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {BaseTest} from "test/shared/BaseTest.sol";
import {Chains, Tokens, Lenders} from "test/data/LenderRegistry.sol";
import "test/composer/utils/CalldataLib.sol";
import {IERC20All} from "test/shared/interfaces/IERC20All.sol";
import {ComposerPlugin, IComposerLike} from "plugins/ComposerPlugin.sol";
import {console} from "forge-std/console.sol";
import {IChain} from "test/shared/chains/ChainInitializer.sol";
import {StringUtils} from "test/composer/calldata/StringUtils.sol";

contract DirectLendingExpectedOutputGen is BaseTest {
    using StringUtils for bytes;

    IComposerLike internal TEST_COMPOSER;

    // Test constants matching TypeScript
    address internal constant TEST_RECEIVER = 0x1De17a0000000000000000000000000000003333;
    address internal TEST_COMPOSER_ADDRESS;
    uint256 internal constant TEST_AMOUNT = 1000e6; // 1000 USDT (6 decimals)
    uint256 internal constant TEST_AMOUNT_ETH = 1e18; // 1 ETH in wei

    // Pool addresses (from test data)
    address internal AAVE_V3_POOL;
    address internal AAVE_V2_POOL;

    address internal USDT;
    address internal WETH;
    address internal WPOL;

    address internal aUSDT;
    address internal aWETH;
    address internal aWPOL;

    address internal vUSDT;
    address internal vWETH;
    address internal vWPOL;

    // Quick action types matching TypeScript
    enum QuickActionType {
        Deposit,
        Withdraw,
        Borrow,
        Repay
    }

    // Lender groups matching TypeScript
    enum LenderGroups {
        AaveV2,
        AaveV3,
        CompoundV2,
        CompoundV3,
        MorphoBlue
    }

    // Aave interest modes
    enum AaveInterestMode {
        NONE,
        STABLE,
        VARIABLE
    }

    // Transfer types
    enum TransferToLenderType {
        Amount,
        UserBalance,
        ContractBalance
    }

    // Lending operation structure
    struct LendingOperation {
        address asset;
        address lender;
        uint256 amount;
        QuickActionType actionType;
        address receiver;
        bool isAll;
        bool inIsNative;
        bool outIsNative;
        address composerAddress;
        LenderGroups lenderGroup;
        AaveInterestMode aaveBorrowMode;
        bool hasPermitData;
    }

    // Morpho consts
    bytes internal constant MORPHO_MARKET = hex"7506b33817b57f686e37b87b5d4c5c93fdef4cffd21bbf9291f18b2f29ab0550";
    address internal constant MORPHO_BLUE = 0x1bF0c2541F820E775182832f06c0B7Fc27A25f67;

    struct MorphoParams {
        bytes market;
        bool isShares;
        address morphoB;
        bytes data;
        uint256 pId;
        bool unsafeRepayment;
    }

    MorphoParams morphoParams =
        MorphoParams({market: MORPHO_MARKET, isShares: false, morphoB: MORPHO_BLUE, data: hex"", pId: 0, unsafeRepayment: false});

    bytes internal depositAaveV3UsdtOutput;
    bytes internal depositAaveV3NativeOutput;
    bytes internal withdrawAaveV3UsdtOutput;
    bytes internal withdrawAaveV3NativeOutput;
    bytes internal borrowAaveV3UsdtOutput;
    bytes internal repayAaveV3UsdtOutput;
    bytes internal repayAllAaveV3UsdtOutput;
    bytes internal depositCompoundV2UsdtOutput;
    bytes internal depositCompoundV3UsdtOutput;
    bytes internal depositMorphoBlueUsdtOutput;

    function setUp() public virtual {
        _init(Chains.POLYGON_MAINNET, 0, false);

        TEST_COMPOSER = ComposerPlugin.getComposer(Chains.POLYGON_MAINNET);
        TEST_COMPOSER_ADDRESS = address(TEST_COMPOSER);

        USDT = chain.getTokenAddress(Tokens.USDT);
        WETH = chain.getTokenAddress(Tokens.WETH);
        WPOL = chain.getTokenAddress(Tokens.WPOL);

        aUSDT = chain.getLendingTokens(USDT, Lenders.AAVE_V3).collateral;
        aWETH = chain.getLendingTokens(WETH, Lenders.AAVE_V3).collateral;
        aWPOL = chain.getLendingTokens(WPOL, Lenders.AAVE_V3).collateral;

        vUSDT = chain.getLendingTokens(USDT, Lenders.AAVE_V3).debt;
        vWETH = chain.getLendingTokens(WETH, Lenders.AAVE_V3).debt;
        vWPOL = chain.getLendingTokens(WPOL, Lenders.AAVE_V3).debt;

        AAVE_V3_POOL = chain.getLendingController(Lenders.AAVE_V3);
        AAVE_V2_POOL = chain.getLendingController(Lenders.AAVE_V2);
    }

    function createBaseLendingOperation(
        QuickActionType actionType,
        LenderGroups lenderGroup,
        address lender,
        uint256 amount,
        address asset,
        bool inIsNative,
        bool outIsNative,
        bool isAll
    )
        internal
        returns (LendingOperation memory)
    {
        return LendingOperation({
            asset: asset,
            lender: lender,
            amount: amount,
            actionType: actionType,
            receiver: TEST_RECEIVER,
            isAll: isAll,
            inIsNative: inIsNative,
            outIsNative: outIsNative,
            composerAddress: TEST_COMPOSER_ADDRESS,
            lenderGroup: lenderGroup,
            aaveBorrowMode: AaveInterestMode.VARIABLE,
            hasPermitData: false
        });
    }

    function createUsdtDepositAaveV3() internal returns (bytes memory) {
        bytes memory permitCall = hex"";
        bytes memory transferCall = CalldataLib.encodeTransferIn(USDT, TEST_COMPOSER_ADDRESS, TEST_AMOUNT);
        bytes memory depositCall = CalldataLib.encodeAaveDeposit(USDT, TEST_AMOUNT, TEST_RECEIVER, AAVE_V3_POOL);
        return abi.encodePacked(permitCall, transferCall, depositCall);
    }

    function createNativeDepositAaveV3() internal returns (bytes memory) {
        bytes memory permitCall = hex"";
        bytes memory transferCall = CalldataLib.encodeWrap(TEST_AMOUNT_ETH, TEST_COMPOSER_ADDRESS);
        bytes memory depositCall = CalldataLib.encodeAaveDeposit(WPOL, TEST_AMOUNT_ETH, TEST_RECEIVER, AAVE_V3_POOL);
        return abi.encodePacked(permitCall, transferCall, depositCall);
    }

    function createUsdtWithdrawAaveV3() internal returns (bytes memory) {
        bytes memory permitCall = hex""; // Simplified
        bytes memory withdrawCall = CalldataLib.encodeAaveWithdraw(USDT, TEST_AMOUNT, TEST_COMPOSER_ADDRESS, aUSDT, AAVE_V3_POOL);
        bytes memory transferCall = CalldataLib.encodeSweep(USDT, TEST_RECEIVER, TEST_AMOUNT, SweepType.AMOUNT);
        return abi.encodePacked(permitCall, withdrawCall, transferCall);
    }

    function createNativeWithdrawAaveV3() internal returns (bytes memory) {
        bytes memory permitCall = hex""; // Simplified
        bytes memory withdrawCall = CalldataLib.encodeAaveWithdraw(WPOL, TEST_AMOUNT_ETH, TEST_RECEIVER, aWPOL, AAVE_V3_POOL);
        bytes memory transferCall = CalldataLib.encodeUnwrap(WPOL, TEST_RECEIVER, TEST_AMOUNT_ETH, SweepType.AMOUNT);
        return abi.encodePacked(permitCall, withdrawCall, transferCall);
    }

    function createUsdtBorrowAaveV3() internal returns (bytes memory) {
        bytes memory permitCall = hex""; // Simplified
        bytes memory borrowCall = CalldataLib.encodeAaveBorrow(USDT, TEST_AMOUNT, TEST_COMPOSER_ADDRESS, 2, AAVE_V3_POOL);
        bytes memory transferCall = CalldataLib.encodeSweep(USDT, TEST_RECEIVER, TEST_AMOUNT, SweepType.AMOUNT);
        return abi.encodePacked(permitCall, borrowCall, transferCall);
    }

    function createUsdtRepayAaveV3() internal returns (bytes memory) {
        bytes memory permitCall = hex""; // Simplified
        bytes memory transferCall = CalldataLib.encodeTransferIn(USDT, TEST_COMPOSER_ADDRESS, TEST_AMOUNT);
        bytes memory repayCall = CalldataLib.encodeAaveRepay(USDT, TEST_AMOUNT, TEST_RECEIVER, 2, vUSDT, AAVE_V3_POOL);
        return abi.encodePacked(permitCall, transferCall, repayCall);
    }

    function createUsdtRepayAllAaveV3() internal returns (bytes memory) {
        bytes memory permitCall = hex""; // Simplified
        bytes memory transferCall = CalldataLib.encodeTransferIn(USDT, TEST_COMPOSER_ADDRESS, TEST_AMOUNT);
        bytes memory repayCall = CalldataLib.encodeAaveRepay(USDT, TEST_AMOUNT, TEST_RECEIVER, 2, vUSDT, AAVE_V3_POOL);
        bytes memory sweepCall = CalldataLib.encodeSweep(USDT, TEST_RECEIVER, 0, SweepType.VALIDATE);
        return abi.encodePacked(permitCall, transferCall, repayCall, sweepCall);
    }

    function createUsdtDepositCompoundV2() internal returns (bytes memory) {
        bytes memory permitCall = hex"";
        bytes memory transferCall = CalldataLib.encodeTransferIn(USDT, TEST_COMPOSER_ADDRESS, TEST_AMOUNT);
        bytes memory depositCall =
            CalldataLib.encodeCompoundV2Deposit(USDT, TEST_AMOUNT, TEST_RECEIVER, chain.getLendingTokens(USDT, Lenders.VENUS).collateral);
        return abi.encodePacked(permitCall, transferCall, depositCall);
    }

    function createUsdtDepositCompoundV3() internal returns (bytes memory) {
        bytes memory permitCall = hex"";
        bytes memory transferCall = CalldataLib.encodeTransferIn(USDT, TEST_COMPOSER_ADDRESS, TEST_AMOUNT);
        bytes memory depositCall =
            CalldataLib.encodeCompoundV3Deposit(USDT, TEST_AMOUNT, TEST_RECEIVER, chain.getLendingController(Lenders.COMPOUND_V3_USDT));
        return abi.encodePacked(permitCall, transferCall, depositCall);
    }

    function createUsdtDepositMorphoBlue() internal returns (bytes memory) {
        bytes memory permitCall = CalldataLib.encodePermit2TransferFrom(USDT, TEST_COMPOSER_ADDRESS, TEST_AMOUNT);
        bytes memory depositCall = CalldataLib.encodeMorphoDeposit(
            morphoParams.market, morphoParams.isShares, TEST_AMOUNT, TEST_RECEIVER, morphoParams.data, morphoParams.morphoB, morphoParams.pId
        );
        return abi.encodePacked(permitCall, depositCall);
    }

    function test_generate_deposit_aave_v3_usdt() public {
        depositAaveV3UsdtOutput = createUsdtDepositAaveV3();
    }

    function test_generate_deposit_aave_v3_native() public {
        depositAaveV3NativeOutput = createNativeDepositAaveV3();
    }

    function test_generate_withdraw_aave_v3_usdt() public {
        withdrawAaveV3UsdtOutput = createUsdtWithdrawAaveV3();
    }

    function test_generate_withdraw_aave_v3_native() public {
        withdrawAaveV3NativeOutput = createNativeWithdrawAaveV3();
    }

    function test_generate_borrow_aave_v3_usdt() public {
        borrowAaveV3UsdtOutput = createUsdtBorrowAaveV3();
    }

    function test_generate_repay_aave_v3_usdt() public {
        repayAaveV3UsdtOutput = createUsdtRepayAaveV3();
    }

    function test_generate_repay_all_aave_v3_usdt() public {
        repayAllAaveV3UsdtOutput = createUsdtRepayAllAaveV3();
    }

    function test_generate_deposit_compound_v2_usdt() public {
        depositCompoundV2UsdtOutput = createUsdtDepositCompoundV2();
    }

    function test_generate_deposit_compound_v3_usdt() public {
        depositCompoundV3UsdtOutput = createUsdtDepositCompoundV3();
    }

    function test_generate_deposit_morpho_blue_usdt() public {
        depositMorphoBlueUsdtOutput = createUsdtDepositMorphoBlue();
    }

    function test_generate_typescript_structure() public {
        test_generate_deposit_aave_v3_usdt();
        test_generate_deposit_aave_v3_native();
        test_generate_withdraw_aave_v3_usdt();
        test_generate_withdraw_aave_v3_native();
        test_generate_borrow_aave_v3_usdt();
        test_generate_repay_aave_v3_usdt();
        test_generate_repay_all_aave_v3_usdt();
        test_generate_deposit_compound_v2_usdt();
        test_generate_deposit_compound_v3_usdt();
        test_generate_deposit_morpho_blue_usdt();

        console.log("const expectedDirectLendingOutputs = {");
        console.log("  deposit_aave_v3_usdt: {");
        console.log("    calldata: '%s' as Hex,", depositAaveV3UsdtOutput.toHexString());
        console.log("    value: undefined,");
        console.log("  },");
        console.log("  deposit_aave_v3_native: {");
        console.log("    calldata: '%s' as Hex,", depositAaveV3NativeOutput.toHexString());
        console.log("    value: '%s',", TEST_AMOUNT_ETH);
        console.log("  },");
        console.log("  withdraw_aave_v3_usdt: {");
        console.log("    calldata: '%s' as Hex,", withdrawAaveV3UsdtOutput.toHexString());
        console.log("    value: '0',");
        console.log("  },");
        console.log("  withdraw_aave_v3_native: {");
        console.log("    calldata: '%s' as Hex,", withdrawAaveV3NativeOutput.toHexString());
        console.log("    value: '0',");
        console.log("  },");
        console.log("  borrow_aave_v3_usdt: {");
        console.log("    calldata: '%s' as Hex,", borrowAaveV3UsdtOutput.toHexString());
        console.log("    value: '0',");
        console.log("  },");
        console.log("  repay_aave_v3_usdt: {");
        console.log("    calldata: '%s' as Hex,", repayAaveV3UsdtOutput.toHexString());
        console.log("    value: undefined,");
        console.log("  },");
        console.log("  repay_all_aave_v3_usdt: {");
        console.log("    calldata: '%s' as Hex,", repayAllAaveV3UsdtOutput.toHexString());
        console.log("    value: undefined,");
        console.log("  },");
        console.log("  deposit_compound_v2_usdt: {");
        console.log("    calldata: '%s' as Hex,", depositCompoundV2UsdtOutput.toHexString());
        console.log("    value: undefined,");
        console.log("  },");
        console.log("  deposit_compound_v3_usdt: {");
        console.log("    calldata: '%s' as Hex,", depositCompoundV3UsdtOutput.toHexString());
        console.log("    value: undefined,");
        console.log("  },");
        console.log("  deposit_morpho_blue_usdt: {");
        console.log("    calldata: '%s' as Hex,", depositMorphoBlueUsdtOutput.toHexString());
        console.log("    value: undefined,");
        console.log("  },");
        console.log("}");

        console.log("");
        console.log("// Test constants matching Solidity:");
        console.log("const TEST_RECEIVER = '%s' as Address", TEST_RECEIVER);
        console.log("const TEST_COMPOSER = '%s' as Address", TEST_COMPOSER_ADDRESS);
        console.log("const TEST_AMOUNT = '%s'", TEST_AMOUNT);
        console.log("const TEST_AMOUNT_ETH = '%s'", TEST_AMOUNT_ETH);
        console.log("const USDT = '%s' as Address", USDT);
        console.log("const WETH = '%s' as Address", WETH);
        console.log("const WPOL = '%s' as Address", WPOL);
        console.log("const MORPHO_BLUE = '%s' as Address", MORPHO_BLUE);
        console.log("const MORPHO_MARKET = '%s' as Hex", MORPHO_MARKET.toHexString());
    }
}
