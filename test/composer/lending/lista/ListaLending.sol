// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

import {ComposerPlugin, IComposerLike} from "plugins/ComposerPlugin.sol";
import {BaseTest} from "test/shared/BaseTest.sol";
import {Chains} from "test/data/LenderRegistry.sol";
import "contracts/utils/CalldataLib.sol";
import {IMorphoEverything} from "../utils/Morpho.sol";

contract ListaLendingTest is BaseTest {
    IComposerLike oneD;

    uint256 internal constant forkBlock = 0;
    address internal constant WBNB = 0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c;
    address internal constant LISTA_PROVIDER = 0x367384C54756a25340c63057D87eA22d47Fd5701;
    address internal constant MOOLAH = 0x8F73b65B4caAf64FBA2aF91cC5D4a2A1318E5D8C;

    address internal constant LOAN_TOKEN = 0x55d398326f99059fF775485246999027B3197955;
    address internal constant COLLATERAL_TOKEN = 0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c;
    address internal constant ORACLE = 0xf3afD82A4071f272F403dC176916141f44E6c750;
    address internal constant IRM = 0xFe7dAe87Ebb11a7BEB9F534BB23267992d9cDe7c;
    uint256 internal constant LLTV = 800000000000000000;

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

    function test_lista_provider_supply_collateral() external {
        uint256 amount = 0.1 ether;
        vm.deal(address(oneD), amount);
        bytes memory market = encodeMarket(LOAN_TOKEN, COLLATERAL_TOKEN, ORACLE, IRM, LLTV);
        bytes memory depositCall = CalldataLib.encodeListaSupplyCollateralViaProvider(
            market,
            amount,
            user,
            LISTA_PROVIDER,
            "",
            0
        );
        uint256 composerBalanceBefore = address(oneD).balance;
        vm.prank(user);
        oneD.deltaCompose(depositCall);
        assertEq(address(oneD).balance, composerBalanceBefore - amount);
    }

    function test_lista_provider_withdraw_collateral() external {
        uint256 amount = 0.1 ether;
        vm.deal(address(oneD), amount);
        bytes memory market = encodeMarket(LOAN_TOKEN, COLLATERAL_TOKEN, ORACLE, IRM, LLTV);
        bytes memory depositCall = CalldataLib.encodeListaSupplyCollateralViaProvider(
            market,
            amount,
            user,
            LISTA_PROVIDER,
            "",
            0
        );
        vm.prank(user);
        oneD.deltaCompose(depositCall);
        vm.prank(user);
        IMorphoEverything(MOOLAH).setAuthorization(address(oneD), true);
        uint256 withdrawAmount = 0.05 ether;
        bytes memory withdrawCall =
            CalldataLib.encodeMorphoWithdrawCollateral(market, withdrawAmount, user, LISTA_PROVIDER);
        uint256 userBalanceBefore = user.balance;
        vm.prank(user);
        oneD.deltaCompose(withdrawCall);
        assertEq(user.balance, userBalanceBefore + withdrawAmount);
    }
}
