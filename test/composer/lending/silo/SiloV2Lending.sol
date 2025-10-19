// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {IERC20All} from "test/shared/interfaces/IERC20All.sol";
import {BaseTest} from "test/shared/BaseTest.sol";
import {Chains, Tokens, Lenders} from "test/data/LenderRegistry.sol";
import "test/composer/utils/CalldataLib.sol";
import {ComposerPlugin, IComposerLike} from "plugins/ComposerPlugin.sol";
import "test/shared/chains/ChainInitializer.sol";
import "test/shared/chains/ChainFactory.sol";

interface ISilo {
    function switchCollateralToThisSilo() external;
    function setReceiveApproval(address owner, uint256 _amount) external;
}

contract SiloV2ComposerLightTest is BaseTest {
    uint16 internal constant COMPOUND_V2_ID = 3000;

    IComposerLike oneDV2;

    address internal USDC;
    address internal WETH;
    address internal WEETH = 0x35751007a407ca6FEFfE80b3cB397736D2cf4dbe;
    address internal SILO_WEETH = 0x038722A3b78A10816Ae0EDC6afA768B03048a0cC;
    address internal SILO_WETH_DEBT_SHARE = 0x4155f07B12f35db4264cCe0257e8Bc0912C8Fc32;
    address internal SILO_WETH = 0x3613d1789583C790D30F3c6c7786A4f36f81C6eC;
    string internal lender;

    uint256 internal constant forkBlock = 391289621;

    function setUp() public virtual {
        // initialize the chain
        string memory chainName = Chains.ARBITRUM_ONE;

        _init(chainName, forkBlock, true);
        lender = Lenders.VENUS;
        USDC = chain.getTokenAddress(Tokens.USDC);
        WETH = chain.getTokenAddress(Tokens.WETH);

        oneDV2 = ComposerPlugin.getComposer(chainName);
    }

    function test_light_lending_siloV2_deposit() external {
        vm.assume(user != address(0));

        address token = WEETH;
        uint256 amount = 1.0e18;
        deal(token, user, amount);

        address silo = SILO_WEETH; // _getCollateralToken(token);

        vm.prank(user);
        IERC20All(token).approve(address(oneDV2), type(uint256).max);

        // Get balances before deposit
        // uint256 collateralBefore = chain.getCollateralBalance(user, token, lender);
        uint256 underlyingBefore = IERC20All(token).balanceOf(user);

        bytes memory transferTo = CalldataLib.encodeTransferIn(
            token,
            address(oneDV2),
            amount //
        );

        bytes memory d = CalldataLib.encodeSiloV2Deposit(token, amount, user, silo, uint8(0));

        vm.prank(user);
        oneDV2.deltaCompose(abi.encodePacked(transferTo, d));

        // Get balances after deposit
        uint256 collateralAfter = chain.getCollateralBalance(user, token, lender);
        uint256 underlyingAfter = IERC20All(token).balanceOf(user);

        // Assert collateral balance increased by amount
        // assertApproxEqAbs(collateralAfter - collateralBefore, amount, 1);
        // Assert underlying balance decreased by amount
        assertApproxEqAbs(underlyingBefore - underlyingAfter, amount, 1);
    }

    function test_light_lending_siloV2_borrow() external {
        vm.assume(user != address(0));

        address depositToken = WEETH;
        address token = WETH;
        address collateralSilo = SILO_WEETH;
        address borrowSilo = SILO_WETH;
        address debtShareToken = SILO_WETH_DEBT_SHARE;

        uint256 amount = 1.0e18;
        deal(token, user, amount);

        depositToSiloV2(depositToken, user, amount, collateralSilo, uint8(SiloV2CollateralType.COLLATERAL));

        // approveBorrowDelegation(user, token, address(oneDV2), lender);

        vm.prank(user);
        ISilo(debtShareToken).setReceiveApproval(address(oneDV2), type(uint256).max);

        // vm.prank(user);
        // ISilo(collateralSilo).switchCollateralToThisSilo();

        uint256 amountToBorrow = 0.5e18;
        bytes memory d = CalldataLib.encodeSiloV2Borrow(amountToBorrow, user, borrowSilo);

        // Check balances before borrowing
        // uint256 borrowBalanceBefore = chain.getDebtBalance(user, token, lender);
        uint256 underlyingBefore = IERC20All(token).balanceOf(user);

        vm.prank(user);
        oneDV2.deltaCompose(d);

        // Check balances after borrowing
        // uint256 borrowBalanceAfter = chain.getDebtBalance(user, token, lender);
        uint256 underlyingAfter = IERC20All(token).balanceOf(user);

        // Assert debt increased by borrowed amount
        // assertApproxEqAbs(borrowBalanceAfter - borrowBalanceBefore, amountToBorrow, 1);
        // Assert underlying increased by borrowed amount
        assertApproxEqAbs(underlyingAfter - underlyingBefore, amountToBorrow, 1);
    }

    function depositToSiloV2(address token, address userAddress, uint256 amount, address silo, uint8 collateralMode) internal {
        deal(token, userAddress, amount);

        vm.prank(userAddress);
        IERC20All(token).approve(address(oneDV2), type(uint256).max);

        bytes memory transferTo = CalldataLib.encodeTransferIn(
            token,
            address(oneDV2),
            amount //
        );

        bytes memory d = CalldataLib.encodeSiloV2Deposit(token, amount, userAddress, silo, collateralMode);

        vm.prank(userAddress);
        oneDV2.deltaCompose(abi.encodePacked(transferTo, d));
    }

    function borrowFromCompoundV2(address token, address userAddress, uint256 amountToBorrow, address comptroller) internal {
        vm.prank(userAddress);
        IERC20All(comptroller).updateDelegate(address(oneDV2), true);

        address cToken = _getCollateralToken(token);
        bytes memory d = CalldataLib.encodeCompoundV2Borrow(token, amountToBorrow, userAddress, cToken);

        vm.prank(userAddress);
        oneDV2.deltaCompose(d);
    }

    function _getCollateralToken(address token) internal view returns (address) {
        return chain.getLendingTokens(token, lender).collateral;
    }
}
