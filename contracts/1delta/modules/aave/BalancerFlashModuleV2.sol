// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.23;

import {IERC20} from "../../../interfaces/IERC20.sol";
import {IPool} from "../../interfaces/IAAVEV3Pool.sol";
import {WithStorage} from "../../storage/BrokerStorage.sol";
import {TokenTransfer} from "./../../libraries/TokenTransfer.sol";
import {IBalancerFlashLoans, IFlashLoanRecipient} from "../../../external-protocols/balancer/IBalancerFlashLoans.sol";

/// @notice Balancer flash loans do NOT draw the required loan plus fee from the caller
//  as such, we have to make sure that we always transer loan plus fee
//  during the flash loan call
contract BalancerFlashModuleV2 is WithStorage, TokenTransfer {
    // immutables
    IBalancerFlashLoans private immutable _balancerFlashLoans;
    address private immutable DEFAULT_ADDRESS_CACHED;

    constructor(address _balancer) {
        _balancerFlashLoans = IBalancerFlashLoans(_balancer);
    }

    /**
     * Excutes flash loan
     */
    function executeOnBalancer(
        IERC20[] calldata tokens, // token to be flash borrowed
        uint256[] calldata amounts, // flash amounts
        bytes calldata data
    ) external payable {
        // cache the sender address
        acs().cachedAddress = msg.sender;
        // open for flash laon
        gs().isOpen = 1;
        _balancerFlashLoans.flashLoan(
            IFlashLoanRecipient(address(this)),
            tokens,
            amounts,
            data // send the data directly
        );
        // set entry flag to 0
        gs().isOpen = 0;
        // reset cache
        acs().cachedAddress = DEFAULT_ADDRESS_CACHED;
    }

    /**
     * @dev When `flashLoan` is called on the Vault, it invokes the `receiveFlashLoan` hook on the recipient.
     * Ideally, a multitude of calls via the multicall function are executed via the calldata.
     */
    function receiveFlashLoan(
        address[] calldata tokens, // token to be flash borrowed
        uint256[] calldata amounts, // flash amounts
        uint256[] calldata feeAmounts,
        bytes calldata userData
    ) external {
        // validate callback
        require(gs().isOpen == 1, "CannotEnter()");
        require(msg.sender == address(_balancerFlashLoans), "VaultNotCaller()");

        // call self
        {
            (bool success, bytes memory result) = address(this).delegatecall(userData);
            if (!success) {
                // Next 5 lines from https://ethereum.stackexchange.com/a/83577
                if (result.length < 68) revert();
                assembly {
                    result := add(result, 0x04)
                }
                revert(abi.decode(result, (string)));
            }
        }
        // repay loan balances and fees
        for (uint256 i; i != tokens.length; i++) {
            _transferERC20TokensFrom(tokens[i], msg.sender, address(this), amounts[i] + feeAmounts[i]);
        }
    }

    // allows ths contract to pull funds from cached address
    // this is for allowing this contract to pull funds from the sender
    // within the flash loan
    function pullTokens(address asset, uint256 amount) external payable {
        require(msg.sender == address(this), "InvalidCaller()");
        require(gs().isOpen == 1, "NotInFLashLoan()");
        _transferERC20TokensFrom(asset, acs().cachedAddress, address(this), amount);
    }
}
