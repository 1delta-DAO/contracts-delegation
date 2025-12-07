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

    address private ZEROLEND;
    address private LENDOS;
    address private LAYERBANK_V3;

    address private WBTC;

    struct PoolCase {
        uint8 poolId;
        address poolAddr;
        address asset; // The specific asset for each pool to lend, not used in this test, can be used with chain forking
    }

    PoolCase[] validPools;

    function setUp() public virtual {
        string memory chainName = Chains.HEMI_NETWORK;

        // Initialize chain (for token info) with no forking
        _init(chainName, 0, false);

        getAddressFromRegistry();

        mockERC20FunctionsForAllTokens();

        populateValidPools();

        oneDV2 = ComposerPlugin.getComposer(chainName);
        mockPool = new AaveMockPool();
    }

    function test_unit_lending_flashloans_aaveV3_callback_zerolendPool() public {
        // mock implementation
        replaceLendingPoolWithMock(ZEROLEND);

        bytes memory params = CalldataLib.encodeFlashLoan(WBTC, 1e6, ZEROLEND, uint8(2), uint8(20), sweepCall());

        vm.prank(user);
        oneDV2.deltaCompose(params);
    }

    function test_unit_lending_flashloans_aaveV3_callback_lendosPool() public {
        // mock implementation
        replaceLendingPoolWithMock(LENDOS);

        bytes memory params = CalldataLib.encodeFlashLoan(WBTC, 1e6, LENDOS, uint8(2), uint8(83), sweepCall());

        vm.prank(user);
        oneDV2.deltaCompose(params);
    }

    function test_unit_lending_flashloans_aaveV3_callback_layerbank_v3Pool() public {
        // mock implementation
        replaceLendingPoolWithMock(LAYERBANK_V3);

        bytes memory params = CalldataLib.encodeFlashLoan(WBTC, 1e6, LAYERBANK_V3, uint8(2), uint8(91), sweepCall());

        vm.prank(user);
        oneDV2.deltaCompose(params);
    }

    function test_unit_lending_flashloans_aaveV3_callback_wrongCallerRevert() public {
        for (uint256 i = 0; i < validPools.length; i++) {
            bytes memory params = CalldataLib.encodeFlashLoan(WBTC, 1e6, address(mockPool), uint8(2), uint8(validPools[0].poolId), sweepCall());

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
            IAavePool(pc.poolAddr).flashLoanSimple(address(oneDV2), WBTC, 1e6, abi.encodePacked(address(user), pc.poolId), 0);
        }
    }

    function test_unit_lending_flashloans_aaveV3_callback_fuzzInvalidPoolIds(uint8 poolId) public {
        replaceLendingPoolWithMock(ZEROLEND);

        for (uint256 i = 0; i < validPools.length; i++) {
            if (poolId == validPools[i].poolId) return;
        }
        bytes memory params = CalldataLib.encodeFlashLoan(WBTC, 1e6, ZEROLEND, uint8(2), uint8(poolId), sweepCall());
        vm.prank(user);
        vm.expectRevert(DeltaErrors.INVALID_FLASH_LOAN);
        oneDV2.deltaCompose(params);
    }

    // Helper Functions
    function sweepCall() internal returns (bytes memory) {
        return CalldataLib.encodeSweep(WBTC, user, 0, SweepType.VALIDATE);
    }

    function getAddressFromRegistry() internal {
        ZEROLEND = chain.getLendingController(Lenders.ZEROLEND);
        LENDOS = chain.getLendingController(Lenders.LENDOS);
        LAYERBANK_V3 = chain.getLendingController(Lenders.LAYERBANK_V3);

        // Get token addresses
        WBTC = chain.getTokenAddress(Tokens.WBTC);
    }

    function populateValidPools() internal {
        validPools.push(PoolCase({poolId: 20, poolAddr: ZEROLEND, asset: WBTC}));
        validPools.push(PoolCase({poolId: 83, poolAddr: LENDOS, asset: WBTC}));
        validPools.push(PoolCase({poolId: 91, poolAddr: LAYERBANK_V3, asset: WBTC}));
    }

    function mockERC20FunctionsForAllTokens() internal {
        mockERC20Functions(WBTC);
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
