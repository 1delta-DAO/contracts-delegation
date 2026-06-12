// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {ComposerPlugin, IComposerLike} from "plugins/ComposerPlugin.sol";
import {BaseTest} from "test/shared/BaseTest.sol";
import {Chains} from "test/data/LenderRegistry.sol";
import "contracts/utils/CalldataLib.sol";
import {IMorphoEverything, MarketParams} from "../utils/Morpho.sol";
import {IERC20All} from "test/shared/interfaces/IERC20All.sol";

interface IListaBroker {
    struct FixedLoanPosition {
        uint256 posId;
        uint256 principal;
        uint256 apr;
        uint256 start;
        uint256 end;
        uint256 lastRepaidTime;
        uint256 interestRepaid;
        uint256 principalRepaid;
    }

    function userFixedPositions(address user) external view returns (FixedLoanPosition[] memory);
    function getUserTotalDebt(address user) external view returns (uint256);
    function MARKET_ID() external view returns (bytes32);
}

/// @notice Fork tests for the Lista fixed-term `LendingBroker` borrow/repay composer path.
/// Market: WBNB (loan) / slisBNB (collateral); the market oracle IS the broker.
contract ListaBrokerTest is BaseTest {
    IComposerLike oneD;

    uint256 internal constant forkBlock = 0;

    address internal constant MOOLAH = 0x8F73b65B4caAf64FBA2aF91cC5D4a2A1318E5D8C;
    address internal constant BROKER = 0x1Fa26015286D1270343d7526C60bd57aB6bE8b54;
    address internal constant WBNB = 0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c;
    address internal constant slisBNB = 0xB0b84D294e0C75A6abe60171b70edEb2EFd14A1B;
    // for this market the oracle slot is the broker itself
    address internal constant ORACLE = BROKER;
    address internal constant IRM = 0x5F9f9173B405C6CEAfa7f98d09e4B8447e9797E6;
    // collateral supply for this market is gated by the registered slisBNB provider
    address internal constant SLISBNB_PROVIDER = 0x33f7A980a246f9B8FEA2254E3065576E127D4D5f;
    uint256 internal constant LLTV = 965000000000000000;
    uint256 internal constant LISTA_PID = 0;
    uint256 internal constant TERM_7D = 1;

    function setUp() public virtual {
        _init(Chains.BNB_SMART_CHAIN_MAINNET, forkBlock, true);
        oneD = ComposerPlugin.getComposer(Chains.BNB_SMART_CHAIN_MAINNET);
    }

    function market() internal pure returns (bytes memory) {
        return CalldataLib.encodeMorphoMarket(WBNB, slisBNB, ORACLE, IRM, LLTV);
    }

    function marketId() internal pure returns (bytes32) {
        return keccak256(abi.encode(WBNB, slisBNB, ORACLE, IRM, LLTV));
    }

    /// @dev supply slisBNB collateral for `user` and authorize the composer in Moolah.
    ///      Collateral supply is gated by the registered slisBNB provider, so we set up the
    ///      precondition position by acting as that provider (orthogonal to the broker path).
    function _depositCollateralAndAuthorize(uint256 collateralAmount) internal {
        MarketParams memory mp = MarketParams(WBNB, slisBNB, ORACLE, IRM, LLTV);
        deal(slisBNB, SLISBNB_PROVIDER, collateralAmount);
        vm.startPrank(SLISBNB_PROVIDER);
        IERC20All(slisBNB).approve(MOOLAH, collateralAmount);
        IMorphoEverything(MOOLAH).supplyCollateral(mp, collateralAmount, user, "");
        vm.stopPrank();

        // user authorizes the composer; the broker checks isAuthorized(user, composer)
        vm.prank(user);
        IMorphoEverything(MOOLAH).setAuthorization(address(oneD), true);
    }

    function test_lista_broker_borrow_fixed() external {
        assertEq(IListaBroker(BROKER).MARKET_ID(), marketId());

        _depositCollateralAndAuthorize(5 ether);

        uint256 borrowAmount = 1 ether;
        uint256 userWbnbBefore = IERC20All(WBNB).balanceOf(user);

        // receiver = user (the broker forwards the borrowed WBNB as ERC20)
        bytes memory borrowCall = CalldataLib.encodeListaBrokerBorrow(borrowAmount, BROKER, user, TERM_7D);
        vm.prank(user);
        oneD.deltaCompose(borrowCall);

        // a fixed position was created for the caller (onBehalf == authenticated caller)
        IListaBroker.FixedLoanPosition[] memory pos = IListaBroker(BROKER).userFixedPositions(user);
        assertEq(pos.length, 1);
        assertEq(pos[0].principal, borrowAmount);

        // borrowed WBNB landed at the receiver
        assertEq(IERC20All(WBNB).balanceOf(user), userWbnbBefore + borrowAmount);
    }

    function test_lista_broker_repay_fixed_partial() external {
        _depositCollateralAndAuthorize(5 ether);

        uint256 borrowAmount = 1 ether;
        bytes memory borrowCall = CalldataLib.encodeListaBrokerBorrow(borrowAmount, BROKER, address(oneD), TERM_7D);
        vm.prank(user);
        oneD.deltaCompose(borrowCall);

        IListaBroker.FixedLoanPosition[] memory pos = IListaBroker(BROKER).userFixedPositions(user);
        uint256 loanId = pos[0].posId;

        // repay 0.4 WBNB of the position; composer holds the borrowed WBNB
        uint256 repayAmount = 0.4 ether;
        bytes memory repayCall = CalldataLib.encodeListaBrokerRepay(WBNB, repayAmount, false, BROKER, loanId, user);
        vm.prank(user);
        oneD.deltaCompose(repayCall);

        pos = IListaBroker(BROKER).userFixedPositions(user);
        assertEq(pos.length, 1);
        assertGt(pos[0].principalRepaid, 0);
        assertLt(pos[0].principalRepaid, pos[0].principal);
    }

    /// @dev Over-repay: the broker uses only what is owed and refunds the excess to the composer.
    function test_lista_broker_repay_excess_is_refunded() external {
        _depositCollateralAndAuthorize(5 ether);

        uint256 borrowAmount = 1 ether;
        bytes memory borrowCall = CalldataLib.encodeListaBrokerBorrow(borrowAmount, BROKER, address(oneD), TERM_7D);
        vm.prank(user);
        oneD.deltaCompose(borrowCall);

        uint256 loanId = IListaBroker(BROKER).userFixedPositions(user)[0].posId;

        // fund the composer well above the debt and repay with amount==0 (use full balance)
        deal(WBNB, address(oneD), 3 ether);
        uint256 composerBalBefore = IERC20All(WBNB).balanceOf(address(oneD));
        assertGt(composerBalBefore, borrowAmount);

        bytes memory repayCall = CalldataLib.encodeListaBrokerRepay(WBNB, 0, false, BROKER, loanId, user);
        vm.prank(user);
        oneD.deltaCompose(repayCall);

        // position fully closed
        assertEq(IListaBroker(BROKER).userFixedPositions(user).length, 0);
        // the composer kept the excess (only principal + interest were consumed)
        uint256 composerBalAfter = IERC20All(WBNB).balanceOf(address(oneD));
        assertGt(composerBalAfter, 0);
        assertLt(composerBalAfter, composerBalBefore);
        // consumed at least the principal
        assertGe(composerBalBefore - composerBalAfter, borrowAmount);
    }

    /// @dev Repay-on-behalf: a third party with no Moolah authorization repays `user`'s position.
    ///      Repaying only pays debt down, so it is permissionless — `onBehalf` is calldata-supplied.
    function test_lista_broker_repay_on_behalf() external {
        _depositCollateralAndAuthorize(5 ether);

        uint256 borrowAmount = 1 ether;
        bytes memory borrowCall = CalldataLib.encodeListaBrokerBorrow(borrowAmount, BROKER, address(oneD), TERM_7D);
        vm.prank(user);
        oneD.deltaCompose(borrowCall);

        uint256 loanId = IListaBroker(BROKER).userFixedPositions(user)[0].posId;
        uint256 debtBefore = IListaBroker(BROKER).getUserTotalDebt(user);
        assertGt(debtBefore, 0);

        // a stranger (never authorized in Moolah) funds the composer and repays user's debt
        address stranger = address(0xBEEF);
        deal(WBNB, address(oneD), 3 ether);

        bytes memory repayCall = CalldataLib.encodeListaBrokerRepay(WBNB, 0, false, BROKER, loanId, user);
        vm.prank(stranger);
        oneD.deltaCompose(repayCall);

        // user's position was paid off by the stranger
        assertEq(IListaBroker(BROKER).userFixedPositions(user).length, 0);
        assertLt(IListaBroker(BROKER).getUserTotalDebt(user), debtBefore);
    }
}
