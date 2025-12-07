// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

abstract contract ERC721Receiver {
    function onERC721Received(address, address, uint256, bytes memory) public virtual returns (bytes4) {
        return this.onERC721Received.selector;
    }
}
