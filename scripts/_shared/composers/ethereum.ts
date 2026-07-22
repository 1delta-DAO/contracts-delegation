import {ethers} from "hardhat";
import {OneDeltaComposerEthereum__factory} from "../../../types";
import {Chain} from "@1delta/chain-registry";

async function main() {
    const accounts = await ethers.getSigners();
    const operator = accounts[1];
    const chainId = await operator.getChainId();
    if (String(chainId) !== Chain.ETHEREUM_MAINNET) throw new Error("IC");
    console.log("operator", operator.address, "on", chainId);

    const gp = await operator.getGasPrice();

    console.log("gasPrice", gp.toNumber() / 1e9);

    const factory = new OneDeltaComposerEthereum__factory(operator);

    // This composer sits near the EIP-170 24,576-byte ceiling, so the code-deposit cost
    // (200 gas/byte ≈ 4.9M) dominates. Private/MEV RPCs (e.g. BlockRazor) mis-estimate or cap
    // eth_estimateGas for large CREATEs and return "contract creation code storage out of gas".
    // Don't rely on the RPC estimate: use it as a best-effort input, but floor the gas limit at a
    // value that always covers a full-size contract deposit.
    let gasLimit = ethers.BigNumber.from(7_000_000);
    try {
        const est = await operator.estimateGas(factory.getDeployTransaction());
        const padded = est.mul(13).div(10); // +30% headroom
        if (padded.gt(gasLimit)) gasLimit = padded;
    } catch (e) {
        console.warn("estimateGas failed (RPC), using floor gasLimit", gasLimit.toString(), "-", (e as Error).message);
    }
    console.log("gasLimit", gasLimit.toString());

    const composer = await factory.deploy({gasPrice: gp, gasLimit});
    await composer.deployed();

    console.log("deployed expected to", composer.address);
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
