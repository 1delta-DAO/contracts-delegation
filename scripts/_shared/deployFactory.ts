import { ethers } from "hardhat";
import { DeployFactory__factory } from "../../types";

// deployed on
// avalanche
// mantle
// base
// polygon
// arbitrum
// blast
// linea
// optimism
// bnb chain
// taiko
// xdai
// metis
// mode
// hemi
// core
// sonic
// fantom
// scroll
// kaia
// soneium
// hyperEVM
// unichain
// katana
// ethereum
// berachain
// cronos
// xdc
// manta
// telos
// morph
// moonbeam
// sei
// monad
// flare
// abstract
// ink
// corn
// stable
// megaeth
// plume
// bob
// lisk
// pulse
// x-layer
// robinhood
// pharos

async function main() {
    const accounts = await ethers.getSigners();
    const operator = accounts[3];
    const chainId = await operator.getChainId();
    console.log("operator", operator.address, "on", chainId);
    // Buffer the gas price: on chains with a volatile base fee (e.g. robinhood) the
    // value returned by getGasPrice() can drop below the block base fee before the tx
    // is mined, which reverts with "max fee per gas less than block base fee".
    const gp = (await operator.getGasPrice()).mul(2);

    console.log("gasPrice", gp.toNumber() / 1e9);

    console.log("Deploy factory");
    const deployFactory = await new DeployFactory__factory(operator).deploy({ gasPrice: gp });

    await deployFactory.deployed();

    console.log("factory:", deployFactory.address);
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
