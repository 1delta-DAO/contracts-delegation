
import { ethers } from "hardhat";
import { Comet } from "../../test-ts/1delta/shared/compoundV3Fixture";
import { CometExt, CometExt__factory, CometLens__factory, Comet__factory } from "../../types";

async function main() {
    const accounts = await ethers.getSigners()
    const operator = accounts[0]
    const chainId = await operator.getChainId();

    console.log("Tests lens on ", chainId, " by ", operator.address)
    const comet = await new Comet__factory(operator).attach('0xF09F0369aB0a875254fB565E52226c88f10Bc839') as Comet 

    const cometExt = await new CometExt__factory(operator).attach('0x1c3080d7fd5c97A58E0F2EA19e9Eec4745dC4BDe')

    const c = await cometExt.collateralBalanceOf(operator.address, '0x4B5A0F4E00bC0d6F16A593Cae27338972614E713',)
    console.log(c)
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });