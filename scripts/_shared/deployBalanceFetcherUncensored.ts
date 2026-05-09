import {ethers} from "hardhat";
import {DeployFactory__factory} from "../../types";
import {DEPLOY_FACTORY} from "./addresses";
import {formatEther, keccak256} from "ethers/lib/utils";

// Soneium Mainnet OptimismPortal (on L1)
const PORTAL = "0x88e529a6ccd302c948689cd5156c83d4614fae92";
const ADDRESS_ALIAS_OFFSET = "0x1111000000000000000000000000000000001111";
const SALT = "0x16c4dc0f662e2becec91fc5e7aeec6a25684698ab8b2457e1ea1fd039c69f19c";

// creation bytecode of the canonical mainnet deployment (0xba1a60c7B0e784Bf25F731Ca9fcA6762fFd63a11)
// sourced from the original deploy tx 0x0f79692aca05dba3df2f440abb1d8d833d3517812c042f8d27a9c30977258068
// BalanceFetcher__factory.bytecode recompiles to a different metadata hash and won't match 0xba1a…
const BYTECODE =
    "0x6080604052348015600f57600080fd5b506102a08061001f6000396000f3fe60806040523415610034577ff2365b5b0000000000000000000000000000000000000000000000000000000060005260046000fd5b610063565b7f7db491eb0000000000000000000000000000000000000000000000000000000060005260046000fd5b7f70a08231000000000000000000000000000000000000000000000000000000006000526100b6565b8160045260006020600460246000855afa156100b057601f3d11156100b057506004515b92915050565b6044356024358160f01c8260e01c61ffff1692508215811517156100dc576100dc610039565b6014830260148202016004018218156100f7576100f7610039565b604051915060108184020260048402016048018201604052602082524360c01b6040830152604882016014840260040160005b85811015610211576004830192604860148302013560601c90600090815b878110156101cf576044601482028701013560601c600081158015610170578631915061017d565b61017a878461008c565b91505b508061018a5750506101c7565b6dffffffffffffffffffffffffffff8116607084901b6fffff0000000000000000000000000000161760801b895250506010870196506001830192505b600101610148565b5080517bffffffffffffffffffffffffffffffffffffffffffffffffffffffff1661ffff8316601086901b63ffff0000161760e01b179052505060010161012a565b50507fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe0601f8201166040528281037fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffc08101602085015283f3fea2646970667358221220e70fe2f286bb2c355aa2e1e9e5742cbd41da375c987f7b85761495dd0efe4dbf64736f6c634300081c0033";

function applyL1ToL2Alias(l1Address: string): string {
    return ethers.utils.getAddress(ethers.BigNumber.from(l1Address).add(ADDRESS_ALIAS_OFFSET).toHexString());
}

async function main() {
    // operator is your L1 signer (mainnet account in hardhat config)
    const [_, operator] = await ethers.getSigners();

    const l1Provider = ethers.provider;
    const l2Provider = new ethers.providers.JsonRpcProvider("https://rpc.soneium.org");

    console.log("L1 operator:  ", operator.address);
    console.log("L1 chain ID:  ", (await l1Provider.getNetwork()).chainId); // should be 1
    console.log("L1 balance:   ", formatEther(await operator.getBalance()), "ETH");

    const gasPrice = await l1Provider.getGasPrice();
    console.log("L1 gas price: ", gasPrice.toNumber() / 1e9, "gwei");

    // Build the calldata for deployFactory.deploy(salt, bytecode) on L2
    const initCodeHash = keccak256(BYTECODE);
    console.log("Initcode hash:", initCodeHash);

    const deployFactoryInterface = DeployFactory__factory.createInterface();
    const calldata = deployFactoryInterface.encodeFunctionData("deploy", [SALT, BYTECODE]);

    // Verify predicted address using L2 provider
    const deployFactory = DeployFactory__factory.connect(DEPLOY_FACTORY, l2Provider);
    const predictedAddress = await deployFactory.computeAddress(SALT, initCodeHash);
    console.log("Predicted L2 address:", predictedAddress);

    // Check if already deployed
    const existingCode = await l2Provider.getCode(predictedAddress);
    if (existingCode !== "0x") {
        console.log("Contract already deployed at", predictedAddress, "— nothing to do.");
        return;
    }

    // Estimate L2 gas for the deployFactory call
    let l2GasLimit: number;
    try {
        const l2Estimate = await l2Provider.estimateGas({
            to: DEPLOY_FACTORY,
            data: calldata,
        });
        l2GasLimit = Math.ceil(l2Estimate.toNumber() * 1.25);
        console.log("L2 gas estimate:", l2Estimate.toString(), "→ using", l2GasLimit);
    } catch (e) {
        console.warn("L2 gas estimation failed, falling back to 5_000_000:", e);
        l2GasLimit = 5_000_000;
    }

    // Portal contract on L1
    const portal = new ethers.Contract(PORTAL, ["function depositTransaction(address,uint256,uint64,bool,bytes) payable"], operator);

    const boostedGasPrice = gasPrice.mul(150).div(100);

    const l1GasEstimate = await portal.estimateGas.depositTransaction(
        DEPLOY_FACTORY, // to: the L2 DeployFactory
        0, // value
        l2GasLimit, // L2 gas limit
        false, // isCreation: false — we're calling an existing contract
        calldata, // encoded deploy(salt, bytecode)
        {value: 0}
    );
    console.log("L1 gas estimate:", l1GasEstimate.toString());
    console.log("Estimated L1 cost:", formatEther(l1GasEstimate.mul(boostedGasPrice)), "ETH");

    console.log("\nSending forced deployment via L1 portal...");

    const tx = await portal.depositTransaction(DEPLOY_FACTORY, 0, l2GasLimit, false, calldata, {gasPrice: boostedGasPrice});

    console.log("L1 tx hash:", tx.hash);
    const receipt = await tx.wait();
    console.log("L1 tx confirmed in block:", receipt.blockNumber);

    const l2Deployer = applyL1ToL2Alias(operator.address);
    console.log("\nForced tx submitted. Monitor L2 for execution:");
    console.log("  L2 msg.sender (aliased):", l2Deployer);
    console.log("  Expect BalanceFetcher at:", predictedAddress);
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
