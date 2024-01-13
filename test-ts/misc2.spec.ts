


import { impersonateAccount } from "@nomicfoundation/hardhat-network-helpers";
import { formatEther, parseUnits } from "ethers/lib/utils";
import { ERC20Mock__factory } from "../types";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import { ethers, network } from "hardhat";
import { utils } from "ethers";

const trader0 = ''

const ct = ""

let user: SignerWithAddress

it("Test", async function () {
    const [signer] = await ethers.getSigners();
    user = signer

    const ltc = '0x4338665CBB7B2485A8855A139b75D5e34AB0DB94'
    const usdt = '0x55d398326f99059fF775485246999027B3197955'
    const busd = '0x55d398326f99059fF775485246999027B3197955'
    const wbnb = '0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c'
    const fee = 2000
    const factory = '0x93BB94a0d5269cb437A1F71FF3a77AB753844422'
    
    const f = function getCreate2Address(
        factoryAddress: string,
        [tokenA, tokenB]: [string, string],
        fee: number,
        // bytecodeHash: string
    ): string {
        const [token0, token1] = tokenA.toLowerCase() < tokenB.toLowerCase() ? [tokenA, tokenB] : [tokenB, tokenA]
        const constructorArgumentsEncoded = utils.defaultAbiCoder.encode(
            ['address', 'address', 'uint24'],
            [token0, token1, fee]
        )
        const create2Inputs = [
            '0xff',
            factoryAddress,
            // salt
            utils.keccak256(constructorArgumentsEncoded),
            // init code. bytecode + constructor arguments
            // bytecode ??  utils.keccak256(bytecode),
            '0xbe0bfe068cdd78cafa3ddd44e214cfa4e412c15d7148e932f8043fe883865e40'
        ]
        // console.log("Code hash", utils.keccak256(bytecode))
  
        // OTHER (OLD) BISWAPV3 0x712a91d34948c3b3e0b473b519235f7d14dbf2472983bc5d3f7e67c501d7a348
        // CURRENT BISWAPV3 0xf3034e9d7a0088686a7f25c4f21bbc3aaef5c12a91c85768621e4d450abb1cb1
        const sanitizedInputs = `0x${create2Inputs.map((i) => i.slice(2)).join('')}`
        return utils.getAddress(`0x${utils.keccak256(sanitizedInputs).slice(-40)}`)
    }
    console.log(f(factory, [busd, wbnb], fee))

})

