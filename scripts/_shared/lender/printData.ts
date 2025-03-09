import { Chain } from "@1delta/asset-registry";
import { getAaveForkApproves, getAaveForkDatas, getCompoundV3Approves } from "./getDatas";

async function main() {

    const apprsCompound = getCompoundV3Approves(Chain.OP_MAINNET)
    const apprsAave = getAaveForkApproves(Chain.OP_MAINNET)
    const insertsAave = getAaveForkDatas(Chain.OP_MAINNET)

    const allDatas = [...apprsCompound, ...apprsAave, ...insertsAave]
    allDatas.map(a => console.log(a))
}


main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });

