import {ethers} from "ethers";
import {TransparentUpgradeableProxy__factory} from "../../../types";
import {Chain} from "@1delta/chain-registry";
import {COMPOSER_LOGICS} from "../addresses";

async function main() {
    const p = new ethers.providers.JsonRpcProvider("https://rpc.mantle.xyz");
    // const accounts = await ethers.getSigners()
    const operator = new ethers.Wallet(process.env.PK_5!, p);
    // const operator = accounts[1]
    const chainId = await operator.getChainId();
    console.log("operator", operator.address, "on", chainId);

    if (String(chainId) !== Chain.MANTLE) throw new Error("IC");

    console.log("deploy proxy");
    const dt = await new TransparentUpgradeableProxy__factory(operator).getDeployTransaction(
        // @ts-ignore
        COMPOSER_LOGICS[chainId],
        operator.address,
        "0x"
    );
    const gl = await operator.estimateGas(dt);

    const gs = await p.getGasPrice();

    await operator.sendTransaction({...dt, gasLimit: gl, gasPrice: gs});
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
