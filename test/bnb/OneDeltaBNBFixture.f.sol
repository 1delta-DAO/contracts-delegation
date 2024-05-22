// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.26;

import "./CommonAddresses.f.sol";

// modules
import {VenusFlashAggregatorBNB} from "../../contracts/1delta/modules/deploy/bnb/venus/FlashAggregator.sol";
import {VenusManagementModule} from "../../contracts/1delta/modules/venus/ManagementModule.sol";
import {VenusMarginTraderInit} from "../../contracts/1delta/initializers/VenusMarginTraderInit.sol";
import {MarginTrading} from "../../contracts/1delta/modules/deploy/bnb/venus/MarginTrading.sol";

// proxy & config
import {DeltaBrokerProxy} from "../../contracts/1delta/proxy/DeltaBroker.sol";
import {ConfigModule, IModuleConfig} from "../../contracts/1delta/proxy/modules/ConfigModule.sol";

// misc
import {IVToken, IERC20Minimal} from "./interfaces.sol";

// forge
import {Test} from "forge-std/Test.sol";

contract OneDeltaBNBFixture is CommonBNBAddresses, Test {
    DeltaBrokerProxy proxy;
    ConfigModule config;
    VenusManagementModule management;
    VenusFlashAggregatorBNB aggregator;
    address oneDelta;

    function mmtSelectors() internal pure returns (bytes4[] memory selectors) {
        selectors = new bytes4[](9);
        selectors[0] = VenusManagementModule.addCollateralToken.selector;
        selectors[1] = VenusManagementModule.approveCollateralTokens.selector;
        selectors[2] = VenusManagementModule.setComptroller.selector;
        selectors[3] = VenusManagementModule.setValidTarget.selector;
        selectors[4] = VenusManagementModule.approveAddress.selector;
        selectors[5] = VenusManagementModule.decreaseAllowance.selector;
        selectors[6] = VenusManagementModule.getComptroller.selector;
        selectors[7] = VenusManagementModule.getCollateralToken.selector;
        selectors[8] = VenusManagementModule.getIsValidTarget.selector;
        return selectors;
    }

    function aggSelectors() internal pure returns (bytes4[] memory selectors) {
        selectors = new bytes4[](9);
        selectors[0] = VenusFlashAggregatorBNB.deposit.selector;
        selectors[1] = VenusFlashAggregatorBNB.withdraw.selector;
        selectors[2] = VenusFlashAggregatorBNB.borrow.selector;
        selectors[3] = VenusFlashAggregatorBNB.repay.selector;
        selectors[4] = MarginTrading.flashSwapExactIn.selector;
        selectors[5] = MarginTrading.pancakeV3SwapCallback.selector;
        selectors[6] = MarginTrading.pancakeCall.selector;
        selectors[7] = MarginTrading.flashSwapExactOut.selector;
        selectors[8] = MarginTrading.BiswapCall.selector;
        return selectors;
    }

    function initSelectors() internal pure returns (bytes4[] memory selectors) {
        selectors = new bytes4[](1);
        selectors[0] = VenusMarginTraderInit.initVenusMarginTrader.selector;
        return selectors;
    }

    function deployAndInit1delta() internal {
        // config & proxy
        ConfigModule _config = new ConfigModule();
        proxy = new DeltaBrokerProxy(address(this), address(_config));

        oneDelta = address(proxy);
        config = ConfigModule(oneDelta);

        // deploy mdoules
        VenusManagementModule _management = new VenusManagementModule();
        VenusFlashAggregatorBNB _aggregator = new VenusFlashAggregatorBNB();
        VenusMarginTraderInit init = new VenusMarginTraderInit();

        // assign env
        management = VenusManagementModule(oneDelta);
        aggregator = VenusFlashAggregatorBNB(oneDelta);

        // define configs to add to proxy
        IModuleConfig.ModuleConfig[] memory _moduleConfig = new IModuleConfig.ModuleConfig[](3);
        _moduleConfig[0] = IModuleConfig.ModuleConfig(address(_management), IModuleConfig.ModuleConfigAction.Add, mmtSelectors());
        _moduleConfig[1] = IModuleConfig.ModuleConfig(address(_aggregator), IModuleConfig.ModuleConfigAction.Add, aggSelectors());
        _moduleConfig[2] = IModuleConfig.ModuleConfig(address(init), IModuleConfig.ModuleConfigAction.Add, initSelectors());
        // add all modules
        config.configureModules(_moduleConfig);

        // set comptroller
        VenusMarginTraderInit(oneDelta).initVenusMarginTrader(address(comptroller));

        // add asset data
        for (uint i; i < assets.length; i++) {
            address asset = assets[i];
            management.addCollateralToken(asset, vTokens[i]);
        }

        // approve all relevant spending
        management.approveCollateralTokens(assets);
        management.addCollateralToken(wNative, vNative);
    }

    function setUp() public {
        // select bnb chain to fork
        vm.createSelectFork({blockNumber: 34_958_582, urlOrAlias: "https://rpc.ankr.com/bsc"});
        // set up 1delta
        deployAndInit1delta();
        address asset;
        // fund 10 first assets
        for (uint i; i < 10; i++) {
            asset = assets[i];
            vm.startPrank(asset);
            uint balance = IERC20Minimal(asset).balanceOf(asset);
            if (balance > 0) IERC20Minimal(asset).transfer(address(this), balance);
            vm.stopPrank();
        }
        asset = wNative;
        vm.startPrank(asset);
        IERC20Minimal(asset).transfer(address(this), 1e20);
        vm.stopPrank();
    }
}
