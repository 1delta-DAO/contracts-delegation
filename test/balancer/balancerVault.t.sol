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

    address constant WETH = 0x4200000000000000000000000000000000000006;

    /**
     * rounding error for the flash loan due to ERC4626 usage
     * balancer adds a layer of deviation by 1
     * the (stata) vault has also one on withdrawal, making 2
     * then, once we have GHO, we add another one by creating the stata token, totalling to 3 at most
     */
    uint256 internal constant ROUNDING_ERROR = 3;

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

        amount = bound(amount, 100 ether, 1000 ether);

        console.log("Starting unwrap test with amount:", amount);

        // note that this is to ensure that this
        {
            // deal(address(ghoToken), address(this), 10);
            deal(WETH, address(this), 100 ether);

            IERC20(WETH).approve(AAVE_POOL, type(uint256).max);
            aavePool.supply(WETH, 1 ether, address(this), 0);
            aavePool.borrow(GHO, ROUNDING_ERROR, 2, 0, address(this));
        }
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
        // vault.sendTo(params.wrappedToken, address(this), params.amountGivenRaw);
        console.log("Initial GHO balance:", initialGhoBalance);
        uint256 initialWaBasGhoBalance = waBasGHOToken.balanceOf(address(vault));
        console.log("Initial waBasGHO balance:", initialWaBasGhoBalance);
        uint256 initialaBasGhoBalance = aBasGHOToken.balanceOf(address(vault));
        console.log("Initial aBasGHO balance:", initialaBasGhoBalance);
        console.log("------------------------------------------------");

        console.log("waBasGHOToken.balanceOf(address(this)", waBasGHOToken.balanceOf(address(this)));

        // Unwrap the tokens using balancer
        (uint256 amountCalculated, uint256 amountIn, uint256 amountOut) = vault.erc4626BufferWrapOrUnwrap(params);

        // take gho
        vault.sendTo(ghoToken, address(this), amountOut);

        uint256 amountToSettle = amountOut + ROUNDING_ERROR; // inalGhoBalance - initialGhoBalance; // the amount unwrapped

        uint256 accountGhoBalanceBefore = ghoToken.balanceOf(address(this));
        console.log("Account GHO balance before:", accountGhoBalanceBefore);

        console.log("amountToSettle:", amountToSettle);

        // settlement process
        {
            ghoToken.approve(AAVE_POOL, type(uint256).max);
            aavePool.supply(GHO, amountToSettle, address(this), 0);
            aBasGHOToken.approve(WABASGHO, type(uint256).max);
            IStataVault(WABASGHO).depositATokens(amountToSettle, address(this));
            waBasGHOToken.transfer(address(vault), amountIn);
        }
        // settle
        vault.settle(waBasGHOToken, amountIn);

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
    function supply(address asset, uint256 amount, address onBehalfOf, uint16 referralCode) external;
    function borrow(address asset, uint256 amount, uint256 interestRateMode, uint16 referralCode, address onBehalfOf) external;
}

interface IStataVault {
    function deposit(uint256 assets, address onBehalfOf) external;
    function depositATokens(uint256 assets, address onBehalfOf) external;
    function redeem(uint256 shares, address receiver, address owner) external returns (uint256);
    function withdraw(uint256 assets, address receiver, address owner) external returns (uint256);
    function redeemATokens(uint256 shares, address receiver, address owner) external returns (uint256);
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
