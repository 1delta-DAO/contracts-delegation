


import { impersonateAccount } from "@nomicfoundation/hardhat-network-helpers";
import { formatEther, parseUnits } from "ethers/lib/utils";
import { ERC20Mock__factory } from "../types";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import { ethers } from "hardhat";
import { utils } from "ethers";

const trader0 = ''

const ct = ""

let user: SignerWithAddress

it("Test", async function () {
    const [signer] = await ethers.getSigners();
    user = signer
    // await impersonateAccount(trader0)
    // const impersonatedSigner = await ethers.getSigner(trader0);

    // const contract = await new ERC20Mock__factory(user).attach('')
    // const bal = await contract.balanceOf(trader0)

    // const bal2 = await contract.balanceOf(trader0)
    // console.log(formatEther(bal), formatEther(bal2))
    // '0x6100003d81600a3d39f3363d3d373d3d3d3d610000806035363936013d73'
    // const hash = '0x51cfe5b1e764dc253f4c8c1f19a081ff4c3517ed78c1b0c915c4faa5fffa6cabf0219da63d7f4cb8'//utils.keccak256("0x5af43d3d93803e603357fd5bf3")
    // console.log("bc", hash)

    // const wmnt = '0x78c1b0c915c4faa5fffa6cabf0219da63d7f4cb8'
    const minu = '0x51cfe5b1E764dC253F4c8C1f19a081fF4C3517eD'
    const packAddresses = (a0: string, a1: string) => {
        return `${a0}${a1.replace('0x', '')}`
    }
    const func = function getCreate2Address(
        factoryAddress: string,
        [tokenA, tokenB]: [string, string],
        hash: string
    ): string {
        const [token0, token1] = tokenA.toLowerCase() < tokenB.toLowerCase() ? [tokenA, tokenB] : [tokenB, tokenA]
        const constructorArgumentsEncoded = packAddresses(token0, token1)
        console.log("SALT", utils.keccak256(constructorArgumentsEncoded))
        const create2Inputs = [
            '0xff',
            factoryAddress,
            // salt
            utils.keccak256(constructorArgumentsEncoded),
            // init code. bytecode + constructor arguments
            hash,
        ]
        // console.log("Code hash", utils.keccak256(bytecode))
        const sanitizedInputs = `0x${create2Inputs.map((i) => i.slice(2)).join('')}`
        console.log("sanitizedInputs", sanitizedInputs, create2Inputs)
        console.log("utils.keccak256(sanitizedInputs)", utils.keccak256(sanitizedInputs))
        return utils.getAddress(`0x${utils.keccak256(sanitizedInputs).slice(-40)}`)
    }
    // console.log("FUNC", func(fac, [wmnt, minu], hash))

    const implementation = '0x08477e01A19d44C31E4C11Dc2aC86E3BBE69c28B'
    // blobs
    // const b1 = "0x61005f3d81600a3d39f3363d3d373d3d3d3d61002a806035363936013d730847"
    // const b2 = '0x7e01a19d44c31e4c11dc2ac86e3bbe69c28b5af43d3d93803e603357fd5bf337'
    // const b3 = '0x1c7ec6d8039ff7933a2aa28eb827ffe1f52f0778c1b0c915c4faa5fffa6cabf0'
    // const b4 = '0x219da63d7f4cb8002a0000000000000000000000000000000000000000000000' 
    const getInitCodeHash = (impl: string, token0: string, token1: string) => {
        const bytecode = `0x61005f3d81600a3d39f3363d3d373d3d3d3d61002a806035363936013d73${impl.replace('0x', '')}5af43d3d93803e603357fd5bf3${token0.replace('0x', '')}${token1.replace('0x', '')}002a`
        return utils.keccak256(bytecode)

    }


    const getInitCodeHashFromTkns = (tokenA: string, tokenB: string) => {
        const [token0, token1] = tokenA.toLowerCase() < tokenB.toLowerCase() ? [tokenA, tokenB] : [tokenB, tokenA]
        const bytecode = `0x61005f3d81600a3d39f3363d3d373d3d3d3d61002a806035363936013d73${implementation.replace('0x', '')}5af43d3d93803e603357fd5bf3${token0.replace('0x', '')}${token1.replace('0x', '')}002a`
        return utils.keccak256(bytecode)
    }

    const fac = '0x5bef015ca9424a7c07b68490616a4c1f094bedec'
    const wmnt_ = "0x78c1b0C915c4FAA5FffA6CAbf0219DA63d7f4cb8"
    const joe_ = "0x371c7ec6D8039ff7933a2AA28EB827Ffe1F52f07"
    const btx = "0x61005f3d81600a3d39f3363d3d373d3d3d3d61002a806035363936013d7308477e01a19d44c31e4c11dc2ac86e3bbe69c28b5af43d3d93803e603357fd5bf3371c7ec6d8039ff7933a2aa28eb827ffe1f52f0778c1b0c915c4faa5fffa6cabf0219da63d7f4cb8002a"
    console.log("getInitCodeHashFromTkns", getInitCodeHashFromTkns(wmnt_, joe_))
    const hash_wmnt_joe = utils.keccak256(btx)

    // '0x0f6fab083eff0c5734107aa4efc38c1b0d60725b824ebee8d431abfbf12bc953'
    console.log("hash", hash_wmnt_joe)
    console.log("wmnt_, joe_", func(fac, [wmnt_, joe_], getInitCodeHashFromTkns(wmnt_, joe_)))

    console.log("wmnt_, minu", func(fac, [wmnt_, minu], getInitCodeHashFromTkns(wmnt_, minu)))

})

