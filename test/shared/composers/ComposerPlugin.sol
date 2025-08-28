// SPDX-License-Identifier: NONE
pragma solidity ^0.8.28;

import {IComposerLike} from "./IComposerLike.sol";
import {Chains} from "../../data/LenderRegistry.sol";
import {OneDeltaComposerArbitrumOne} from "../../../contracts/1delta/composer//chains/arbitrum-one/Composer.sol";
import {OneDeltaComposerHemi} from "../../../contracts/1delta/composer//chains/hemi/Composer.sol";
import {OneDeltaComposerBnb} from "../../../contracts/1delta/composer//chains/bnb/Composer.sol";
import {OneDeltaComposerMetisAndromeda} from "../../../contracts/1delta/composer//chains/metis-andromeda/Composer.sol";
import {OneDeltaComposerBase} from "../../../contracts/1delta/composer//chains/base/Composer.sol";
import {OneDeltaComposerPolygon} from "../../../contracts/1delta/composer//chains/polygon/Composer.sol";
import {OneDeltaComposerTaiko} from "../../../contracts/1delta/composer//chains/taiko/Composer.sol";
import {OneDeltaComposerMantle} from "../../../contracts/1delta/composer//chains/mantle/Composer.sol";
import {OneDeltaComposerCelo} from "../../../contracts/1delta/composer//chains/celo/Composer.sol";
import {OneDeltaComposerGnosis} from "../../../contracts/1delta/composer//chains/gnosis/Composer.sol";
import {OneDeltaComposerAvalanche} from "../../../contracts/1delta/composer//chains/avalanche/Composer.sol";
import {OneDeltaComposerSonic} from "../../../contracts/1delta/composer//chains/sonic/Composer.sol";
import {OneDeltaComposerOp} from "../../../contracts/1delta/composer//chains/op/Composer.sol";
import {OneDeltaComposerScroll} from "../../../contracts/1delta/composer//chains/scroll/Composer.sol";
import {OneDeltaComposerLinea} from "../../../contracts/1delta/composer//chains/linea/Composer.sol";
import {OneDeltaComposerBlast} from "../../../contracts/1delta/composer//chains/blast/Composer.sol";
import {OneDeltaComposerSoneium} from "../../../contracts/1delta/composer//chains/soneium/Composer.sol";
import {OneDeltaComposerMode} from "../../../contracts/1delta/composer//chains/mode/Composer.sol";
import {OneDeltaComposerCore} from "../../../contracts/1delta/composer//chains/core/Composer.sol";
import {OneDeltaComposerFantomOpera} from "../../../contracts/1delta/composer//chains/fantom-opera/Composer.sol";
import {OneDeltaComposerKaia} from "../../../contracts/1delta/composer//chains/kaia/Composer.sol";
import {OneDeltaComposerHyperevm} from "../../../contracts/1delta/composer//chains/hyperevm/Composer.sol";
import {OneDeltaComposerUnichain} from "../../../contracts/1delta/composer//chains/unichain/Composer.sol";
import {OneDeltaComposerKatana} from "../../../contracts/1delta/composer//chains/katana/Composer.sol";
import {OneDeltaComposerPulsechain} from "../../../contracts/1delta/composer//chains/pulsechain/Composer.sol";
import {OneDeltaComposerEthereum} from "../../../contracts/1delta/composer//chains/ethereum/Composer.sol";
import {OneDeltaComposerBerachain} from "../../../contracts/1delta/composer//chains/berachain/Composer.sol";
import {OneDeltaComposerCronos} from "../../../contracts/1delta/composer//chains/cronos/Composer.sol";
import {OneDeltaComposerXdc} from "../../../contracts/1delta/composer//chains/xdc/Composer.sol";

library ComposerPlugin {
    function getComposer(string memory chainName) public returns (IComposerLike) {
        if (keccak256(bytes(chainName)) == keccak256(bytes(Chains.ARBITRUM_ONE))) return IComposerLike(address(new OneDeltaComposerArbitrumOne()));
        if (keccak256(bytes(chainName)) == keccak256(bytes(Chains.HEMI_NETWORK))) return IComposerLike(address(new OneDeltaComposerHemi()));
        if (keccak256(bytes(chainName)) == keccak256(bytes(Chains.BNB_SMART_CHAIN_MAINNET))) return IComposerLike(address(new OneDeltaComposerBnb()));
        if (keccak256(bytes(chainName)) == keccak256(bytes(Chains.METIS_ANDROMEDA_MAINNET))) {
            return IComposerLike(address(new OneDeltaComposerMetisAndromeda()));
        }
        if (keccak256(bytes(chainName)) == keccak256(bytes(Chains.BASE))) return IComposerLike(address(new OneDeltaComposerBase()));
        if (keccak256(bytes(chainName)) == keccak256(bytes(Chains.POLYGON_MAINNET))) return IComposerLike(address(new OneDeltaComposerPolygon()));
        if (keccak256(bytes(chainName)) == keccak256(bytes(Chains.TAIKO_ALETHIA))) return IComposerLike(address(new OneDeltaComposerTaiko()));
        if (keccak256(bytes(chainName)) == keccak256(bytes(Chains.MANTLE))) return IComposerLike(address(new OneDeltaComposerMantle()));
        if (keccak256(bytes(chainName)) == keccak256(bytes(Chains.CELO_MAINNET))) return IComposerLike(address(new OneDeltaComposerCelo()));
        if (keccak256(bytes(chainName)) == keccak256(bytes(Chains.GNOSIS))) return IComposerLike(address(new OneDeltaComposerGnosis()));
        if (keccak256(bytes(chainName)) == keccak256(bytes(Chains.AVALANCHE_C_CHAIN))) return IComposerLike(address(new OneDeltaComposerAvalanche()));
        if (keccak256(bytes(chainName)) == keccak256(bytes(Chains.SONIC_MAINNET))) return IComposerLike(address(new OneDeltaComposerSonic()));
        if (keccak256(bytes(chainName)) == keccak256(bytes(Chains.OP_MAINNET))) return IComposerLike(address(new OneDeltaComposerOp()));
        if (keccak256(bytes(chainName)) == keccak256(bytes(Chains.SCROLL))) return IComposerLike(address(new OneDeltaComposerScroll()));
        if (keccak256(bytes(chainName)) == keccak256(bytes(Chains.LINEA))) return IComposerLike(address(new OneDeltaComposerLinea()));
        if (keccak256(bytes(chainName)) == keccak256(bytes(Chains.BLAST))) return IComposerLike(address(new OneDeltaComposerBlast()));
        if (keccak256(bytes(chainName)) == keccak256(bytes(Chains.SONEIUM))) return IComposerLike(address(new OneDeltaComposerSoneium()));
        if (keccak256(bytes(chainName)) == keccak256(bytes(Chains.MODE))) return IComposerLike(address(new OneDeltaComposerMode()));
        if (keccak256(bytes(chainName)) == keccak256(bytes(Chains.CORE_BLOCKCHAIN_MAINNET))) {
            return IComposerLike(address(new OneDeltaComposerCore()));
        }
        if (keccak256(bytes(chainName)) == keccak256(bytes(Chains.FANTOM_OPERA))) return IComposerLike(address(new OneDeltaComposerFantomOpera()));
        if (keccak256(bytes(chainName)) == keccak256(bytes(Chains.KAIA_MAINNET))) return IComposerLike(address(new OneDeltaComposerKaia()));
        if (keccak256(bytes(chainName)) == keccak256(bytes(Chains.HYPEREVM))) return IComposerLike(address(new OneDeltaComposerHyperevm()));
        if (keccak256(bytes(chainName)) == keccak256(bytes(Chains.UNICHAIN))) return IComposerLike(address(new OneDeltaComposerUnichain()));
        if (keccak256(bytes(chainName)) == keccak256(bytes(Chains.KATANA))) return IComposerLike(address(new OneDeltaComposerKatana()));
        if (keccak256(bytes(chainName)) == keccak256(bytes(Chains.PULSECHAIN))) return IComposerLike(address(new OneDeltaComposerPulsechain()));
        if (keccak256(bytes(chainName)) == keccak256(bytes(Chains.ETHEREUM_MAINNET))) return IComposerLike(address(new OneDeltaComposerEthereum()));
        if (keccak256(bytes(chainName)) == keccak256(bytes(Chains.BERACHAIN))) return IComposerLike(address(new OneDeltaComposerBerachain()));
        if (keccak256(bytes(chainName)) == keccak256(bytes(Chains.CRONOS_MAINNET))) return IComposerLike(address(new OneDeltaComposerCronos()));
        if (keccak256(bytes(chainName)) == keccak256(bytes(Chains.XDC_NETWORK))) return IComposerLike(address(new OneDeltaComposerXdc()));

        revert("No composer for chain");
    }
}
