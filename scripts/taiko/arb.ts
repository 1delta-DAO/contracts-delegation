
import { ethers } from "hardhat";
import {
    OneDeltaComposerTaiko__factory,
} from "../../types";

async function main() {
    const accounts = await ethers.getSigners()
    const operator = accounts[0]
    const chainId = await operator.getChainId();
    if (chainId !== 167000) throw new Error("invalid chainId")
    console.log("operator", operator.address, "on", chainId)


    // deploy modules

    // composer
    const composer = await new OneDeltaComposerTaiko__factory(operator).attach("0x97716A91e4e7Eb6f5E0449E23410D6E16B32e3C8")

    let tx = await composer.deltaCompose("0x02800000000000000000000000000186a0000000000000058d15e176280000006ccc0966d8418d412c599a6421b760a847eb169a8c00b4b56f2a15c3540c5d5f4ddb58650fdc7972027a5101541fd749419ca806a8bc7da8ac23d346f2df8b77003dc55e123cf0a6e7e9221174f0a7501e85febaa723000103cc0966d8418d412c599a6421b760a847eb169a8c22cc0966d8418d412c599a6421b760a847eb169a8c91ae002a960e63ccb0e5bde83a8c13e51e1cb91a000000000000000000000000000000")

    console.log("tx sent")
    await tx.wait()
    console.log("completed")

}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
