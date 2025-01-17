// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.28;

abstract contract GMXQuoterArbitrum {
    address internal constant GMX_READER = 0x22199a49A999c351eF7927602CFB187ec3cae489;

    function getGMXAmountOut(address _tokenIn, address _tokenOut, address vault, uint256 amountIn) internal view returns (uint256 amountOut) {
        assembly {
            let ptr := mload(0x40)
            // getAmountOut(address,address,address,uint256)
            mstore(ptr, 0xd7176ca900000000000000000000000000000000000000000000000000000000)
            // get maxPrice
            mstore(add(ptr, 0x4), vault) // vault
            mstore(add(ptr, 0x24), _tokenIn)
            mstore(add(ptr, 0x44), _tokenOut)
            mstore(add(ptr, 0x64), amountIn)
            pop(
                staticcall(
                    gas(),
                    GMX_READER, // this goes to the oracle
                    ptr,
                    0x84,
                    0x0, // do NOT override the selector
                    0x20
                )
            )
            amountOut := mload(0x0)
        }
    }
}
