
import { ethers } from "hardhat";
import { CometLens__factory } from "../../types";

const usedMaxFeePerGas = 370_000_000_000
const usedMaxPriorityFeePerGas = 70_000_000_000

const opts = {
    maxFeePerGas: usedMaxFeePerGas,
    maxPriorityFeePerGas: usedMaxPriorityFeePerGas,
    // gasLimit: 4_500_000
}


async function main() {
    const accounts = await ethers.getSigners()
    const operator = accounts[1]
    const chainId = await operator.getChainId();

    console.log("Deploy lens on ", chainId, " by ", operator.address)
    const lens = await new CometLens__factory(operator).deploy(opts)
    await lens.deployed()
    console.log("lens:", lens.address)
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });


// Deploy lens on  80001  by  0xdfF1b98cbFAc68Af1b2722Ed78D6e47AbFb7D8C1
// lens: 0xC49bfddbbBFB3274e9b9D2059a6344472FC91fBB
                                                                                
// Deploy lens on  137  by  0x999999833d965c275A2C102a4Ebf222ca938546f
// lens: 0x47B087eBeD0d5a2Eb93034D8239a5B89d0ddD990
