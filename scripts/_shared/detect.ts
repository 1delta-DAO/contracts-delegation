
import { ethers } from "hardhat";
import { FeeOnTransferDetector__factory } from "../../types";


async function main() {
    const accounts = await ethers.getSigners()
    const operator = accounts[1]
    const chainId = await operator.getChainId();
    console.log("operator", operator.address, "on", chainId)

    console.log("deploy for detector")

    const dt = new FeeOnTransferDetector__factory(operator).attach("0xA453ba397c61B0c292EA3959A858821145B2707F")


    const detector = await dt.callStatic.validate("0x186573b175aDF5801cF95Fb06b232ccAB123c6F4", "0x75cb093E4D61d2A2e65D8e0BBb01DE8d89b53481", 10000000)

    console.log("detector:", detector)
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
