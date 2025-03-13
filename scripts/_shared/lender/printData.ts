import { Chain } from "@1delta/asset-registry";
import { getAaveForkApproves, getAaveForkDatas, getCompoundV3Approves } from "./getDatas";

async function main() {

    // const apprsCompound = getCompoundV3Approves(Chain.HEMI_NETWORK)
    const apprsAave = getAaveForkApproves(Chain.HEMI_NETWORK)
    const insertsAave = getAaveForkDatas(Chain.HEMI_NETWORK)

    const allDatas = [
        // ...apprsCompound,
         ...apprsAave, ...insertsAave]
    allDatas.map(a => console.log(a))
}


main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });

