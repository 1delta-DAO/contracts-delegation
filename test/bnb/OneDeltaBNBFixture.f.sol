// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.28;

import "./CommonAddresses.f.sol";

// modules
import {VenusFlashAggregatorBNB} from "../../contracts/1delta/modules/bnb/venus/FlashAggregator.sol";
import {VenusManagementModule} from "../../contracts/1delta/modules/venus/ManagementModule.sol";

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
        selectors = new bytes4[](4);
        selectors[0] = VenusFlashAggregatorBNB.deposit.selector;
        selectors[1] = VenusFlashAggregatorBNB.withdraw.selector;
        selectors[2] = VenusFlashAggregatorBNB.borrow.selector;
        selectors[3] = VenusFlashAggregatorBNB.repay.selector;
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

        // assign env
        management = VenusManagementModule(oneDelta);
        aggregator = VenusFlashAggregatorBNB(oneDelta);

        // define configs to add to proxy
        IModuleConfig.ModuleConfig[] memory _moduleConfig = new IModuleConfig.ModuleConfig[](2);
        _moduleConfig[0] = IModuleConfig.ModuleConfig(address(_management), IModuleConfig.ModuleConfigAction.Add, mmtSelectors());
        _moduleConfig[1] = IModuleConfig.ModuleConfig(address(_aggregator), IModuleConfig.ModuleConfigAction.Add, aggSelectors());
        // add all modules
        config.configureModules(_moduleConfig);

        // add asset data
        for (uint256 i; i < assets.length; i++) {
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
        for (uint256 i; i < 10; i++) {
            asset = assets[i];
            vm.startPrank(asset);
            uint256 balance = IERC20Minimal(asset).balanceOf(asset);
            if (balance > 0) IERC20Minimal(asset).transfer(address(this), balance);
            vm.stopPrank();
        }
        asset = wNative;
        vm.startPrank(asset);
        IERC20Minimal(asset).transfer(address(this), 1e20);
        vm.stopPrank();
    }
}
