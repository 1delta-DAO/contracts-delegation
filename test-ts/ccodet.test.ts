


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

    const weth = '0xA51894664A773981C6C112C43ce576f315d5b1B6'
    const usdc = "0x07d83526730c7438048D55A4fc0b850e2aaB6f0b"
    const factory = '0x0d22b434E478386Cd3564956BFc722073B3508f6'

    const f = function getCreate2Address(
        factoryAddress: string,
        [tokenA, tokenB]: [string, string],
        // bytecodeHash: string
    ): string {
        const [token0, token1] = tokenA.toLowerCase() < tokenB.toLowerCase() ? [tokenA, tokenB] : [tokenB, tokenA]
        const constructorArgumentsEncoded = utils.defaultAbiCoder.encode(
            ['address', 'address'],
            [token0, token1]
        )


        // await network.provider.
        const bc = ""
        const create2Inputs = [
            '0xff',
            factoryAddress,
            // salt
            utils.keccak256(constructorArgumentsEncoded),
            // init code. bytecode + constructor arguments
            bc ?? utils.keccak256(bc),
            // "0x4b9e4a8044ce5695e06fce9421a63b6f5c3db8a561eebb30ea4c775469e36eaf",
            // '0xbe0bfe068cdd78cafa3ddd44e214cfa4e412c15d7148e932f8043fe883865e40'
        ]
        console.log("Code hash", utils.keccak256(bc))

        // OTHER (OLD) BISWAPV3 0x712a91d34948c3b3e0b473b519235f7d14dbf2472983bc5d3f7e67c501d7a348
        // CURRENT BISWAPV3 0xf3034e9d7a0088686a7f25c4f21bbc3aaef5c12a91c85768621e4d450abb1cb1
        const sanitizedInputs = `0x${create2Inputs.map((i) => i.slice(2)).join('')}`
        return utils.getAddress(`0x${utils.keccak256(sanitizedInputs).slice(-40)}`)
    }
    console.log("factory, [usdc, weth]", factory, [usdc, weth])
    console.log(f(factory, [usdc, weth]))
    const pool = '0x044e9d04E95Da164E7C7a9E2Ec734610C09Aae13'
    console.log("exp", pool)

})

