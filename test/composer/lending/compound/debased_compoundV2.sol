// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {IERC20All} from "test/shared/interfaces/IERC20All.sol";
import {BaseTest} from "test/shared/BaseTest.sol";
import {Chains, Tokens, Lenders} from "test/data/LenderRegistry.sol";
import "test/composer/utils/CalldataLib.sol";
import {ComposerPlugin, IComposerLike} from "plugins/ComposerPlugin.sol";
import "test/shared/chains/ChainInitializer.sol";
import "test/shared/chains/ChainFactory.sol";
import "forge-std/console.sol";

contract CompoundV2ComposerLightTest is BaseTest {
    uint16 internal constant COMPOUND_V2_ID = 3000;

    IComposerLike oneDV2;

    address internal WETH;
    address internal WETH_CTOKEN;

    address internal USDT;
    address internal USDT_CTOKEN;

    address internal VENUS_COMPTROLLER;
    string internal lender;

    address internal MORPHO_BLUE = 0x6c247b1F6182318877311737BaC0844bAa518F5e;

    uint256 internal constant forkBlock = 391949445;

    function setUp() public virtual {
        string memory chainName = Chains.ARBITRUM_ONE;

        _init(chainName, forkBlock, true);
        lender = Lenders.VENUS;
        WETH = chain.getTokenAddress(Tokens.WETH);
        WETH_CTOKEN = _getCollateralToken(WETH);
        USDT = chain.getTokenAddress(Tokens.USDT);
        USDT_CTOKEN = _getCollateralToken(USDT);
        VENUS_COMPTROLLER = chain.getLendingController(lender);

        oneDV2 = ComposerPlugin.getComposer(chainName);

        vm.label(WETH, "WETH");
        vm.label(USDT, "USDT");
        vm.label(VENUS_COMPTROLLER, "VENUS");
        vm.label(address(oneDV2), "oneDV2");
        vm.label(user, "user");
        vm.label(WETH_CTOKEN, "WETH_CTOKEN");
        vm.label(USDT_CTOKEN, "USDT_CTOKEN");
        vm.label(MORPHO_BLUE, "MORPHO_BLUE");
    }

    function test_debased() external {
        // required approvals
        address[] memory cTokens = new address[](1);
        cTokens[0] = WETH_CTOKEN;

        vm.startPrank(user);
        IERC20All(WETH).approve(address(oneDV2), type(uint256).max);
        IERC20All(USDT).approve(address(oneDV2), type(uint256).max);
        IERC20All(WETH_CTOKEN).approve(address(oneDV2), type(uint256).max);
        IERC20All(USDT_CTOKEN).approve(address(oneDV2), type(uint256).max);
        IERC20All(VENUS_COMPTROLLER).enterMarkets(cTokens);
        IERC20All(VENUS_COMPTROLLER).updateDelegate(address(oneDV2), true);
        (cTokens);
        vm.stopPrank();

        uint256 amount = 49 ether;
        uint256 compensationAmount = 1e9;

        vm.deal(user, 1 ether);

        uint256 initialUserBalance = user.balance;

        bytes memory innerCalldata = CalldataLib.encodeCompoundV2Deposit(WETH, amount, user, WETH_CTOKEN, uint8(CompoundV2Selector.MINT_BEHALF));

        uint256 amountToBorrow = 100000e6;
        innerCalldata = abi.encodePacked(innerCalldata, CalldataLib.encodeCompoundV2Borrow(USDT, amountToBorrow, user, USDT_CTOKEN));

        innerCalldata = abi.encodePacked(innerCalldata, CalldataLib.encodeTransferIn(USDT, address(oneDV2), amountToBorrow));

        innerCalldata = abi.encodePacked(innerCalldata, CalldataLib.encodeCompoundV2Repay(USDT, type(uint112).max, user, USDT_CTOKEN));

        innerCalldata = abi.encodePacked(
            innerCalldata,
            CalldataLib.encodeCompoundV2Withdraw(WETH, type(uint112).max, address(oneDV2), WETH_CTOKEN, uint8(CompoundV2Selector.REDEEM_BEHALF)),
            CalldataLib.encodeWrap(compensationAmount, WETH)
        );

        bytes memory sweep = CalldataLib.encodeSweep(WETH, user, 0, SweepType.VALIDATE);

        bytes memory flashLoanCalldata = CalldataLib.encodeFlashLoan(WETH, amount, MORPHO_BLUE, uint8(0), uint8(0), innerCalldata);

        vm.prank(user);
        oneDV2.deltaCompose{value: compensationAmount}(abi.encodePacked(flashLoanCalldata, sweep));
    }

    function _getCollateralToken(address token) internal view returns (address) {
        return chain.getLendingTokens(token, lender).collateral;
    }
}
