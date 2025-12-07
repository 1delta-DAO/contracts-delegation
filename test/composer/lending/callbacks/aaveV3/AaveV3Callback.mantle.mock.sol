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

    address private KINZA;
    address private LENDLE_CMETH;
    address private LENDLE_PT_CMETH;
    address private LENDLE_SUSDE;
    address private LENDLE_SUSDE_USDT;
    address private LENDLE_METH_WETH;
    address private LENDLE_METH_USDE;
    address private LENDLE_CMETH_WETH;
    address private LENDLE_CMETH_USDE;
    address private LENDLE_CMETH_WMNT;
    address private LENDLE_FBTC_WETH;
    address private LENDLE_FBTC_USDE;
    address private LENDLE_FBTC_WMNT;
    address private LENDLE_WMNT_WETH;
    address private LENDLE_WMNT_USDE;

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

    function test_unit_lending_flashloans_aaveV3_callback_kinzaPool() public {
        // mock implementation
        replaceLendingPoolWithMock(KINZA);

        bytes memory params = CalldataLib.encodeFlashLoan(USDC, 1e6, KINZA, uint8(2), uint8(82), sweepCall());

        vm.prank(user);
        oneDV2.deltaCompose(params);
    }

    function test_unit_lending_flashloans_aaveV3_callback_lendle_cmethPool() public {
        // mock implementation
        replaceLendingPoolWithMock(LENDLE_CMETH);

        bytes memory params = CalldataLib.encodeFlashLoan(USDC, 1e6, LENDLE_CMETH, uint8(2), uint8(102), sweepCall());

        vm.prank(user);
        oneDV2.deltaCompose(params);
    }

    function test_unit_lending_flashloans_aaveV3_callback_lendle_pt_cmethPool() public {
        // mock implementation
        replaceLendingPoolWithMock(LENDLE_PT_CMETH);

        bytes memory params = CalldataLib.encodeFlashLoan(USDC, 1e6, LENDLE_PT_CMETH, uint8(2), uint8(103), sweepCall());

        vm.prank(user);
        oneDV2.deltaCompose(params);
    }

    function test_unit_lending_flashloans_aaveV3_callback_lendle_susdePool() public {
        // mock implementation
        replaceLendingPoolWithMock(LENDLE_SUSDE);

        bytes memory params = CalldataLib.encodeFlashLoan(USDC, 1e6, LENDLE_SUSDE, uint8(2), uint8(104), sweepCall());

        vm.prank(user);
        oneDV2.deltaCompose(params);
    }

    function test_unit_lending_flashloans_aaveV3_callback_lendle_susde_usdtPool() public {
        // mock implementation
        replaceLendingPoolWithMock(LENDLE_SUSDE_USDT);

        bytes memory params = CalldataLib.encodeFlashLoan(USDC, 1e6, LENDLE_SUSDE_USDT, uint8(2), uint8(105), sweepCall());

        vm.prank(user);
        oneDV2.deltaCompose(params);
    }

    function test_unit_lending_flashloans_aaveV3_callback_lendle_meth_wethPool() public {
        // mock implementation
        replaceLendingPoolWithMock(LENDLE_METH_WETH);

        bytes memory params = CalldataLib.encodeFlashLoan(USDC, 1e6, LENDLE_METH_WETH, uint8(2), uint8(106), sweepCall());

        vm.prank(user);
        oneDV2.deltaCompose(params);
    }

    function test_unit_lending_flashloans_aaveV3_callback_lendle_meth_usdePool() public {
        // mock implementation
        replaceLendingPoolWithMock(LENDLE_METH_USDE);

        bytes memory params = CalldataLib.encodeFlashLoan(USDC, 1e6, LENDLE_METH_USDE, uint8(2), uint8(107), sweepCall());

        vm.prank(user);
        oneDV2.deltaCompose(params);
    }

    function test_unit_lending_flashloans_aaveV3_callback_lendle_cmeth_wethPool() public {
        // mock implementation
        replaceLendingPoolWithMock(LENDLE_CMETH_WETH);

        bytes memory params = CalldataLib.encodeFlashLoan(USDC, 1e6, LENDLE_CMETH_WETH, uint8(2), uint8(108), sweepCall());

        vm.prank(user);
        oneDV2.deltaCompose(params);
    }

    function test_unit_lending_flashloans_aaveV3_callback_lendle_cmeth_usdePool() public {
        // mock implementation
        replaceLendingPoolWithMock(LENDLE_CMETH_USDE);

        bytes memory params = CalldataLib.encodeFlashLoan(USDC, 1e6, LENDLE_CMETH_USDE, uint8(2), uint8(109), sweepCall());

        vm.prank(user);
        oneDV2.deltaCompose(params);
    }

    function test_unit_lending_flashloans_aaveV3_callback_lendle_cmeth_wmntPool() public {
        // mock implementation
        replaceLendingPoolWithMock(LENDLE_CMETH_WMNT);

        bytes memory params = CalldataLib.encodeFlashLoan(USDC, 1e6, LENDLE_CMETH_WMNT, uint8(2), uint8(110), sweepCall());

        vm.prank(user);
        oneDV2.deltaCompose(params);
    }

    function test_unit_lending_flashloans_aaveV3_callback_lendle_fbtc_wethPool() public {
        // mock implementation
        replaceLendingPoolWithMock(LENDLE_FBTC_WETH);

        bytes memory params = CalldataLib.encodeFlashLoan(USDC, 1e6, LENDLE_FBTC_WETH, uint8(2), uint8(111), sweepCall());

        vm.prank(user);
        oneDV2.deltaCompose(params);
    }

    function test_unit_lending_flashloans_aaveV3_callback_lendle_fbtc_usdePool() public {
        // mock implementation
        replaceLendingPoolWithMock(LENDLE_FBTC_USDE);

        bytes memory params = CalldataLib.encodeFlashLoan(USDC, 1e6, LENDLE_FBTC_USDE, uint8(2), uint8(112), sweepCall());

        vm.prank(user);
        oneDV2.deltaCompose(params);
    }

    function test_unit_lending_flashloans_aaveV3_callback_lendle_fbtc_wmntPool() public {
        // mock implementation
        replaceLendingPoolWithMock(LENDLE_FBTC_WMNT);

        bytes memory params = CalldataLib.encodeFlashLoan(USDC, 1e6, LENDLE_FBTC_WMNT, uint8(2), uint8(113), sweepCall());

        vm.prank(user);
        oneDV2.deltaCompose(params);
    }

    function test_unit_lending_flashloans_aaveV3_callback_lendle_wmnt_wethPool() public {
        // mock implementation
        replaceLendingPoolWithMock(LENDLE_WMNT_WETH);

        bytes memory params = CalldataLib.encodeFlashLoan(USDC, 1e6, LENDLE_WMNT_WETH, uint8(2), uint8(114), sweepCall());

        vm.prank(user);
        oneDV2.deltaCompose(params);
    }

    function test_unit_lending_flashloans_aaveV3_callback_lendle_wmnt_usdePool() public {
        // mock implementation
        replaceLendingPoolWithMock(LENDLE_WMNT_USDE);

        bytes memory params = CalldataLib.encodeFlashLoan(USDC, 1e6, LENDLE_WMNT_USDE, uint8(2), uint8(115), sweepCall());

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
        LENDLE_SUSDE_USDT = chain.getLendingController(Lenders.LENDLE_SUSDE_USDT);
        LENDLE_METH_WETH = chain.getLendingController(Lenders.LENDLE_METH_WETH);
        LENDLE_METH_USDE = chain.getLendingController(Lenders.LENDLE_METH_USDE);
        LENDLE_CMETH_WETH = chain.getLendingController(Lenders.LENDLE_CMETH_WETH);
        LENDLE_CMETH_USDE = chain.getLendingController(Lenders.LENDLE_CMETH_USDE);
        LENDLE_CMETH_WMNT = chain.getLendingController(Lenders.LENDLE_CMETH_WMNT);
        LENDLE_FBTC_WETH = chain.getLendingController(Lenders.LENDLE_FBTC_WETH);
        LENDLE_FBTC_USDE = chain.getLendingController(Lenders.LENDLE_FBTC_USDE);
        LENDLE_FBTC_WMNT = chain.getLendingController(Lenders.LENDLE_FBTC_WMNT);
        LENDLE_WMNT_WETH = chain.getLendingController(Lenders.LENDLE_WMNT_WETH);
        LENDLE_WMNT_USDE = chain.getLendingController(Lenders.LENDLE_WMNT_USDE);

        // Get token addresses
        USDC = chain.getTokenAddress(Tokens.USDC);
    }

    function populateValidPools() internal {
        validPools.push(PoolCase({poolId: 82, poolAddr: KINZA, asset: USDC}));
        validPools.push(PoolCase({poolId: 102, poolAddr: LENDLE_CMETH, asset: USDC}));
        validPools.push(PoolCase({poolId: 103, poolAddr: LENDLE_PT_CMETH, asset: USDC}));
        validPools.push(PoolCase({poolId: 104, poolAddr: LENDLE_SUSDE, asset: USDC}));
        validPools.push(PoolCase({poolId: 105, poolAddr: LENDLE_SUSDE_USDT, asset: USDC}));
        validPools.push(PoolCase({poolId: 106, poolAddr: LENDLE_METH_WETH, asset: USDC}));
        validPools.push(PoolCase({poolId: 107, poolAddr: LENDLE_METH_USDE, asset: USDC}));
        validPools.push(PoolCase({poolId: 108, poolAddr: LENDLE_CMETH_WETH, asset: USDC}));
        validPools.push(PoolCase({poolId: 109, poolAddr: LENDLE_CMETH_USDE, asset: USDC}));
        validPools.push(PoolCase({poolId: 110, poolAddr: LENDLE_CMETH_WMNT, asset: USDC}));
        validPools.push(PoolCase({poolId: 111, poolAddr: LENDLE_FBTC_WETH, asset: USDC}));
        validPools.push(PoolCase({poolId: 112, poolAddr: LENDLE_FBTC_USDE, asset: USDC}));
        validPools.push(PoolCase({poolId: 113, poolAddr: LENDLE_FBTC_WMNT, asset: USDC}));
        validPools.push(PoolCase({poolId: 114, poolAddr: LENDLE_WMNT_WETH, asset: USDC}));
        validPools.push(PoolCase({poolId: 115, poolAddr: LENDLE_WMNT_USDE, asset: USDC}));
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
