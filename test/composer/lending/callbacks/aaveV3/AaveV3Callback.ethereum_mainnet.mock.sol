
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
    address private AAVE_V3_PRIME;
    address private AAVE_V3_ETHER_FI;
    address private AAVE_V3_HORIZON;
    address private SPARK;
    address private ZEROLEND_STABLECOINS_RWA;
    address private ZEROLEND_ETH_LRTS;
    address private ZEROLEND_BTC_LRTS;
    address private AVALON_SOLVBTC;
    address private AVALON_SWELLBTC;
    address private AVALON_PUMPBTC;
    address private AVALON_EBTC_LBTC;
    address private KINZA;
    address private YLDR;

    address private USDC;
    address private LBTC;


    struct PoolCase {
        uint8 poolId;
        address poolAddr;
        address asset; // The specific asset for each pool to lend, not used in this test, can be used with chain forking
    }

    PoolCase[] validPools;

    function setUp() public virtual {
        string memory chainName = Chains.ETHEREUM_MAINNET;

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

    function test_unit_lending_flashloans_aaveV3_callback_aave_v3_primePool() public {
        // mock implementation
        replaceLendingPoolWithMock(AAVE_V3_PRIME);

        bytes memory params = CalldataLib.encodeFlashLoan(USDC, 1e6, AAVE_V3_PRIME, uint8(2), uint8(1), sweepCall());

        vm.prank(user);
        oneDV2.deltaCompose(params);
    }

    function test_unit_lending_flashloans_aaveV3_callback_aave_v3_ether_fiPool() public {
        // mock implementation
        replaceLendingPoolWithMock(AAVE_V3_ETHER_FI);

        bytes memory params = CalldataLib.encodeFlashLoan(USDC, 1e6, AAVE_V3_ETHER_FI, uint8(2), uint8(2), sweepCall());

        vm.prank(user);
        oneDV2.deltaCompose(params);
    }

    function test_unit_lending_flashloans_aaveV3_callback_aave_v3_horizonPool() public {
        // mock implementation
        replaceLendingPoolWithMock(AAVE_V3_HORIZON);

        bytes memory params = CalldataLib.encodeFlashLoan(USDC, 1e6, AAVE_V3_HORIZON, uint8(2), uint8(3), sweepCall());

        vm.prank(user);
        oneDV2.deltaCompose(params);
    }

    function test_unit_lending_flashloans_aaveV3_callback_sparkPool() public {
        // mock implementation
        replaceLendingPoolWithMock(SPARK);

        bytes memory params = CalldataLib.encodeFlashLoan(USDC, 1e6, SPARK, uint8(2), uint8(10), sweepCall());

        vm.prank(user);
        oneDV2.deltaCompose(params);
    }

    function test_unit_lending_flashloans_aaveV3_callback_zerolend_stablecoins_rwaPool() public {
        // mock implementation
        replaceLendingPoolWithMock(ZEROLEND_STABLECOINS_RWA);

        bytes memory params = CalldataLib.encodeFlashLoan(USDC, 1e6, ZEROLEND_STABLECOINS_RWA, uint8(2), uint8(21), sweepCall());

        vm.prank(user);
        oneDV2.deltaCompose(params);
    }

    function test_unit_lending_flashloans_aaveV3_callback_zerolend_eth_lrtsPool() public {
        // mock implementation
        replaceLendingPoolWithMock(ZEROLEND_ETH_LRTS);

        bytes memory params = CalldataLib.encodeFlashLoan(USDC, 1e6, ZEROLEND_ETH_LRTS, uint8(2), uint8(22), sweepCall());

        vm.prank(user);
        oneDV2.deltaCompose(params);
    }

    function test_unit_lending_flashloans_aaveV3_callback_zerolend_btc_lrtsPool() public {
        // mock implementation
        replaceLendingPoolWithMock(ZEROLEND_BTC_LRTS);

        bytes memory params = CalldataLib.encodeFlashLoan(USDC, 1e6, ZEROLEND_BTC_LRTS, uint8(2), uint8(23), sweepCall());

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

    function test_unit_lending_flashloans_aaveV3_callback_avalon_swellbtcPool() public {
        // mock implementation
        replaceLendingPoolWithMock(AVALON_SWELLBTC);

        bytes memory params = CalldataLib.encodeFlashLoan(LBTC, 1e6, AVALON_SWELLBTC, uint8(2), uint8(52), sweepCall());

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

    function test_unit_lending_flashloans_aaveV3_callback_avalon_ebtc_lbtcPool() public {
        // mock implementation
        replaceLendingPoolWithMock(AVALON_EBTC_LBTC);

        bytes memory params = CalldataLib.encodeFlashLoan(LBTC, 1e6, AVALON_EBTC_LBTC, uint8(2), uint8(54), sweepCall());

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

    function test_unit_lending_flashloans_aaveV3_callback_yldrPool() public {
        // mock implementation
        replaceLendingPoolWithMock(YLDR);

        bytes memory params = CalldataLib.encodeFlashLoan(USDC, 1e6, YLDR, uint8(2), uint8(100), sweepCall());

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
        AAVE_V3_PRIME = chain.getLendingController(Lenders.AAVE_V3_PRIME);
        AAVE_V3_ETHER_FI = chain.getLendingController(Lenders.AAVE_V3_ETHER_FI);
        AAVE_V3_HORIZON = chain.getLendingController(Lenders.AAVE_V3_HORIZON);
        SPARK = chain.getLendingController(Lenders.SPARK);
        ZEROLEND_STABLECOINS_RWA = chain.getLendingController(Lenders.ZEROLEND_STABLECOINS_RWA);
        ZEROLEND_ETH_LRTS = chain.getLendingController(Lenders.ZEROLEND_ETH_LRTS);
        ZEROLEND_BTC_LRTS = chain.getLendingController(Lenders.ZEROLEND_BTC_LRTS);
        AVALON_SOLVBTC = chain.getLendingController(Lenders.AVALON_SOLVBTC);
        AVALON_SWELLBTC = chain.getLendingController(Lenders.AVALON_SWELLBTC);
        AVALON_PUMPBTC = chain.getLendingController(Lenders.AVALON_PUMPBTC);
        AVALON_EBTC_LBTC = chain.getLendingController(Lenders.AVALON_EBTC_LBTC);
        KINZA = chain.getLendingController(Lenders.KINZA);
        YLDR = chain.getLendingController(Lenders.YLDR);

        // Get token addresses
        USDC = chain.getTokenAddress(Tokens.USDC);
        LBTC = chain.getTokenAddress(Tokens.LBTC);
    }

    function populateValidPools() internal {
        validPools.push(PoolCase({poolId: 0, poolAddr: AAVE_V3, asset: USDC}));
        validPools.push(PoolCase({poolId: 1, poolAddr: AAVE_V3_PRIME, asset: USDC}));
        validPools.push(PoolCase({poolId: 2, poolAddr: AAVE_V3_ETHER_FI, asset: USDC}));
        validPools.push(PoolCase({poolId: 3, poolAddr: AAVE_V3_HORIZON, asset: USDC}));
        validPools.push(PoolCase({poolId: 10, poolAddr: SPARK, asset: USDC}));
        validPools.push(PoolCase({poolId: 21, poolAddr: ZEROLEND_STABLECOINS_RWA, asset: USDC}));
        validPools.push(PoolCase({poolId: 22, poolAddr: ZEROLEND_ETH_LRTS, asset: USDC}));
        validPools.push(PoolCase({poolId: 23, poolAddr: ZEROLEND_BTC_LRTS, asset: USDC}));
        validPools.push(PoolCase({poolId: 51, poolAddr: AVALON_SOLVBTC, asset: USDC}));
        validPools.push(PoolCase({poolId: 52, poolAddr: AVALON_SWELLBTC, asset: LBTC}));
        validPools.push(PoolCase({poolId: 53, poolAddr: AVALON_PUMPBTC, asset: USDC}));
        validPools.push(PoolCase({poolId: 54, poolAddr: AVALON_EBTC_LBTC, asset: LBTC}));
        validPools.push(PoolCase({poolId: 82, poolAddr: KINZA, asset: USDC}));
        validPools.push(PoolCase({poolId: 100, poolAddr: YLDR, asset: USDC}));

    }

    function mockERC20FunctionsForAllTokens() internal {
        mockERC20Functions(USDC);
        mockERC20Functions(LBTC);

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
