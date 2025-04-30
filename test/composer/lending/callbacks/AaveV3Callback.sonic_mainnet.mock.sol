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

contract AaveV3FlashLoanCallbackTest is BaseTest, DeltaErrors {
    IComposerLike oneDV2;
    AaveMockPool mockPool;

    address private AAVE_V3;
    address private AVALON;
    address private AVALON_USDA;
    address private AVALON_BEETS;
    address private MAGSIN;

    address private WETH;

    struct PoolCase {
        uint8 poolId;
        address poolAddr;
        address asset; // The specific asset for each pool to lend, not used in this test, can be used with chain forking
    }

    PoolCase[] validPools;

    function setUp() public virtual {
        string memory chainName = Chains.SONIC_MAINNET;

        // Initialize chain (for token info) with no forking
        _init(chainName, 0, false);

        getAddressFromRegistry();

        mockERC20FunctionsForAllTokens();

        populateValidPools();

        oneDV2 = ComposerPlugin.getComposer(chainName);
        mockPool = new AaveMockPool();
    }

    function test_flash_loan_AaveV3_AAVE_V3_with_callbacks() public {
        // mock implementation
        replaceLendingPoolWithMock(AAVE_V3);

        bytes memory params = CalldataLib.encodeFlashLoan(WETH, 1e6, AAVE_V3, uint8(2), uint8(0), "");

        vm.prank(user);
        oneDV2.deltaCompose(params);
    }

    function test_flash_loan_AaveV3_AVALON_with_callbacks() public {
        // mock implementation
        replaceLendingPoolWithMock(AVALON);

        bytes memory params = CalldataLib.encodeFlashLoan(WETH, 1e6, AVALON, uint8(2), uint8(50), "");

        vm.prank(user);
        oneDV2.deltaCompose(params);
    }

    function test_flash_loan_AaveV3_AVALON_USDA_with_callbacks() public {
        // mock implementation
        replaceLendingPoolWithMock(AVALON_USDA);

        bytes memory params = CalldataLib.encodeFlashLoan(WETH, 1e6, AVALON_USDA, uint8(2), uint8(55), "");

        vm.prank(user);
        oneDV2.deltaCompose(params);
    }

    function test_flash_loan_AaveV3_AVALON_BEETS_with_callbacks() public {
        // mock implementation
        replaceLendingPoolWithMock(AVALON_BEETS);

        bytes memory params = CalldataLib.encodeFlashLoan(WETH, 1e6, AVALON_BEETS, uint8(2), uint8(61), "");

        vm.prank(user);
        oneDV2.deltaCompose(params);
    }

    function test_flash_loan_AaveV3_MAGSIN_with_callbacks() public {
        // mock implementation
        replaceLendingPoolWithMock(MAGSIN);

        bytes memory params = CalldataLib.encodeFlashLoan(WETH, 1e6, MAGSIN, uint8(2), uint8(84), "");

        vm.prank(user);
        oneDV2.deltaCompose(params);
    }

    function test_flash_loan_AaveV3_wrongCaller_revert() public {
        for (uint256 i = 0; i < validPools.length; i++) {
            bytes memory params = CalldataLib.encodeFlashLoan(WETH, 1e6, address(mockPool), uint8(2), uint8(validPools[0].poolId), "");

            vm.prank(user);
            vm.expectRevert(DeltaErrors.INVALID_CALLER);
            oneDV2.deltaCompose(params);
        }
    }

    function test_flash_loan_AaveV3_wrongInitiator_revert() public {
        for (uint256 i = 0; i < validPools.length; i++) {
            PoolCase memory pc = validPools[i];
            // mock implementation
            replaceLendingPoolWithMock(pc.poolAddr);

            vm.prank(user);
            vm.expectRevert(DeltaErrors.INVALID_INITIATOR);
            IAavePool(pc.poolAddr).flashLoanSimple(address(oneDV2), WETH, 1e6, abi.encodePacked(address(user), pc.poolId), 0);
        }
    }

    function test_flash_loan_AaveV3_fuzz_invalidPoolIds(uint8 poolId) public {
        replaceLendingPoolWithMock(AAVE_V3);

        for (uint256 i = 0; i < validPools.length; i++) {
            if (poolId == validPools[i].poolId) return;
        }
        bytes memory params = CalldataLib.encodeFlashLoan(WETH, 1e6, AAVE_V3, uint8(2), uint8(poolId), "");
        vm.prank(user);
        vm.expectRevert(DeltaErrors.INVALID_FLASH_LOAN);
        oneDV2.deltaCompose(params);
    }

    // Helper Functions
    function getAddressFromRegistry() internal {
        AAVE_V3 = chain.getLendingController(Lenders.AAVE_V3);
        AVALON = chain.getLendingController(Lenders.AVALON);
        AVALON_USDA = chain.getLendingController(Lenders.AVALON_USDA);
        AVALON_BEETS = chain.getLendingController(Lenders.AVALON_BEETS);
        MAGSIN = chain.getLendingController(Lenders.MAGSIN);

        // Get token addresses
        WETH = chain.getTokenAddress(Tokens.WETH);
    }

    function populateValidPools() internal {
        validPools.push(PoolCase({poolId: 0, poolAddr: AAVE_V3, asset: WETH}));
        validPools.push(PoolCase({poolId: 50, poolAddr: AVALON, asset: WETH}));
        validPools.push(PoolCase({poolId: 55, poolAddr: AVALON_USDA, asset: WETH}));
        validPools.push(PoolCase({poolId: 61, poolAddr: AVALON_BEETS, asset: WETH}));
        validPools.push(PoolCase({poolId: 84, poolAddr: MAGSIN, asset: WETH}));
    }

    function mockERC20FunctionsForAllTokens() internal {
        mockERC20Functions(WETH);
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
