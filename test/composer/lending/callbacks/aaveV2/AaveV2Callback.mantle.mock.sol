
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

    address private LENDLE;
    address private AURELIUS;

    address private USDC;


    struct PoolCase {
        uint8 poolId;
        address poolAddr;
        address asset;
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
        mockPool = new AaveV2MockPool();
    }

    function test_unit_lending_flashloans_aaveV2_callback_lendlePool() public {

    replaceLendingPoolWithMock(LENDLE);

        bytes memory params = CalldataLib.encodeFlashLoan(USDC, 1e6, LENDLE, uint8(3), uint8(1), sweepCall());

        vm.prank(user);
        oneDV2.deltaCompose(params);
    }

    function test_unit_lending_flashloans_aaveV2_callback_aureliusPool() public {

    replaceLendingPoolWithMock(AURELIUS);

        bytes memory params = CalldataLib.encodeFlashLoan(USDC, 1e6, AURELIUS, uint8(3), uint8(2), sweepCall());

        vm.prank(user);
        oneDV2.deltaCompose(params);
    }

    function test_unit_lending_flashloans_aaveV2_callback_wrongCallerRevert() public {
        bytes memory params = CalldataLib.encodeFlashLoan(USDC, 1e6, address(mockPool), uint8(3), uint8(1), sweepCall());

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
            address(oneDV2),
            assets,
            amounts,
            modes,
            address(0),
            abi.encodePacked(address(user), pc.poolId),
            0
        );
    }

    function test_unit_lending_flashloans_aaveV2_callback_fuzzInvalidPoolIds(uint8 poolId) public {
        replaceLendingPoolWithMock(LENDLE);

        for (uint256 i = 0; i < validPools.length; i++) {
            if (poolId == validPools[i].poolId) return;
        }
        bytes memory params = CalldataLib.encodeFlashLoan(USDC, 1e6, LENDLE, uint8(3), uint8(poolId), sweepCall());
        vm.prank(user);
        vm.expectRevert(DeltaErrors.INVALID_FLASH_LOAN);
        oneDV2.deltaCompose(params);
    }

    // Helper Functions
        function sweepCall() internal returns (bytes memory){
        return CalldataLib.encodeSweep(USDC, user, 0, SweepType.VALIDATE);
    }

    function getAddressFromRegistry() internal {
        LENDLE = chain.getLendingController(Lenders.LENDLE);
        AURELIUS = chain.getLendingController(Lenders.AURELIUS);

        // Get token addresses
        USDC = chain.getTokenAddress(Tokens.USDC);
    }

    function populateValidPools() internal {
        validPools.push(PoolCase({poolId: 1, poolAddr: LENDLE, asset: USDC}));
        validPools.push(PoolCase({poolId: 2, poolAddr: AURELIUS, asset: USDC}));

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
