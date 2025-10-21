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

    address internal USDC;
    address internal USDC_CTOKEN;

    address internal USDT;
    address internal USDT_CTOKEN;

    address internal VENUS_COMPTROLLER;
    string internal lender;

    uint256 internal constant forkBlock = 290934482;

    function setUp() public virtual {
        // initialize the chain
        string memory chainName = Chains.ARBITRUM_ONE;

        _init(chainName, forkBlock, true);
        lender = Lenders.VENUS;
        USDC = chain.getTokenAddress(Tokens.USDC);
        USDC_CTOKEN = _getCollateralToken(USDC);
        USDT = chain.getTokenAddress(Tokens.USDT);
        USDT_CTOKEN = _getCollateralToken(USDT);
        VENUS_COMPTROLLER = chain.getLendingController(lender);

        oneDV2 = ComposerPlugin.getComposer(chainName);

        vm.label(USDC, "USDC");
        vm.label(USDT, "USDT");
        vm.label(VENUS_COMPTROLLER, "VENUS");
        vm.label(address(oneDV2), "oneDV2");
        vm.label(user, "user");
        vm.label(USDC_CTOKEN, "USDC_CTOKEN");
        vm.label(USDT_CTOKEN, "USDT_CTOKEN");
    }

    function test_debased() external {
        uint256 amount = 1e12; // 1 million
        deal(USDC, user, amount);

        address[] memory cTokens = new address[](1);
        cTokens[0] = USDC_CTOKEN;

        vm.prank(user);
        IERC20All(VENUS_COMPTROLLER).enterMarkets(cTokens);

        vm.prank(user);
        IERC20All(USDC).approve(address(oneDV2), amount);

        bytes memory depositCallData = CalldataLib.encodeTransferIn(USDC, address(oneDV2), amount);

        depositCallData = abi.encodePacked(
            depositCallData, CalldataLib.encodeCompoundV2Deposit(USDC, amount, user, USDC_CTOKEN, uint8(CompoundV2Selector.MINT_BEHALF))
        );

        vm.prank(user);
        oneDV2.deltaCompose(depositCallData);

        approveBorrowDelegation(user, USDC, address(oneDV2), lender);

        uint256 amountToBorrow = 100000e6;
        bytes memory borrowCallData = CalldataLib.encodeCompoundV2Borrow(USDT, amountToBorrow, user, USDT_CTOKEN);
        vm.prank(user);
        oneDV2.deltaCompose(borrowCallData);

        // uint256 amountToWithdraw = 100000.0e6;
        // bytes memory d = CalldataLib.encodeCompoundV2Withdraw(USDT, amountToWithdraw, user, USDT_CTOKEN, uint8(CompoundV2Selector.REDEEM_BEHALF));

        // vm.prank(user);
        // oneDV2.deltaCompose(d);

        // uint256 bb = 0;
        // (bool success, bytes memory data) = USDT_CTOKEN.call(abi.encodeWithSelector(0x17bfdfbc, user));
        // if (success) {
        //     bb = abi.decode(data, (uint256));
        // }
        // console.log("bb", bb);
    }

    function _getCollateralToken(address token) internal view returns (address) {
        return chain.getLendingTokens(token, lender).collateral;
    }
}
