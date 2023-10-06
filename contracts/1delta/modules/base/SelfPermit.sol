// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {ICreditPermit} from "../../interfaces/ICreditPermit.sol";
import {IERC20Permit} from "../../interfaces/IERC20Permit.sol";
import {IERC20PermitAllowed} from "../../interfaces/IERC20PermitAllowed.sol";

abstract contract SelfPermit {
    // standard permit (incl Aave aTokens)
    function selfPermit(
        address token,
        uint256 value,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external payable {
        IERC20Permit(token).permit(msg.sender, address(this), value, deadline, v, r, s);
    }

    // DAI-type permit
    function selfPermitAllowed(
        address token,
        uint256 nonce,
        uint256 expiry,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external payable {
        IERC20PermitAllowed(token).permit(msg.sender, address(this), nonce, expiry, true, v, r, s);
    }

    // Aave credit delegation permit
    function selfCreditDelegate(
        address creditToken,
        uint256 value,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external payable {
        ICreditPermit(creditToken).delegationWithSig(msg.sender, address(this), value, deadline, v, r, s);
    }
}
