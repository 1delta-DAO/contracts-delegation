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
import {OneDeltaComposerMorph} from "../../../contracts/1delta/composer//chains/morph/Composer.sol";
import {OneDeltaComposerMantaPacific} from "../../../contracts/1delta/composer//chains/manta-pacific/Composer.sol";
import {OneDeltaComposerTelosEvm} from "../../../contracts/1delta/composer//chains/telos-evm/Composer.sol";
import {OneDeltaComposerPlasma} from "../../../contracts/1delta/composer//chains/plasma/Composer.sol";
import {OneDeltaComposerMoonbeam} from "../../../contracts/1delta/composer//chains/moonbeam/Composer.sol";
import {OneDeltaComposerSei} from "../../../contracts/1delta/composer//chains/sei/Composer.sol";
import {OneDeltaComposerMonad} from "../../../contracts/1delta/composer//chains/monad/Composer.sol";
import {OneDeltaComposerEtherlink} from "../../../contracts/1delta/composer//chains/etherlink/Composer.sol";
import {OneDeltaComposerLisk} from "../../../contracts/1delta/composer//chains/lisk/Composer.sol";
import {OneDeltaComposerBob} from "../../../contracts/1delta/composer//chains/bob/Composer.sol";
import {OneDeltaComposerCorn} from "../../../contracts/1delta/composer//chains/corn/Composer.sol";
import {OneDeltaComposerStable} from "../../../contracts/1delta/composer//chains/stable/Composer.sol";
import {OneDeltaComposerPlume} from "../../../contracts/1delta/composer//chains/plume/Composer.sol";
import {OneDeltaComposerGoat} from "../../../contracts/1delta/composer//chains/goat/Composer.sol";
import {OneDeltaComposerAbstract} from "../../../contracts/1delta/composer//chains/abstract/Composer.sol";
import {OneDeltaComposerMegaeth} from "../../../contracts/1delta/composer//chains/megaeth/Composer.sol";
import {OneDeltaComposerInk} from "../../../contracts/1delta/composer//chains/ink/Composer.sol";
import {OneDeltaComposerFlare} from "../../../contracts/1delta/composer//chains/flare/Composer.sol";
import {OneDeltaComposerXLayer} from "../../../contracts/1delta/composer//chains/x-layer/Composer.sol";

library ComposerPlugin {
    function getComposer(string memory chainName) public returns (IComposerLike) {
        if (keccak256(bytes(chainName)) == keccak256(bytes(Chains.ARBITRUM_ONE))) {
            return IComposerLike(address(new OneDeltaComposerArbitrumOne()));
        }
        if (keccak256(bytes(chainName)) == keccak256(bytes(Chains.HEMI_NETWORK))) {
            return IComposerLike(address(new OneDeltaComposerHemi()));
        }
        if (keccak256(bytes(chainName)) == keccak256(bytes(Chains.BNB_SMART_CHAIN_MAINNET))) {
            return IComposerLike(address(new OneDeltaComposerBnb()));
        }
        if (keccak256(bytes(chainName)) == keccak256(bytes(Chains.METIS_ANDROMEDA_MAINNET))) {
            return IComposerLike(address(new OneDeltaComposerMetisAndromeda()));
        }
        if (keccak256(bytes(chainName)) == keccak256(bytes(Chains.BASE))) {
            return IComposerLike(address(new OneDeltaComposerBase()));
        }
        if (keccak256(bytes(chainName)) == keccak256(bytes(Chains.POLYGON_MAINNET))) {
            return IComposerLike(address(new OneDeltaComposerPolygon()));
        }
        if (keccak256(bytes(chainName)) == keccak256(bytes(Chains.TAIKO_ALETHIA))) {
            return IComposerLike(address(new OneDeltaComposerTaiko()));
        }
        if (keccak256(bytes(chainName)) == keccak256(bytes(Chains.MANTLE))) {
            return IComposerLike(address(new OneDeltaComposerMantle()));
        }
        if (keccak256(bytes(chainName)) == keccak256(bytes(Chains.CELO_MAINNET))) {
            return IComposerLike(address(new OneDeltaComposerCelo()));
        }
        if (keccak256(bytes(chainName)) == keccak256(bytes(Chains.GNOSIS))) {
            return IComposerLike(address(new OneDeltaComposerGnosis()));
        }
        if (keccak256(bytes(chainName)) == keccak256(bytes(Chains.AVALANCHE_C_CHAIN))) {
            return IComposerLike(address(new OneDeltaComposerAvalanche()));
        }
        if (keccak256(bytes(chainName)) == keccak256(bytes(Chains.SONIC_MAINNET))) {
            return IComposerLike(address(new OneDeltaComposerSonic()));
        }
        if (keccak256(bytes(chainName)) == keccak256(bytes(Chains.OP_MAINNET))) {
            return IComposerLike(address(new OneDeltaComposerOp()));
        }
        if (keccak256(bytes(chainName)) == keccak256(bytes(Chains.SCROLL))) {
            return IComposerLike(address(new OneDeltaComposerScroll()));
        }
        if (keccak256(bytes(chainName)) == keccak256(bytes(Chains.LINEA))) {
            return IComposerLike(address(new OneDeltaComposerLinea()));
        }
        if (keccak256(bytes(chainName)) == keccak256(bytes(Chains.BLAST))) {
            return IComposerLike(address(new OneDeltaComposerBlast()));
        }
        if (keccak256(bytes(chainName)) == keccak256(bytes(Chains.SONEIUM))) {
            return IComposerLike(address(new OneDeltaComposerSoneium()));
        }
        if (keccak256(bytes(chainName)) == keccak256(bytes(Chains.MODE))) {
            return IComposerLike(address(new OneDeltaComposerMode()));
        }
        if (keccak256(bytes(chainName)) == keccak256(bytes(Chains.CORE_BLOCKCHAIN_MAINNET))) {
            return IComposerLike(address(new OneDeltaComposerCore()));
        }
        if (keccak256(bytes(chainName)) == keccak256(bytes(Chains.FANTOM_OPERA))) {
            return IComposerLike(address(new OneDeltaComposerFantomOpera()));
        }
        if (keccak256(bytes(chainName)) == keccak256(bytes(Chains.KAIA_MAINNET))) {
            return IComposerLike(address(new OneDeltaComposerKaia()));
        }
        if (keccak256(bytes(chainName)) == keccak256(bytes(Chains.HYPEREVM))) {
            return IComposerLike(address(new OneDeltaComposerHyperevm()));
        }
        if (keccak256(bytes(chainName)) == keccak256(bytes(Chains.UNICHAIN))) {
            return IComposerLike(address(new OneDeltaComposerUnichain()));
        }
        if (keccak256(bytes(chainName)) == keccak256(bytes(Chains.KATANA))) {
            return IComposerLike(address(new OneDeltaComposerKatana()));
        }
        if (keccak256(bytes(chainName)) == keccak256(bytes(Chains.PULSECHAIN))) {
            return IComposerLike(address(new OneDeltaComposerPulsechain()));
        }
        if (keccak256(bytes(chainName)) == keccak256(bytes(Chains.ETHEREUM_MAINNET))) {
            return IComposerLike(address(new OneDeltaComposerEthereum()));
        }
        if (keccak256(bytes(chainName)) == keccak256(bytes(Chains.BERACHAIN))) {
            return IComposerLike(address(new OneDeltaComposerBerachain()));
        }
        if (keccak256(bytes(chainName)) == keccak256(bytes(Chains.CRONOS_MAINNET))) {
            return IComposerLike(address(new OneDeltaComposerCronos()));
        }
        if (keccak256(bytes(chainName)) == keccak256(bytes(Chains.XDC_NETWORK))) {
            return IComposerLike(address(new OneDeltaComposerXdc()));
        }
        if (keccak256(bytes(chainName)) == keccak256(bytes(Chains.MORPH))) {
            return IComposerLike(address(new OneDeltaComposerMorph()));
        }
        if (keccak256(bytes(chainName)) == keccak256(bytes(Chains.MANTA_PACIFIC_MAINNET))) {
            return IComposerLike(address(new OneDeltaComposerMantaPacific()));
        }
        if (keccak256(bytes(chainName)) == keccak256(bytes(Chains.TELOS_EVM_MAINNET))) {
            return IComposerLike(address(new OneDeltaComposerTelosEvm()));
        }
        if (keccak256(bytes(chainName)) == keccak256(bytes(Chains.PLASMA_MAINNET))) {
            return IComposerLike(address(new OneDeltaComposerPlasma()));
        }
        if (keccak256(bytes(chainName)) == keccak256(bytes(Chains.MOONBEAM))) {
            return IComposerLike(address(new OneDeltaComposerMoonbeam()));
        }
        if (keccak256(bytes(chainName)) == keccak256(bytes(Chains.SEI_NETWORK))) {
            return IComposerLike(address(new OneDeltaComposerSei()));
        }
        if (keccak256(bytes(chainName)) == keccak256(bytes(Chains.MONAD_MAINNET))) {
            return IComposerLike(address(new OneDeltaComposerMonad()));
        }
        if (keccak256(bytes(chainName)) == keccak256(bytes(Chains.ETHERLINK_MAINNET))) {
            return IComposerLike(address(new OneDeltaComposerEtherlink()));
        }
        if (keccak256(bytes(chainName)) == keccak256(bytes(Chains.LISK))) {
            return IComposerLike(address(new OneDeltaComposerLisk()));
        }
        if (keccak256(bytes(chainName)) == keccak256(bytes(Chains.BOB))) {
            return IComposerLike(address(new OneDeltaComposerBob()));
        }
        if (keccak256(bytes(chainName)) == keccak256(bytes(Chains.CORN))) {
            return IComposerLike(address(new OneDeltaComposerCorn()));
        }
        if (keccak256(bytes(chainName)) == keccak256(bytes(Chains.STABLE_MAINNET))) {
            return IComposerLike(address(new OneDeltaComposerStable()));
        }
        if (keccak256(bytes(chainName)) == keccak256(bytes(Chains.PLUME_MAINNET))) {
            return IComposerLike(address(new OneDeltaComposerPlume()));
        }
        if (keccak256(bytes(chainName)) == keccak256(bytes(Chains.GOAT_NETWORK))) {
            return IComposerLike(address(new OneDeltaComposerGoat()));
        }
        if (keccak256(bytes(chainName)) == keccak256(bytes(Chains.ABSTRACT))) {
            return IComposerLike(address(new OneDeltaComposerAbstract()));
        }
        if (keccak256(bytes(chainName)) == keccak256(bytes(Chains.MEGAETH_MAINNET))) {
            return IComposerLike(address(new OneDeltaComposerMegaeth()));
        }
        if (keccak256(bytes(chainName)) == keccak256(bytes(Chains.INK))) {
            return IComposerLike(address(new OneDeltaComposerInk()));
        }
        if (keccak256(bytes(chainName)) == keccak256(bytes(Chains.FLARE_MAINNET))) {
            return IComposerLike(address(new OneDeltaComposerFlare()));
        }
        if (keccak256(bytes(chainName)) == keccak256(bytes(Chains.X_LAYER_MAINNET))) {
            return IComposerLike(address(new OneDeltaComposerXLayer()));
        }

        revert("No composer for chain");
    }
}
