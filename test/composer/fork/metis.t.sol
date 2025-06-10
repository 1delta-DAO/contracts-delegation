// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {IERC20All} from "test/shared/interfaces/IERC20All.sol";
import {BaseTest} from "test/shared/BaseTest.sol";
import {Chains, Tokens, Lenders} from "test/data/LenderRegistry.sol";
import "test/composer/utils/CalldataLib.sol";
import {console} from "forge-std/console.sol";
import {ComposerPlugin, IComposerLike} from "plugins/ComposerPlugin.sol";

import "../../../contracts/external-protocols/misc/FeeOnTransferDetector.sol";
import "./FOT.sol";

// solhint-disable max-line-length

interface IA {
    function upgradeAndCall(address proxy, address implementation, bytes memory data) external;
}

interface IUniswapInterfaceMulticall {
    struct Call {
        address target;
        uint256 gasLimit;
        bytes callData;
    }

    struct Result {
        bool success;
        uint256 gasUsed;
        bytes returnData;
    }

    function multicall(Call[] memory calls) external returns (uint256 blockNumber, Result[] memory returnData);
}

contract ForkTestMetis is BaseTest {
    IComposerLike oneDV2;

    address admin = 0xAd723f9A94D8b295781311ca4Ec31D5aBAe07c4f;
    address owner = 0x999999833d965c275A2C102a4Ebf222ca938546f;
    address proxy = 0xCe434378adacC51d54312c872113D687Ac19B516;

    address mockSender = 0x91ae002a960e63Ccb0E5bDE83A8C13E51e1cB91A;
    // address mockSender = 0xdFF70A71618739f4b8C81B11254BcE855D02496B;

    uint256 internal constant forkBlock = 0;

    address internal constant factory = 0xF38E7c7f8eA779e8A193B61f9155E6650CbAE095;
    bool internal constant isSolidly = false;
    bytes32 internal constant codeHash = 0xa856464ae65f7619087bc369daaf7e387dae1e5af69cfa7935850ebf754b04c1;

    FeeOnTransferDetector d;

    function setUp() public virtual {
        // initialize the chain
        string memory chainName = Chains.METIS_ANDROMEDA_MAINNET;

        _init(chainName, forkBlock, true);

        oneDV2 = ComposerPlugin.getComposer(chainName);

        vm.prank(owner);
        IA(admin).upgradeAndCall(proxy, address(oneDV2), hex"");

        d = FeeOnTransferDetector(0xA453ba397c61B0c292EA3959A858821145B2707F);

        labelAddresses();
    }

    function labelAddresses() internal {
        vm.label(owner, "owner");
        vm.label(admin, "admin");
        vm.label(proxy, "proxy");
        vm.label(address(oneDV2), "Composer");
        vm.label(mockSender, "MeMeMeMe");
    }

    function test_fork_raw_metis_fot() external {
        address(d).call(
            hex"ade44597000000000000000000000000000000000000000000000000000000000000006000000000000000000000000075cb093e4d61d2a2e65d8e0bbb01de8d89b5348100000000000000000000000000000000000000000000000000000000009896800000000000000000000000000000000000000000000000000000000000000001000000000000000000000000186573b175adf5801cf95fb06b232ccab123c6f4"
        );
    }

    function test_fork_raw_metis_fot_mc() external {
        IUniswapInterfaceMulticall.Call[] memory calls = new IUniswapInterfaceMulticall.Call[](1);
        calls[0] = IUniswapInterfaceMulticall.Call({
            target: 0xA453ba397c61B0c292EA3959A858821145B2707F,
            callData: hex"ade44597000000000000000000000000000000000000000000000000000000000000006000000000000000000000000075cb093e4d61d2a2e65d8e0bbb01de8d89b5348100000000000000000000000000000000000000000000000000000000009896800000000000000000000000000000000000000000000000000000000000000001000000000000000000000000186573b175adf5801cf95fb06b232ccab123c6f4",
            gasLimit: 4000000
        });

        IUniswapInterfaceMulticall(0x7a59ddbB76521E8982Fa3A08598C9a83b14A6C07).multicall(calls);
    }

    function test_fork_raw_metis_swap() external {
        vm.prank(mockSender);
        address(proxy).call(getData());
    }

    function test_fork_params_metis() external {
        IUniswapV2PairAndERC20(0x186573b175aDF5801cF95Fb06b232ccAB123c6F4).allowance(mockSender, proxy);
        uint256 bal = IUniswapV2PairAndERC20(0x186573b175aDF5801cF95Fb06b232ccAB123c6F4).balanceOf(mockSender);

        vm.prank(mockSender);
        (bytes memory params, uint256 value) = getParams2();
        IComposerLike(proxy).deltaCompose{value: value}(params);
    }

    // nonce 0n
    // cometCreditPermit.ts:120 expiry 1748970849
    // cometCreditPermit.ts:121 v,r,s 27n 0x8c2ebd619f0fef85520e275e95f372e76a6442b28cfe60b76547baca0decc64f 0x16eac8a7b9737f99696f09db674e26ce6e362eb4036153e70a5f9da3eece7aab
    // cometCreditPermit.ts:126 r 8c2ebd619f0fef85520e275e95f372e76a6442b28cfe60b76547baca0decc64f
    // cometCreditPermit.ts:127 vs 16eac8a7b9737f99696f09db674e26ce6e362eb4036153e70a5f9da3eece7aab

    function getData() internal pure returns (bytes memory d) {
        d =
            hex"17d73091000000000000000000000000000000000000000000000000000000000000002000000000000000000000000000000000000000000000000000000000000000ee100000000000000006fab6b9106fe461a9000000000000000000be8498e7a2dcdb186573b175adf5801cf95fb06b232ccab123c6f4010001000000420000000000000000000000000000000000000ace434378adacc51d54312c872113d687ac19b516036d2d52d788a5eab4009dc4e039505212f444bf642134820000000075cb093e4d61d2a2e65d8e0bbb01de8d89b53481ce434378adacc51d54312c872113d687ac19b51600bd718c67cd1e2f7fbe22d47be21036cd647c77141e0bb800010000000000000000000000000000000000000000000091ae002a960e63ccb0e5bde83a8c13e51e1cb91afe0001000000000000000000000000000000000000";
    }

    function getParams2() internal pure returns (bytes memory d, uint256 value) {
        value = 0;
        d =
            hex"100000000000000006fab6b9106fe461a900000000000000000108093d7c88eb5e186573b175adf5801cf95fb06b232ccab123c6f4010002000000420000000000000000000000000000000000000af5988809ac97c65121e2c34f5d49558e3d12c253036d2d52d788a5eab4009dc4e039505212f444bf6426f28200000000ea32a96608495e54156ae48931a7c20f0dcc1a21ef874fede49cf49940e8c472f3e58e75ea65b34c01f5988809ac97c65121e2c34f5d49558e3d12c25326f2000002000075cb093e4d61d2a2e65d8e0bbb01de8d89b53481ce434378adacc51d54312c872113d687ac19b51601ef874fede49cf49940e8c472f3e58e75ea65b34c26f28200020000000000000000000000000000000000000000000091ae002a960e63ccb0e5bde83a8c13e51e1cb91afe0001";
    }
}
