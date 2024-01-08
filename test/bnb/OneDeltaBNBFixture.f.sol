// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.23;

import "./CommonAddresses.f.sol";

// modules
import {VenusFlashAggregatorBNB} from "../../contracts/1delta/modules/deploy/bnb/venus/FlashAggregator.sol";
import {VenusManagementModule} from "../../contracts/1delta/modules/venus/ManagementModule.sol";
import {VenusMarginTraderInit} from "../../contracts/1delta/initializers/VenusMarginTraderInit.sol";
// proxy & config
import {DeltaBrokerProxy} from "../../contracts/1delta/proxy/DeltaBroker.sol";
import {ConfigModule, IModuleConfig} from "../../contracts/1delta/proxy/modules/ConfigModule.sol";

contract OneDeltaBNBFixture is CommonBNBAddresses {
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
        selectors = new bytes4[](4);
        selectors[0] = VenusFlashAggregatorBNB.deposit.selector;
        selectors[1] = VenusFlashAggregatorBNB.withdraw.selector;
        selectors[2] = VenusFlashAggregatorBNB.borrow.selector;
        selectors[3] = VenusFlashAggregatorBNB.repay.selector;
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
    }
}
