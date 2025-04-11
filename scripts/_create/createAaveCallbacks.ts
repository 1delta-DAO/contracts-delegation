

import { AAVE_FORK_POOL_DATA, AAVE_V2_LENDERS, AAVE_V3_LENDERS, Chain } from "@1delta/asset-registry";
import { getAddress } from "ethers/lib/utils";
import * as fs from "fs";

const templateAaveV2 = (addressContants: string, switchCaseContent: string) => `
// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.28;

import {Masks} from "../../../shared/masks/Masks.sol";
import {DeltaErrors} from "../../../shared/errors/Errors.sol";

/**
 * @title Take an Aave V2 flash loan callback
 */
contract AaveV2FlashLoanCallback is Masks, DeltaErrors {
    // Aave v2s
    ${addressContants}

    /**
     * @dev Aave V2 style flash loan callback
     */
    function executeOperation(
        address[] calldata,
        uint256[] calldata,
        uint256[] calldata, // we assume that the data is known to the caller in advance
        address initiator,
        bytes calldata params
    ) external returns (bool) {
        address origCaller;
        uint256 calldataOffset;
        uint256 calldataLength;
        assembly {
            calldataOffset := params.offset
            calldataLength := params.length
            // validate caller
            // - extract id from params
            let firstWord := calldataload(calldataOffset)
            let source := and(UINT8_MASK, shr(88, firstWord))

            // Validate the caller
            // We check that the caller is one of the lending pools
            // This is a crucial check since this makes
            // the initiator paramter the caller of flashLoan
            switch source
            ${switchCaseContent}
            // We revert on any other id
            default {
                mstore(0, INVALID_FLASH_LOAN)
                revert(0, 0x4)
            }
            // We require to self-initiate
            // this prevents caller impersonation,
            // but ONLY if the caller address is
            // an Aave V2 type lending pool
            if xor(address(), initiator) {
                mstore(0, INVALID_CALLER)
                revert(0, 0x4)
            }
            // Slice the original caller off the beginnig of the calldata
            // From here on we have validated that the origCaller
            // was attached in the deltaCompose function
            // Otherwise, this would be a vulnerability
            origCaller := shr(96, firstWord)
            // shift / slice params
            calldataOffset := add(calldataOffset, 21)
            calldataLength := sub(calldataLength, 21)
        }
        // within the flash loan, any compose operation
        // can be executed
        // we pass the payAmount and loaned amount for consistent usage
        _deltaComposeInternal(origCaller, calldataOffset, calldataLength);
        return true;
    }

    function _deltaComposeInternal(address callerAddress, uint256 offset, uint256 length) internal virtual {}
}
`


const templateAaveV3 = (addressContants: string, switchCaseContent: string) => `
// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.28;

import {Masks} from "../../../shared/masks/Masks.sol";
import {DeltaErrors} from "../../../shared/errors/Errors.sol";

/**
 * @title Take an Aave v3 flash loan callback
 */
contract AaveV3FlashLoanCallback is Masks, DeltaErrors {
    // Aave V3 style lender pool addresses
    ${addressContants}

    /**
     * @dev Aave V3 style flash loan callback
     */
    function executeOperation(
        address,
        uint256,
        uint256,
        address initiator,
        bytes calldata params // user params
    ) external returns (bool) {
        address origCaller;
        uint256 calldataLength;
        assembly {
            calldataLength := params.length

            // validate caller
            // - extract id from params
            let firstWord := calldataload(196)
            let source := and(UINT8_MASK, shr(88, firstWord))

            // Validate the caller
            // We check that the caller is one of the lending pools
            // This is a crucial check since this makes
            // the initiator paramter the caller of flashLoan
            switch source
            ${switchCaseContent}
            // We revert on any other id
            default {
                mstore(0, INVALID_FLASH_LOAN)
                revert(0, 0x4)
            }
            // We require to self-initiate
            // this prevents caller impersonation,
            // but ONLY if the caller address is
            // an Aave V3 type lending pool
            if xor(address(), initiator) {
                mstore(0, INVALID_CALLER)
                revert(0, 0x4)
            }
            // Slice the original caller off the beginnig of the calldata
            // From here on we have validated that the origCaller
            // was attached in the deltaCompose function
            // Otherwise, this would be a vulnerability
            origCaller := shr(96, firstWord)
            // shift / slice params
            calldataLength := sub(calldataLength, 21)
        }
        // within the flash loan, any compose operation
        // can be executed
        _deltaComposeInternal(
            origCaller,
            217, // 196 +21 as constant offset
            calldataLength
        );
        return true;
    }

    function _deltaComposeInternal(address callerAddress, uint256 offset, uint256 length) internal virtual {}
}

`

function createConstant(pool: string, lender: string) {
    return `address private constant ${lender} = ${getAddress(pool)};\n`
}

function createCase(lender: string, lenderId: string) {
    return `case ${lenderId} {
                if xor(caller(), ${lender}) {
                    mstore(0, INVALID_CALLER)
                    revert(0, 0x4)
                }
            }\n`
}

interface LenderIdData {
    lender: string
    lenderId: string
    pool: string
}

async function main() {
    const chain = Chain.MANTLE

    let lenderIdsAaveV2: LenderIdData[] = []
    let lenderIdsAaveV3: LenderIdData[] = []
    let currentIdAaveV2 = 0
    let currentIdAaveV3 = 0
    // aave
    Object.entries(AAVE_FORK_POOL_DATA).forEach(([lender, maps], i) => {
        Object.entries(maps).forEach(([chains, e]) => {
            if (chains === chain) {
                if (AAVE_V2_LENDERS.includes(lender as any)) {
                    lenderIdsAaveV2.push({ lender, lenderId: String(currentIdAaveV2), pool: e.pool })
                    currentIdAaveV2 += 1
                }
                if (AAVE_V3_LENDERS.includes(lender as any)) {
                    lenderIdsAaveV3.push({ lender, lenderId: String(currentIdAaveV3), pool: e.pool })
                    currentIdAaveV3 += 1
                }
            }
        });

    });

    let constantsDataV2 = ``
    let switchCaseContentV2 = ``
    lenderIdsAaveV2 = lenderIdsAaveV2.sort(a => a.lender.includes("AAVE") ? -1 : 1)
    console.log("lenderIds", lenderIdsAaveV2)
    lenderIdsAaveV2.forEach(({ pool, lender, lenderId }) => {
        constantsDataV2 += createConstant(pool, lender)
        switchCaseContentV2 += createCase(lender, lenderId)
    })


    let constantsDataV3 = ``
    let switchCaseContentV3 = ``
    lenderIdsAaveV3 = lenderIdsAaveV3.sort(a => a.lender.includes("AAVE") ? -1 : 1)
    console.log("lenderIds", lenderIdsAaveV3)
    lenderIdsAaveV3.forEach(({ pool, lender, lenderId }) => {
        constantsDataV3 += createConstant(pool, lender)
        switchCaseContentV3 += createCase(lender, lenderId)
    })


    const filePathV2 = `./test/data/BamBanV2.sol`;
    fs.writeFileSync(filePathV2, templateAaveV2(constantsDataV2, switchCaseContentV2));


    const filePathV3 = `./test/data/BamBanV3.sol`;
    fs.writeFileSync(filePathV3, templateAaveV3(constantsDataV3, switchCaseContentV3));

    console.log(`Generated BamBan.sol with library constants`);
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
