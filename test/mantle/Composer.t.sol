// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import "./DeltaSetup.f.sol";
import {Composer} from "../../contracts/1delta/modules/deploy/mantle/composable/Composer.sol";

contract SwapGen2Test is DeltaSetup {
    function test_composer() external {
        Composer composer = new Composer();
        bytes memory data = abi.encodePacked(uint8(0), uint16(20), uint8(1), USDT, uint16(32), uint8(2), uint256(1));
        uint gas = gasleft();
        composer.deltaCompose(data);
        gas = gas - gasleft();
        console.log("gas", gas);
    }
}
