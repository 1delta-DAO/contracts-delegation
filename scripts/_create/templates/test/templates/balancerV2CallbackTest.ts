import {getAddress} from "ethers/lib/utils";

export const templateBalancerV2Test = (
    chainKey: string,
    lenders: {entityName: string; entityId: string; pool: string; assetType: string}[],
    isCancun = false,
) => {
    // Generate private address declarations
    let addressDeclarations = "";
    let tokenDeclarations = "";
    let mockTokens = "";
    let populateValidPools = "";
    let individualTestFunctions = "";

    // Collect unique token types from the lenders
    const uniqueTokens = new Set<string>();

    // Generate address declarations for all lenders
    lenders.forEach((lender) => {
        addressDeclarations += `    address private constant ${lender.entityName} = ${getAddress(lender.pool)};\n`;

        // Add the token to unique tokens
        uniqueTokens.add(lender.assetType);

        // Add pool entry
        populateValidPools += `        validPools.push(PoolCase({poolId: ${lender.entityId}, poolAddr: ${lender.entityName}, asset: ${lender.assetType}}));\n`;

        // Create an individual test function for each lender
        individualTestFunctions += isCancun
            ? ``
            : `
    function test_unit_lending_flashloans_balancerV2_callback_${lender.entityName.toLowerCase()}Pool() public {
        // mock implementation
        replaceLendingPoolWithMock(${lender.entityName});

        bytes memory params = CalldataLib.encodeBalancerV2FlashLoan(${lender.assetType}, 1e6, uint8(${lender.entityId}), sweepCall());
        
        // check gateway flag is 0
        assertEq(uint256(vm.load(address(oneDV2), bytes32(uint256(FLASH_LOAN_GATEWAY_SLOT)))), 0);

        vm.prank(user);
        oneDV2.deltaCompose(params);
        
        // Verify gateway flag is set to 1 after the callback
        assertEq(uint256(vm.load(address(oneDV2), bytes32(uint256(FLASH_LOAN_GATEWAY_SLOT)))), 1);
    }
`;
    });

    // Generate token declaration statements
    uniqueTokens.forEach((token) => {
        tokenDeclarations += `    address private ${token};\n`;
        mockTokens += `        mockERC20Functions(${token});\n`;
    });

    return `
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Chains, Tokens} from "test/data/LenderRegistry.sol";
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

${addressDeclarations}
${tokenDeclarations}

    struct PoolCase {
        uint8 poolId;
        address poolAddr;
        address asset;
    }

    PoolCase[] validPools;

    function setUp() public virtual {
        string memory chainName = Chains.${chainKey};

        // Initialize chain (for token info) with no forking
        _init(chainName, 0, false);

        getAddressFromRegistry();

        mockERC20FunctionsForAllTokens();

        populateValidPools();

        oneDV2 = ComposerPlugin.getComposer(chainName);
        mockVault = new BalancerV2MockVault();
    }
${individualTestFunctions}
    function test_unit_lending_flashloans_balancerV2_callback_wrongCallerRevert() public {
                replaceLendingPoolWithMock(validPools[0].poolAddr);

        address[] memory tokens = new address[](1);
        tokens[0] = ${uniqueTokens.values().next().value || "address(0)"};

        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 1e6;

        vm.prank(user);
        vm.expectRevert(DeltaErrors.INVALID_CALLER);
        IVault(validPools[0].poolAddr).flashLoan(address(oneDV2), tokens, amounts, abi.encodePacked(address(user), uint8(validPools[0].poolId)));
    }


    function test_unit_lending_flashloans_balancerV2_callback_fuzzInvalidPoolIds(uint8 poolId) public {
        replaceLendingPoolWithMock(${lenders[0]?.entityName || "address(0)"});

        for (uint256 i = 0; i < validPools.length; i++) {
            if (poolId == validPools[i].poolId) return;
        }
        
        bytes memory params = CalldataLib.encodeBalancerV2FlashLoan(${
            uniqueTokens.values().next().value || "address(0)"
        }, 1e6, uint8(poolId), sweepCall());
        
        vm.prank(user);
        vm.expectRevert();
        oneDV2.deltaCompose(params);
    }

    // Helper Functions
    function sweepCall() internal returns (bytes memory){
        return CalldataLib.encodeSweep(${uniqueTokens.values().next().value || "address(0)"}, user, 0, SweepType.VALIDATE);
    }
    function getAddressFromRegistry() internal {
        // Get token addresses
${Array.from(uniqueTokens)
    .map((token) => `        ${token} = chain.getTokenAddress(Tokens.${token});`)
    .join("\n")}
    }

    function populateValidPools() internal {
${populateValidPools}
    }

    function mockERC20FunctionsForAllTokens() internal {
${mockTokens}
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
`;
};
