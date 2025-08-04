import {ethers} from "ethers";
import {getPDDeployCode} from "./aaveV2PDProvider";

/** The address provider for the deployment */
const addressesProvider = "0x746fE703B81EA56499C62A447d67183C850DcAcA";

/** Deploy an aave v2/3 protocol data provider based on simple bytecode (no explicit contract needed) */
async function main() {
    const provider = new ethers.providers.JsonRpcProvider("https://rpc.pulsechain.com");
    // const accounts = await ethers.getSigners()
    const operator = new ethers.Wallet(process.env.PK_5!, provider);
    // const operator = accounts[1]

    console.log("deploy quoter");

    // get the deploy code
    const dt = "0x" + getPDDeployCode(addressesProvider.replace("0x", ""));

    const gl = await operator.estimateGas({data: dt});

    const gs = await provider.getFeeData();

    const tx = await operator.sendTransaction({data: dt, gasLimit: gl});

    console.log("tx", tx.hash);
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
