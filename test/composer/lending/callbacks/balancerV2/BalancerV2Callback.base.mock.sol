// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {console} from "forge-std/console.sol";
import {Vm} from "forge-std/Vm.sol";
import {Chains, Lenders, Tokens} from "test/data/LenderRegistry.sol";
import {DeltaErrors} from "contracts/1delta/shared/errors/Errors.sol";
import {ComposerPlugin, IComposerLike} from "plugins/ComposerPlugin.sol";
import {CalldataLib} from "contracts/utils/CalldataLib.sol";
import {BaseTest} from "test/shared/BaseTest.sol";
import {Slots} from "contracts/1delta/composer/slots/Slots.sol";
import {BalancerV2MockVault, IVault} from "test/mocks/BalancerV2MockVault.sol";
import {SweepType} from "contracts/1delta/composer/enums/MiscEnums.sol";

contract BalancerV2FlashLoanCallbackTest is BaseTest, DeltaErrors, Slots {
    IComposerLike oneDV2;
    BalancerV2MockVault mockVault;

    address private constant BALANCER_V2 = 0xBA12222222228d8Ba445958a75a0704d566BF2C8;
    address private constant SWAAP = 0x03C01Acae3D0173a93d819efDc832C7C4F153B06;

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
        mockVault = new BalancerV2MockVault();
    }

    function test_unit_lending_flashloans_balancerV2_callback_wrongCaller_revert() public {
        replaceLendingPoolWithMock(validPools[0].poolAddr);

        address[] memory tokens = new address[](1);
        tokens[0] = USDC;

        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 1e6;

        vm.prank(user);
        vm.expectRevert(DeltaErrors.INVALID_CALLER);
        IVault(validPools[0].poolAddr).flashLoan(
            address(oneDV2), tokens, amounts, abi.encodePacked(address(user), uint8(validPools[0].poolId))
        );
    }

    function test_unit_lending_flashloans_balancerV2_callback_fuzz_invalidPoolIds(uint8 poolId) public {
        replaceLendingPoolWithMock(BALANCER_V2);

        for (uint256 i = 0; i < validPools.length; i++) {
            if (poolId == validPools[i].poolId) return;
        }

        bytes memory params = CalldataLib.encodeBalancerV2FlashLoan(USDC, 1e6, uint8(poolId), sweepCall());

        vm.prank(user);
        vm.expectRevert();
        oneDV2.deltaCompose(params);
    }

    // Helper Functions
    function sweepCall() internal returns (bytes memory) {
        return CalldataLib.encodeSweep(USDC, user, 0, SweepType.VALIDATE);
    }

    function getAddressFromRegistry() internal {
        // Get token addresses
        USDC = chain.getTokenAddress(Tokens.USDC);
    }

    function populateValidPools() internal {
        validPools.push(PoolCase({poolId: 0, poolAddr: BALANCER_V2, asset: USDC}));
        validPools.push(PoolCase({poolId: 2, poolAddr: SWAAP, asset: USDC}));
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
        vm.etch(poolAddr, address(mockVault).code);
    }
}
