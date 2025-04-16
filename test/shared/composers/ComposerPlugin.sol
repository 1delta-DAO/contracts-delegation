// SPDX-License-Identifier: NONE
pragma solidity ^0.8.28;

import {IComposerLike} from "./IComposerLike.sol";
import {Chains} from "../../data/LenderRegistry.sol";
import {OneDeltaComposerArbitrumOne} from "../../../contracts/1delta/modules/light/chains/arbitrum-one/Composer.sol";
import {OneDeltaComposerHemi} from "../../../contracts/1delta/modules/light/chains/hemi/Composer.sol";
import {OneDeltaComposerBnb} from "../../../contracts/1delta/modules/light/chains/bnb/Composer.sol";
import {OneDeltaComposerBase} from "../../../contracts/1delta/modules/light/chains/base/Composer.sol";
import {OneDeltaComposerPolygon} from "../../../contracts/1delta/modules/light/chains/polygon/Composer.sol";
import {OneDeltaComposerTaiko} from "../../../contracts/1delta/modules/light/chains/taiko/Composer.sol";
import {OneDeltaComposerSonic} from "../../../contracts/1delta/modules/light/chains/sonic/Composer.sol";

library ComposerPlugin {
    function getComposer(string memory chainName) public returns (IComposerLike) {
        if (keccak256(bytes(chainName)) == keccak256(bytes(Chains.ARBITRUM_ONE))) return IComposerLike(address(new OneDeltaComposerArbitrumOne()));
        if (keccak256(bytes(chainName)) == keccak256(bytes(Chains.HEMI_NETWORK))) return IComposerLike(address(new OneDeltaComposerHemi()));
        if (keccak256(bytes(chainName)) == keccak256(bytes(Chains.BNB_SMART_CHAIN_MAINNET))) return IComposerLike(address(new OneDeltaComposerBnb()));
        if (keccak256(bytes(chainName)) == keccak256(bytes(Chains.BASE))) return IComposerLike(address(new OneDeltaComposerBase()));
        if (keccak256(bytes(chainName)) == keccak256(bytes(Chains.POLYGON_MAINNET))) return IComposerLike(address(new OneDeltaComposerPolygon()));
        if (keccak256(bytes(chainName)) == keccak256(bytes(Chains.TAIKO_ALETHIA))) return IComposerLike(address(new OneDeltaComposerTaiko()));
        if (keccak256(bytes(chainName)) == keccak256(bytes(Chains.SONIC_MAINNET))) return IComposerLike(address(new OneDeltaComposerSonic()));

        revert("No composer for chain");
    }
}
