// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.26;

import "./FlashAggregatorInternal.sol";
import "./TokenTransfer.sol";

contract Composer is DeltaFlashAggregatorMantleInternal, RawTokenTransfer {

    /// @dev determines whether we skip caching the caller address
    ///      Typically we want to skip cahching when executing spot batches
    modifier handleSetCache(bytes1 useCache) {
        assembly {
            if useCache {
                sstore(CACHE_SLOT, caller())
            }
        }
        _;
        assembly {
            if useCache {
                sstore(CACHE_SLOT, DEFAULT_CACHE)
            }
        }
    }

    bytes1 private constant ZERO = 0x0;

    /**
     * Execute a set op packed operations
     * @param data packed ops array
     * requireCache |op0 | length0 | data0 | op1 | length1 | ...
     *      1       | 1   |    16   | ...   |  1  |    16   | ...
     */
    function deltaCompose(
        bytes calldata data
    )
        external
        payable
        handleSetCache(bytes1(data)) // the first bytes determines whether we skip the cache
    {
        assembly {
            data.offset := add(data.offset, 1)
            data.length := sub(data.length, 1)
        }
        // data encding paramters
        uint calldatalength;
        uint currentOffset;
        uint8 operation;
        bytes calldata opdata;
        // execute ops
        while (true) {
            // fetch op metadata
            assembly {
                let word := calldataload(add(data.offset, currentOffset))
                calldatalength := and(shr(240, word), UINT16_MASK)
                operation := and(shr(232, word), UINT8_MASK)
                opdata.offset := currentOffset
                opdata.length := calldatalength
            }
            // exec op
            if (operation == 0x0) _transferERC20TokensFromInternal(opdata);
            else if (operation == 0x01) flashSwapExactIn(opdata);
            else if (operation == 0x02) flashSwapExactOut(opdata);
            else if (operation == 0x03) swapExactInSpot(opdata);
            else if (operation == 0x04) swapExactInSpotSelf(opdata);
            else if (operation == 0x05) swapExactOutSpot(opdata);
            else if (operation == 0x06) swapExactOutSpotSelf(opdata);
            else if (operation == 0x07) depo(opdata);
            else if (operation == 0x08) borrow(opdata);
            else if (operation == 0x09) withdraw(opdata);
            else if (operation == 0x10) repay(opdata);
            else if (operation == 0x11) _transferERC20TokensInternal(opdata);
            else revert();

            // update op offset
            assembly {
                // length plus uint16 plus bytes1
                currentOffset := add(add(calldatalength, 3), currentOffset)
            }
            // break criteria
            if (currentOffset == data.length) break;
        }
    }

    ////////////////////////////////////////////////////
    // Transfers
    ////////////////////////////////////////////////////

    function transferIn(bytes calldata data) internal {
        _transferERC20TokensFrom(msg.sender, address(bytes20(data)), address(this), uint(bytes32(data[20:52])));
    }

    function transferOutWithCheck(bytes calldata data) internal {
        _transferERC20Tokens(address(bytes20(data)), address(bytes20(data[20:40])), uint(bytes32(data[20:52])));
    }

    function refund(bytes calldata data) internal {
        _transferERC20Tokens(address(bytes20(data)), address(bytes20(data[20:40])), uint(bytes32(data[20:52])));
    }

    ////////////////////////////////////////////////////
    // Lending
    ////////////////////////////////////////////////////

    function depo(bytes calldata data) internal {
        _deposit(address(bytes20(data)), address(bytes20(data[20:40])), uint(bytes32(data[20:52])), 0);
    }

    function borrow(bytes calldata data) internal {
        _borrow(address(bytes20(data)), address(bytes20(data[20:40])), uint(bytes32(data[20:52])), 1, 0);
    }

    function withdraw(bytes calldata data) internal {
        _withdraw(address(bytes20(data)), address(bytes20(data[20:40])), uint(bytes32(data[20:52])), 0);
    }

    function repay(bytes calldata data) internal {
        _repay(address(bytes20(data)), address(bytes20(data[20:40])), uint(bytes32(data[20:52])), 1, 0);
    }
}
