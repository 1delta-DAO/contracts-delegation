// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {IERC20All} from "test/shared/interfaces/IERC20All.sol";
import {BaseTest} from "test/shared/BaseTest.sol";
import {Chains, Tokens, Lenders} from "test/data/LenderRegistry.sol";
import "test/composer/utils/CalldataLib.sol";
import {console} from "forge-std/console.sol";

import {ComposerValidator} from "contracts/1delta/composer/validator/ComposerValidator.sol";
import {AddressWhitelistManager} from "contracts/1delta/composer/validator/AddressWhitelistManager.sol";
import {ComposerCommands, LenderOps, LenderIds} from "contracts/1delta/composer/enums/DeltaEnums.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract ComposerValidatorTest is BaseTest {
    ComposerValidator public validator;
    AddressWhitelistManager public whitelistManager;

    address public owner;
    address public aaveV3Pool;
    address public validAaveV2Pool;
    address public compoundV3Comet;
    address public validCompoundV2CToken;
    address public morpho;

    address public invalidPool = address(0xDeaD500100000000000000000000000000000000);

    uint256 internal constant forkBlock = 0;

    function setUp() public virtual {
        string memory chainName = Chains.BASE;
        _init(chainName, forkBlock, true);

        owner = address(this);

        aaveV3Pool = chain.getLendingController(Lenders.AAVE_V3);
        compoundV3Comet = chain.getLendingController(Lenders.COMPOUND_V3_USDC);
        morpho = address(0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb);

        AddressWhitelistManager implementation = new AddressWhitelistManager();
        bytes memory initData = abi.encodeWithSelector(AddressWhitelistManager.initialize.selector, owner);
        ERC1967Proxy proxy = new ERC1967Proxy(address(implementation), initData);
        whitelistManager = AddressWhitelistManager(address(proxy));

        validator = new ComposerValidator(address(whitelistManager));

        whitelistManager.setAaveV3PoolWhitelist(aaveV3Pool, true);
        whitelistManager.setCompoundV3CometWhitelist(compoundV3Comet, true);
        whitelistManager.setMorphoWhitelist(morpho, true);
    }

    function test_validator_external_call_valid() external {
        address target = address(0x1111111111111111111111111111111111111111);
        uint256 value = 0;
        bytes memory data = abi.encodeWithSignature("balanceOf(address)", user);

        bytes memory calldataBytes = CalldataLib.encodeExternalCall(target, value, false, data);

        (bool isValid, string memory errorMessage, uint256 failedAtOffset) = validator.validateComposerCalldata(calldataBytes);

        assertTrue(isValid, errorMessage);
        assertEq(bytes(errorMessage).length, 0);
    }

    function test_validator_external_call_invalid_permit2() external {
        address permit2 = 0x000000000022D473030F116dDEE9F6B43aC78BA3;
        uint256 value = 0;
        bytes memory data = abi.encodeWithSignature("permitTransferFrom(bytes,bytes,address)", "", "", user);

        bytes memory calldataBytes = CalldataLib.encodeExternalCall(permit2, value, false, data);
        calldataBytes = CalldataLib.encodeExternalCall(address(0xdEad000000000000000000000000000000000000), value, false, calldataBytes);

        (bool isValid, string memory errorMessage, uint256 failedAtOffset) = validator.validateComposerCalldata(calldataBytes);

        assertFalse(isValid);
        assertEq(errorMessage, "Permit2 calls forbidden");
    }

    function test_validator_external_call_invalid_transferFrom() external {
        address target = address(0x1111111111111111111111111111111111111111);
        uint256 value = 0;
        bytes memory data = abi.encodeWithSignature("transferFrom(address,address,uint256)", user, address(this), 100);

        bytes memory calldataBytes = CalldataLib.encodeExternalCall(target, value, false, data);

        (bool isValid, string memory errorMessage, uint256 failedAtOffset) = validator.validateComposerCalldata(calldataBytes);

        assertFalse(isValid);
        assertEq(errorMessage, "transferFrom calls forbidden");
    }

    function test_validator_external_call_data_too_long() external {
        address target = address(0x1111111111111111111111111111111111111111);
        uint256 value = 0;
        bytes memory data = new bytes(10001);

        bytes memory calldataBytes = CalldataLib.encodeExternalCall(target, value, false, data);

        (bool isValid, string memory errorMessage, uint256 failedAtOffset) = validator.validateComposerCalldata(calldataBytes);

        assertFalse(isValid);
        assertEq(errorMessage, "Calldata too long");
    }

    function test_validator_aave_v3_deposit_valid_whitelisted_pool() external {
        address token = chain.getTokenAddress(Tokens.USDC);
        uint256 amount = 100e6;

        bytes memory calldataBytes = CalldataLib.encodeAaveDeposit(token, amount, user, aaveV3Pool);

        (bool isValid, string memory errorMessage, uint256 failedAtOffset) = validator.validateComposerCalldata(calldataBytes);

        assertTrue(isValid, errorMessage);
        assertEq(bytes(errorMessage).length, 0);
    }

    function test_validator_aave_v3_deposit_invalid_non_whitelisted_pool() external {
        address token = chain.getTokenAddress(Tokens.USDC);
        uint256 amount = 100e6;

        bytes memory calldataBytes = CalldataLib.encodeAaveDeposit(token, amount, user, invalidPool);

        (bool isValid, string memory errorMessage, uint256 failedAtOffset) = validator.validateComposerCalldata(calldataBytes);

        assertFalse(isValid);
        assertEq(errorMessage, "Aave V3 pool not whitelisted");
    }

    function test_validator_aave_v3_borrow_valid_whitelisted_pool() external {
        address token = chain.getTokenAddress(Tokens.USDC);
        uint256 amount = 50e6;
        uint256 mode = 2;

        bytes memory calldataBytes = CalldataLib.encodeAaveBorrow(token, amount, user, mode, aaveV3Pool);

        (bool isValid, string memory errorMessage, uint256 failedAtOffset) = validator.validateComposerCalldata(calldataBytes);

        assertTrue(isValid, errorMessage);
        assertEq(bytes(errorMessage).length, 0);
    }

    function test_validator_aave_v3_borrow_invalid_non_whitelisted_pool() external {
        address token = chain.getTokenAddress(Tokens.USDC);
        uint256 amount = 50e6;
        uint256 mode = 2;

        bytes memory calldataBytes = CalldataLib.encodeAaveBorrow(token, amount, user, mode, invalidPool);

        (bool isValid, string memory errorMessage, uint256 failedAtOffset) = validator.validateComposerCalldata(calldataBytes);

        assertFalse(isValid);
        assertEq(errorMessage, "Aave V3 pool not whitelisted");
    }

    function test_validator_compound_v3_deposit_valid_whitelisted_comet() external {
        address token = chain.getTokenAddress(Tokens.USDC);
        uint256 amount = 100e6;

        bytes memory calldataBytes = CalldataLib.encodeCompoundV3Deposit(token, amount, user, compoundV3Comet);

        (bool isValid, string memory errorMessage, uint256 failedAtOffset) = validator.validateComposerCalldata(calldataBytes);

        assertTrue(isValid, errorMessage);
        assertEq(bytes(errorMessage).length, 0);
    }

    function test_validator_compound_v3_deposit_invalid_non_whitelisted_comet() external {
        address token = chain.getTokenAddress(Tokens.USDC);
        uint256 amount = 100e6;

        bytes memory calldataBytes = CalldataLib.encodeCompoundV3Deposit(token, amount, user, invalidPool);

        (bool isValid, string memory errorMessage, uint256 failedAtOffset) = validator.validateComposerCalldata(calldataBytes);

        assertFalse(isValid);
        assertEq(errorMessage, "Compound V3 comet not whitelisted");
    }

    function test_validator_compound_v3_borrow_valid_whitelisted_comet() external {
        address token = chain.getTokenAddress(Tokens.USDC);
        uint256 amount = 50e6;

        bytes memory calldataBytes = CalldataLib.encodeCompoundV3Borrow(token, amount, user, compoundV3Comet);

        (bool isValid, string memory errorMessage, uint256 failedAtOffset) = validator.validateComposerCalldata(calldataBytes);

        assertTrue(isValid, errorMessage);
        assertEq(bytes(errorMessage).length, 0);
    }

    function test_validator_compound_v3_borrow_invalid_non_whitelisted_comet() external {
        address token = chain.getTokenAddress(Tokens.USDC);
        uint256 amount = 50e6;

        bytes memory calldataBytes = CalldataLib.encodeCompoundV3Borrow(token, amount, user, invalidPool);

        (bool isValid, string memory errorMessage, uint256 failedAtOffset) = validator.validateComposerCalldata(calldataBytes);

        assertFalse(isValid);
        assertEq(errorMessage, "Compound V3 comet not whitelisted");
    }

    function test_validator_morpho_borrow_valid_whitelisted_morpho() external {
        address loanToken = chain.getTokenAddress(Tokens.USDC);
        address collateralToken = chain.getTokenAddress(Tokens.WETH);
        address oracle = address(0x2222222222222222222222222222222222222222);
        address irm = address(0x3333333333333333333333333333333333333333);
        uint256 lltv = 800000000000000000; // 80%
        uint256 amount = 50e6;

        bytes memory marketData = CalldataLib.encodeMorphoMarket(loanToken, collateralToken, oracle, irm, lltv);
        bytes memory calldataBytes = CalldataLib.encodeMorphoBorrow(marketData, false, amount, user, morpho);

        (bool isValid, string memory errorMessage, uint256 failedAtOffset) = validator.validateComposerCalldata(calldataBytes);

        assertTrue(isValid, errorMessage);
        assertEq(bytes(errorMessage).length, 0);
    }

    function test_validator_morpho_borrow_invalid_non_whitelisted_morpho() external {
        address loanToken = chain.getTokenAddress(Tokens.USDC);
        address collateralToken = chain.getTokenAddress(Tokens.WETH);
        address oracle = address(0x2222222222222222222222222222222222222222);
        address irm = address(0x3333333333333333333333333333333333333333);
        uint256 lltv = 800000000000000000; // 80%
        uint256 amount = 50e6;

        bytes memory marketData = CalldataLib.encodeMorphoMarket(loanToken, collateralToken, oracle, irm, lltv);
        bytes memory calldataBytes = CalldataLib.encodeMorphoBorrow(marketData, false, amount, user, invalidPool);

        (bool isValid, string memory errorMessage, uint256 failedAtOffset) = validator.validateComposerCalldata(calldataBytes);

        assertFalse(isValid);
        assertEq(errorMessage, "Morpho not whitelisted");
    }

    function test_validator_invalid_lending_operation() external {
        bytes memory calldataBytes = abi.encodePacked(
            uint8(ComposerCommands.LENDING),
            uint8(10), // Invalid operation > 5
            uint16(LenderIds.UP_TO_AAVE_V3 - 1)
        );

        (bool isValid, string memory errorMessage, uint256 failedAtOffset) = validator.validateComposerCalldata(calldataBytes);

        assertFalse(isValid);
        assertEq(errorMessage, "Invalid lending operation");
    }

    function test_validator_invalid_lender_id() external {
        bytes memory calldataBytes = abi.encodePacked(
            uint8(ComposerCommands.LENDING),
            uint8(LenderOps.DEPOSIT),
            uint16(LenderIds.UP_TO_MORPHO) // Invalid lender ID
        );

        (bool isValid, string memory errorMessage, uint256 failedAtOffset) = validator.validateComposerCalldata(calldataBytes);

        assertFalse(isValid);
        assertEq(errorMessage, "Invalid lender ID");
    }

    function test_validator_invalid_zero_addresses() external {
        // Test with zero addresses that should fail validation
        address token = address(0);
        uint256 amount = 100e6;

        bytes memory calldataBytes = CalldataLib.encodeAaveDeposit(token, amount, user, aaveV3Pool);

        (bool isValid, string memory errorMessage, uint256 failedAtOffset) = validator.validateComposerCalldata(calldataBytes);

        assertFalse(isValid);
        assertEq(errorMessage, "Invalid underlying address");
    }

    function test_validator_whitelist_management() external {
        address newPool = address(0x9999999999999999999999999999999999999999);

        assertFalse(whitelistManager.isAaveV3PoolWhitelisted(newPool));

        whitelistManager.setAaveV3PoolWhitelist(newPool, true);
        assertTrue(whitelistManager.isAaveV3PoolWhitelisted(newPool));

        whitelistManager.setAaveV3PoolWhitelist(newPool, false);
        assertFalse(whitelistManager.isAaveV3PoolWhitelisted(newPool));
    }

    function test_validator_ownership_transfer() external {
        address newOwner = address(0x1111111111111111111111111111111111111111);

        whitelistManager.transferOwnership(newOwner);
        assertEq(whitelistManager.owner(), newOwner);

        vm.prank(newOwner);
        whitelistManager.setAaveV3PoolWhitelist(address(0x123), true);

        vm.expectRevert("Not owner");
        whitelistManager.setAaveV3PoolWhitelist(address(0x456), true);
    }

    function test_validator_combined_operations() external {
        address token = chain.getTokenAddress(Tokens.USDC);
        uint256 amount = 100e6;

        bytes memory transferIn = CalldataLib.encodeTransferIn(token, address(this), amount);
        bytes memory aaveDeposit = CalldataLib.encodeAaveDeposit(token, amount, user, aaveV3Pool);
        bytes memory combinedCalldata = abi.encodePacked(transferIn, aaveDeposit);

        (bool isValid, string memory errorMessage, uint256 failedAtOffset) = validator.validateComposerCalldata(combinedCalldata);

        assertTrue(isValid, errorMessage);
        assertEq(bytes(errorMessage).length, 0);
    }

    function test_validator_try_external_call_valid() external {
        address target = address(0x1111111111111111111111111111111111111111);
        uint256 value = 0;
        bytes memory data = abi.encodeWithSignature("balanceOf(address)", user);
        bytes memory catchData = abi.encodePacked(uint8(ComposerCommands.TRANSFERS), uint8(0)); // Simple transfer operation

        bytes memory calldataBytes = CalldataLib.encodeTryExternalCall(target, value, false, false, data, catchData);

        (bool isValid, string memory errorMessage, uint256 failedAtOffset) = validator.validateComposerCalldata(calldataBytes);

        assertTrue(isValid, errorMessage);
        assertEq(bytes(errorMessage).length, 0);
    }
}
