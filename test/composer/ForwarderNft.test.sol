// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {BaseTest} from "test/shared/BaseTest.sol";
import {Chains} from "test/data/LenderRegistry.sol";
import {ComposerPlugin, IComposerLike} from "plugins/ComposerPlugin.sol";
import {CalldataLib} from "test/composer/utils/CalldataLib.sol";
import {CallForwarder} from "contracts/1delta/composer/generic/CallForwarder.sol";

contract ForwarderNftTest is BaseTest {
    using CalldataLib for bytes;

    IComposerLike oneDV2;
    IERC721 PPGNft = IERC721(0xBd3531dA5CF5857e7CfAA92426877b022e612cf8);
    address ppg_owner = 0x621C70De47c35BE4622c891555a6016cDe2E1a61; // #524
    CallForwarder forwarder;

    function setUp() public virtual {
        rpcOverrides[Chains.ETHEREUM_MAINNET] = "https://eth1.lava.build";
        _init(Chains.ETHEREUM_MAINNET, 23847194, true);

        forwarder = new CallForwarder();

        oneDV2 = IComposerLike(0x97648606fcc22Bd96F87345Ac83Bd6cFCdF0ACBa);
    }

    function test_receive_nft() public {
        vm.prank(ppg_owner);
        PPGNft.approve(address(forwarder), 524);
        PPGNft.setApprovalForAll(address(forwarder), true);
        bytes memory data = CalldataLib.encodeExternalCall(
            address(forwarder),
            0, //
            false,
            CalldataLib.encodeExternalCall(
                address(PPGNft), //
                0,
                false,
                abi.encodeWithSelector(IERC721.safeTransferFrom.selector, ppg_owner, address(forwarder), 524)
            )
        );

        vm.prank(user);
        oneDV2.deltaCompose(data);

        assertEq(PPGNft.ownerOf(524), address(forwarder));
    }
}

interface IERC721 {
    function safeTransferFrom(address from, address to, uint256 tokenId) external;
    function approve(address to, uint256 tokenId) external;
    function setApprovalForAll(address operator, bool _approved) external;
    function ownerOf(uint256 tokenId) external view returns (address);
}
