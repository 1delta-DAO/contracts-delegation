// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "forge-std/Test.sol";
import "forge-std/console.sol";

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/interfaces/IERC4626.sol";

contract BalancerFlashLoanTest is Test {
    address constant BALANCER_VAULT = 0xbA1333333333a1BA1108E8412f11850A5C319bA9;
    address constant AAVE_POOL = 0xA238Dd80C259a72e81d7e4664a9801593F98d1c5;

    address constant WABASGHO = 0x88b1Cd4b430D95b406E382C3cDBaE54697a0286E;
    address constant ABASGHO = 0x067ae75628177FD257c2B1e500993e1a0baBcBd1;
    address constant GHO = 0x6Bb7a212910682DCFdbd5BCBb3e28FB4E8da10Ee;

    IVault vault;
    IPool aavePool;
    IERC20 waBasGHOToken;
    IERC20 aBasGHOToken;
    IERC20 ghoToken;

    uint256 flashLoanAmount;

    function setUp() public {
        string memory rpcUrl = "wss://base-rpc.publicnode.com";
        vm.createSelectFork(rpcUrl);

        vault = IVault(BALANCER_VAULT);
        aavePool = IPool(AAVE_POOL);
        waBasGHOToken = IERC20(WABASGHO);
        aBasGHOToken = IERC20(ABASGHO);
        ghoToken = IERC20(GHO);

        vm.label(BALANCER_VAULT, "Balancer Vault");
        vm.label(AAVE_POOL, "Aave Pool");
        vm.label(WABASGHO, "waBasGHO");
        vm.label(ABASGHO, "aBasGHO");
        vm.label(GHO, "GHO");
    }

    function testWaBasGHOToGHOUnwrapping(uint256 amount) public {
        // uint256 reserves = vault.getReservesOf(waBasGHOToken);
        // console.log("waBasGHOToken reserves:", reserves);

        amount = bound(amount, 1 ether, 100 ether);

        console.log("Starting unwrap test with amount:", amount);

        IVault.BufferWrapOrUnwrapParams memory unwrapParams = IVault.BufferWrapOrUnwrapParams({
            kind: IVault.SwapKind.EXACT_IN,
            direction: IVault.WrappingDirection.UNWRAP,
            wrappedToken: IERC4626(WABASGHO),
            amountGivenRaw: amount,
            limitRaw: 0 // todo: minimum limit, zero for now
        });

        bytes memory unlockData = abi.encodeWithSelector(this.unlockCallback.selector, unwrapParams);

        bytes memory result = vault.unlock(unlockData);
        bool success = abi.decode(result, (bool));

        assertTrue(success, "Unwrap operation failed");
    }

    function unlockCallback(IVault.BufferWrapOrUnwrapParams memory params) external returns (bool) {
        require(msg.sender == address(vault), "Unauthorized caller");
        console.log("------------------------------------------------");
        uint256 initialGhoBalance = ghoToken.balanceOf(address(vault));
        console.log("Initial GHO balance:", initialGhoBalance);
        uint256 initialWaBasGhoBalance = waBasGHOToken.balanceOf(address(vault));
        console.log("Initial waBasGHO balance:", initialWaBasGhoBalance);
        uint256 initialaBasGhoBalance = aBasGHOToken.balanceOf(address(vault));
        console.log("Initial aBasGHO balance:", initialaBasGhoBalance);
        console.log("------------------------------------------------");

        // Unwrap the tokens
        (uint256 amountCalculated, uint256 amountIn, uint256 amountOut) = vault.erc4626BufferWrapOrUnwrap(params);
        console.log("Unwrap result");
        console.log("calculated:", amountCalculated);
        console.log("in:", amountIn);
        console.log("out:", amountOut);
        console.log("------------------------------------------------");
        uint256 finalGhoBalance = ghoToken.balanceOf(address(vault));
        console.log("Final GHO balance:", finalGhoBalance);
        uint256 finalWaBasGhoBalance = waBasGHOToken.balanceOf(address(vault));
        console.log("Final waBasGHO balance:", finalWaBasGhoBalance);
        uint256 finalaBasGhoBalance = aBasGHOToken.balanceOf(address(vault));
        console.log("Final aBasGHO balance:", finalaBasGhoBalance);
        console.log("------------------------------------------------");

        uint256 amountToSettle = finalGhoBalance - initialGhoBalance; // the amount unwrapped

        uint256 accountGhoBalanceBefore = ghoToken.balanceOf(address(this));
        console.log("Account GHO balance before:", accountGhoBalanceBefore);

        vault.sendTo(ghoToken, address(this), amountToSettle);

        uint256 accountGhoBalanceAfter = ghoToken.balanceOf(address(this));
        console.log("Account GHO balance after:", accountGhoBalanceAfter);
        console.log("------------------------------------------------");

        // settle
        vault.settle(ghoToken, amountToSettle);

        return true;
    }
}

// structs and interfaces

struct ReserveData {
    ReserveConfigurationMap configuration;
    uint128 liquidityIndex;
    uint128 currentLiquidityRate;
    uint128 variableBorrowIndex;
    uint128 currentVariableBorrowRate;
    uint128 currentStableBorrowRate;
    uint40 lastUpdateTimestamp;
    uint16 id;
    address aTokenAddress;
    address stableDebtTokenAddress;
    address variableDebtTokenAddress;
    address interestRateStrategyAddress;
    uint128 availableLiquidity;
    uint128 totalStableDebt;
    uint128 totalVariableDebt;
}

struct ReserveConfigurationMap {
    uint256 data;
}

interface IPool {
    function getReserveData(address asset) external view returns (ReserveData memory);
    function withdraw(address token, uint256 amount, address to) external returns (uint256);
    function supply(address token, uint256 amount, address to, uint256 referralCode) external;
}

interface IVault {
    enum SwapKind {
        EXACT_IN,
        EXACT_OUT
    }
    enum WrappingDirection {
        WRAP,
        UNWRAP
    }

    struct BufferWrapOrUnwrapParams {
        SwapKind kind;
        WrappingDirection direction;
        IERC4626 wrappedToken;
        uint256 amountGivenRaw;
        uint256 limitRaw;
    }

    function sendTo(IERC20 token, address to, uint256 amount) external;
    function settle(IERC20 token, uint256 amountHint) external returns (uint256 credit);
    function unlock(bytes calldata data) external returns (bytes memory result);
    function getReservesOf(IERC20 token) external view returns (uint256 reserveAmount);
    function erc4626BufferWrapOrUnwrap(BufferWrapOrUnwrapParams memory params)
        external
        returns (uint256 amountCalculatedRaw, uint256 amountInRaw, uint256 amountOutRaw);
}
