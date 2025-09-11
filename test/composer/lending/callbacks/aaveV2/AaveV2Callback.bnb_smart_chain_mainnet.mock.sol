// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {console} from "forge-std/console.sol";
import {Vm} from "forge-std/Vm.sol";
import {Chains, Lenders, Tokens} from "test/data/LenderRegistry.sol";
import {DeltaErrors} from "contracts/1delta/shared/errors/Errors.sol";
import {ComposerPlugin, IComposerLike} from "plugins/ComposerPlugin.sol";
import {CalldataLib} from "test/composer/utils/CalldataLib.sol";
import {BaseTest} from "test/shared/BaseTest.sol";
import {AaveV2MockPool, IAaveV2Pool} from "test/mocks/AaveV2MockPool.sol";
import {SweepType} from "contracts/1delta/composer/enums/MiscEnums.sol";

contract AaveV2FlashLoanCallbackTest is BaseTest, DeltaErrors {
    IComposerLike oneDV2;
    AaveV2MockPool mockPool;

    address private GRANARY;
    address private VALAS;
    address private RADIANT_V2;

    address private USDC;

    struct PoolCase {
        uint8 poolId;
        address poolAddr;
        address asset;
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
        mockPool = new AaveV2MockPool();
    }

    function test_flash_loan_aaveV2_type_granary_pool_with_callbacks() public {
        replaceLendingPoolWithMock(GRANARY);

        bytes memory params = CalldataLib.encodeFlashLoan(USDC, 1e6, GRANARY, uint8(3), uint8(7), sweepCall());

        vm.prank(user);
        oneDV2.deltaCompose(params);
    }

    function test_flash_loan_aaveV2_type_valas_pool_with_callbacks() public {
        replaceLendingPoolWithMock(VALAS);

        bytes memory params = CalldataLib.encodeFlashLoan(USDC, 1e6, VALAS, uint8(3), uint8(16), sweepCall());

        vm.prank(user);
        oneDV2.deltaCompose(params);
    }

    function test_flash_loan_aaveV2_type_radiant_v2_pool_with_callbacks() public {
        replaceLendingPoolWithMock(RADIANT_V2);

        bytes memory params = CalldataLib.encodeFlashLoan(USDC, 1e6, RADIANT_V2, uint8(3), uint8(20), sweepCall());

        vm.prank(user);
        oneDV2.deltaCompose(params);
    }

    function test_flash_loan_aaveV2_type_wrongCaller_revert() public {
        bytes memory params = CalldataLib.encodeFlashLoan(USDC, 1e6, address(mockPool), uint8(3), uint8(7), sweepCall());

        vm.prank(user);
        vm.expectRevert(DeltaErrors.INVALID_CALLER);
        oneDV2.deltaCompose(params);
    }

    function test_flash_loan_aaveV2_type_WrongInitiator_revert() public {
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
        IAaveV2Pool(pc.poolAddr).flashLoan(address(oneDV2), assets, amounts, modes, address(0), abi.encodePacked(address(user), pc.poolId), 0);
    }

    function test_flash_loan_aaveV2_type_fuzz_invalidPoolIds(uint8 poolId) public {
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
        VALAS = chain.getLendingController(Lenders.VALAS);
        RADIANT_V2 = chain.getLendingController(Lenders.RADIANT_V2);

        // Get token addresses
        USDC = chain.getTokenAddress(Tokens.USDC);
    }

    function populateValidPools() internal {
        validPools.push(PoolCase({poolId: 7, poolAddr: GRANARY, asset: USDC}));
        validPools.push(PoolCase({poolId: 16, poolAddr: VALAS, asset: USDC}));
        validPools.push(PoolCase({poolId: 20, poolAddr: RADIANT_V2, asset: USDC}));
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
