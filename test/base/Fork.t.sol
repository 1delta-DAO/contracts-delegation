// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {Test} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";
import {IBrokerProxy} from "../shared/interfaces/IBrokerProxy.sol";
import {IFlashAggregator} from "../shared/interfaces/IFlashAggregator.sol";
import {OneDeltaComposerBase} from "../../contracts/1delta/modules/base/Composer.sol";
import {IManagement} from "../shared/interfaces/IManagement.sol";
import {IModuleConfig} from "../../contracts/1delta/proxy/interfaces/IModuleConfig.sol";
import {IFlashLoanReceiver} from "./utils/IFlashLoanReceiver.sol";
import {IModuleLens} from "../../contracts/1delta/proxy/interfaces/IModuleLens.sol";

// solhint-disable max-line-length

contract ForkTestBase is Test {
    address internal constant brokerProxyAddress = 0x816EBC5cb8A5651C902Cb06659907A93E574Db0B;

    function setUp() public virtual {
        vm.createSelectFork({blockNumber: 26943916, urlOrAlias: "https://mainnet.base.org"});
        address admin = 0x999999833d965c275A2C102a4Ebf222ca938546f;
        address oldModule = 0x1A3B6150F08Ed6568FB36781f6bB3A3c84b38dFE;
        upgradeExistingDelta(admin, oldModule);
    }


    // skipt this one for now
    function test_generic_base() external /** address user, uint8 lenderId */ {
        address user = 0x91ae002a960e63Ccb0E5bDE83A8C13E51e1cB91A;
        vm.prank(user);
        vm.expectRevert(); // should revert with slippage
        (bool success, bytes memory ret) = address(brokerProxyAddress).call(getGenericData());
        if (!success) {
            console.logBytes(ret);
            // Next 5 lines from https://ethereum.stackexchange.com/a/83577
            if (ret.length < 68) revert();
            assembly {
                ret := add(ret, 0x04)
            }
            revert(abi.decode(ret, (string)));
        }
    }

    function getGenericData() internal pure returns (bytes memory data) {
        // this data is incorrect for block 60576346
        data = hex"17d73091000000000000000000000000000000000000000000000000000000000000002000000000000000000000000000000000000000000000000000000000000007d133e11333bc86f00895d9b147113c1bb8aa2d6787ff0064000000000000000000000000000000000000000000000000000002dff2885b4367c0a8f6c1d87fb0bb4ba331d8ca1a0639a2fa037b4f4215dfd520f92369a8e381ebb4c6d284476c4e1c69d3f62df68d83f5243e43ac0372c2485d74425fb0bbd4499cee3464c26c9099bd3789107888c35bb41178079b282561000000000000000002d8a9293968073004c26c9099bd3789107888c35bb41178079b2825616131b5fae19ea4f9d964eac0408e4408b66337b5000000000000000002d8a92939680684e21fd0e90000000000000000000000000000000000000000000000000000000000000020000000000000000000000000c7d3ab410d49b664d03fe5b1038852ac852b1b29000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000a000000000000000000000000000000000000000000000000000000000000001c0000000000000000000000000000000000000000000000000000000000000040000000000000000000000000000000000000000000000000000000000000000fc01010000005100c7d3ab410d49b664d03fe5b1038852ac852b1b29000000283f82a1d3b65090ed241b30c3d4ccb777b1e8ae0000000000000000000002d8a92939680100000000000000000000000000000000000000000ac26c9099bd3789107888c35bb41178079b2825613b86ad95859b6ab773f55f8d94b4b9d443ee931f816ebc5cb8a5651c902cb06659907a93e574db0b00000000000000000000000067c0a580000000540000000000000000000000000000000000000000000000000000000000000000000000000000000000000000002f56610000000000000000000002d24fcbeb204f82e73edb06d29ff62c91ec8f5ff06571bdeb2900000000000000000000000000000000c26c9099bd3789107888c35bb41178079b2825610000000000000000000000003b86ad95859b6ab773f55f8d94b4b9d443ee931f000000000000000000000000000000000000000000000000000000000000016000000000000000000000000000000000000000000000000000000000000001a000000000000000000000000000000000000000000000000000000000000001e00000000000000000000000000000000000000000000000000000000000000200000000000000000000000000816ebc5cb8a5651c902cb06659907a93e574db0b000000000000000000000000000000000000000000000000000002d8a9293968000000000000000000000000000000000000000000000000000002cb16adb822000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000002200000000000000000000000000000000000000000000000000000000000000001000000000000000000000000c7d3ab410d49b664d03fe5b1038852ac852b1b290000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000002d8a929396800000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000002217b22536f75726365223a226e756c6c3a6c6f63616c686f7374222c22416d6f756e74496e555344223a2230222c22416d6f756e744f7574555344223a22302e32363132343139373139303535373134222c22526566657272616c223a22222c22466c616773223a302c22416d6f756e744f7574223a2233313032333035313531373736222c2254696d657374616d70223a313734303637373332382c22496e74656772697479496e666f223a7b224b65794944223a2231222c225369676e6174757265223a224b7a646f374c2b71576e4a59792f74734f2f4d7469386d7464484a394a704b64695932776c75543331643578546453563957385641313478776532667771747a617a456d7a6a4e512f524f6f7232416e417255324b474e3074684d30563767716e6a767259564e76356e31505630727839685a4b54683862753549336f756465696a6d2b5538754d556e3275506c632b6f64774d71776a5474634e6d34376265736a4351304448644d4f35496d5849656c45524c697148436e394c43745734324e34715670496235617a4d4e4b56346a37472b7555315541306d2b3959694132463446582f3237376d664c5a5a68374f6639386c414d57576e6f6b43625877587269556879396b48357362697744744d57494d6f5a2b47594552514a51327671454e3173514d2b525367424377437646694b72793366376c702b34706a58705a6e62614839747748385656664a456f4f595835727a513d3d227d7d00000000000000000000000000000000000000000000000000000000000000103b86ad95859b6ab773f55f8d94b4b9d443ee931f91ae002a960e63ccb0e5bde83a8c13e51e1cb91a0064000000000000000000000000000011c26c9099bd3789107888c35bb41178079b282561816ebc5cb8a5651c902cb06659907a93e574db0b006402000000000000000002d9066dfb1a000000000000000000000000000000";
    }

    function upgradeExistingDelta(address admin, address oldModule) internal virtual {
        OneDeltaComposerBase _aggregator = new OneDeltaComposerBase();

        IModuleConfig deltaConfig = IModuleConfig(brokerProxyAddress);

        bytes4[] memory oldSelectors = IModuleLens(brokerProxyAddress).moduleFunctionSelectors(oldModule);

        // define configs to add to proxy
        IModuleConfig.ModuleConfig[] memory _moduleConfig = new IModuleConfig.ModuleConfig[](2);
        _moduleConfig[0] = IModuleConfig.ModuleConfig(address(0), IModuleConfig.ModuleConfigAction.Remove, oldSelectors);
        _moduleConfig[1] = IModuleConfig.ModuleConfig(address(_aggregator), IModuleConfig.ModuleConfigAction.Add, flashAggregatorSelectors());

        // add all modules
        vm.prank(admin);
        deltaConfig.configureModules(_moduleConfig);
    }

    function flashAggregatorSelectors() internal pure returns (bytes4[] memory selectors) {
        selectors = new bytes4[](27);
        /** margin */
        selectors[0] = IFlashAggregator.flashSwapExactIn.selector;
        selectors[1] = IFlashAggregator.flashSwapExactOut.selector;
        selectors[2] = IFlashAggregator.flashSwapAllIn.selector;
        selectors[3] = IFlashAggregator.flashSwapAllOut.selector;
        /** spot */
        selectors[4] = IFlashAggregator.swapExactOutSpot.selector;
        selectors[5] = IFlashAggregator.swapExactOutSpotSelf.selector;
        selectors[6] = IFlashAggregator.swapExactInSpot.selector;
        selectors[7] = IFlashAggregator.swapAllOutSpot.selector;
        selectors[8] = IFlashAggregator.swapAllOutSpotSelf.selector;
        selectors[9] = IFlashAggregator.swapAllInSpot.selector;
        /** callbacks */
        selectors[10] = IFlashAggregator.fusionXV3SwapCallback.selector;
        selectors[11] = IFlashAggregator.agniSwapCallback.selector;
        selectors[12] = IFlashAggregator.algebraSwapCallback.selector;
        selectors[13] = IFlashAggregator.butterSwapCallback.selector;
        selectors[14] = IFlashAggregator.ramsesV2SwapCallback.selector;
        selectors[15] = IFlashAggregator.uniswapV2Call.selector;
        selectors[16] = IFlashAggregator.hook.selector;
        selectors[17] = IFlashAggregator.moeCall.selector;
        selectors[18] = IFlashAggregator.swapY2XCallback.selector;
        selectors[19] = IFlashAggregator.swapX2YCallback.selector;
        selectors[20] = IFlashAggregator.uniswapV3SwapCallback.selector;
        selectors[21] = IFlashAggregator.swapExactInSpotSelf.selector;
        selectors[21] = IFlashAggregator.deltaCompose.selector;
        selectors[22] = IFlashLoanReceiver.executeOperation.selector;
        selectors[23] = IFlashLoanReceiver.receiveFlashLoan.selector;
        selectors[24] = IFlashAggregator.waultSwapCall.selector;
        selectors[25] = IFlashAggregator.apeCall.selector;
        selectors[26] = IFlashAggregator.pancakeV3SwapCallback.selector;
        return selectors;
    }
}
// 0x23000000000000013fe7fdfbcfd381120d500b1d8e8ef31e21c99d1db9a6444d3adf127091ae002a960e63ccb0e5bde83a8c13e51e1cb91a0002ffffffffffffffffffffffffffff220d500b1d8e8ef31e21c99d1db9a6444d3adf127091ae002a960e63ccb0e5bde83a8c13e51e1cb91a000000000000000000000000000000
// 90045595608142721
// 65168370
// 0x17d730910000000000000000000000000000000000000000000000000000000000000020000000000000000000000000000000000000000000000000000000000000034d33fccf3cabbe80101232d343252614b6a3ee81c98900e000000000000000000000000091ae002a960e63ccb0e5bde83a8c13e51e1cb91a0000000000000000000000006a6faa54b9238f0f079c8e6cba08a7b9776c7fe40000000000000000000000000000000000000000000000000000000000b8cea10000000000000000000000000000000000000000000000000000000067537bb2000000000000000000000000000000000000000000000000000000000000001b9214cb4960304fb4a87269163541971c502fb1a4b5827910ad236d32c89207c25e61fe8b2ca2d7ebdbbaaf42d624ead85cd5a1fef3fec13dc2858fcf3d4d3ee034002791bca1f2de4661ed88a30c99a7a9449aa841740000000000000000000000b6fa350230042791bca1f2de4661ed88a30c99a7a9449aa841744e3288c9ca110bcc82bf38f09a7b425c095d92bf4e3288c9ca110bcc82bf38f09a7b425c095d92bf0000000000000000000000b6fa35017283bd37f900012791bca1f2de4661ed88a30c99a7a9449aa8417400017ceb23fd6bc0add59e62ac25578270cff1b9f61903b6fa35070a84ab91955b1200c49b00018D3D65F675f096dB9f27fc4162757A5162EF103A000000016A6faa54B9238f0F079C8e6CBa08a7b9776C7fE4000000000802040a0138c49d06030102010203011e014055da85030200010403001e00200306030606030001000506010f020300010001070118040f0001080901ff0000007fec4bfcadabf3a811792d568743842fb571b6730df9e46c0eaedf41b9d4bbe2cea2af6e8181b0332791bca1f2de4661ed88a30c99a7a9449aa84174e15e9d2a5af5c1d3524bbc594ddc4a7d80ad27cd6d3842ab227a0436a6e8c459e93c74bd8c16fb341bfd67037b42cf73acf2047067bd4f2c47d9bfd63a3df212b7aa91aa0402b9035b098891d276572b0312692e9cadd3ddaace2e112a4e36397bd2f18a0b3f868e0be5597d5db7feb59e1cadbb0fdda50a000000000000000000000000107ceb23fd6bc0add59e62ac25578270cff1b9f61991ae002a960e63ccb0e5bde83a8c13e51e1cb91a000000000000000000000000000000112791bca1f2de4661ed88a30c99a7a9449aa841746a6faa54b9238f0f079c8e6cba08a7b9776c7fe400020000000000000000000000b711a000000000000000000000000000000000000000
