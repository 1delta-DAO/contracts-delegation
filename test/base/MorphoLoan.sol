// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {Test} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";
import {ComposerUtils, Commands} from "../shared/utils/ComposerUtils.sol";

import {OneDeltaComposerBase} from "../../contracts/1delta/modules/base/Composer.sol";
import {IERC20All} from "../shared/interfaces/IERC20All.sol";

struct MarketParams {
    address loanToken;
    address collateralToken;
    address oracle;
    address irm;
    uint256 lltv;
}

/// @title IMorphoFlashLoanCallback
/// @notice Interface that users willing to use `flashLoan`'s callback must implement.
interface IMorphoFlashLoanCallback {
    function onMorphoFlashLoan(uint256 assets, bytes calldata data) external;

    function flashLoan(address token, uint256 assets, bytes calldata data) external;

    function supply(
        MarketParams memory marketParams,
        uint256 assets,
        uint256 shares,
        address onBehalf,
        bytes memory data
    ) external returns (uint256 assetsSupplied, uint256 sharesSupplied);

    function withdraw(
        MarketParams memory marketParams,
        uint256 assets,
        uint256 shares,
        address onBehalf,
        address receiver
    ) external returns (uint256 assetsWithdrawn, uint256 sharesWithdrawn);

    function borrow(
        MarketParams memory marketParams,
        uint256 assets,
        uint256 shares,
        address onBehalf,
        address receiver
    ) external returns (uint256 assetsBorrowed, uint256 sharesBorrowed);

    function repay(
        MarketParams memory marketParams,
        uint256 assets,
        uint256 shares,
        address onBehalf,
        bytes memory data
    ) external returns (uint256 assetsRepaid, uint256 sharesRepaid);

    function supplyCollateral(
        MarketParams memory marketParams,
        uint256 assets,
        address onBehalf, //
        bytes memory data
    ) external;

    function withdrawCollateral(MarketParams memory marketParams, uint256 assets, address onBehalf, address receiver) external;

    function setAuthorization(address authorized, bool newIsAuthorized) external;

    function position(bytes32 id, address user) external view returns (uint256 supplyShares, uint128 borrowShares, uint128 collateral);
}

/**
 * We test flash swap executions using exact in trade types (given that the first pool supports flash swaps)
 * These are always applied on margin, however, we make sure that we always get
 * The expected amounts. Exact out swaps always execute flash swaps whenever possible.
 */
contract FlashLoanTestMorpho is Test, ComposerUtils {
    OneDeltaComposerBase oneD;

    address internal constant user = address(984327);

    address internal constant LBTC = 0xecAc9C5F704e954931349Da37F60E39f515c11c1;
    address internal constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;

    MarketParams LBTC_USDC_MARKET =
        MarketParams(
            USDC,
            LBTC,
            0x6E877Ff82A5ED6cB4f4789c27D9F9B1d54388e4F,
            0x46415998764C29aB2a25CbeA6254146D50D22687,
            860000000000000000 //
        );

    address internal constant MORPHO = 0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb;

    function setUp() public virtual {
        vm.createSelectFork({blockNumber: 26696865, urlOrAlias: "https://mainnet.base.org"});
        oneD = new OneDeltaComposerBase();
    }

    function test_base_flsah_loan_morpho() external {
        address asset = 0x4200000000000000000000000000000000000006;
        uint256 sweepAm = 30.0e18;
        vm.deal(address(oneD), 30.0e18);
        uint256 amount = 11111;
        bytes memory dp = sweep(
            address(0),
            user,
            sweepAm, //
            SweepType.AMOUNT
        );

        bytes memory d = encodeFlashLoan(
            asset,
            amount,
            uint8(254), //
            dp
        );
        oneD.deltaCompose(d);

        vm.expectRevert();
        oneD.onMorphoFlashLoan(0, d);
    }

    function test_morpho_borrow() external {
        deal(LBTC, user, 30.0e8);
        deal(USDC, user, 300_000.0e6);

        uint assets = 1.0e8;

        address borrowAsset = USDC;
        uint borrowAssets = 30_000.0e6;
        depositToMorpho(user, assets);

        bytes memory borrowCall = morphoBorrow(
            encodeMarket(LBTC_USDC_MARKET),
            false,
            borrowAssets, //
            user,
            hex""
        );

        vm.prank(user);
        IMorphoFlashLoanCallback(MORPHO).setAuthorization(address(oneD), true);

        uint bal = IERC20All(borrowAsset).balanceOf(user);

        vm.prank(user);
        oneD.deltaCompose(borrowCall);

        uint balAf = IERC20All(borrowAsset).balanceOf(user);

        assertApproxEqAbs(balAf - bal, borrowAssets, 0);
        // (, , uint128 collateralAmount) = IMorphoFlashLoanCallback(MORPHO).position(marketId(LBTC_USDC_MARKET), user);
    }

    function test_morpho_deposit() external {
        deal(LBTC, user, 30.0e8);
        deal(USDC, user, 300_000.0e6);

        uint assets = 1.0e8;

        address collateral = LBTC;
        bytes memory transferTo = transferIn(
            collateral,
            address(oneD),
            assets //
        );

        bytes memory deposit = morphoDeposit(encodeMarket(LBTC_USDC_MARKET), assets, hex"");
        vm.prank(user);
        IERC20All(collateral).approve(address(oneD), type(uint).max);

        vm.prank(user);
        oneD.deltaCompose(abi.encodePacked(transferTo, deposit));
        (, , uint128 collateralAmount) = IMorphoFlashLoanCallback(MORPHO).position(marketId(LBTC_USDC_MARKET), user);
        assertApproxEqAbs(assets, collateralAmount, 0);
    }

    function encodeMarket(MarketParams memory m) internal pure returns (bytes memory) {
        return abi.encodePacked(m.loanToken, m.collateralToken, m.oracle, m.irm, uint128(m.lltv));
    }

    function depositToMorpho(address userAddr, uint amount) internal {
        address collateral = LBTC;
        bytes memory transferTo = transferIn(
            collateral,
            address(oneD),
            amount //
        );

        bytes memory deposit = morphoDeposit(encodeMarket(LBTC_USDC_MARKET), amount, hex"");
        vm.prank(userAddr);
        IERC20All(collateral).approve(address(oneD), type(uint).max);

        vm.prank(userAddr);
        oneD.deltaCompose(abi.encodePacked(transferTo, deposit));
    }

    function test_base_params() external {
        address onBehalf = 0x937Ce2d6c488b361825D2DB5e8A70e26d48afEd5;
        uint256 assets = 543978;
        uint256 shares = 9753284975432;
        MarketParams memory market = MarketParams(
            0x4200000000000000000000000000000000000006,
            0x4200000000000000000000000000000000000007,
            0x4200000000000000000000000000000000000008,
            0x4200000000000000000000000000000000000009,
            860000000000000000
        );

        bytes memory dp = sweep(
            address(0),
            onBehalf,
            assets, //
            SweepType.AMOUNT
        );
        console.log(dp.length);
        console.logBytes(abi.encodeWithSelector(IMorphoFlashLoanCallback.supplyCollateral.selector, market, assets, onBehalf, dp));
    }

    /// @notice Returns the id of the market `marketParams`.
    function marketId(MarketParams memory marketParams) internal pure returns (bytes32 marketParamsId) {
        assembly ("memory-safe") {
            marketParamsId := keccak256(marketParams, mul(5, 32))
        }
    }

    // 0x238d6579
    // 0000000000000000000000004200000000000000000000000000000000000006
    // 0000000000000000000000004200000000000000000000000000000000000007
    // 0000000000000000000000004200000000000000000000000000000000000008
    // 0000000000000000000000004200000000000000000000000000000000000009
    // 0000000000000000000000000000000000000000000000000bef55718ad60000
    // 0000000000000000000000000000000000000000000000000000000000084cea
    // 000000000000000000000000937ce2d6c488b361825d2db5e8a70e26d48afed5
    // 0000000000000000000000000000000000000000000000000000000000000100
    // 0000000000000000000000000000000000000000000000000000000000000038
    // 220000000000000000000000000000000000000000937ce2d6c488b361825d2d
    // b5e8a70e26d48afed5020000000000000000000000084cea0000000000000000
}
