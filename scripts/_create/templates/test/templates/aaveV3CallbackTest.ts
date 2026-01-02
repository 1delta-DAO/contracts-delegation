export const templateAaveV3Test = (chainKey: string, lenders: {entityName: string; entityId: string; pool: string; assetType: string}[]) => {
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
        addressDeclarations += `    address private ${lender.entityName};\n`;

        // Add the token to unique tokens
        uniqueTokens.add(lender.assetType);

        // Add pool entry
        populateValidPools += `        validPools.push(PoolCase({poolId: ${lender.entityId}, poolAddr: ${lender.entityName}, asset: ${lender.assetType}}));\n`;

        // Create an individual test function for each lender
        individualTestFunctions += `
    function test_unit_lending_flashloans_aaveV3_callback_${lender.entityName.toLowerCase()}Pool() public {
        // mock implementation
        replaceLendingPoolWithMock(${lender.entityName});

        bytes memory params = CalldataLib.encodeFlashLoan(${lender.assetType}, 1e6, ${lender.entityName}, uint8(2), uint8(${
            lender.entityId
        }), sweepCall());

        vm.prank(user);
        oneDV2.deltaCompose(params);
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

${addressDeclarations}
${tokenDeclarations}

    struct PoolCase {
        uint8 poolId;
        address poolAddr;
        address asset; // The specific asset for each pool to lend, not used in this test, can be used with chain forking
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
        mockPool = new AaveMockPool();
    }
${individualTestFunctions}
    function test_unit_lending_flashloans_aaveV3_callback_wrongCallerRevert() public {
        for (uint256 i = 0; i < validPools.length; i++) {
            bytes memory params = CalldataLib.encodeFlashLoan(${
                uniqueTokens.values().next().value || "address(0)"
            }, 1e6, address(mockPool), uint8(2), uint8(validPools[0].poolId), sweepCall());

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
            IAavePool(pc.poolAddr).flashLoanSimple(address(oneDV2), ${
                uniqueTokens.values().next().value || "address(0)"
            }, 1e6, abi.encodePacked(address(user), pc.poolId), 0);
        }
    }

    function test_unit_lending_flashloans_aaveV3_callback_fuzzInvalidPoolIds(uint8 poolId) public {
        replaceLendingPoolWithMock(${lenders[0]?.entityName || "address(0)"});

        for (uint256 i = 0; i < validPools.length; i++) {
            if (poolId == validPools[i].poolId) return;
        }
        bytes memory params = CalldataLib.encodeFlashLoan(${uniqueTokens.values().next().value || "address(0)"}, 1e6, ${
            lenders[0]?.entityName || "address(0)"
        }, uint8(2), uint8(poolId), sweepCall());
        vm.prank(user);
        vm.expectRevert(DeltaErrors.INVALID_FLASH_LOAN);
        oneDV2.deltaCompose(params);
    }

    // Helper Functions
        function sweepCall() internal returns (bytes memory){
        return CalldataLib.encodeSweep(${uniqueTokens.values().next().value || "address(0)"}, user, 0, SweepType.VALIDATE);
    }

    function getAddressFromRegistry() internal {
${lenders.map((lender) => `        ${lender.entityName} = chain.getLendingController(Lenders.${lender.entityName});`).join("\n")}

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
        vm.etch(poolAddr, address(mockPool).code);
    }
}
`;
};
