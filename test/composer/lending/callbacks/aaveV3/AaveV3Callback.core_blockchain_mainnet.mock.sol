// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Chains, Lenders, Tokens} from "test/data/LenderRegistry.sol";
import {DeltaErrors} from "contracts/1delta/shared/errors/Errors.sol";
import {ComposerPlugin, IComposerLike} from "plugins/ComposerPlugin.sol";
import {CalldataLib} from "contracts/utils/CalldataLib.sol";
import {BaseTest} from "test/shared/BaseTest.sol";
import {AaveMockPool, IAavePool} from "test/mocks/AaveMockPool.sol";
import {SweepType} from "contracts/1delta/composer/enums/MiscEnums.sol";

contract AaveV3FlashLoanCallbackTest is BaseTest, DeltaErrors {
    IComposerLike oneDV2;
    AaveMockPool mockPool;

    address private AVALON;
    address private AVALON_UBTC;
    address private AVALON_OBTC;
    address private COLEND;
    address private COLEND_LSTBTC;

    address private SOLVBTC_B;
    address private USDC;
    address private STBTC;

    struct PoolCase {
        uint8 poolId;
        address poolAddr;
        address asset; // The specific asset for each pool to lend, not used in this test, can be used with chain forking
    }

    PoolCase[] validPools;

    function setUp() public virtual {
        string memory chainName = Chains.CORE_BLOCKCHAIN_MAINNET;

        // Initialize chain (for token info) with no forking
        _init(chainName, 0, false);

        getAddressFromRegistry();

        mockERC20FunctionsForAllTokens();

        populateValidPools();

        oneDV2 = ComposerPlugin.getComposer(chainName);
        mockPool = new AaveMockPool();
    }

    function test_unit_lending_flashloans_aaveV3_callback_avalonPool() public {
        // mock implementation
        replaceLendingPoolWithMock(AVALON);

        bytes memory params = CalldataLib.encodeFlashLoan(SOLVBTC_B, 1e6, AVALON, uint8(2), uint8(50), sweepCall());

        vm.prank(user);
        oneDV2.deltaCompose(params);
    }

    function test_unit_lending_flashloans_aaveV3_callback_avalon_ubtcPool() public {
        // mock implementation
        replaceLendingPoolWithMock(AVALON_UBTC);

        bytes memory params = CalldataLib.encodeFlashLoan(USDC, 1e6, AVALON_UBTC, uint8(2), uint8(59), sweepCall());

        vm.prank(user);
        oneDV2.deltaCompose(params);
    }

    function test_unit_lending_flashloans_aaveV3_callback_avalon_obtcPool() public {
        // mock implementation
        replaceLendingPoolWithMock(AVALON_OBTC);

        bytes memory params = CalldataLib.encodeFlashLoan(USDC, 1e6, AVALON_OBTC, uint8(2), uint8(60), sweepCall());

        vm.prank(user);
        oneDV2.deltaCompose(params);
    }

    function test_unit_lending_flashloans_aaveV3_callback_colendPool() public {
        // mock implementation
        replaceLendingPoolWithMock(COLEND);

        bytes memory params = CalldataLib.encodeFlashLoan(USDC, 1e6, COLEND, uint8(2), uint8(102), sweepCall());

        vm.prank(user);
        oneDV2.deltaCompose(params);
    }

    function test_unit_lending_flashloans_aaveV3_callback_colend_lstbtcPool() public {
        // mock implementation
        replaceLendingPoolWithMock(COLEND_LSTBTC);

        bytes memory params = CalldataLib.encodeFlashLoan(STBTC, 1e6, COLEND_LSTBTC, uint8(2), uint8(103), sweepCall());

        vm.prank(user);
        oneDV2.deltaCompose(params);
    }

    function test_unit_lending_flashloans_aaveV3_callback_wrongCallerRevert() public {
        for (uint256 i = 0; i < validPools.length; i++) {
            bytes memory params =
                CalldataLib.encodeFlashLoan(SOLVBTC_B, 1e6, address(mockPool), uint8(2), uint8(validPools[0].poolId), sweepCall());

            vm.prank(user);
            vm.expectRevert(DeltaErrors.INVALID_CALLER);
            oneDV2.deltaCompose(params);
        }
    }

    function test_unit_lending_flashloans_aaveV3_callback_wrongInitiatorRevert() public {
        for (uint256 i = 0; i < validPools.length; i++) {
            PoolCase memory pc = validPools[i];
            // mock implementation
            replaceLendingPoolWithMock(pc.poolAddr);

            vm.prank(user);
            vm.expectRevert(DeltaErrors.INVALID_INITIATOR);
            IAavePool(pc.poolAddr).flashLoanSimple(address(oneDV2), SOLVBTC_B, 1e6, abi.encodePacked(address(user), pc.poolId), 0);
        }
    }

    function test_unit_lending_flashloans_aaveV3_callback_fuzzInvalidPoolIds(uint8 poolId) public {
        replaceLendingPoolWithMock(AVALON);

        for (uint256 i = 0; i < validPools.length; i++) {
            if (poolId == validPools[i].poolId) return;
        }
        bytes memory params = CalldataLib.encodeFlashLoan(SOLVBTC_B, 1e6, AVALON, uint8(2), uint8(poolId), sweepCall());
        vm.prank(user);
        vm.expectRevert(DeltaErrors.INVALID_FLASH_LOAN);
        oneDV2.deltaCompose(params);
    }

    // Helper Functions
    function sweepCall() internal returns (bytes memory) {
        return CalldataLib.encodeSweep(SOLVBTC_B, user, 0, SweepType.VALIDATE);
    }

    function getAddressFromRegistry() internal {
        AVALON = chain.getLendingController(Lenders.AVALON);
        AVALON_UBTC = chain.getLendingController(Lenders.AVALON_UBTC);
        AVALON_OBTC = chain.getLendingController(Lenders.AVALON_OBTC);
        COLEND = chain.getLendingController(Lenders.COLEND);
        COLEND_LSTBTC = chain.getLendingController(Lenders.COLEND_LSTBTC);

        // Get token addresses
        SOLVBTC_B = chain.getTokenAddress(Tokens.SOLVBTC_B);
        USDC = chain.getTokenAddress(Tokens.USDC);
        STBTC = chain.getTokenAddress(Tokens.STBTC);
    }

    function populateValidPools() internal {
        validPools.push(PoolCase({poolId: 50, poolAddr: AVALON, asset: SOLVBTC_B}));
        validPools.push(PoolCase({poolId: 59, poolAddr: AVALON_UBTC, asset: USDC}));
        validPools.push(PoolCase({poolId: 60, poolAddr: AVALON_OBTC, asset: USDC}));
        validPools.push(PoolCase({poolId: 102, poolAddr: COLEND, asset: USDC}));
        validPools.push(PoolCase({poolId: 103, poolAddr: COLEND_LSTBTC, asset: STBTC}));
    }

    function mockERC20FunctionsForAllTokens() internal {
        mockERC20Functions(SOLVBTC_B);
        mockERC20Functions(USDC);
        mockERC20Functions(STBTC);
    }

    function mockERC20Functions(address token) internal {
        vm.mockCall(token, abi.encodeWithSignature("transfer(address,uint256)"), abi.encode(true));
        vm.mockCall(token, abi.encodeWithSignature("transferFrom(address,address,uint256)"), abi.encode(true));
        vm.mockCall(token, abi.encodeWithSignature("approve(address,uint256)"), abi.encode(true));
        vm.mockCall(token, abi.encodeWithSignature("balanceOf(address)"), abi.encode(1e20));
    }

    /// @notice mock implementation for each pool
    function replaceLendingPoolWithMock(address poolAddr) internal {
        vm.etch(poolAddr, address(mockPool).code);
    }
}
