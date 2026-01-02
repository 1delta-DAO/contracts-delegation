// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Chains, Lenders, Tokens} from "test/data/LenderRegistry.sol";
import {DeltaErrors} from "contracts/1delta/shared/errors/Errors.sol";
import {ComposerPlugin, IComposerLike} from "plugins/ComposerPlugin.sol";
import {CalldataLib} from "contracts/utils/CalldataLib.sol";
import {BaseTest} from "test/shared/BaseTest.sol";
import {AaveV2MockPool, IAaveV2Pool} from "test/mocks/AaveV2MockPool.sol";
import {SweepType} from "contracts/1delta/composer/enums/MiscEnums.sol";

contract AaveV2FlashLoanCallbackTest is BaseTest, DeltaErrors {
    IComposerLike oneDV2;
    AaveV2MockPool mockPool;

    address private GRANARY;
    address private POLTER;
    address private RADIANT_V2;
    address private PRIME_FI;

    address private USDC;

    struct PoolCase {
        uint8 poolId;
        address poolAddr;
        address asset;
    }

    PoolCase[] validPools;

    function setUp() public virtual {
        string memory chainName = Chains.BASE;

        // Initialize chain (for token info) with no forking
        _init(chainName, 0, false);

        getAddressFromRegistry();

        mockERC20FunctionsForAllTokens();

        populateValidPools();

        oneDV2 = ComposerPlugin.getComposer(chainName);
        mockPool = new AaveV2MockPool();
    }

    function test_unit_lending_flashloans_aaveV2_callback_granaryPool() public {
        replaceLendingPoolWithMock(GRANARY);

        bytes memory params = CalldataLib.encodeFlashLoan(USDC, 1e6, GRANARY, uint8(3), uint8(7), sweepCall());

        vm.prank(user);
        oneDV2.deltaCompose(params);
    }

    function test_unit_lending_flashloans_aaveV2_callback_polterPool() public {
        replaceLendingPoolWithMock(POLTER);

        bytes memory params = CalldataLib.encodeFlashLoan(USDC, 1e6, POLTER, uint8(3), uint8(11), sweepCall());

        vm.prank(user);
        oneDV2.deltaCompose(params);
    }

    function test_unit_lending_flashloans_aaveV2_callback_radiant_v2Pool() public {
        replaceLendingPoolWithMock(RADIANT_V2);

        bytes memory params = CalldataLib.encodeFlashLoan(USDC, 1e6, RADIANT_V2, uint8(3), uint8(20), sweepCall());

        vm.prank(user);
        oneDV2.deltaCompose(params);
    }

    function test_unit_lending_flashloans_aaveV2_callback_prime_fiPool() public {
        replaceLendingPoolWithMock(PRIME_FI);

        bytes memory params = CalldataLib.encodeFlashLoan(USDC, 1e6, PRIME_FI, uint8(3), uint8(21), sweepCall());

        vm.prank(user);
        oneDV2.deltaCompose(params);
    }

    function test_unit_lending_flashloans_aaveV2_callback_wrongCallerRevert() public {
        bytes memory params = CalldataLib.encodeFlashLoan(USDC, 1e6, address(mockPool), uint8(3), uint8(7), sweepCall());

        vm.prank(user);
        vm.expectRevert(DeltaErrors.INVALID_CALLER);
        oneDV2.deltaCompose(params);
    }

    function test_unit_lending_flashloans_aaveV2_callback_wrongInitiatorRevert() public {
        PoolCase memory pc = validPools[0];

        replaceLendingPoolWithMock(pc.poolAddr);

        address[] memory assets = new address[](1);
        assets[0] = USDC;

        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 1e6;

        uint256[] memory modes = new uint256[](1);
        modes[0] = 0;

        vm.prank(user);
        vm.expectRevert(DeltaErrors.INVALID_INITIATOR);
        IAaveV2Pool(pc.poolAddr).flashLoan(
            address(oneDV2), assets, amounts, modes, address(0), abi.encodePacked(address(user), pc.poolId), 0
        );
    }

    function test_unit_lending_flashloans_aaveV2_callback_fuzzInvalidPoolIds(uint8 poolId) public {
        replaceLendingPoolWithMock(GRANARY);

        for (uint256 i = 0; i < validPools.length; i++) {
            if (poolId == validPools[i].poolId) return;
        }
        bytes memory params = CalldataLib.encodeFlashLoan(USDC, 1e6, GRANARY, uint8(3), uint8(poolId), sweepCall());
        vm.prank(user);
        vm.expectRevert(DeltaErrors.INVALID_FLASH_LOAN);
        oneDV2.deltaCompose(params);
    }

    // Helper Functions
    function sweepCall() internal returns (bytes memory) {
        return CalldataLib.encodeSweep(USDC, user, 0, SweepType.VALIDATE);
    }

    function getAddressFromRegistry() internal {
        GRANARY = chain.getLendingController(Lenders.GRANARY);
        POLTER = chain.getLendingController(Lenders.POLTER);
        RADIANT_V2 = chain.getLendingController(Lenders.RADIANT_V2);
        PRIME_FI = chain.getLendingController(Lenders.PRIME_FI);

        // Get token addresses
        USDC = chain.getTokenAddress(Tokens.USDC);
    }

    function populateValidPools() internal {
        validPools.push(PoolCase({poolId: 7, poolAddr: GRANARY, asset: USDC}));
        validPools.push(PoolCase({poolId: 11, poolAddr: POLTER, asset: USDC}));
        validPools.push(PoolCase({poolId: 20, poolAddr: RADIANT_V2, asset: USDC}));
        validPools.push(PoolCase({poolId: 21, poolAddr: PRIME_FI, asset: USDC}));
    }

    function mockERC20FunctionsForAllTokens() internal {
        mockERC20Functions(USDC);
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
