// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;
import {CTokenSignatures} from "./CTokenSignatures.sol";
import {ILendingProvider} from "../../../interfaces/ILendingProvider.sol";

abstract contract Benqi is CTokenSignatures, ILendingProvider {
    address public constant BENQI_COMPTROLLER = 0x486Af39519B4Dc9a7fCcd318217352830E8AD9b4;
    function benqiSupply(address cToken, uint256 amount) external {
        address underlying = _getUnderlying(cToken);

        // Approve the cToken to spend the underlying asset
        underlying.call(abi.encodeWithSignature("approve(address,uint256)", cToken, amount));

        // Mint cTokens
        (bool success, ) = cToken.call(abi.encodeWithSelector(CTOKEN_MINT_SELECTOR, amount));
        require(success, "Mint failed");

        emit Supplied(address(this), underlying, amount);
    }

    function benqiWithdraw(address cToken, uint256 amount) external {
        // withdraw the cToken
        (bool success, ) = cToken.call(abi.encodeWithSelector(CTOKEN_REDEEM_SELECTOR, amount));
        require(success, "Withdraw failed");

        emit Withdrawn(address(this), cToken, amount);
    }

    function benqiWithdrawUnderlying(address cToken, uint256 amount) external {
        // withdraw the underlying asset
        (bool success, ) = cToken.call(abi.encodeWithSelector(CTOKEN_REDEEM_UNDERLYING_SELECTOR, amount));
        require(success, "Withdraw failed");

        emit Withdrawn(address(this), cToken, amount);
    }

    function benqiBorrow(address cToken, uint256 amount) external {
        address underlying = _getUnderlying(cToken);

        // Borrow the underlying asset
        (bool success, ) = cToken.call(abi.encodeWithSelector(CTOKEN_BORROW_SELECTOR, amount));
        require(success, "Borrow failed");

        emit Borrowed(address(this), underlying, amount);
    }

    function benqiRepay(address cToken, uint256 amount) external {
        address underlying = _getUnderlying(cToken);

        // Approve the cToken to spend the underlying asset
        (bool success, ) = underlying.call(abi.encodeWithSignature("approve(address,uint256)", cToken, amount));
        require(success, "Approve failed");

        // Repay the underlying asset
        (success, ) = cToken.call(abi.encodeWithSelector(CTOKEN_REPAY_BORROW_SELECTOR, amount));
        require(success, "Repay failed");

        emit Repaid(address(this), underlying, amount);
    }

    function _getUnderlying(address cToken) internal returns (address) {
        require(cToken != address(0), "invalid cToken");

        (bool success, bytes memory data) = cToken.call(abi.encodeWithSelector(CTOKEN_UNDERLYING_SELECTOR));
        require(success, "Failed to get underlying");
        return abi.decode(data, (address));
    }
}
