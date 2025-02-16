import { Chain } from "@1delta/asset-registry";
import { getAaveForkApproveDatas, getAaveForkDatas, getCompoundV3Approves } from "./getDatas";

async function main() {

    const apprsCompound = getCompoundV3Approves(Chain.ARBITRUM_ONE)
    const apprsAave = getAaveForkApproveDatas(Chain.ARBITRUM_ONE)
    const insertsAave = getAaveForkDatas(Chain.ARBITRUM_ONE)

    const allDatas = [...apprsCompound, ...apprsAave, ...insertsAave]
    allDatas.map(a => console.log(a))
}


main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });

