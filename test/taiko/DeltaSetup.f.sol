// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {AddressesTaiko, IFactoryFeeGetter} from "./utils/CommonAddresses.f.sol";
import "../../contracts/1delta/quoter/test/TestQuoterTaiko.sol";
import {ComposerUtils, Commands} from "../shared/utils/ComposerUtils.sol";

// interfaces
import {IFlashAggregator} from "../shared/interfaces/IFlashAggregator.sol";
import {IFlashLoanReceiver} from "./utils/IFlashLoanReceiver.sol";
import {IManagement} from "../shared/interfaces/IManagement.sol";
import {ILending} from "../shared/interfaces/ILending.sol";
import {IInitialize} from "../shared/interfaces/IInitialize.sol";
import {IBrokerProxy} from "../shared/interfaces/IBrokerProxy.sol";
import {IModuleConfig} from "../../contracts/1delta/proxy/interfaces/IModuleConfig.sol";
import {IModuleLens} from "../../contracts/1delta/proxy/interfaces/IModuleLens.sol";
// universal erc20
import {IERC20All} from "../shared/interfaces/IERC20All.sol";
// lending pool for debugging
import {ILendingPool} from "./utils/ILendingPool.sol";

// proxy and management
import {ConfigModule} from "../../contracts/1delta/proxy/modules/ConfigModule.sol";
import {DeltaBrokerProxyGen2} from "../../contracts/1delta/proxy/DeltaBrokerGen2.sol";

// initializer

// core modules
import {ManagementModule} from "../../contracts/1delta/modules/shared/storage/ManagementModule.sol";
import {OneDeltaComposerTaiko} from "../../contracts/1delta/modules/taiko/Composer.sol";

// forge
import {Script, console2} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {Test} from "forge-std/Test.sol";

contract DeltaSetup is AddressesTaiko, ComposerUtils, Script, Test {
    address internal brokerProxyAddress;
    IBrokerProxy internal brokerProxy;
    IModuleConfig internal deltaConfig;
    IManagement internal management;
    TestQuoterTaiko testQuoter;
    OneDeltaComposerTaiko internal aggregator;

    mapping(address => mapping(uint16 => address)) internal collateralTokens;
    mapping(address => mapping(uint16 => address)) internal debtTokens;

    /** SELECTOR GETTERS */

    function managementSelectors() internal pure returns (bytes4[] memory selectors) {
        selectors = new bytes4[](13);
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
        selectors[11] = IManagement.clearCache.selector;
        selectors[12] = IManagement.setValidSingleTarget.selector;
        return selectors;
    }

    function initializeSelectors() internal pure returns (bytes4[] memory selectors) {
        selectors = new bytes4[](1);
        selectors[0] = IInitialize.initMarginTrader.selector;
        return selectors;
    }

    function flashAggregatorSelectors() internal pure returns (bytes4[] memory selectors) {
        selectors = new bytes4[](25);
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
        selectors[20] = IFlashAggregator.uniswapV3SwapCallback.selector;
        selectors[21] = IFlashAggregator.swapExactInSpotSelf.selector;
        selectors[21] = IFlashAggregator.deltaCompose.selector;
        selectors[22] = IFlashLoanReceiver.executeOperation.selector;
        selectors[23] = IFlashAggregator.syncSwapBaseSwapCallback.selector;
        selectors[24] = IFlashAggregator.pancakeV3SwapCallback.selector;
        return selectors;
    }

    /** DEPLOY PROZY AND MODULES */

    function deployDelta() internal virtual {
        ConfigModule _config = new ConfigModule();
        brokerProxyAddress = address(new DeltaBrokerProxyGen2(address(this), address(_config)));

        brokerProxy = IBrokerProxy(brokerProxyAddress);

        ManagementModule _management = new ManagementModule();
        OneDeltaComposerTaiko _aggregator = new OneDeltaComposerTaiko();

        management = IManagement(brokerProxyAddress);
        deltaConfig = IModuleConfig(brokerProxyAddress);

        // define configs to add to proxy
        IModuleConfig.ModuleConfig[] memory _moduleConfig = new IModuleConfig.ModuleConfig[](2);
        _moduleConfig[0] = IModuleConfig.ModuleConfig(address(_management), IModuleConfig.ModuleConfigAction.Add, managementSelectors());
        _moduleConfig[1] = IModuleConfig.ModuleConfig(address(_aggregator), IModuleConfig.ModuleConfigAction.Add, flashAggregatorSelectors());

        // add all modules
        deltaConfig.configureModules(_moduleConfig);
        aggregator = _aggregator;
        management = IManagement(brokerProxyAddress);
    }

    function upgradeExistingDelta(address proxy, address admin, address oldModule) internal virtual {
        brokerProxyAddress = proxy;

        brokerProxy = IBrokerProxy(brokerProxyAddress);

        OneDeltaComposerTaiko _aggregator = new OneDeltaComposerTaiko();

        management = IManagement(brokerProxyAddress);
        deltaConfig = IModuleConfig(brokerProxyAddress);

        bytes4[] memory oldSelectors = IModuleLens(brokerProxyAddress).moduleFunctionSelectors(oldModule);

        // define configs to add to proxy
        IModuleConfig.ModuleConfig[] memory _moduleConfig = new IModuleConfig.ModuleConfig[](2);
        _moduleConfig[0] = IModuleConfig.ModuleConfig(address(0), IModuleConfig.ModuleConfigAction.Remove, oldSelectors);
        _moduleConfig[1] = IModuleConfig.ModuleConfig(address(_aggregator), IModuleConfig.ModuleConfigAction.Add, flashAggregatorSelectors());

        // add all modules
        vm.prank(admin);
        deltaConfig.configureModules(_moduleConfig);
        aggregator = _aggregator;
        management = IManagement(brokerProxyAddress);
    }

    /** ADD AND APPROVE LENDER TOKENS */

    function initializeDeltaBase() internal virtual {
        // quoter

        testQuoter = new TestQuoterTaiko();

        management.clearCache();
    }

    function initializeDeltaHana() internal virtual {
        // hana
        management.addGeneralLenderTokens(USDC, HANA_A_USDC, HANA_V_USDC, HANA_S_USDC, 0);
        management.addGeneralLenderTokens(TAIKO, HANA_A_TAIKO, HANA_V_TAIKO, HANA_S_TAIKO, 0);
        management.addGeneralLenderTokens(WETH, HANA_A_WETH, HANA_V_WETH, HANA_S_WETH, 0);

        collateralTokens[USDC][0] = HANA_A_USDC;
        collateralTokens[TAIKO][0] = HANA_A_TAIKO;
        collateralTokens[WETH][0] = HANA_A_WETH;

        debtTokens[USDC][0] = HANA_V_USDC;
        debtTokens[TAIKO][0] = HANA_V_TAIKO;
        debtTokens[WETH][0] = HANA_V_WETH;

        // approve pools
        address[] memory assets = new address[](3);
        assets[0] = USDC;
        assets[1] = WETH;
        assets[2] = TAIKO;
        management.approveAddress(assets, HANA_POOL);
    }

    function initializeDeltaMeridian() internal virtual {
        // meridian
        management.addGeneralLenderTokens(USDC, MERIDIAN_A_USDC, MERIDIAN_V_USDC, MERIDIAN_S_USDC, 1);
        management.addGeneralLenderTokens(TAIKO, MERIDIAN_A_TAIKO, MERIDIAN_V_TAIKO, MERIDIAN_S_TAIKO, 1);
        management.addGeneralLenderTokens(WETH, MERIDIAN_A_WETH, MERIDIAN_V_WETH, MERIDIAN_S_WETH, 1);

        collateralTokens[USDC][1] = MERIDIAN_A_USDC;
        collateralTokens[TAIKO][1] = MERIDIAN_A_TAIKO;
        collateralTokens[WETH][1] = MERIDIAN_A_WETH;

        debtTokens[USDC][1] = MERIDIAN_V_USDC;
        debtTokens[TAIKO][1] = MERIDIAN_V_TAIKO;
        debtTokens[WETH][1] = MERIDIAN_V_WETH;

        // approve pools
        address[] memory assets = new address[](3);
        assets[0] = USDC;
        assets[1] = WETH;
        assets[2] = TAIKO;
        management.approveAddress(assets, MERIDIAN_POOL);
    }

    function initializeDeltaTakoTako() internal virtual {
        // takotako
        management.addGeneralLenderTokens(USDC, TAKOTAKO_A_USDC, TAKOTAKO_V_USDC, TAKOTAKO_S_USDC, TAKOTAKO_ID);
        management.addGeneralLenderTokens(TAIKO, TAKOTAKO_A_TAIKO, TAKOTAKO_V_TAIKO, TAKOTAKO_S_TAIKO, TAKOTAKO_ID);
        management.addGeneralLenderTokens(WETH, TAKOTAKO_A_WETH, TAKOTAKO_V_WETH, TAKOTAKO_S_WETH, TAKOTAKO_ID);

        collateralTokens[USDC][TAKOTAKO_ID] = TAKOTAKO_A_USDC;
        collateralTokens[TAIKO][TAKOTAKO_ID] = TAKOTAKO_A_TAIKO;
        collateralTokens[WETH][TAKOTAKO_ID] = TAKOTAKO_A_WETH;

        debtTokens[USDC][TAKOTAKO_ID] = TAKOTAKO_V_USDC;
        debtTokens[TAIKO][TAKOTAKO_ID] = TAKOTAKO_V_TAIKO;
        debtTokens[WETH][TAKOTAKO_ID] = TAKOTAKO_V_WETH;

        // approve pools
        address[] memory assets = new address[](3);
        assets[0] = USDC;
        assets[1] = WETH;
        assets[2] = TAIKO;
        management.approveAddress(assets, TAKOTAKO_POOL);
    }

    function initializeDeltaAvalon() internal virtual {
        // takotako
        management.addGeneralLenderTokens(SOLV_BTC, AVALON_A_SOLV_BTC, AVALON_V_SOLV_BTC, AVALON_S_SOLV_BTC, AVALON_ID);
        management.addGeneralLenderTokens(TAIKO, AVALON_A_SOLV_BTC_BBN, AVALON_V_SOLV_BTC_BBN, AVALON_S_SOLV_BTC_BBN, AVALON_ID);

        collateralTokens[SOLV_BTC][AVALON_ID] = AVALON_A_SOLV_BTC;
        collateralTokens[SOLV_BTC_BBN][AVALON_ID] = AVALON_A_SOLV_BTC_BBN;

        debtTokens[SOLV_BTC][AVALON_ID] = AVALON_V_SOLV_BTC;
        debtTokens[SOLV_BTC_BBN][AVALON_ID] = AVALON_V_SOLV_BTC_BBN;

        // approve pools
        address[] memory assets = new address[](2);
        assets[0] = SOLV_BTC;
        assets[1] = SOLV_BTC_BBN;
        management.approveAddress(assets, AVALON_POOL);
    }

    function getAssets() internal view returns (address[] memory assetList) {
        assetList = new address[](3);
        assetList[0] = USDC;
        assetList[1] = WETH;
        assetList[2] = TAIKO;
    }

    function setUp() public virtual {
        vm.createSelectFork({blockNumber: 536078, urlOrAlias: "https://rpc.mainnet.taiko.xyz"});

        intitializeFullDelta();
    }

    function intitializeFullDelta() internal virtual {
        deployDelta();
        initializeDeltaHana();
        initializeDeltaMeridian();
        initializeDeltaTakoTako();
        initializeDeltaAvalon();
        initializeDeltaBase();
    }

    /** DEPOSIT AND OPEN TO SPIN UP POSITIONS */

    function execDeposit(address user, address asset, uint256 depositAmount, uint16 lenderId) internal {
        deal(asset, user, depositAmount);

        bytes memory data = transferIn(asset, brokerProxyAddress, depositAmount);

        data = abi.encodePacked(
            data,
            deposit(asset, user, depositAmount, lenderId) //
        );

        vm.prank(user);
        IERC20All(asset).approve(brokerProxyAddress, depositAmount);
        vm.prank(user);
        IFlashAggregator(brokerProxyAddress).deltaCompose(data);
    }

    function openSimple(address user, address asset, address borrowAsset, uint256 depositAmount, uint256 borrowAmount, uint16 lenderId) internal {
        address debtAsset = debtTokens[borrowAsset][lenderId];
        deal(asset, user, depositAmount);

        bytes memory data = transferIn(asset, brokerProxyAddress, depositAmount);

        data = abi.encodePacked(
            data,
            deposit(asset, user, depositAmount, lenderId) //
        );

        bytes memory swapPath = getOpenExactInSingle(borrowAsset, asset, lenderId);
        uint256 checkAmount = 0; // we do not care about slippage in that regard
        data = abi.encodePacked(
            data,
            encodeFlashSwap(
                Commands.FLASH_SWAP_EXACT_IN, // open
                borrowAmount,
                checkAmount,
                false,
                swapPath
            )
        );

        vm.prank(user);
        IERC20All(asset).approve(brokerProxyAddress, depositAmount);
        vm.prank(user);
        IERC20All(debtAsset).approveDelegation(brokerProxyAddress, borrowAmount);
        vm.prank(user);
        IFlashAggregator(brokerProxyAddress).deltaCompose(data);
    }

    function openExactIn(
        address user,
        address asset,
        address borrowAsset,
        uint256 depositAmount,
        uint256 borrowAmount,
        uint256 checkAmount,
        bytes memory path, //
        uint16 lenderId
    ) internal {
        address debtAsset = debtTokens[borrowAsset][lenderId];
        deal(asset, user, depositAmount);

        bytes memory data = transferIn(asset, brokerProxyAddress, depositAmount);

        data = abi.encodePacked(
            data,
            deposit(asset, user, depositAmount, lenderId) //
        );

        data = abi.encodePacked(
            data,
            encodeFlashSwap(
                uint8(Commands.FLASH_SWAP_EXACT_IN), // open
                borrowAmount,
                checkAmount,
                false,
                path
            )
        );

        vm.prank(user);
        IERC20All(asset).approve(brokerProxyAddress, depositAmount);
        vm.prank(user);
        IERC20All(debtAsset).approveDelegation(brokerProxyAddress, borrowAmount);
        vm.prank(user);
        IFlashAggregator(brokerProxyAddress).deltaCompose(data);
    }

    function openExactOut(
        address user,
        address asset,
        address borrowAsset,
        uint256 depositAmount,
        uint256 amountToReceive,
        uint256 checkAmount,
        bytes memory path, //
        uint16 lenderId
    ) internal {
        address debtAsset = debtTokens[borrowAsset][lenderId];
        deal(asset, user, depositAmount);

        bytes memory data = transferIn(asset, brokerProxyAddress, depositAmount);

        data = abi.encodePacked(
            data,
            deposit(asset, user, depositAmount, lenderId) //
        );

        data = abi.encodePacked(
            data,
            encodeFlashSwap(
                uint8(Commands.FLASH_SWAP_EXACT_OUT), // open
                amountToReceive,
                checkAmount,
                false,
                path
            )
        );

        vm.prank(user);
        IERC20All(asset).approve(brokerProxyAddress, depositAmount);
        vm.prank(user);
        IERC20All(debtAsset).approveDelegation(brokerProxyAddress, checkAmount);
        vm.prank(user);
        IFlashAggregator(brokerProxyAddress).deltaCompose(data);
    }

    /** HELPER FUNCTIONS */

    /** OPEN */

    function getOpenExactInSingle(address tokenIn, address tokenOut, uint16 lenderId) internal view returns (bytes memory data) {
        uint16 fee = uint16(DEX_FEE_LOW);
        uint8 poolId = AGNI;
        address pool = testQuoter._v3TypePool(tokenIn, tokenOut, fee, poolId);
        (uint8 actionId, , uint8 endId) = getOpenExactInFlags();
        return abi.encodePacked(tokenIn, actionId, poolId, pool, fee, tokenOut, lenderId, endId);
    }

    function getOpenExactInSingle_izi(address tokenIn, address tokenOut, uint16 lenderId) internal view returns (bytes memory data) {
        uint16 fee = uint16(DEX_FEE_LOW_HIGH);
        uint8 poolId = IZUMI;
        address pool = testQuoter._getiZiPool(tokenIn, tokenOut, fee);
        (uint8 actionId, , uint8 endId) = getOpenExactInFlags();
        return abi.encodePacked(tokenIn, actionId, poolId, pool, fee, tokenOut, lenderId, endId);
    }

    function getSpotExactInSingle_izi(address tokenIn, address tokenOut) internal view returns (bytes memory data) {
        uint16 fee = uint16(DEX_FEE_LOW_HIGH);
        uint8 poolId = IZUMI;
        address pool = testQuoter._getiZiPool(tokenIn, tokenOut, fee);
        return abi.encodePacked(tokenIn, uint8(0), poolId, pool, fee, tokenOut);
    }

    function getSpotExactOutSingle_izi(address tokenIn, address tokenOut) internal view returns (bytes memory data) {
        uint16 fee = uint16(DEX_FEE_LOW_HIGH);
        uint8 poolId = IZUMI;
        address pool = testQuoter._getiZiPool(tokenIn, tokenOut, fee);
        return abi.encodePacked(tokenOut, uint8(0), poolId, pool, fee, tokenIn);
    }

    function getOpenExactOutSingle(address tokenIn, address tokenOut, uint16 lenderId) internal view returns (bytes memory data) {
        uint16 fee = uint16(DEX_FEE_LOW);
        uint8 poolId = AGNI;
        address pool = testQuoter._v3TypePool(tokenIn, tokenOut, fee, poolId);
        (uint8 actionId, , uint8 endId) = getOpenExactOutFlags();
        return abi.encodePacked(tokenOut, actionId, poolId, pool, fee, tokenIn, lenderId, endId);
    }

    function getOpenExactInMulti(address tokenIn, address tokenOut, uint16 lenderId) internal view returns (bytes memory data) {
        uint16 fee = uint16(DEX_FEE_LOW);
        (uint8 actionId, uint8 midId, uint8 endId) = getOpenExactInFlags();
        uint8 poolId = IZUMI;
        address pool = testQuoter._getiZiPool(tokenIn, TAIKO, fee);
        bytes memory firstPart = abi.encodePacked(tokenIn, actionId, poolId, pool, fee, TAIKO);
        fee = uint16(DEX_FEE_STABLES);
        poolId = UNI_V3;
        pool = testQuoter._v3TypePool(TAIKO, tokenOut, fee, poolId);
        return abi.encodePacked(firstPart, midId, poolId, pool, fee, tokenOut, lenderId, endId);
    }

    function getOpenExactOutMulti(address tokenIn, address tokenOut, uint16 lenderId) internal view returns (bytes memory data) {
        uint16 fee = uint16(DEX_FEE_STABLES);
        (uint8 actionId, uint8 midId, uint8 endId) = getOpenExactOutFlags();
        uint8 poolId = UNI_V3;
        address pool = testQuoter._v3TypePool(tokenOut, TAIKO, fee, poolId);
        bytes memory firstPart = abi.encodePacked(tokenOut, actionId, poolId, pool, fee, TAIKO);
        fee = uint16(DEX_FEE_LOW);
        poolId = IZUMI;
        pool = testQuoter._getiZiPool(TAIKO, tokenIn, fee);
        return abi.encodePacked(firstPart, midId, poolId, pool, fee, tokenIn, lenderId, endId);
    }

    /** CLOSE */

    function getCloseExactOutSingle(address tokenIn, address tokenOut, uint16 lenderId) internal view returns (bytes memory data) {
        uint16 fee = uint16(DEX_FEE_LOW);
        uint8 poolId = AGNI;
        address pool = testQuoter._v3TypePool(tokenIn, tokenOut, fee, poolId);
        (uint8 actionId, , uint8 endId) = getCloseExactOutFlags();
        return abi.encodePacked(tokenOut, actionId, poolId, pool, fee, tokenIn, lenderId, endId);
    }

    function getCloseExactInSingle(address tokenIn, address tokenOut, uint16 lenderId) internal view returns (bytes memory data) {
        uint16 fee = uint16(DEX_FEE_LOW);
        uint8 poolId = AGNI;
        address pool = testQuoter._v3TypePool(tokenIn, tokenOut, fee, poolId);
        (uint8 actionId, , uint8 endId) = getCloseExactInFlags();
        return abi.encodePacked(tokenIn, actionId, poolId, pool, fee, tokenOut, lenderId, endId);
    }

    function getCloseExactInMulti(address tokenIn, address tokenOut, uint16 lenderId) internal view returns (bytes memory data) {
        uint16 fee = uint16(DEX_FEE_LOW);
        (uint8 actionId, uint8 midId, uint8 endId) = getCloseExactInFlags();
        uint8 poolId = IZUMI;
        address pool = testQuoter._getiZiPool(TAIKO, tokenIn, fee);
        bytes memory firstPart = abi.encodePacked(tokenIn, actionId, poolId, pool, fee, TAIKO);
        fee = uint16(DEX_FEE_STABLES);
        poolId = UNI_V3;
        pool = testQuoter._v3TypePool(TAIKO, tokenOut, fee, poolId);
        return abi.encodePacked(firstPart, midId, poolId, pool, fee, tokenOut, lenderId, endId);
    }

    function getCloseExactOutMulti(address tokenIn, address tokenOut, uint16 lenderId) internal view returns (bytes memory data) {
        uint16 fee = uint16(DEX_FEE_STABLES);
        (uint8 actionId, uint8 midId, uint8 endId) = getCloseExactOutFlags();
        uint8 poolId = UNI_V3;
        address pool = testQuoter._v3TypePool(TAIKO, tokenOut, fee, poolId);
        bytes memory firstPart = abi.encodePacked(tokenOut, actionId, poolId, pool, fee, TAIKO);
        fee = uint16(DEX_FEE_LOW);
        poolId = IZUMI;
        pool = testQuoter._getiZiPool(TAIKO, tokenIn, fee);
        return abi.encodePacked(firstPart, midId, poolId, pool, fee, tokenIn, lenderId, endId);
    }

    /** COLLATERAL SWAP */

    function getCollateralSwapExactInSingle(address tokenIn, address tokenOut, uint16 lenderId) internal view returns (bytes memory data) {
        uint16 fee = uint16(DEX_FEE_LOW);
        uint8 poolId = AGNI;
        address pool = testQuoter._v3TypePool(tokenIn, tokenOut, fee, poolId);
        (uint8 actionId, , uint8 endId) = getCollateralSwapExactInFlags();
        return abi.encodePacked(tokenIn, actionId, poolId, pool, fee, tokenOut, lenderId, endId);
    }

    function getCollateralSwapExactOutSingle(address tokenIn, address tokenOut, uint16 lenderId) internal view returns (bytes memory data) {
        uint16 fee = uint16(DEX_FEE_LOW);
        uint8 poolId = AGNI;
        address pool = testQuoter._v3TypePool(tokenIn, tokenOut, fee, poolId);
        (uint8 actionId, , uint8 endId) = getCollateralSwapExactOutFlags();
        return abi.encodePacked(tokenOut, actionId, poolId, pool, fee, tokenIn, lenderId, endId);
    }

    function getCollateralSwapExactInMulti(address tokenIn, address tokenOut, uint16 lenderId) internal view returns (bytes memory data) {
        uint16 fee = uint16(DEX_FEE_LOW_MEDIUM);
        (uint8 actionId, uint8 midId, uint8 endId) = getCollateralSwapExactInFlags();
        uint8 poolId = AGNI;
        address pool = testQuoter._v3TypePool(tokenIn, WETH, fee, poolId);
        bytes memory firstPart = abi.encodePacked(tokenIn, actionId, poolId, pool, fee, WETH);
        fee = uint16(DEX_FEE_LOW);
        poolId = UNI_V3;
        pool = testQuoter._v3TypePool(tokenOut, WETH, fee, poolId);
        return abi.encodePacked(firstPart, midId, poolId, pool, fee, tokenOut, lenderId, endId);
    }

    function getCollateralSwapExactOutMulti(address tokenIn, address tokenOut, uint16 lenderId) internal view returns (bytes memory data) {
        uint16 fee = uint16(DEX_FEE_LOW_MEDIUM);
        (uint8 actionId, uint8 midId, uint8 endId) = getCollateralSwapExactOutFlags();
        uint8 poolId = AGNI;
        address pool = testQuoter._v3TypePool(tokenOut, WETH, fee, poolId);
        bytes memory firstPart = abi.encodePacked(tokenOut, actionId, poolId, pool, fee, WETH);
        fee = uint16(DEX_FEE_LOW);
        poolId = UNI_V3;
        pool = testQuoter._v3TypePool(tokenIn, WETH, fee, poolId);
        return abi.encodePacked(firstPart, midId, poolId, pool, fee, tokenIn, lenderId, endId);
    }

    /** DEBT SWAP */

    function getDebtSwapExactInSingle(address tokenIn, address tokenOut, uint16 lenderId) internal view returns (bytes memory data) {
        uint16 fee = uint16(DEX_FEE_LOW_MEDIUM);
        uint8 poolId = AGNI;
        address pool = testQuoter._v3TypePool(tokenOut, tokenIn, fee, poolId);
        (uint8 actionId, , uint8 endId) = getDebtSwapExactInFlags();
        return abi.encodePacked(tokenIn, actionId, poolId, pool, fee, tokenOut, lenderId, endId);
    }

    function getDebtSwapExactOutSingle(address tokenIn, address tokenOut, uint16 lenderId) internal view returns (bytes memory data) {
        uint16 fee = uint16(DEX_FEE_LOW_MEDIUM);
        uint8 poolId = AGNI;
        address pool = testQuoter._v3TypePool(tokenOut, tokenIn, fee, poolId);
        (uint8 actionId, , uint8 endId) = getDebtSwapExactOutFlags();
        return abi.encodePacked(tokenOut, actionId, poolId, pool, fee, tokenIn, lenderId, endId);
    }

    function getDebtSwapExactInMulti(address tokenIn, address tokenOut, uint16 lenderId) internal view returns (bytes memory data) {
        uint16 fee = uint16(DEX_FEE_LOW);
        (uint8 actionId, uint8 midId, uint8 endId) = getDebtSwapExactInFlags();
        uint8 poolId = BUTTER;
        address pool = testQuoter._v3TypePool(tokenIn, TAIKO, fee, poolId);
        bytes memory firstPart = abi.encodePacked(tokenIn, actionId, poolId, pool, fee, TAIKO);
        fee = uint16(DEX_FEE_LOW);
        poolId = BUTTER;
        pool = testQuoter._v3TypePool(tokenOut, TAIKO, fee, poolId);
        return abi.encodePacked(firstPart, midId, poolId, pool, fee, tokenOut, lenderId, endId);
    }

    function getDebtSwapExactOutMulti(address tokenIn, address tokenOut, uint16 lenderId) internal view returns (bytes memory data) {
        uint16 fee = uint16(DEX_FEE_LOW);
        (uint8 actionId, uint8 midId, uint8 endId) = getDebtSwapExactOutFlags();
        uint8 poolId = BUTTER;
        address pool = testQuoter._v3TypePool(tokenOut, TAIKO, fee, poolId);
        bytes memory firstPart = abi.encodePacked(tokenOut, actionId, poolId, pool, fee, TAIKO);
        fee = uint16(DEX_FEE_LOW);
        poolId = BUTTER;
        pool = testQuoter._v3TypePool(tokenIn, TAIKO, fee, poolId);
        return abi.encodePacked(firstPart, midId, poolId, pool, fee, tokenIn, lenderId, endId);
    }

    /** OPEN */

    function getOpenExactInSingleV2(address tokenIn, address tokenOut, uint16 lenderId) internal view returns (bytes memory data) {
        uint8 poolId = MERCHANT_MOE;
        (uint8 actionId, , uint8 endId) = getOpenExactInFlags();
        address pool = testQuoter._v2TypePairAddress(tokenIn, tokenOut, poolId);
        return abi.encodePacked(tokenIn, actionId, poolId, pool, MERCHANT_MOE_FEE_DENOM, tokenOut, lenderId, endId);
    }

    function getOpenExactOutSingleV2(address tokenIn, address tokenOut, uint16 lenderId) internal view returns (bytes memory data) {
        uint8 poolId = MERCHANT_MOE;
        (uint8 actionId, , uint8 endId) = getOpenExactOutFlags();
        address pool = testQuoter._v2TypePairAddress(tokenIn, tokenOut, poolId);
        return abi.encodePacked(tokenOut, actionId, poolId, pool, MERCHANT_MOE_FEE_DENOM, tokenIn, lenderId, endId);
    }

    function getOpenExactInMultiV2(address tokenIn, address tokenOut, uint16 lenderId) internal view returns (bytes memory data) {
        (uint8 actionId, uint8 midId, uint8 endId) = getOpenExactInFlags();
        uint8 poolId = MERCHANT_MOE;
        address pool = testQuoter._v2TypePairAddress(tokenIn, TAIKO, poolId);
        bytes memory firstPart = abi.encodePacked(tokenIn, actionId, poolId, pool, MERCHANT_MOE_FEE_DENOM, TAIKO);
        poolId = MERCHANT_MOE;
        pool = testQuoter._v2TypePairAddress(TAIKO, tokenOut, poolId);
        return abi.encodePacked(firstPart, midId, poolId, pool, MERCHANT_MOE_FEE_DENOM, tokenOut, lenderId, endId);
    }

    function getOpenExactOutMultiV2(address tokenIn, address tokenOut, uint16 lenderId) internal view returns (bytes memory data) {
        (uint8 actionId, uint8 midId, uint8 endId) = getOpenExactOutFlags();
        uint8 poolId = MERCHANT_MOE;
        address pool = testQuoter._v2TypePairAddress(TAIKO, tokenOut, poolId);
        bytes memory firstPart = abi.encodePacked(tokenOut, actionId, poolId, pool, MERCHANT_MOE_FEE_DENOM, TAIKO);
        pool = testQuoter._v2TypePairAddress(tokenIn, TAIKO, poolId);
        return abi.encodePacked(firstPart, midId, poolId, pool, MERCHANT_MOE_FEE_DENOM, tokenIn, lenderId, endId);
    }

    /** CLOSE */

    function getCloseExactOutSingleV2(address tokenIn, address tokenOut, uint16 lenderId) internal view returns (bytes memory data) {
        uint8 poolId = MERCHANT_MOE;
        address pool = testQuoter._v2TypePairAddress(tokenIn, tokenOut, poolId);
        (uint8 actionId, , uint8 endId) = getCloseExactOutFlags();
        return abi.encodePacked(tokenOut, actionId, poolId, pool, MERCHANT_MOE_FEE_DENOM, tokenIn, lenderId, endId);
    }

    function getCloseExactInSingleV2(address tokenIn, address tokenOut, uint16 lenderId) internal view returns (bytes memory data) {
        uint8 poolId = MERCHANT_MOE;
        address pool = testQuoter._v2TypePairAddress(tokenIn, tokenOut, poolId);
        (uint8 actionId, , uint8 endId) = getCloseExactInFlags();
        return abi.encodePacked(tokenIn, actionId, poolId, pool, MERCHANT_MOE_FEE_DENOM, tokenOut, lenderId, endId);
    }

    function getCloseExactInMultiV2(address tokenIn, address tokenOut, uint16 lenderId) internal view returns (bytes memory data) {
        (uint8 actionId, uint8 midId, uint8 endId) = getCloseExactInFlags();
        uint8 poolId = MERCHANT_MOE;
        address pool = testQuoter._v2TypePairAddress(tokenIn, TAIKO, poolId);
        bytes memory firstPart = abi.encodePacked(tokenIn, actionId, poolId, pool, MERCHANT_MOE_FEE_DENOM, TAIKO);
        poolId = MERCHANT_MOE;
        pool = testQuoter._v2TypePairAddress(tokenOut, TAIKO, poolId);
        return abi.encodePacked(firstPart, midId, poolId, pool, MERCHANT_MOE_FEE_DENOM, tokenOut, lenderId, endId);
    }

    function getCloseExactOutMultiV2(address tokenIn, address tokenOut, uint16 lenderId) internal view returns (bytes memory data) {
        (uint8 actionId, uint8 midId, uint8 endId) = getCloseExactOutFlags();
        uint8 poolId = MERCHANT_MOE;
        address pool = testQuoter._v2TypePairAddress(tokenOut, TAIKO, poolId);
        bytes memory firstPart = abi.encodePacked(tokenOut, actionId, poolId, pool, MERCHANT_MOE_FEE_DENOM, TAIKO);
        poolId = MERCHANT_MOE;
        pool = testQuoter._v2TypePairAddress(tokenIn, TAIKO, poolId);
        return abi.encodePacked(firstPart, midId, poolId, pool, MERCHANT_MOE_FEE_DENOM, tokenIn, lenderId, endId);
    }

    /** COLLATERAL SWAP */

    function getCollateralSwapExactInSingleV2(address tokenIn, address tokenOut, uint16 lenderId) internal view returns (bytes memory data) {
        uint8 poolId = MERCHANT_MOE;
        address pool = testQuoter._v2TypePairAddress(tokenIn, tokenOut, poolId);
        (uint8 actionId, , uint8 endId) = getCollateralSwapExactInFlags();
        return abi.encodePacked(tokenIn, actionId, poolId, pool, MERCHANT_MOE_FEE_DENOM, tokenOut, lenderId, endId);
    }

    function getCollateralSwapExactOutSingleV2(address tokenIn, address tokenOut, uint16 lenderId) internal view returns (bytes memory data) {
        uint8 poolId = MERCHANT_MOE;
        address pool = testQuoter._v2TypePairAddress(tokenIn, tokenOut, poolId);
        (uint8 actionId, , uint8 endId) = getCollateralSwapExactOutFlags();
        return abi.encodePacked(tokenOut, actionId, poolId, pool, MERCHANT_MOE_FEE_DENOM, tokenIn, lenderId, endId);
    }

    function getCollateralSwapExactInMultiV2(address tokenIn, address tokenOut, uint16 lenderId) internal view returns (bytes memory data) {
        (uint8 actionId, uint8 midId, uint8 endId) = getCollateralSwapExactInFlags();
        uint8 poolId = MERCHANT_MOE;
        address pool = testQuoter._v2TypePairAddress(tokenIn, TAIKO, poolId);
        bytes memory firstPart = abi.encodePacked(tokenIn, actionId, poolId, pool, MERCHANT_MOE_FEE_DENOM, TAIKO);
        poolId = MERCHANT_MOE;
        pool = testQuoter._v2TypePairAddress(tokenOut, TAIKO, poolId);
        return abi.encodePacked(firstPart, midId, poolId, pool, MERCHANT_MOE_FEE_DENOM, tokenOut, lenderId, endId);
    }

    function getCollateralSwapExactOutMultiV2(address tokenIn, address tokenOut, uint16 lenderId) internal view returns (bytes memory data) {
        (uint8 actionId, uint8 midId, uint8 endId) = getCollateralSwapExactOutFlags();
        uint8 poolId = MERCHANT_MOE;
        address pool = testQuoter._v2TypePairAddress(tokenOut, TAIKO, poolId);
        bytes memory firstPart = abi.encodePacked(tokenOut, actionId, poolId, pool, MERCHANT_MOE_FEE_DENOM, TAIKO);
        poolId = MERCHANT_MOE;
        pool = testQuoter._v2TypePairAddress(tokenIn, TAIKO, poolId);
        return abi.encodePacked(firstPart, midId, poolId, pool, MERCHANT_MOE_FEE_DENOM, tokenIn, lenderId, endId);
    }

    /** DEBT SWAP */

    function getDebtSwapExactInSingleV2(address tokenIn, address tokenOut, uint16 lenderId) internal view returns (bytes memory data) {
        uint8 poolId = MERCHANT_MOE;
        address pool = testQuoter._v2TypePairAddress(tokenIn, tokenOut, poolId);
        (uint8 actionId, , uint8 endId) = getDebtSwapExactInFlags();
        return abi.encodePacked(tokenIn, actionId, poolId, pool, MERCHANT_MOE_FEE_DENOM, tokenOut, lenderId, endId);
    }

    function getDebtSwapExactOutSingleV2(address tokenIn, address tokenOut, uint16 lenderId) internal view returns (bytes memory data) {
        uint8 poolId = MERCHANT_MOE;
        address pool = testQuoter._v2TypePairAddress(tokenIn, tokenOut, poolId);
        (uint8 actionId, , uint8 endId) = getDebtSwapExactOutFlags();
        return abi.encodePacked(tokenOut, actionId, poolId, pool, MERCHANT_MOE_FEE_DENOM, tokenIn, lenderId, endId);
    }

    function getDebtSwapExactInMultiV2(address tokenIn, address tokenOut, uint16 lenderId) internal view returns (bytes memory data) {
        (uint8 actionId, uint8 midId, uint8 endId) = getDebtSwapExactInFlags();
        uint8 poolId = MERCHANT_MOE;
        address pool = testQuoter._v2TypePairAddress(tokenIn, TAIKO, poolId);
        bytes memory firstPart = abi.encodePacked(tokenIn, actionId, poolId, pool, MERCHANT_MOE_FEE_DENOM, TAIKO);
        poolId = MERCHANT_MOE;
        pool = testQuoter._v2TypePairAddress(tokenOut, TAIKO, poolId);
        return abi.encodePacked(firstPart, midId, poolId, pool, MERCHANT_MOE_FEE_DENOM, tokenOut, lenderId, endId);
    }

    function getDebtSwapExactOutMultiV2(address tokenIn, address tokenOut, uint16 lenderId) internal view returns (bytes memory data) {
        (uint8 actionId, uint8 midId, uint8 endId) = getDebtSwapExactOutFlags();
        uint8 poolId = MERCHANT_MOE;
        address pool = testQuoter._v2TypePairAddress(tokenOut, TAIKO, poolId);
        bytes memory firstPart = abi.encodePacked(tokenOut, actionId, poolId, pool, MERCHANT_MOE_FEE_DENOM, TAIKO);
        poolId = MERCHANT_MOE;
        pool = testQuoter._v2TypePairAddress(tokenIn, TAIKO, poolId);
        return abi.encodePacked(firstPart, midId, poolId, pool, MERCHANT_MOE_FEE_DENOM, tokenIn, lenderId, endId);
    }

    struct TestParamsOpen {
        address borrowAsset;
        address collateralAsset;
        address debtToken;
        address collateralToken;
        uint256 amountToDeposit;
        uint256 swapAmount;
        uint256 checkAmount;
    }

    function getOpenParams(
        address borrowAsset,
        address collateralAsset,
        uint256 amountToDeposit,
        uint256 swapAmount,
        uint256 checkAmount,
        uint16 lenderId
    ) internal view returns (TestParamsOpen memory p) {
        p = TestParamsOpen(
            borrowAsset, //
            collateralAsset,
            debtTokens[borrowAsset][lenderId],
            collateralTokens[collateralAsset][lenderId],
            amountToDeposit,
            swapAmount,
            checkAmount
        );
    }
}
