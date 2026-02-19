// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {ComposerPlugin, IComposerLike} from "plugins/ComposerPlugin.sol";
import {BaseTest} from "test/shared/BaseTest.sol";
import {Chains} from "test/data/LenderRegistry.sol";
import "contracts/utils/CalldataLib.sol";
import {IMorphoEverything} from "../utils/Morpho.sol";
import {MorphoMathLib} from "../utils/MathLib.sol";
import {IERC20All} from "test/shared/interfaces/IERC20All.sol";

contract ListaLendingTest is BaseTest {
    using MorphoMathLib for uint256;
    using MorphoMathLib for uint128;

    IComposerLike oneD;

    uint256 internal constant forkBlock = 0;
    address internal constant LISTA_PROVIDER = 0x367384C54756a25340c63057D87eA22d47Fd5701;
    address internal constant MOOLAH = 0x8F73b65B4caAf64FBA2aF91cC5D4a2A1318E5D8C;

    address internal constant ETH = 0x2416092f143378750bb29b79eD961ab195CcEea5;

    address internal constant USDT = 0x55d398326f99059fF775485246999027B3197955;
    address internal constant WBNB = 0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c;
    address internal constant ORACLE = 0xf3afD82A4071f272F403dC176916141f44E6c750;
    address internal constant IRM = 0xFe7dAe87Ebb11a7BEB9F534BB23267992d9cDe7c;
    uint256 internal constant LLTV = 800000000000000000;
    uint256 internal constant LLTV_2 = 850000000000000000;
    uint256 internal constant LISTA_PID = 0;

    function setUp() public virtual {
        _init(Chains.BNB_SMART_CHAIN_MAINNET, forkBlock, true);
        oneD = ComposerPlugin.getComposer(Chains.BNB_SMART_CHAIN_MAINNET);
    }

    function encodeMarket(
        address loanToken,
        address collateralToken,
        address oracle,
        address irm,
        uint256 lltv
    )
        internal
        pure
        returns (bytes memory)
    {
        return CalldataLib.encodeMorphoMarket(loanToken, collateralToken, oracle, irm, lltv);
    }

    function marketId() internal pure returns (bytes32 id) {
        id = keccak256(abi.encode(USDT, WBNB, ORACLE, IRM, LLTV));
    }

    function test_lista_provider_supply_collateral() external {
        uint256 amount = 0.1 ether;
        vm.deal(address(oneD), amount);
        bytes memory market = encodeMarket(USDT, WBNB, ORACLE, IRM, LLTV);
        bytes memory depositCall =
            CalldataLib.encodeListaSupplyCollateralViaProvider(market, amount, user, "", LISTA_PROVIDER, LISTA_PID);
        uint256 composerBalanceBefore = address(oneD).balance;
        vm.prank(user);
        oneD.deltaCompose(depositCall);
        assertEq(address(oneD).balance, composerBalanceBefore - amount);
        (,, uint128 collateral) = IMorphoEverything(MOOLAH).position(marketId(), user);
        assertEq(collateral, amount);
    }

    function test_lista_provider_supply_collateral_selfbalance() external {
        uint256 amount = 0.1 ether;
        vm.deal(address(oneD), amount);
        bytes memory market = encodeMarket(USDT, WBNB, ORACLE, IRM, LLTV);
        // amount=0 triggers selfbalance() path
        bytes memory depositCall =
            CalldataLib.encodeListaSupplyCollateralViaProvider(market, 0, user, "", LISTA_PROVIDER, LISTA_PID);
        vm.prank(user);
        oneD.deltaCompose(depositCall);
        assertEq(address(oneD).balance, 0);
        (,, uint128 collateral) = IMorphoEverything(MOOLAH).position(marketId(), user);
        assertEq(collateral, amount);
    }

    function test_lista_provider_withdraw_collateral() external {
        uint256 amount = 0.1 ether;
        vm.deal(address(oneD), amount);
        bytes memory market = encodeMarket(USDT, WBNB, ORACLE, IRM, LLTV);
        bytes memory depositCall =
            CalldataLib.encodeListaSupplyCollateralViaProvider(market, amount, user, "", LISTA_PROVIDER, LISTA_PID);
        vm.prank(user);
        oneD.deltaCompose(depositCall);

        (,, uint128 collateralAfterDeposit) = IMorphoEverything(MOOLAH).position(marketId(), user);
        assertEq(collateralAfterDeposit, amount);

        vm.prank(user);
        IMorphoEverything(MOOLAH).setAuthorization(address(oneD), true);
        uint256 withdrawAmount = 0.05 ether;
        bytes memory withdrawCall = CalldataLib.encodeMorphoWithdrawCollateral(market, withdrawAmount, user, LISTA_PROVIDER);
        uint256 userBalanceBefore = user.balance;
        vm.prank(user);
        oneD.deltaCompose(withdrawCall);
        assertEq(user.balance, userBalanceBefore + withdrawAmount);

        (,, uint128 collateralAfterWithdraw) = IMorphoEverything(MOOLAH).position(marketId(), user);
        assertEq(collateralAfterWithdraw, amount - withdrawAmount);
    }

    function depositAndBorrow() internal {
        // collateral: usdt, loan: wbnb
        uint256 collateralAmount = 1e24;
        bytes32 id = keccak256(abi.encode(WBNB, USDT, ORACLE, IRM, LLTV_2)); // loan,collateral,oracle,irm,lltv

        deal(USDT, address(oneD), collateralAmount);
        bytes memory market = encodeMarket(WBNB, USDT, ORACLE, IRM, LLTV_2);
        bytes memory depositCall =
            CalldataLib.encodeMorphoDepositCollateral(market, collateralAmount, user, hex"", MOOLAH, LISTA_PID);
        vm.prank(user);
        oneD.deltaCompose(depositCall);

        vm.prank(user);
        IMorphoEverything(MOOLAH).setAuthorization(address(oneD), true);

        deal(WBNB, address(oneD), 1e24);
        depositCall = abi.encodePacked(
            CalldataLib.encodeApprove(WBNB, address(MOOLAH)),
            CalldataLib.encodeMorphoDeposit(market, false, 1e24, address(this), "", MOOLAH, LISTA_PID)
        );
        oneD.deltaCompose(depositCall); // deposit some loan token to the market

        uint256 borrowAmount = 1 ether;
        bytes memory borrowCall = CalldataLib.encodeMorphoBorrow(market, false, borrowAmount, user, LISTA_PROVIDER);
        vm.prank(user);
        oneD.deltaCompose(borrowCall);

        (, uint128 borrowSharesBefore,) = IMorphoEverything(MOOLAH).position(id, user);
        assertGt(borrowSharesBefore, 0);
    }

    function test_lista_provider_repay_partial_via_provider() external {
        bytes32 id = keccak256(abi.encode(WBNB, USDT, ORACLE, IRM, LLTV_2)); // loan,collateral,oracle,irm,lltv
        depositAndBorrow();

        (, uint128 borrowSharesBefore,) = IMorphoEverything(MOOLAH).position(id, user);

        uint256 repayAmount = 0.5 ether;
        vm.deal(address(oneD), repayAmount);

        bytes memory market = encodeMarket(WBNB, USDT, ORACLE, IRM, LLTV_2);
        bytes memory repayCall =
            CalldataLib.encodeListaRepayViaProvider(market, false, repayAmount, user, hex"", LISTA_PROVIDER, LISTA_PID);

        vm.prank(user);
        oneD.deltaCompose(repayCall);

        (, uint128 borrowSharesAfter,) = IMorphoEverything(MOOLAH).position(id, user);
        assertGt(borrowSharesBefore, borrowSharesAfter);
        assertGt(borrowSharesAfter, 0);
    }

    function test_lista_provider_repay_balance_via_provider() external {
        bytes32 id = keccak256(abi.encode(WBNB, USDT, ORACLE, IRM, LLTV_2)); // loan,collateral,oracle,irm,lltv
        depositAndBorrow();

        (, uint128 borrowSharesBefore,) = IMorphoEverything(MOOLAH).position(id, user);

        uint256 nativeAmount = 0.5 ether;
        // deal 0.5 ether to the composer; amount=0 triggers the selfbalance() repay path
        vm.deal(user, nativeAmount);

        bytes memory market = encodeMarket(WBNB, USDT, ORACLE, IRM, LLTV_2);
        bytes memory repayCall = CalldataLib.encodeListaRepayViaProvider(market, false, 0, user, hex"", LISTA_PROVIDER, LISTA_PID);

        vm.prank(user);
        oneD.deltaCompose{value: nativeAmount}(repayCall);

        (, uint128 borrowSharesAfter,) = IMorphoEverything(MOOLAH).position(id, user);
        assertGt(borrowSharesBefore, borrowSharesAfter);
        assertGt(borrowSharesAfter, 0);
        assertEq(address(oneD).balance, 0);
    }

    function test_lista_provider_repay_max_via_provider() external {
        bytes32 id = keccak256(abi.encode(WBNB, USDT, ORACLE, IRM, LLTV_2)); // loan,collateral,oracle,irm,lltv
        depositAndBorrow();

        vm.deal(address(oneD), 2 ether);

        bytes memory market = encodeMarket(WBNB, USDT, ORACLE, IRM, LLTV_2);
        bytes memory repayCall =
            CalldataLib.encodeListaRepayViaProvider(market, false, type(uint112).max, user, hex"", LISTA_PROVIDER, LISTA_PID);

        vm.prank(user);
        oneD.deltaCompose(repayCall);

        (, uint128 borrowSharesAfter,) = IMorphoEverything(MOOLAH).position(id, user);
        assertEq(borrowSharesAfter, 0);
    }

    function test_lista_provider_borrow_via_provider() external {
        bytes32 id = keccak256(abi.encode(WBNB, USDT, ORACLE, IRM, LLTV_2));

        uint256 collateralAmount = 1e24;
        deal(USDT, address(oneD), collateralAmount);
        bytes memory market = encodeMarket(WBNB, USDT, ORACLE, IRM, LLTV_2);
        bytes memory depositCall =
            CalldataLib.encodeMorphoDepositCollateral(market, collateralAmount, user, hex"", MOOLAH, LISTA_PID);
        vm.prank(user);
        oneD.deltaCompose(depositCall);

        vm.prank(user);
        IMorphoEverything(MOOLAH).setAuthorization(address(oneD), true);

        deal(WBNB, address(oneD), 1e24);
        bytes memory supplyCall = abi.encodePacked(
            CalldataLib.encodeApprove(WBNB, address(MOOLAH)),
            CalldataLib.encodeMorphoDeposit(market, false, 1e24, address(this), "", MOOLAH, LISTA_PID)
        );
        oneD.deltaCompose(supplyCall);

        uint256 borrowAmount = 1 ether;
        uint256 userNativeBalanceBefore = user.balance;
        uint256 userWbnbBalanceBefore = IERC20All(WBNB).balanceOf(user);

        bytes memory borrowCall = CalldataLib.encodeMorphoBorrow(market, false, borrowAmount, user, LISTA_PROVIDER);
        vm.prank(user);
        oneD.deltaCompose(borrowCall);

        (, uint128 borrowShares,) = IMorphoEverything(MOOLAH).position(id, user);
        assertGt(borrowShares, 0);

        (,, uint128 totalBorrowAssets, uint128 totalBorrowShares,,) = IMorphoEverything(MOOLAH).market(id);
        uint256 borrowBalance = borrowShares.toAssetsDown(totalBorrowAssets, totalBorrowShares);
        assertEq(borrowBalance, borrowAmount);

        assertEq(user.balance, userNativeBalanceBefore + borrowAmount);
        assertEq(IERC20All(WBNB).balanceOf(user), userWbnbBalanceBefore);
    }

    function test_lista_provider_withdraw_collateral_max() external {
        uint256 amount = 0.1 ether;
        vm.deal(address(oneD), amount);
        bytes memory market = encodeMarket(USDT, WBNB, ORACLE, IRM, LLTV);
        bytes memory depositCall =
            CalldataLib.encodeListaSupplyCollateralViaProvider(market, amount, user, "", LISTA_PROVIDER, LISTA_PID);
        vm.prank(user);
        oneD.deltaCompose(depositCall);

        (,, uint128 collateralAfterDeposit) = IMorphoEverything(MOOLAH).position(marketId(), user);
        assertEq(collateralAfterDeposit, amount);

        vm.prank(user);
        IMorphoEverything(MOOLAH).setAuthorization(address(oneD), true);

        uint256 userBalanceBefore = user.balance;
        bytes memory withdrawCall =
            CalldataLib.encodeListaWithdrawCollateralViaProvider(market, type(uint112).max, user, LISTA_PROVIDER);
        vm.prank(user);
        oneD.deltaCompose(withdrawCall);

        (,, uint128 collateralAfterWithdraw) = IMorphoEverything(MOOLAH).position(marketId(), user);
        assertEq(collateralAfterWithdraw, 0);

        assertEq(user.balance, userBalanceBefore + amount);
    }

    function test_lista_provider_deposit_collateral_with_callback() external {
        uint256 amount = 0.1 ether;
        vm.deal(address(oneD), amount);
        bytes memory market = encodeMarket(USDT, WBNB, ORACLE, IRM, LLTV);

        uint256 recoverETH = 1.0e18;
        deal(ETH, address(oneD), recoverETH);

        uint256 assets = 1.0e8;

        bytes memory sweepETHInCallback = CalldataLib.encodeSweep(
            ETH,
            user,
            recoverETH,
            SweepType.VALIDATE //
        );

        bytes memory deposit = CalldataLib.encodeListaSupplyCollateralViaProvider(
            market,
            assets,
            user,
            sweepETHInCallback,
            LISTA_PROVIDER, //
            LISTA_PID
        );
        vm.prank(user);
        vm.expectRevert(abi.encodeWithSelector(0x88036ba5));
        oneD.deltaCompose(deposit);
    }
}
