import {ethers} from "ethers";
import {OneDeltaComposerHyperevm__factory} from "../../../../types";
import {formatEther} from "ethers/lib/utils";

async function main() {
    const p = new ethers.providers.JsonRpcProvider("https://rpc.hyperliquid.xyz/evm");
    // const accounts = await ethers.getSigners()
    const operator = new ethers.Wallet(process.env.PK_5!, p);
    // const operator = accounts[1]
    const chainId = await operator.getChainId();
    console.log("operator", operator.address, "on", chainId);

    console.log("deploy composer");

    const dt = new OneDeltaComposerHyperevm__factory(operator).getDeployTransaction();

    const gl = await operator.estimateGas(dt);

    console.log(formatEther(gl));

    const gs = await p.getGasPrice();

    await operator.sendTransaction({...dt, gasLimit: gl, gasPrice: gs});

    // const oneDeltaManagement = await new QuoterLight__factory(operator).deploy()

    // console.log("quoter:", oneDeltaManagement.address)
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
