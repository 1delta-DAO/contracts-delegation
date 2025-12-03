
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

    address private AAVE_V3;
    address private AVALON_SOLVBTC;
    address private AVALON_PUMPBTC;
    address private AVALON_STBTC;
    address private AVALON_WBTC;
    address private AVALON_LBTC;
    address private AVALON_XAUM;
    address private AVALON_LISTA;
    address private AVALON_USDX;
    address private AVALON_UNIBTC;
    address private KINZA;

    address private USDC;
    address private STBTC;
    address private WBTC;
    address private LBTC;
    address private XAUM;
    address private LISTA;
    address private USDX;


    struct PoolCase {
        uint8 poolId;
        address poolAddr;
        address asset; // The specific asset for each pool to lend, not used in this test, can be used with chain forking
    }

    PoolCase[] validPools;

    function setUp() public virtual {
        string memory chainName = Chains.BNB_SMART_CHAIN_MAINNET;

        // Initialize chain (for token info) with no forking
        _init(chainName, 0, false);

        getAddressFromRegistry();

        mockERC20FunctionsForAllTokens();

        populateValidPools();

        oneDV2 = ComposerPlugin.getComposer(chainName);
        mockPool = new AaveMockPool();
    }

    function test_unit_lending_flashloans_aaveV3_callback_aave_v3Pool() public {
        // mock implementation
        replaceLendingPoolWithMock(AAVE_V3);

        bytes memory params = CalldataLib.encodeFlashLoan(USDC, 1e6, AAVE_V3, uint8(2), uint8(0), sweepCall());

        vm.prank(user);
        oneDV2.deltaCompose(params);
    }

    function test_unit_lending_flashloans_aaveV3_callback_avalon_solvbtcPool() public {
        // mock implementation
        replaceLendingPoolWithMock(AVALON_SOLVBTC);

        bytes memory params = CalldataLib.encodeFlashLoan(USDC, 1e6, AVALON_SOLVBTC, uint8(2), uint8(51), sweepCall());

        vm.prank(user);
        oneDV2.deltaCompose(params);
    }

    function test_unit_lending_flashloans_aaveV3_callback_avalon_pumpbtcPool() public {
        // mock implementation
        replaceLendingPoolWithMock(AVALON_PUMPBTC);

        bytes memory params = CalldataLib.encodeFlashLoan(USDC, 1e6, AVALON_PUMPBTC, uint8(2), uint8(53), sweepCall());

        vm.prank(user);
        oneDV2.deltaCompose(params);
    }

    function test_unit_lending_flashloans_aaveV3_callback_avalon_stbtcPool() public {
        // mock implementation
        replaceLendingPoolWithMock(AVALON_STBTC);

        bytes memory params = CalldataLib.encodeFlashLoan(STBTC, 1e6, AVALON_STBTC, uint8(2), uint8(64), sweepCall());

        vm.prank(user);
        oneDV2.deltaCompose(params);
    }

    function test_unit_lending_flashloans_aaveV3_callback_avalon_wbtcPool() public {
        // mock implementation
        replaceLendingPoolWithMock(AVALON_WBTC);

        bytes memory params = CalldataLib.encodeFlashLoan(WBTC, 1e6, AVALON_WBTC, uint8(2), uint8(65), sweepCall());

        vm.prank(user);
        oneDV2.deltaCompose(params);
    }

    function test_unit_lending_flashloans_aaveV3_callback_avalon_lbtcPool() public {
        // mock implementation
        replaceLendingPoolWithMock(AVALON_LBTC);

        bytes memory params = CalldataLib.encodeFlashLoan(LBTC, 1e6, AVALON_LBTC, uint8(2), uint8(66), sweepCall());

        vm.prank(user);
        oneDV2.deltaCompose(params);
    }

    function test_unit_lending_flashloans_aaveV3_callback_avalon_xaumPool() public {
        // mock implementation
        replaceLendingPoolWithMock(AVALON_XAUM);

        bytes memory params = CalldataLib.encodeFlashLoan(XAUM, 1e6, AVALON_XAUM, uint8(2), uint8(67), sweepCall());

        vm.prank(user);
        oneDV2.deltaCompose(params);
    }

    function test_unit_lending_flashloans_aaveV3_callback_avalon_listaPool() public {
        // mock implementation
        replaceLendingPoolWithMock(AVALON_LISTA);

        bytes memory params = CalldataLib.encodeFlashLoan(LISTA, 1e6, AVALON_LISTA, uint8(2), uint8(68), sweepCall());

        vm.prank(user);
        oneDV2.deltaCompose(params);
    }

    function test_unit_lending_flashloans_aaveV3_callback_avalon_usdxPool() public {
        // mock implementation
        replaceLendingPoolWithMock(AVALON_USDX);

        bytes memory params = CalldataLib.encodeFlashLoan(USDX, 1e6, AVALON_USDX, uint8(2), uint8(69), sweepCall());

        vm.prank(user);
        oneDV2.deltaCompose(params);
    }

    function test_unit_lending_flashloans_aaveV3_callback_avalon_unibtcPool() public {
        // mock implementation
        replaceLendingPoolWithMock(AVALON_UNIBTC);

        bytes memory params = CalldataLib.encodeFlashLoan(USDC, 1e6, AVALON_UNIBTC, uint8(2), uint8(70), sweepCall());

        vm.prank(user);
        oneDV2.deltaCompose(params);
    }

    function test_unit_lending_flashloans_aaveV3_callback_kinzaPool() public {
        // mock implementation
        replaceLendingPoolWithMock(KINZA);

        bytes memory params = CalldataLib.encodeFlashLoan(USDC, 1e6, KINZA, uint8(2), uint8(82), sweepCall());

        vm.prank(user);
        oneDV2.deltaCompose(params);
    }

    function test_unit_lending_flashloans_aaveV3_callback_wrongCallerRevert() public {
        for (uint256 i = 0; i < validPools.length; i++) {
            bytes memory params = CalldataLib.encodeFlashLoan(USDC, 1e6, address(mockPool), uint8(2), uint8(validPools[0].poolId), sweepCall());

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
            IAavePool(pc.poolAddr).flashLoanSimple(address(oneDV2), USDC, 1e6, abi.encodePacked(address(user), pc.poolId), 0);
        }
    }

    function test_unit_lending_flashloans_aaveV3_callback_fuzzInvalidPoolIds(uint8 poolId) public {
        replaceLendingPoolWithMock(AAVE_V3);

        for (uint256 i = 0; i < validPools.length; i++) {
            if (poolId == validPools[i].poolId) return;
        }
        bytes memory params = CalldataLib.encodeFlashLoan(USDC, 1e6, AAVE_V3, uint8(2), uint8(poolId), sweepCall());
        vm.prank(user);
        vm.expectRevert(DeltaErrors.INVALID_FLASH_LOAN);
        oneDV2.deltaCompose(params);
    }

    // Helper Functions
        function sweepCall() internal returns (bytes memory){
        return CalldataLib.encodeSweep(USDC, user, 0, SweepType.VALIDATE);
    }

    function getAddressFromRegistry() internal {
        AAVE_V3 = chain.getLendingController(Lenders.AAVE_V3);
        AVALON_SOLVBTC = chain.getLendingController(Lenders.AVALON_SOLVBTC);
        AVALON_PUMPBTC = chain.getLendingController(Lenders.AVALON_PUMPBTC);
        AVALON_STBTC = chain.getLendingController(Lenders.AVALON_STBTC);
        AVALON_WBTC = chain.getLendingController(Lenders.AVALON_WBTC);
        AVALON_LBTC = chain.getLendingController(Lenders.AVALON_LBTC);
        AVALON_XAUM = chain.getLendingController(Lenders.AVALON_XAUM);
        AVALON_LISTA = chain.getLendingController(Lenders.AVALON_LISTA);
        AVALON_USDX = chain.getLendingController(Lenders.AVALON_USDX);
        AVALON_UNIBTC = chain.getLendingController(Lenders.AVALON_UNIBTC);
        KINZA = chain.getLendingController(Lenders.KINZA);

        // Get token addresses
        USDC = chain.getTokenAddress(Tokens.USDC);
        STBTC = chain.getTokenAddress(Tokens.STBTC);
        WBTC = chain.getTokenAddress(Tokens.WBTC);
        LBTC = chain.getTokenAddress(Tokens.LBTC);
        XAUM = chain.getTokenAddress(Tokens.XAUM);
        LISTA = chain.getTokenAddress(Tokens.LISTA);
        USDX = chain.getTokenAddress(Tokens.USDX);
    }

    function populateValidPools() internal {
        validPools.push(PoolCase({poolId: 0, poolAddr: AAVE_V3, asset: USDC}));
        validPools.push(PoolCase({poolId: 51, poolAddr: AVALON_SOLVBTC, asset: USDC}));
        validPools.push(PoolCase({poolId: 53, poolAddr: AVALON_PUMPBTC, asset: USDC}));
        validPools.push(PoolCase({poolId: 64, poolAddr: AVALON_STBTC, asset: STBTC}));
        validPools.push(PoolCase({poolId: 65, poolAddr: AVALON_WBTC, asset: WBTC}));
        validPools.push(PoolCase({poolId: 66, poolAddr: AVALON_LBTC, asset: LBTC}));
        validPools.push(PoolCase({poolId: 67, poolAddr: AVALON_XAUM, asset: XAUM}));
        validPools.push(PoolCase({poolId: 68, poolAddr: AVALON_LISTA, asset: LISTA}));
        validPools.push(PoolCase({poolId: 69, poolAddr: AVALON_USDX, asset: USDX}));
        validPools.push(PoolCase({poolId: 70, poolAddr: AVALON_UNIBTC, asset: USDC}));
        validPools.push(PoolCase({poolId: 82, poolAddr: KINZA, asset: USDC}));

    }

    function mockERC20FunctionsForAllTokens() internal {
        mockERC20Functions(USDC);
        mockERC20Functions(STBTC);
        mockERC20Functions(WBTC);
        mockERC20Functions(LBTC);
        mockERC20Functions(XAUM);
        mockERC20Functions(LISTA);
        mockERC20Functions(USDX);

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
