// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import "forge-std/Test.sol";
import {FlashAccountWithRegistry} from "@flash-account/AdapterWithRegistry/FlashAccountWithRegistry.sol";
import {BenqiAdapter} from "@flash-account/AdapterWithRegistry/adapters/BenqiAdapter.sol";
import {LendingAdapterRegistry} from "@flash-account/AdapterWithRegistry/LendingAdapterRegistry.sol";
import {ILendingProvider} from "@flash-account/interfaces/ILendingProvider.sol";
import {IEntryPoint} from "account-abstraction/interfaces/IEntryPoint.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/// @title TestBenqi_WithRegistery
/// @notice Test the BenqiAdapter with the LendingAdapterRegistry
/// @dev The test uses the deployed contracts on Avalanche C-Chain (entrypoint, comptroller, USDC, qiUSDC)
contract BenqiAdapterTest is Test {
    address constant ENTRY_POINT = 0x5FF137D4b0FDCD49DcA30c7CF57E578a026d2789;
    address constant BENQI_COMPTROLLER = 0x486Af39519B4Dc9a7fCcd318217352830E8AD9b4;
    address constant USDC = 0xB97EF9Ef8734C71904D8002F8b6Bc66Dd9c48a6E;
    address constant qiUSDC = 0xB715808a78F6041E46d61Cb123C9B4A27056AE9C;

    FlashAccountWithRegistry account;
    BenqiAdapter benqiAdapter;
    LendingAdapterRegistry registry;

    address user = address(0x1de17a);

    function setUp() public {
        string memory rpcUrl = vm.envString("AVAX_RPC_URL");
        uint256 chainFork = vm.createSelectFork(rpcUrl); // , 40840732);

        registry = new LendingAdapterRegistry();
        benqiAdapter = new BenqiAdapter();
        account = new FlashAccountWithRegistry(IEntryPoint(ENTRY_POINT), address(registry));

        // Register adapter
        registry.registerAdapter(address(benqiAdapter), BENQI_COMPTROLLER);

        deal(USDC, user, 1000e6);

        vm.prank(user);
        IERC20(USDC).approve(address(account), 1000e6);
    }
    function testSupply() public {
        // supply 100 USDC
        ILendingProvider.LendingParams memory params = ILendingProvider.LendingParams({
            caller: user,
            lender: BENQI_COMPTROLLER,
            asset: USDC,
            collateralToken: qiUSDC,
            amount: 100e6,
            params: ""
        });

        vm.prank(user);
        account.supply(params);

        uint256 qiBalance = IERC20(qiUSDC).balanceOf(address(account));
        assertGt(qiBalance, 0, "No qiUSDC received");
    }

    function testSupplyAll() public {
        uint256 initQiBalance = IERC20(qiUSDC).balanceOf(address(account));
        assertEq(initQiBalance, 0);
        // when the amount is 0, all the balance of the account is supplied
        deal(USDC, address(account), 100e6);
        // supply 100 USDC
        ILendingProvider.LendingParams memory params = ILendingProvider.LendingParams({
            caller: user,
            lender: BENQI_COMPTROLLER,
            asset: USDC,
            collateralToken: qiUSDC,
            amount: 0,
            params: ""
        });

        vm.prank(user);
        account.supply(params);

        uint256 qiBalance = IERC20(qiUSDC).balanceOf(address(account));
        assertGt(qiBalance, 0, "No qiUSDC received");
    }

    function testWithdraw() public {
        testSupply();

        uint256 initialQiUSDCBalance = IERC20(qiUSDC).balanceOf(address(account));
        uint256 initialUsdcBalance = IERC20(USDC).balanceOf(user);

        ILendingProvider.LendingParams memory params = ILendingProvider.LendingParams({
            caller: user,
            lender: BENQI_COMPTROLLER,
            asset: USDC,
            collateralToken: qiUSDC,
            amount: initialQiUSDCBalance / 2, // Withdraw half
            params: ""
        });

        vm.prank(user);
        account.withdraw(params);

        uint256 finalQiBalance = IERC20(qiUSDC).balanceOf(address(account));
        uint256 finalUsdcBalance = IERC20(USDC).balanceOf(user);

        assertLt(finalQiBalance, initialQiUSDCBalance, "qiUSDC balance not decreased");
        assertGt(finalUsdcBalance, initialUsdcBalance, "USDC balance not increased");
    }

    function testWithdrawAll() public {
        testSupply(); // supply 100 USDC

        uint256 initialUsdcBalance = IERC20(USDC).balanceOf(user);
        uint256 initialQiUSDCBalance = IERC20(qiUSDC).balanceOf(address(account));

        // warp time 100 days
        vm.warp(block.timestamp + 100 days);

        ILendingProvider.LendingParams memory params = ILendingProvider.LendingParams({
            caller: user,
            lender: BENQI_COMPTROLLER,
            asset: USDC,
            collateralToken: qiUSDC,
            amount: 0, // Withdraw All
            params: ""
        });

        vm.prank(user);
        account.withdraw(params);

        uint256 finalQiBalance = IERC20(qiUSDC).balanceOf(address(account));
        uint256 finalUsdcBalance = IERC20(USDC).balanceOf(user);

        assertEq(finalQiBalance, 0); // no dust
        assertGt(finalUsdcBalance, 100e6 + initialUsdcBalance, "USDC balance not increased"); // interest should be accrued and the final amount should be greater than 100 usdc
    }
    // Todo: add test for amount=0
    function testBorrow() public {
        testSupply();

        uint256 initialUsdcBalance = IERC20(USDC).balanceOf(user);

        // borrow 10 USDC
        ILendingProvider.LendingParams memory params = ILendingProvider.LendingParams({
            caller: user,
            lender: BENQI_COMPTROLLER,
            asset: USDC,
            collateralToken: qiUSDC,
            amount: 10e6,
            params: ""
        });

        vm.prank(user);
        account.borrow(params);

        uint256 finalUsdcBalance = IERC20(USDC).balanceOf(user);
        assertEq(finalUsdcBalance, initialUsdcBalance + 10e6, "USDC balance not increased");
    }

    // Todo: add test for amount=0
    function testRepay() public {
        testBorrow();

        uint256 initialUsdcBalance = IERC20(USDC).balanceOf(user);
        vm.prank(user);
        IERC20(USDC).transfer(address(account), initialUsdcBalance);

        // repay 5 USDC
        ILendingProvider.LendingParams memory params = ILendingProvider.LendingParams({
            caller: user,
            lender: BENQI_COMPTROLLER,
            asset: USDC,
            collateralToken: qiUSDC,
            amount: 5e6,
            params: ""
        });

        vm.prank(user);
        account.repay(params);

        uint256 finalUsdcBalance = IERC20(USDC).balanceOf(user);
        assertLt(finalUsdcBalance, initialUsdcBalance, "USDC balance not decreased");
    }
}
