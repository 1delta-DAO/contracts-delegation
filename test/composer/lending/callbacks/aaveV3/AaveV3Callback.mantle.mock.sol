// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {console} from "forge-std/console.sol";
import {Vm} from "forge-std/Vm.sol";
import {Chains, Lenders, Tokens} from "test/data/LenderRegistry.sol";
import {DeltaErrors} from "contracts/1delta/shared/errors/Errors.sol";
import {ComposerPlugin, IComposerLike} from "plugins/ComposerPlugin.sol";
import {CalldataLib} from "test/composer/utils/CalldataLib.sol";
import {BaseTest} from "test/shared/BaseTest.sol";
import {AaveMockPool, IAaveFlashLoanReceiver, IAavePool} from "test/mocks/AaveMockPool.sol";
import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {SweepType} from "contracts/1delta/composer/enums/MiscEnums.sol";

contract AaveV3FlashLoanCallbackTest is BaseTest, DeltaErrors {
    IComposerLike oneDV2;
    AaveMockPool mockPool;

    address private KINZA;
    address private LENDLE_CMETH;
    address private LENDLE_PT_CMETH;
    address private LENDLE_SUSDE;

    address private USDC;

    struct PoolCase {
        uint8 poolId;
        address poolAddr;
        address asset; // The specific asset for each pool to lend, not used in this test, can be used with chain forking
    }

    PoolCase[] validPools;

    function setUp() public virtual {
        string memory chainName = Chains.MANTLE;

        // Initialize chain (for token info) with no forking
        _init(chainName, 0, false);

        getAddressFromRegistry();

        mockERC20FunctionsForAllTokens();

        populateValidPools();

        oneDV2 = ComposerPlugin.getComposer(chainName);
        mockPool = new AaveMockPool();
    }

    function test_flash_loan_aaveV3_type_kinza_pool_with_callbacks() public {
        // mock implementation
        replaceLendingPoolWithMock(KINZA);

        bytes memory params = CalldataLib.encodeFlashLoan(USDC, 1e6, KINZA, uint8(2), uint8(82), sweepCall());

        vm.prank(user);
        oneDV2.deltaCompose(params);
    }

    function test_flash_loan_aaveV3_type_lendle_cmeth_pool_with_callbacks() public {
        // mock implementation
        replaceLendingPoolWithMock(LENDLE_CMETH);

        bytes memory params = CalldataLib.encodeFlashLoan(USDC, 1e6, LENDLE_CMETH, uint8(2), uint8(102), sweepCall());

        vm.prank(user);
        oneDV2.deltaCompose(params);
    }

    function test_flash_loan_aaveV3_type_lendle_pt_cmeth_pool_with_callbacks() public {
        // mock implementation
        replaceLendingPoolWithMock(LENDLE_PT_CMETH);

        bytes memory params = CalldataLib.encodeFlashLoan(USDC, 1e6, LENDLE_PT_CMETH, uint8(2), uint8(103), sweepCall());

        vm.prank(user);
        oneDV2.deltaCompose(params);
    }

    function test_flash_loan_aaveV3_type_lendle_susde_pool_with_callbacks() public {
        // mock implementation
        replaceLendingPoolWithMock(LENDLE_SUSDE);

        bytes memory params = CalldataLib.encodeFlashLoan(USDC, 1e6, LENDLE_SUSDE, uint8(2), uint8(104), sweepCall());

        vm.prank(user);
        oneDV2.deltaCompose(params);
    }

    function test_flash_loan_aaveV3_type_wrongCaller_revert() public {
        for (uint256 i = 0; i < validPools.length; i++) {
            bytes memory params = CalldataLib.encodeFlashLoan(USDC, 1e6, address(mockPool), uint8(2), uint8(validPools[0].poolId), sweepCall());

            vm.prank(user);
            vm.expectRevert(DeltaErrors.INVALID_CALLER);
            oneDV2.deltaCompose(params);
        }
    }

    function test_flash_loan_aaveV3_type_WrongInitiator_revert() public {
        for (uint256 i = 0; i < validPools.length; i++) {
            PoolCase memory pc = validPools[i];
            // mock implementation
            replaceLendingPoolWithMock(pc.poolAddr);

            vm.prank(user);
            vm.expectRevert(DeltaErrors.INVALID_INITIATOR);
            IAavePool(pc.poolAddr).flashLoanSimple(address(oneDV2), USDC, 1e6, abi.encodePacked(address(user), pc.poolId), 0);
        }
    }

    function test_flash_loan_aaveV3_type_fuzz_invalidPoolIds(uint8 poolId) public {
        replaceLendingPoolWithMock(KINZA);

        for (uint256 i = 0; i < validPools.length; i++) {
            if (poolId == validPools[i].poolId) return;
        }
        bytes memory params = CalldataLib.encodeFlashLoan(USDC, 1e6, KINZA, uint8(2), uint8(poolId), sweepCall());
        vm.prank(user);
        vm.expectRevert(DeltaErrors.INVALID_FLASH_LOAN);
        oneDV2.deltaCompose(params);
    }

    // Helper Functions
    function sweepCall() internal returns (bytes memory) {
        return CalldataLib.encodeSweep(USDC, user, 0, SweepType.VALIDATE);
    }

    function getAddressFromRegistry() internal {
        KINZA = chain.getLendingController(Lenders.KINZA);
        LENDLE_CMETH = chain.getLendingController(Lenders.LENDLE_CMETH);
        LENDLE_PT_CMETH = chain.getLendingController(Lenders.LENDLE_PT_CMETH);
        LENDLE_SUSDE = chain.getLendingController(Lenders.LENDLE_SUSDE);

        // Get token addresses
        USDC = chain.getTokenAddress(Tokens.USDC);
    }

    function populateValidPools() internal {
        validPools.push(PoolCase({poolId: 82, poolAddr: KINZA, asset: USDC}));
        validPools.push(PoolCase({poolId: 102, poolAddr: LENDLE_CMETH, asset: USDC}));
        validPools.push(PoolCase({poolId: 103, poolAddr: LENDLE_PT_CMETH, asset: USDC}));
        validPools.push(PoolCase({poolId: 104, poolAddr: LENDLE_SUSDE, asset: USDC}));
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
