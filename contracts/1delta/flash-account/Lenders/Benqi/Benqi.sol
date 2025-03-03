// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;
import {CTokenSignatures} from "./CTokenSignatures.sol";
import {ILendingProvider} from "@flash-account/interfaces/ILendingProvider.sol";

abstract contract Benqi is CTokenSignatures {
    address public constant BENQI_COMPTROLLER = 0x486Af39519B4Dc9a7fCcd318217352830E8AD9b4;

    function _supplyBenqi(ILendingProvider.LendingParams calldata params) internal {
        require(params.asset != address(0) && params.collateralToken != address(0), "Invalid asset or collateral token");
        require(params.amount > 0, "Amount must be greater than 0");
        // Approve the cToken to spend the underlying asset
        (bool success, ) = params.asset.call(abi.encodeWithSignature("approve(address,uint256)", params.collateralToken, params.amount));
        require(success, "Approve failed");

        // Mint cTokens
        (success, ) = params.collateralToken.call(abi.encodeWithSelector(CTOKEN_MINT_SELECTOR, params.amount));
        require(success, "Mint failed");

        emit ILendingProvider.Supplied(params.caller, params.asset, params.amount);
    }

    function _withdrawBenqi(ILendingProvider.LendingParams calldata params) internal {
        // Withdraw the cToken
        (bool success, ) = params.collateralToken.call(abi.encodeWithSelector(CTOKEN_REDEEM_SELECTOR, params.amount));
        require(success, "Withdraw failed");

        emit ILendingProvider.Withdrawn(params.caller, params.asset, params.amount);
    }

    // function withdrawUnderlying(ILendingProvider.LendingParams calldata params) external {
    //     // Withdraw the underlying asset
    //     (bool success, ) = params.collateralToken.call(abi.encodeWithSelector(CTOKEN_REDEEM_UNDERLYING_SELECTOR, params.amount));
    //     require(success, "Withdraw failed");

    //     emit Withdrawn(params.caller, params.asset, params.amount);
    // }

    function _borrowBenqi(ILendingProvider.LendingParams calldata params) internal {
        // Borrow the underlying asset
        (bool success, ) = params.collateralToken.call(abi.encodeWithSelector(CTOKEN_BORROW_SELECTOR, params.amount));
        require(success, "Borrow failed");

        emit ILendingProvider.Borrowed(params.caller, params.asset, params.amount);
    }

    function _repayBenqi(ILendingProvider.LendingParams calldata params) internal {
        // Approve the cToken to spend the underlying asset
        (bool success, ) = params.asset.call(abi.encodeWithSignature("approve(address,uint256)", params.collateralToken, params.amount));
        require(success, "Approve failed");

        // Repay the underlying asset
        (success, ) = params.collateralToken.call(abi.encodeWithSelector(CTOKEN_REPAY_BORROW_SELECTOR, params.amount));
        require(success, "Repay failed");

        emit ILendingProvider.Repaid(params.caller, params.asset, params.amount);
    }

    function _benqiBalanceOf(address token) internal view returns (uint256) {
        (bool success, bytes memory data) = token.staticcall(abi.encodeWithSignature("balanceOf(address)", address(this)));
        if (!success) revert("Failed to get balance");
        return abi.decode(data, (uint256));
    }
}
