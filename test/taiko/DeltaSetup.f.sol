// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

// solhint-disable max-line-length

import {AddressesTaiko, IFactoryFeeGetter} from "./utils/CommonAddresses.f.sol";
import {QuoterTaiko} from "../../contracts/1delta/quoter/Taiko.sol";
import {PoolGetter} from "../../contracts/1delta/quoter/poolGetter/Taiko.sol";
import {ComposerUtils, Commands} from "../shared/utils/ComposerUtils.sol";

// interfaces
import {IFlashAggregator} from "../shared/interfaces/IFlashAggregator.sol";
import {IFlashLoanReceiver, IFlashLoanReceiverAaveV2} from "../shared/interfaces/IFlashLoanReceiver.sol";
import {IManagement} from "../shared/interfaces/IManagement.sol";
import {ILending} from "../shared/interfaces/ILending.sol";
import {IInitialize} from "../shared/interfaces/IInitialize.sol";
import {IBrokerProxy} from "../shared/interfaces/IBrokerProxy.sol";
import {IModuleConfig} from "../../contracts/1delta/proxy/interfaces/IModuleConfig.sol";
import {IModuleLens} from "../../contracts/1delta/proxy/interfaces/IModuleLens.sol";

// universal erc20
import {IERC20All} from "../shared/interfaces/IERC20All.sol";
// lending pool for debugging
import {ILendingPool} from "../shared/interfaces/ILendingPool.sol";

// proxy and management
import {ConfigModule} from "../../contracts/1delta/proxy/modules/ConfigModule.sol";
import {DeltaBrokerProxyGen2} from "../../contracts/1delta/proxy/DeltaBrokerGen2.sol";

// lenders
import {HanaTaikoAssets, HanaTaiko} from "./utils/lender/hanaAddresses.sol";
import {MeridianTaikoAssets, MeridianTaiko} from "./utils/lender/meridianAddresses.sol";
import {AvalonTaikoAssets, AvalonTaiko} from "./utils/lender/avalonAddresses.sol";
import {TakoTakoTaikoAssets, TakoTakoTaiko} from "./utils/lender/takoTakoAddresses.sol";

// mappings
import {TokensTaiko} from "./utils/tokens.sol";
import {DexMappingsTaiko} from "./utils/DexMappings.sol";
import {LenderMappingsTaiko} from "./utils/LenderMappings.sol";
import {FlashMappingsTaiko} from "./utils/FlashMappings.sol";

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
    PoolGetter testQuoter;
    QuoterTaiko quoter;
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
        return selectors;
    }

    function initializeSelectors() internal pure returns (bytes4[] memory selectors) {
        selectors = new bytes4[](1);
        selectors[0] = IInitialize.initMarginTrader.selector;
        return selectors;
    }

    function flashAggregatorSelectors() internal pure returns (bytes4[] memory selectors) {
        selectors = new bytes4[](26);
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
        selectors[22] = IFlashLoanReceiverAaveV2.executeOperation.selector;
        selectors[23] = IFlashAggregator.syncSwapBaseSwapCallback.selector;
        selectors[24] = IFlashAggregator.pancakeV3SwapCallback.selector;
        selectors[25] = IFlashLoanReceiver.executeOperation.selector;
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
        testQuoter = new PoolGetter();
        quoter = new QuoterTaiko();
    }

    function initializeDeltaHana() internal virtual {
        // hana
        management.addGeneralLenderTokens(
            TokensTaiko.USDC,
            HanaTaikoAssets.USDC_A_TOKEN,
            HanaTaikoAssets.USDC_V_TOKEN,
            HanaTaikoAssets.USDC_S_TOKEN,
            LenderMappingsTaiko.HANA_ID
        );
        management.addGeneralLenderTokens(
            TokensTaiko.TAIKO,
            HanaTaikoAssets.TAIKO_A_TOKEN,
            HanaTaikoAssets.TAIKO_V_TOKEN,
            HanaTaikoAssets.TAIKO_S_TOKEN,
            LenderMappingsTaiko.HANA_ID
        );
        management.addGeneralLenderTokens(
            TokensTaiko.WETH,
            HanaTaikoAssets.WETH_A_TOKEN,
            HanaTaikoAssets.WETH_V_TOKEN,
            HanaTaikoAssets.WETH_S_TOKEN,
            LenderMappingsTaiko.HANA_ID
        );

        collateralTokens[TokensTaiko.USDC][LenderMappingsTaiko.HANA_ID] = HanaTaikoAssets.USDC_A_TOKEN;
        collateralTokens[TokensTaiko.TAIKO][LenderMappingsTaiko.HANA_ID] = HanaTaikoAssets.TAIKO_A_TOKEN;
        collateralTokens[TokensTaiko.WETH][LenderMappingsTaiko.HANA_ID] = HanaTaikoAssets.WETH_A_TOKEN;

        debtTokens[TokensTaiko.USDC][LenderMappingsTaiko.HANA_ID] = HanaTaikoAssets.USDC_V_TOKEN;
        debtTokens[TokensTaiko.TAIKO][LenderMappingsTaiko.HANA_ID] = HanaTaikoAssets.TAIKO_V_TOKEN;
        debtTokens[TokensTaiko.WETH][LenderMappingsTaiko.HANA_ID] = HanaTaikoAssets.WETH_V_TOKEN;

        // approve pools
        address[] memory assets = new address[](3);
        assets[0] = TokensTaiko.USDC;
        assets[1] = TokensTaiko.WETH;
        assets[2] = TokensTaiko.TAIKO;
        management.approveAddress(assets, HanaTaiko.POOL);
    }

    function initializeDeltaMeridian() internal virtual {
        // meridian
        management.addGeneralLenderTokens(
            TokensTaiko.USDC,
            MeridianTaikoAssets.USDC_A_TOKEN,
            MeridianTaikoAssets.USDC_V_TOKEN,
            MeridianTaikoAssets.USDC_S_TOKEN,
            LenderMappingsTaiko.MERIDIAN_ID
        );
        management.addGeneralLenderTokens(
            TokensTaiko.TAIKO,
            MeridianTaikoAssets.TAIKO_A_TOKEN,
            MeridianTaikoAssets.TAIKO_V_TOKEN,
            MeridianTaikoAssets.TAIKO_S_TOKEN,
            LenderMappingsTaiko.MERIDIAN_ID
        );
        management.addGeneralLenderTokens(
            TokensTaiko.WETH,
            MeridianTaikoAssets.WETH_A_TOKEN,
            MeridianTaikoAssets.WETH_V_TOKEN,
            MeridianTaikoAssets.WETH_S_TOKEN,
            LenderMappingsTaiko.MERIDIAN_ID
        );

        collateralTokens[TokensTaiko.USDC][LenderMappingsTaiko.MERIDIAN_ID] = MeridianTaikoAssets.USDC_A_TOKEN;
        collateralTokens[TokensTaiko.TAIKO][LenderMappingsTaiko.MERIDIAN_ID] = MeridianTaikoAssets.TAIKO_A_TOKEN;
        collateralTokens[TokensTaiko.WETH][LenderMappingsTaiko.MERIDIAN_ID] = MeridianTaikoAssets.WETH_A_TOKEN;

        debtTokens[TokensTaiko.USDC][LenderMappingsTaiko.MERIDIAN_ID] = MeridianTaikoAssets.USDC_V_TOKEN;
        debtTokens[TokensTaiko.TAIKO][LenderMappingsTaiko.MERIDIAN_ID] = MeridianTaikoAssets.TAIKO_V_TOKEN;
        debtTokens[TokensTaiko.WETH][LenderMappingsTaiko.MERIDIAN_ID] = MeridianTaikoAssets.WETH_V_TOKEN;

        // approve pools
        address[] memory assets = new address[](3);
        assets[0] = TokensTaiko.USDC;
        assets[1] = TokensTaiko.WETH;
        assets[2] = TokensTaiko.TAIKO;
        management.approveAddress(assets, MeridianTaiko.POOL);
    }

    function initializeDeltaTakoTako() internal virtual {
        // takotako
        management.addGeneralLenderTokens(
            TokensTaiko.USDC,
            TakoTakoTaikoAssets.USDC_A_TOKEN,
            TakoTakoTaikoAssets.USDC_V_TOKEN,
            TakoTakoTaikoAssets.USDC_S_TOKEN,
            LenderMappingsTaiko.TAKOTAKO_ID
        );
        management.addGeneralLenderTokens(
            TokensTaiko.TAIKO,
            TakoTakoTaikoAssets.TAIKO_A_TOKEN,
            TakoTakoTaikoAssets.TAIKO_V_TOKEN,
            TakoTakoTaikoAssets.TAIKO_S_TOKEN,
            LenderMappingsTaiko.TAKOTAKO_ID
        );
        management.addGeneralLenderTokens(
            TokensTaiko.WETH,
            TakoTakoTaikoAssets.WETH_A_TOKEN,
            TakoTakoTaikoAssets.WETH_V_TOKEN,
            TakoTakoTaikoAssets.WETH_S_TOKEN,
            LenderMappingsTaiko.TAKOTAKO_ID
        );

        collateralTokens[TokensTaiko.USDC][LenderMappingsTaiko.TAKOTAKO_ID] = TakoTakoTaikoAssets.USDC_A_TOKEN;
        collateralTokens[TokensTaiko.TAIKO][LenderMappingsTaiko.TAKOTAKO_ID] = TakoTakoTaikoAssets.TAIKO_A_TOKEN;
        collateralTokens[TokensTaiko.WETH][LenderMappingsTaiko.TAKOTAKO_ID] = TakoTakoTaikoAssets.WETH_A_TOKEN;

        debtTokens[TokensTaiko.USDC][LenderMappingsTaiko.TAKOTAKO_ID] = TakoTakoTaikoAssets.USDC_V_TOKEN;
        debtTokens[TokensTaiko.TAIKO][LenderMappingsTaiko.TAKOTAKO_ID] = TakoTakoTaikoAssets.TAIKO_V_TOKEN;
        debtTokens[TokensTaiko.WETH][LenderMappingsTaiko.TAKOTAKO_ID] = TakoTakoTaikoAssets.WETH_V_TOKEN;

        // approve pools
        address[] memory assets = new address[](3);
        assets[0] = TokensTaiko.USDC;
        assets[1] = TokensTaiko.WETH;
        assets[2] = TokensTaiko.TAIKO;
        management.approveAddress(assets, TakoTakoTaiko.POOL);
    }

    function initializeDeltaAvalon() internal virtual {
        // takotako
        management.addGeneralLenderTokens(
            TokensTaiko.SOLV_BTC,
            AvalonTaikoAssets.SOLV_BTC_A_TOKEN,
            AvalonTaikoAssets.SOLV_BTC_V_TOKEN,
            AvalonTaikoAssets.SOLV_BTC_S_TOKEN,
            LenderMappingsTaiko.AVALON_ID
        );
        management.addGeneralLenderTokens(
            TokensTaiko.TAIKO,
            AvalonTaikoAssets.SOLV_BTC_BBN_A_TOKEN,
            AvalonTaikoAssets.SOLV_BTC_BBN_V_TOKEN,
            AvalonTaikoAssets.SOLV_BTC_BBN_S_TOKEN,
            LenderMappingsTaiko.AVALON_ID
        );

        collateralTokens[TokensTaiko.SOLV_BTC][LenderMappingsTaiko.AVALON_ID] = AvalonTaikoAssets.SOLV_BTC_A_TOKEN;
        collateralTokens[TokensTaiko.SOLV_BTC_BBN][LenderMappingsTaiko.AVALON_ID] = AvalonTaikoAssets.SOLV_BTC_BBN_A_TOKEN;

        debtTokens[TokensTaiko.SOLV_BTC][LenderMappingsTaiko.AVALON_ID] = AvalonTaikoAssets.SOLV_BTC_V_TOKEN;
        debtTokens[TokensTaiko.SOLV_BTC_BBN][LenderMappingsTaiko.AVALON_ID] = AvalonTaikoAssets.SOLV_BTC_BBN_V_TOKEN;

        // approve pools
        address[] memory assets = new address[](2);
        assets[0] = TokensTaiko.SOLV_BTC;
        assets[1] = TokensTaiko.SOLV_BTC_BBN;
        management.approveAddress(assets, AvalonTaiko.POOL);
    }

    function getAssets() internal pure returns (address[] memory assetList) {
        assetList = new address[](3);
        assetList[0] = TokensTaiko.USDC;
        assetList[1] = TokensTaiko.WETH;
        assetList[2] = TokensTaiko.TAIKO;
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
        uint16 fee = DEX_FEE_LOW;
        uint8 poolId = DexMappingsTaiko.UNI_V3;
        address pool = testQuoter.v3TypePool(tokenIn, tokenOut, fee, poolId);
        (uint8 actionId, , uint8 endId) = getOpenExactInFlags();
        return abi.encodePacked(tokenIn, actionId, poolId, pool, fee, tokenOut, lenderId, endId);
    }

    function getOpenExactInSingle_izi(address tokenIn, address tokenOut, uint16 lenderId) internal view returns (bytes memory data) {
        uint16 fee = uint16(DEX_FEE_LOW_HIGH);
        uint8 poolId = DexMappingsTaiko.IZUMI;
        address pool = testQuoter.getiZiPool(tokenIn, tokenOut, fee);
        (uint8 actionId, , uint8 endId) = getOpenExactInFlags();
        return abi.encodePacked(tokenIn, actionId, poolId, pool, fee, tokenOut, lenderId, endId);
    }

    function getSpotExactInSingle_izi(address tokenIn, address tokenOut) internal view returns (bytes memory data) {
        uint16 fee = uint16(DEX_FEE_LOW_HIGH);
        uint8 poolId = DexMappingsTaiko.IZUMI;
        address pool = testQuoter.getiZiPool(tokenIn, tokenOut, fee);
        return abi.encodePacked(tokenIn, uint8(0), poolId, pool, fee, tokenOut);
    }

    function getSpotExactOutSingle_izi(address tokenIn, address tokenOut) internal view returns (bytes memory data) {
        uint16 fee = uint16(DEX_FEE_LOW_HIGH);
        uint8 poolId = DexMappingsTaiko.IZUMI;
        address pool = testQuoter.getiZiPool(tokenIn, tokenOut, fee);
        return abi.encodePacked(tokenOut, uint8(0), poolId, pool, fee, tokenIn);
    }

    function getOpenExactOutSingle(address tokenIn, address tokenOut, uint16 lenderId) internal view returns (bytes memory data) {
        uint16 fee = DEX_FEE_LOW;
        uint8 poolId = DexMappingsTaiko.UNI_V3;
        address pool = testQuoter.v3TypePool(tokenIn, tokenOut, fee, poolId);
        (uint8 actionId, , uint8 endId) = getOpenExactOutFlags();
        return abi.encodePacked(tokenOut, actionId, poolId, pool, fee, tokenIn, lenderId, endId);
    }

    function getOpenExactInMulti(address tokenIn, address tokenOut, uint16 lenderId) internal view returns (bytes memory data) {
        uint16 fee = DEX_FEE_LOW;
        (uint8 actionId, uint8 midId, uint8 endId) = getOpenExactInFlags();
        uint8 poolId = DexMappingsTaiko.IZUMI;
        address pool = testQuoter.getiZiPool(tokenIn, TokensTaiko.TAIKO, fee);
        bytes memory firstPart = abi.encodePacked(tokenIn, actionId, poolId, pool, fee, TokensTaiko.TAIKO);
        fee = DEX_FEE_STABLES;
        poolId = DexMappingsTaiko.UNI_V3;
        pool = testQuoter.v3TypePool(TokensTaiko.TAIKO, tokenOut, fee, poolId);
        return abi.encodePacked(firstPart, midId, poolId, pool, fee, tokenOut, lenderId, endId);
    }

    function getOpenExactOutMulti(address tokenIn, address tokenOut, uint16 lenderId) internal view returns (bytes memory data) {
        uint16 fee = DEX_FEE_STABLES;
        (uint8 actionId, uint8 midId, uint8 endId) = getOpenExactOutFlags();
        uint8 poolId = DexMappingsTaiko.UNI_V3;
        address pool = testQuoter.v3TypePool(tokenOut, TokensTaiko.TAIKO, fee, poolId);
        bytes memory firstPart = abi.encodePacked(tokenOut, actionId, poolId, pool, fee, TokensTaiko.TAIKO);
        fee = DEX_FEE_LOW;
        poolId = DexMappingsTaiko.IZUMI;
        pool = testQuoter.getiZiPool(TokensTaiko.TAIKO, tokenIn, fee);
        return abi.encodePacked(firstPart, midId, poolId, pool, fee, tokenIn, lenderId, endId);
    }

    /** CLOSE */

    function getCloseExactOutSingle(address tokenIn, address tokenOut, uint16 lenderId) internal view returns (bytes memory data) {
        uint16 fee = DEX_FEE_LOW;
        uint8 poolId = DexMappingsTaiko.UNI_V3;
        address pool = testQuoter.v3TypePool(tokenIn, tokenOut, fee, poolId);
        (uint8 actionId, , uint8 endId) = getCloseExactOutFlags();
        return abi.encodePacked(tokenOut, actionId, poolId, pool, fee, tokenIn, lenderId, endId);
    }

    function getCloseExactInSingle(address tokenIn, address tokenOut, uint16 lenderId) internal view returns (bytes memory data) {
        uint16 fee = DEX_FEE_LOW;
        uint8 poolId = DexMappingsTaiko.UNI_V3;
        address pool = testQuoter.v3TypePool(tokenIn, tokenOut, fee, poolId);
        (uint8 actionId, , uint8 endId) = getCloseExactInFlags();
        return abi.encodePacked(tokenIn, actionId, poolId, pool, fee, tokenOut, lenderId, endId);
    }

    function getCloseExactInMulti(address tokenIn, address tokenOut, uint16 lenderId) internal view returns (bytes memory data) {
        uint16 fee = DEX_FEE_LOW;
        (uint8 actionId, uint8 midId, uint8 endId) = getCloseExactInFlags();
        uint8 poolId = DexMappingsTaiko.IZUMI;
        address pool = testQuoter.getiZiPool(TokensTaiko.TAIKO, tokenIn, fee);
        bytes memory firstPart = abi.encodePacked(tokenIn, actionId, poolId, pool, fee, TokensTaiko.TAIKO);
        fee = DEX_FEE_STABLES;
        poolId = DexMappingsTaiko.UNI_V3;
        pool = testQuoter.v3TypePool(TokensTaiko.TAIKO, tokenOut, fee, poolId);
        return abi.encodePacked(firstPart, midId, poolId, pool, fee, tokenOut, lenderId, endId);
    }

    function getCloseExactOutMulti(address tokenIn, address tokenOut, uint16 lenderId) internal view returns (bytes memory data) {
        uint16 fee = DEX_FEE_STABLES;
        (uint8 actionId, uint8 midId, uint8 endId) = getCloseExactOutFlags();
        uint8 poolId = DexMappingsTaiko.UNI_V3;
        address pool = testQuoter.v3TypePool(TokensTaiko.TAIKO, tokenOut, fee, poolId);
        bytes memory firstPart = abi.encodePacked(tokenOut, actionId, poolId, pool, fee, TokensTaiko.TAIKO);
        fee = DEX_FEE_LOW;
        poolId = DexMappingsTaiko.IZUMI;
        pool = testQuoter.getiZiPool(TokensTaiko.TAIKO, tokenIn, fee);
        return abi.encodePacked(firstPart, midId, poolId, pool, fee, tokenIn, lenderId, endId);
    }

    /** COLLATERAL SWAP */

    function getCollateralSwapExactInSingle(address tokenIn, address tokenOut, uint16 lenderId) internal view returns (bytes memory data) {
        uint16 fee = DEX_FEE_LOW;
        uint8 poolId = DexMappingsTaiko.UNI_V3;
        address pool = testQuoter.v3TypePool(tokenIn, tokenOut, fee, poolId);
        (uint8 actionId, , uint8 endId) = getCollateralSwapExactInFlags();
        return abi.encodePacked(tokenIn, actionId, poolId, pool, fee, tokenOut, lenderId, endId);
    }

    function getCollateralSwapExactOutSingle(address tokenIn, address tokenOut, uint16 lenderId) internal view returns (bytes memory data) {
        uint16 fee = DEX_FEE_LOW;
        uint8 poolId = DexMappingsTaiko.UNI_V3;
        address pool = testQuoter.v3TypePool(tokenIn, tokenOut, fee, poolId);
        (uint8 actionId, , uint8 endId) = getCollateralSwapExactOutFlags();
        return abi.encodePacked(tokenOut, actionId, poolId, pool, fee, tokenIn, lenderId, endId);
    }

    function getCollateralSwapExactInMulti(address tokenIn, address tokenOut, uint16 lenderId) internal view returns (bytes memory data) {
        uint16 fee = uint16(DEX_FEE_LOW_MEDIUM);
        (uint8 actionId, uint8 midId, uint8 endId) = getCollateralSwapExactInFlags();
        uint8 poolId = DexMappingsTaiko.UNI_V3;
        address pool = testQuoter.v3TypePool(tokenIn, TokensTaiko.WETH, fee, poolId);
        bytes memory firstPart = abi.encodePacked(tokenIn, actionId, poolId, pool, fee, TokensTaiko.WETH);
        fee = DEX_FEE_LOW;
        poolId = DexMappingsTaiko.UNI_V3;
        pool = testQuoter.v3TypePool(tokenOut, TokensTaiko.WETH, fee, poolId);
        return abi.encodePacked(firstPart, midId, poolId, pool, fee, tokenOut, lenderId, endId);
    }

    function getCollateralSwapExactOutMulti(address tokenIn, address tokenOut, uint16 lenderId) internal view returns (bytes memory data) {
        uint16 fee = uint16(DEX_FEE_LOW_MEDIUM);
        (uint8 actionId, uint8 midId, uint8 endId) = getCollateralSwapExactOutFlags();
        uint8 poolId = DexMappingsTaiko.UNI_V3;
        address pool = testQuoter.v3TypePool(tokenOut, TokensTaiko.WETH, fee, poolId);
        bytes memory firstPart = abi.encodePacked(tokenOut, actionId, poolId, pool, fee, TokensTaiko.WETH);
        fee = DEX_FEE_LOW;
        poolId = DexMappingsTaiko.UNI_V3;
        pool = testQuoter.v3TypePool(tokenIn, TokensTaiko.WETH, fee, poolId);
        return abi.encodePacked(firstPart, midId, poolId, pool, fee, tokenIn, lenderId, endId);
    }

    /** DEBT SWAP */

    function getDebtSwapExactInSingle(address tokenIn, address tokenOut, uint16 lenderId) internal view returns (bytes memory data) {
        uint16 fee = uint16(DEX_FEE_LOW_MEDIUM);
        uint8 poolId = DexMappingsTaiko.UNI_V3;
        address pool = testQuoter.v3TypePool(tokenOut, tokenIn, fee, poolId);
        (uint8 actionId, , uint8 endId) = getDebtSwapExactInFlags();
        return abi.encodePacked(tokenIn, actionId, poolId, pool, fee, tokenOut, lenderId, endId);
    }

    function getDebtSwapExactOutSingle(address tokenIn, address tokenOut, uint16 lenderId) internal view returns (bytes memory data) {
        uint16 fee = uint16(DEX_FEE_LOW_MEDIUM);
        uint8 poolId = DexMappingsTaiko.UNI_V3;
        address pool = testQuoter.v3TypePool(tokenOut, tokenIn, fee, poolId);
        (uint8 actionId, , uint8 endId) = getDebtSwapExactOutFlags();
        return abi.encodePacked(tokenOut, actionId, poolId, pool, fee, tokenIn, lenderId, endId);
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
