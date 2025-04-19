export const templateUniversalFlashLoan = (
    hasMorpho: boolean,
    hasAaveV2: boolean,
    hasAaveV3: boolean,
    hasBalancerV2: boolean
) => {
    let isFirst = true

    let imports = ``
    let inherits: string[] = []
    let data = ``
    if (hasMorpho) {
        data += morphoSnippet(isFirst)
        isFirst = false
        imports += `import {MorphoFlashLoans} from "../../../flashLoan/Morpho.sol";\n`
        inherits.push("MorphoFlashLoans")
    }
    if (hasAaveV3) {
        data += aaveV3Snippet(isFirst)
        isFirst = false
        imports += `import {AaveV3FlashLoans} from "../../../flashLoan/AaveV3.sol";\n`
        inherits.push("AaveV3FlashLoans")
    }
    if (hasAaveV2) {
        data += aaveV2Snippet(isFirst)
        isFirst = false
        imports += `import {AaveV2FlashLoans} from "../../../flashLoan/AaveV2.sol";\n`
        inherits.push("AaveV2FlashLoans")
    }

    if (hasBalancerV2) {
        data += balancerV2Snippet(isFirst)
        isFirst = false
        imports += `import {BalancerV2FlashLoans} from "./BalancerV2.sol";\n`
        inherits.push("BalancerV2FlashLoans")
    }


    return `

// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.28;

${imports}
import {FlashLoanCallbacks} from "./FlashLoanCallbacks.sol";
import {FlashLoanIds} from "../../../enums/DeltaEnums.sol";
import {DeltaErrors} from "../../../../shared/errors/Errors.sol";

/**
 * @title Flash loan aggregator
 * @author 1delta Labs AG
 */
contract UniversalFlashLoan is
    ${inherits.join(",")},
    FlashLoanCallbacks //
{
    /**
     * All flash ones in one function -what do you need more?
     */
    function _universalFlashLoan(uint256 currentOffset, address callerAddress) internal virtual returns (uint256) {
        uint256 flashLoanType; // architecture type
        assembly {
            flashLoanType := shr(248, calldataload(currentOffset)) // already masks uint8 as last byte
            currentOffset := add(currentOffset, 1)
        }
        ${data}
        else {
            _invalidOperation();
        }
    }
}

`

}

function aaveV2Snippet(isFirst: boolean) {
    if (isFirst) {
        return `
        if (flashLoanType == FlashLoanIds.AAVE_V2) {
            return aaveV2FlashLoan(currentOffset, callerAddress);
        } `
    }
    return `
        else if (flashLoanType == FlashLoanIds.AAVE_V2) {
            return aaveV2FlashLoan(currentOffset, callerAddress);
        } `
}

function morphoSnippet(isFirst: boolean) {
    if (isFirst) {
        return `
        if (flashLoanType == FlashLoanIds.MORPHO) {
            return morphoFlashLoan(currentOffset, callerAddress);
        } `
    }
    return `
         else if (flashLoanType == FlashLoanIds.MORPHO) {
            return morphoFlashLoan(currentOffset, callerAddress);
        }`
}


function balancerV2Snippet(isFirst: boolean) {
    if (isFirst) {
        return `
        if (flashLoanType == FlashLoanIds.BALANCER_V2) {
            return balancerV2FlashLoan(currentOffset, callerAddress);
        } `
    }
    return `
         else if (flashLoanType == FlashLoanIds.BALANCER_V2) {
            return balancerV2FlashLoan(currentOffset, callerAddress);
        }`
}

function aaveV3Snippet(isFirst: boolean) {
    if (isFirst) {
        return `
        if (flashLoanType == FlashLoanIds.AAVE_V3) {
            return aaveV3FlashLoan(currentOffset, callerAddress);
        } `
    }
    return `
        else if (flashLoanType == FlashLoanIds.AAVE_V3) {
            return aaveV3FlashLoan(currentOffset, callerAddress);
        } `
}
