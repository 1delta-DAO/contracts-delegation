// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {AddressesMantle} from "./CommonAddresses.f.sol";

// interfaces
import {IFlashAggregator} from "./interfaces/IFlashAggregator.sol";
import {IManagement} from "./interfaces/IManagement.sol";
import {ILending} from "./interfaces/ILending.sol";
import {IInitialize} from "./interfaces/IInitialize.sol";
import {IBrokerProxy} from "./interfaces/IBrokerProxy.sol";
import {IModuleConfig} from "../../contracts/1delta/proxy/interfaces/IModuleConfig.sol";
// universal erc20
import {IERC20All} from "./interfaces/IERC20All.sol";
// lending pool for debugging
import {ILendingPool} from "../../contracts/1delta/modules/deploy/mantle/ILendingPool.sol";

// proxy and management
import {ConfigModule} from "../../contracts/1delta/proxy/modules/ConfigModule.sol";
import {DeltaBrokerProxy} from "../../contracts/1delta/proxy/DeltaBroker.sol";

// initializer
import {MarginTraderInit} from "../../contracts/1delta/initializers/MarginTraderInit.sol";

// core modules
import {ManagementModule} from "../../contracts/1delta/modules/aave/ManagementModule.sol";
import {DeltaFlashAggregatorMantle} from "../../contracts/1delta/modules/deploy/mantle/FlashAggregator.sol";
import {DeltaLendingInterfaceMantle} from "../../contracts/1delta/modules/deploy/mantle/LendingInterface.sol";

// forge
import {Script, console2} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {Test} from "forge-std/Test.sol";

contract DeltaSetup is AddressesMantle, Script, Test {
    address internal brokerProxyAddress;
    IBrokerProxy internal brokerProxy;
    IModuleConfig internal deltaConfig;
    IManagement internal management;

    mapping(address => mapping(uint8 => address)) internal collateralTokens;
    mapping(address => mapping(uint8 => address)) internal debtTokens;

    /** SELECTOR GETTERS */

    function managementSelectors() internal pure returns (bytes4[] memory selectors) {
        selectors = new bytes4[](11);
        // setters
        selectors[0] = IManagement.addAToken.selector;
        selectors[1] = IManagement.setValidTarget.selector;
        selectors[3] = IManagement.decreaseAllowance.selector;
        selectors[4] = IManagement.addLenderTokens.selector;
        selectors[5] = IManagement.addGeneralLenderTokens.selector;
        // approve
        selectors[6] = IManagement.approveLendingPool.selector;
        selectors[2] = IManagement.approveAddress.selector;
        // getters
        selectors[7] = IManagement.getIsValidTarget.selector;
        selectors[8] = IManagement.getCollateralToken.selector;
        selectors[9] = IManagement.getStableDebtToken.selector;
        selectors[10] = IManagement.getDebtToken.selector;
        return selectors;
    }

    function initializeSelectors() internal pure returns (bytes4[] memory selectors) {
        selectors = new bytes4[](1);
        selectors[0] = IInitialize.initMarginTrader.selector;
        return selectors;
    }

    function flashAggregatorSelectors() internal pure returns (bytes4[] memory selectors) {
        selectors = new bytes4[](20);
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
        selectors[15] = IFlashAggregator.FusionXCall.selector;
        selectors[16] = IFlashAggregator.hook.selector;
        selectors[17] = IFlashAggregator.moeCall.selector;
        selectors[18] = IFlashAggregator.swapY2XCallback.selector;
        selectors[19] = IFlashAggregator.swapX2YCallback.selector;
        return selectors;
    }

    function lendingSelectors() internal pure returns (bytes4[] memory selectors) {
        selectors = new bytes4[](18);
        // baseline
        selectors[0] = ILending.deposit.selector;
        selectors[1] = ILending.withdraw.selector;
        selectors[2] = ILending.borrow.selector;
        selectors[3] = ILending.repay.selector;
        selectors[4] = ILending.callTarget.selector;
        // permits
        selectors[5] = ILending.selfPermit.selector;
        selectors[6] = ILending.selfPermitAllowed.selector;
        selectors[7] = ILending.selfCreditDelegate.selector;
        // erc20
        selectors[8] = ILending.transferERC20In.selector;
        selectors[9] = ILending.transferERC20AllIn.selector;
        // weth txns
        selectors[10] = ILending.wrap.selector;
        selectors[11] = ILending.unwrap.selector;
        selectors[12] = ILending.unwrapTo.selector;
        selectors[13] = ILending.refundNativeTo.selector;
        // transfers
        selectors[14] = ILending.sweep.selector;
        selectors[15] = ILending.sweepTo.selector;
        selectors[16] = ILending.refundNative.selector;
        selectors[17] = ILending.wrapTo.selector;

        return selectors;
    }

    /** DEPLOY PROZY AND MODULES */

    function deployDelta() internal virtual {
        ConfigModule _config = new ConfigModule();
        brokerProxyAddress = address(new DeltaBrokerProxy(address(this), address(_config)));

        brokerProxy = IBrokerProxy(brokerProxyAddress);

        ManagementModule _management = new ManagementModule();
        DeltaFlashAggregatorMantle _aggregator = new DeltaFlashAggregatorMantle();
        DeltaLendingInterfaceMantle _lending = new DeltaLendingInterfaceMantle();
        MarginTraderInit init = new MarginTraderInit();

        management = IManagement(brokerProxyAddress);
        deltaConfig = IModuleConfig(brokerProxyAddress);

        // define configs to add to proxy
        IModuleConfig.ModuleConfig[] memory _moduleConfig = new IModuleConfig.ModuleConfig[](4);
        _moduleConfig[0] = IModuleConfig.ModuleConfig(address(_management), IModuleConfig.ModuleConfigAction.Add, managementSelectors());
        _moduleConfig[1] = IModuleConfig.ModuleConfig(address(_aggregator), IModuleConfig.ModuleConfigAction.Add, flashAggregatorSelectors());
        _moduleConfig[2] = IModuleConfig.ModuleConfig(address(init), IModuleConfig.ModuleConfigAction.Add, initializeSelectors());
        _moduleConfig[3] = IModuleConfig.ModuleConfig(address(_lending), IModuleConfig.ModuleConfigAction.Add, lendingSelectors());
        // add all modules
        deltaConfig.configureModules(_moduleConfig);

        management = IManagement(brokerProxyAddress);
        MarginTraderInit(brokerProxyAddress).initMarginTrader(address(0));
    }

    /** ADD AND APPROVE LENDER TOKENS */

    function initializeDelta() internal virtual {
        // lendle
        management.addGeneralLenderTokens(USDC, LENDLE_A_USDC, LENDLE_V_USDC, LENDLE_S_USDC, 0);
        management.addGeneralLenderTokens(USDT, LENDLE_A_USDT, LENDLE_V_USDT, LENDLE_S_USDT, 0);
        management.addGeneralLenderTokens(WBTC, LENDLE_A_WBTC, LENDLE_V_WBTC, LENDLE_S_WBTC, 0);
        management.addGeneralLenderTokens(WETH, LENDLE_A_WETH, LENDLE_V_WETH, LENDLE_S_WETH, 0);
        management.addGeneralLenderTokens(WMNT, LENDLE_A_WMNT, LENDLE_V_WMNT, LENDLE_S_WMNT, 0);

        collateralTokens[USDC][0] = LENDLE_A_USDC;
        collateralTokens[USDT][0] = LENDLE_A_USDT;
        collateralTokens[WBTC][0] = LENDLE_A_WBTC;
        collateralTokens[WETH][0] = LENDLE_A_WETH;
        collateralTokens[WMNT][0] = LENDLE_A_WMNT;

        debtTokens[USDC][0] = LENDLE_V_USDC;
        debtTokens[USDT][0] = LENDLE_V_USDT;
        debtTokens[WBTC][0] = LENDLE_V_WBTC;
        debtTokens[WETH][0] = LENDLE_V_WETH;
        debtTokens[WMNT][0] = LENDLE_V_WMNT;

        // aurelius
        management.addGeneralLenderTokens(USDC, AURELIUS_A_USDC, AURELIUS_V_USDC, AURELIUS_S_USDC, 1);
        management.addGeneralLenderTokens(USDT, AURELIUS_A_USDT, AURELIUS_V_USDT, AURELIUS_S_USDT, 1);
        management.addGeneralLenderTokens(WBTC, AURELIUS_A_WBTC, AURELIUS_V_WBTC, AURELIUS_S_WBTC, 1);
        management.addGeneralLenderTokens(WETH, AURELIUS_A_WETH, AURELIUS_V_WETH, AURELIUS_S_WETH, 1);
        management.addGeneralLenderTokens(WMNT, AURELIUS_A_WMNT, AURELIUS_V_WMNT, AURELIUS_S_WMNT, 1);

        collateralTokens[USDC][1] = AURELIUS_A_USDC;
        collateralTokens[USDT][1] = AURELIUS_A_USDT;
        collateralTokens[WBTC][1] = AURELIUS_A_WBTC;
        collateralTokens[WETH][1] = AURELIUS_A_WETH;
        collateralTokens[WMNT][1] = AURELIUS_A_WMNT;

        debtTokens[USDC][1] = AURELIUS_V_USDC;
        debtTokens[USDT][1] = AURELIUS_V_USDT;
        debtTokens[WBTC][1] = AURELIUS_V_WBTC;
        debtTokens[WETH][1] = AURELIUS_V_WETH;
        debtTokens[WMNT][1] = AURELIUS_V_WMNT;

        // approve pools
        address[] memory assets = new address[](5);
        assets[0] = USDC;
        assets[1] = WBTC;
        assets[2] = WETH;
        assets[3] = WMNT;
        assets[4] = USDT;
        management.approveAddress(assets, LENDLE_POOL);
        management.approveAddress(assets, AURELIUS_POOL);
    }


    function setUp() public virtual {
        vm.createSelectFork({blockNumber: 60500956, urlOrAlias: "https://mantle-mainnet.public.blastapi.io"});

        deployDelta();
        initializeDelta();
    }

    /** DEPOSIT AND OPEN TO SPIN UP POSITIONS */

    function openSimple(address user, address asset, address borrowAsset, uint256 depositAmount, uint256 borrowAmount, uint8 lenderId) internal {
        address debtAsset = debtTokens[borrowAsset][lenderId];
        deal(asset, user, depositAmount);

        bytes[] memory calls = new bytes[](3);
        calls[0] = abi.encodeWithSelector(ILending.transferERC20In.selector, asset, depositAmount);
        calls[1] = abi.encodeWithSelector(ILending.deposit.selector, asset, user, lenderId);

        bytes memory swapPath = getOpenExactInSingle(borrowAsset, asset, lenderId);
        uint256 minimumOut = 0; // we do not care about slippage in that regard
        calls[2] = abi.encodeWithSelector(IFlashAggregator.flashSwapExactIn.selector, borrowAmount, minimumOut, swapPath);

        vm.prank(user);
        IERC20All(asset).approve(brokerProxyAddress, depositAmount);
        vm.prank(user);
        IERC20All(debtAsset).approveDelegation(brokerProxyAddress, borrowAmount);

        vm.prank(user);
        brokerProxy.multicall(calls);
    }
}
