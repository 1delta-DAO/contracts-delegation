


import { impersonateAccount } from "@nomicfoundation/hardhat-network-helpers";
import { formatEther, parseUnits } from "ethers/lib/utils";
import { ERC20Mock__factory } from "../types";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import { ethers } from "hardhat";

const trader0 = ''

const ct = ""

let user: SignerWithAddress

it("Test", async function () {
    const [signer] = await ethers.getSigners();
    user = signer
    await impersonateAccount(trader0)
    const impersonatedSigner = await ethers.getSigner(trader0);

    const contract = await new ERC20Mock__factory(user).attach('')
    const bal = await contract.balanceOf(trader0)

    await impersonatedSigner.sendTransaction({
        data: '',
        value: parseUnits('1', 18),
        to: ct
    })

    await impersonatedSigner.sendTransaction({
        data: '',
        to: ct
    })

    const bal2 = await contract.balanceOf(trader0)
    console.log(formatEther(bal), formatEther(bal2))
})

