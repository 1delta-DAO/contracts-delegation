import { formatEther } from "ethers/lib/utils";
import { AaveOracle__factory } from "../types";

import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";

const { ethers } = require("hardhat");

const oracleAddress = '0x870c9692Ab04944C86ec6FEeF63F261226506EfC'

const weth = "0xdEAddEaDdeadDEadDEADDEAddEADDEAddead1111"
const wbtc = "0xCAbAE6f6Ea1ecaB08Ad02fE02ce9A44F09aebfA2"
const usdc = "0x09Bc4E0D864854c6aFB6eB9A9cdF58aC190D0dF9"
const wmnt = "0x78c1b0c915c4faa5fffa6cabf0219da63d7f4cb8"
const usdt = "0x201EBa5CC46D216Ce6DC03F6a759e8E766e956aE"
const meth = "0xcda86a272531e8640cd7f1a92c01839911b90bb0"

const symbols = ["usdc", "usdt", "wmnt", "wbtc", "weth", "meth",]
const assets = [usdc, usdt, wmnt, wbtc, weth, meth]

// 52469580 -> open
// 55865166 -> close
let signer: SignerWithAddress
before(async function () {
    const [_signer] = await ethers.getSigners();
    signer = _signer

})


it("Print snapshot", async function () {
    const oracle = await new AaveOracle__factory(signer).attach(oracleAddress)
    const prices = await oracle.getAssetsPrices(assets)

    console.log(prices)
    symbols.map((s, i) => console.log(s.toUpperCase(), formatEther(prices[i])))
})