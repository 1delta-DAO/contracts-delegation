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

    address private ZEROLEND;
    address private PAC;

    address private USDC;

    struct PoolCase {
        uint8 poolId;
        address poolAddr;
        address asset; // The specific asset for each pool to lend, not used in this test, can be used with chain forking
    }

    PoolCase[] validPools;

    function setUp() public virtual {
        string memory chainName = Chains.BLAST;

        // Initialize chain (for token info) with no forking
        _init(chainName, 0, false);

        getAddressFromRegistry();

        mockERC20FunctionsForAllTokens();

        populateValidPools();

        oneDV2 = ComposerPlugin.getComposer(chainName);
        mockPool = new AaveMockPool();
    }

    function test_flash_loan_aaveV3_type_zerolend_pool_with_callbacks() public {
        // mock implementation
        replaceLendingPoolWithMock(ZEROLEND);

        bytes memory params = CalldataLib.encodeFlashLoan(USDC, 1e6, ZEROLEND, uint8(2), uint8(20), sweepCall());

        vm.prank(user);
        oneDV2.deltaCompose(params);
    }

    function test_flash_loan_aaveV3_type_pac_pool_with_callbacks() public {
        // mock implementation
        replaceLendingPoolWithMock(PAC);

        bytes memory params = CalldataLib.encodeFlashLoan(USDC, 1e6, PAC, uint8(2), uint8(81), sweepCall());

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
        replaceLendingPoolWithMock(ZEROLEND);

        for (uint256 i = 0; i < validPools.length; i++) {
            if (poolId == validPools[i].poolId) return;
        }
        bytes memory params = CalldataLib.encodeFlashLoan(USDC, 1e6, ZEROLEND, uint8(2), uint8(poolId), sweepCall());
        vm.prank(user);
        vm.expectRevert(DeltaErrors.INVALID_FLASH_LOAN);
        oneDV2.deltaCompose(params);
    }

    // Helper Functions
    function sweepCall() internal returns (bytes memory) {
        return CalldataLib.encodeSweep(USDC, user, 0, SweepType.VALIDATE);
    }

    function getAddressFromRegistry() internal {
        ZEROLEND = chain.getLendingController(Lenders.ZEROLEND);
        PAC = chain.getLendingController(Lenders.PAC);

        // Get token addresses
        USDC = chain.getTokenAddress(Tokens.USDC);
    }

    function populateValidPools() internal {
        validPools.push(PoolCase({poolId: 20, poolAddr: ZEROLEND, asset: USDC}));
        validPools.push(PoolCase({poolId: 81, poolAddr: PAC, asset: USDC}));
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
