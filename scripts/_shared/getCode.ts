import {ethers} from "hardhat";

const provider = new ethers.providers.JsonRpcProvider("https://rpcapi.fantom.network", {
    name: "fantom",
    chainId: 250,
});

async function checkCode() {
    const code = await provider.getCode("0xba1a60df762118282D268803BD4581E8904Bd9d0");
    console.log(code === "0x" ? "No contract" : "Contract exists");
}

checkCode();
