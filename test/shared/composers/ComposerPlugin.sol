// SPDX-License-Identifier: NONE
pragma solidity ^0.8.28;

import {IComposerLike} from "./IComposerLike.sol";
import {Chains} from "../../data/LenderRegistry.sol";
import {OneDeltaComposerSonic} from "../../../contracts/1delta/modules/light/chains/sonic/Composer.sol";

library ComposerPlugin {
    function getComposer(string memory chainName) public returns (IComposerLike) {
        if (keccak256(bytes(chainName)) == keccak256(bytes(Chains.SONIC_MAINNET))) return IComposerLike(address(new OneDeltaComposerSonic()));

        revert("No composer for chain");
    }
}
