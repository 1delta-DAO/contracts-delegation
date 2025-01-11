// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.28;

abstract contract KTXQuoterArbitrum {
    address internal constant KTX_VAULT = 0xc657A1440d266dD21ec3c299A8B9098065f663Bb;
    address internal constant KTX_VAULT_UTILS = 0xbde9c699e719bb44811252FDb3B37E6D3eDa5a28;
    address internal constant KTX_VAULT_PRICE_FEED = 0x28403B8668Db61De7484A2EAafB65b950a21a2fb;
    address internal constant USDG = 0x01F28e368dFd0ef184eDA005142650d0B877d645;

    uint256 private constant PRICE_PRECISION = 10 ** 30;

    function getKTXAmountOut(address _tokenIn, address _tokenOut, uint256 amountIn) internal view returns (uint256 amountOut) {
        assembly {
            let ptr := mload(0x40)
            let ptrPlus4 := add(ptr, 0x4)
            ////////////////////////////////////////////////////
            // Step 1: get prices
            ////////////////////////////////////////////////////

            // getPrice(address,bool,bool,bool)
            mstore(ptr, 0x2fc3a70a00000000000000000000000000000000000000000000000000000000)
            // get maxPrice
            mstore(ptrPlus4, _tokenOut)
            mstore(add(ptr, 0x24), 0x1)
            mstore(add(ptr, 0x44), 0x1)
            mstore(add(ptr, 0x64), 0x1)
            pop(
                staticcall(
                    gas(),
                    KTX_VAULT_PRICE_FEED, // this goes to the oracle
                    ptr,
                    0x84,
                    ptrPlus4, // do NOT override the selector
                    0x20
                )
            )
            let priceOut := mload(ptrPlus4)
            // get minPrice
            mstore(ptrPlus4, _tokenIn)
            mstore(add(ptr, 0x24), 0x0)
            // the other vars are stored from the prior call
            pop(
                staticcall(
                    gas(),
                    KTX_VAULT_PRICE_FEED, // this goes to the oracle
                    ptr,
                    0x84,
                    ptr,
                    0x20
                )
            )
            let priceIn := mload(ptr)

            ////////////////////////////////////////////////////
            // Step 2: get amountOut by prices
            ////////////////////////////////////////////////////

            // get gross amountOut unscaled
            amountOut := div(mul(amountIn, priceIn), priceOut)

            ////////////////////////////////////////////////////
            // Step 3: get token decimals and adjust amountOut
            ////////////////////////////////////////////////////

            // selector for decimals()
            mstore(ptr, 0x313ce56700000000000000000000000000000000000000000000000000000000)
            pop(staticcall(gas(), _tokenIn, ptr, 0x4, ptrPlus4, 0x20))
            let decsIn := exp(10, mload(ptrPlus4))
            pop(staticcall(gas(), _tokenOut, ptr, 0x4, ptrPlus4, 0x20))
            let decsOut := exp(10, mload(ptrPlus4))
            // adjust amountOut for correct decimals
            amountOut := div(mul(amountOut, decsOut), decsIn)

            ////////////////////////////////////////////////////
            // Step 4: calculate fees
            //      4.1: get usdg amount
            //      4.2: get getSwapFeeBasisPoints
            ////////////////////////////////////////////////////
            let usdgAmount := div(
                mul(
                    div(
                        mul(amountIn, priceIn), // price adj
                        PRICE_PRECISION
                    ),
                    1000000000000000000 // 1e18
                ),
                decsIn
            )
            // getSwapFeeBasisPoints(address,address,uint256)
            mstore(ptr, 0xda13381600000000000000000000000000000000000000000000000000000000)
            mstore(ptrPlus4, _tokenIn)
            mstore(add(ptr, 0x24), _tokenOut)
            mstore(add(ptr, 0x44), usdgAmount)

            pop(staticcall(gas(), KTX_VAULT_UTILS, ptr, 0x64, ptr, 0x20))
            ////////////////////////////////////////////////////
            // Step 5: get net return amount and validate vs. vault balance
            ////////////////////////////////////////////////////
            amountOut := div(
                mul(
                    amountOut, //  * decsOut / decsIn
                    sub(10000, mload(ptr))
                ),
                10000
            )

            // selector for balanceOf(address)
            mstore(0x0, 0x70a0823100000000000000000000000000000000000000000000000000000000)
            // add this address as parameter
            mstore(0x4, KTX_VAULT)

            // call to tokenOut to fetch balance
            if iszero(staticcall(gas(), _tokenOut, 0x0, 0x24, 0x0, 0x20)) {
                revert(0, 0)
            }
            // vault must have enough liquidity
            if lt(mload(0x0), amountOut) {
                revert(0, 0)
            }
        }
    }
}
