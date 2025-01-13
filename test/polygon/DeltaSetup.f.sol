// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

// solhint-disable max-line-length

import {AddressesPolygon} from "./utils/CommonAddresses.f.sol";
import {QuoterPolygon} from "../../contracts/1delta/quoter/Polygon.sol";
import {PoolGetter} from "../../contracts/1delta/quoter/poolGetter/Polygon.sol";
import {MockRouter} from "../../contracts/mocks/MockRouter.sol";
import {ComposerUtils, Commands} from "../shared/utils/ComposerUtils.sol";

// interfaces
import {IFlashAggregator} from "../shared/interfaces/IFlashAggregator.sol";
import {IFlashLoanReceiver} from "./utils/IFlashLoanReceiver.sol";
import {IManagement} from "../shared/interfaces/IManagement.sol";
import {ILending} from "../shared/interfaces/ILending.sol";
import {IInitialize} from "../shared/interfaces/IInitialize.sol";
import {IBrokerProxy} from "../shared/interfaces/IBrokerProxy.sol";
import {IModuleConfig} from "../../contracts/1delta/proxy/interfaces/IModuleConfig.sol";
import {IComet} from "../../contracts/1delta/interfaces/IComet.sol";
import {IModuleLens} from "../../contracts/1delta/proxy/interfaces/IModuleLens.sol";
// universal erc20
import {IERC20All} from "../shared/interfaces/IERC20All.sol";
// lending pool for debugging
import {ILendingPool} from "./utils/ILendingPool.sol";

// lenders
import {AaveV3PolygonAssets, AaveV3Polygon} from "./utils/lender/aaveAddresses.sol";
import {YldrPolygonAssets, YldrPolygon} from "./utils/lender/yldrAddresses.sol";
import {CompoundV3Polygon} from "./utils/lender/compoundAddresses.sol";

// mappings
import {DexMappingsPolygon} from "./utils/DexMappings.sol";
import {LenderMappingsPolygon} from "./utils/LenderMappings.sol";
import {FlashMappingsPolygon} from "./utils/FlashMappings.sol";
import {TokensPolygon} from "./utils/tokens.sol";

// proxy and management
import {ConfigModule} from "../../contracts/1delta/proxy/modules/ConfigModule.sol";
import {DeltaBrokerProxyGen2} from "../../contracts/1delta/proxy/DeltaBrokerGen2.sol";

// initializer

// core modules
import {ManagementModule} from "../../contracts/1delta/modules/shared/storage/ManagementModule.sol";
import {OneDeltaComposerPolygon} from "../../contracts/1delta/modules/polygon/Composer.sol";

// forge
import {Script, console2} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {Test} from "forge-std/Test.sol";

contract DeltaSetup is AddressesPolygon, ComposerUtils, Script, Test {
    address internal brokerProxyAddress;
    IBrokerProxy internal brokerProxy;
    IModuleConfig internal deltaConfig;
    IManagement internal management;
    PoolGetter testQuoter;
    QuoterPolygon quoter;
    OneDeltaComposerPolygon internal aggregator;
    MockRouter router;

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
        return selectors;
    }

    /** DEPLOY PROZY AND MODULES */

    function deployDelta() internal virtual {
        ConfigModule _config = new ConfigModule();
        brokerProxyAddress = address(new DeltaBrokerProxyGen2(address(this), address(_config)));

        brokerProxy = IBrokerProxy(brokerProxyAddress);

        ManagementModule _management = new ManagementModule();
        OneDeltaComposerPolygon _aggregator = new OneDeltaComposerPolygon();

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

    /** ADD AND APPROVE LENDER TOKENS */

    function intitializeFullDelta() internal virtual {
        deployDelta();
        initializeDeltaBase();
        initializeDeltaAave();
        initializeDeltaYldr();
        initializeDeltaCompound();
    }

    function initializeDeltaAave() internal virtual {
        // aave
        management.addGeneralLenderTokens(
            TokensPolygon.USDC,
            AaveV3PolygonAssets.USDC_A_TOKEN,
            AaveV3PolygonAssets.USDC_V_TOKEN,
            AaveV3PolygonAssets.USDC_S_TOKEN,
            LenderMappingsPolygon.AAVE_V3
        );
        management.addGeneralLenderTokens(
            TokensPolygon.USDT,
            AaveV3PolygonAssets.USDT_A_TOKEN,
            AaveV3PolygonAssets.USDT_V_TOKEN,
            AaveV3PolygonAssets.USDT_S_TOKEN,
            LenderMappingsPolygon.AAVE_V3
        );
        management.addGeneralLenderTokens(
            TokensPolygon.WBTC,
            AaveV3PolygonAssets.WBTC_A_TOKEN,
            AaveV3PolygonAssets.WBTC_V_TOKEN,
            AaveV3PolygonAssets.WBTC_S_TOKEN,
            LenderMappingsPolygon.AAVE_V3
        );
        management.addGeneralLenderTokens(
            TokensPolygon.WETH,
            AaveV3PolygonAssets.WETH_A_TOKEN,
            AaveV3PolygonAssets.WETH_V_TOKEN,
            AaveV3PolygonAssets.WETH_S_TOKEN,
            LenderMappingsPolygon.AAVE_V3
        );
        management.addGeneralLenderTokens(
            TokensPolygon.WMATIC,
            AaveV3PolygonAssets.WMATIC_A_TOKEN,
            AaveV3PolygonAssets.WMATIC_V_TOKEN,
            AaveV3PolygonAssets.WMATIC_S_TOKEN,
            LenderMappingsPolygon.AAVE_V3
        );

        collateralTokens[TokensPolygon.USDC][LenderMappingsPolygon.AAVE_V3] = AaveV3PolygonAssets.USDC_A_TOKEN;
        collateralTokens[TokensPolygon.USDT][LenderMappingsPolygon.AAVE_V3] = AaveV3PolygonAssets.USDT_A_TOKEN;
        collateralTokens[TokensPolygon.WBTC][LenderMappingsPolygon.AAVE_V3] = AaveV3PolygonAssets.WBTC_A_TOKEN;
        collateralTokens[TokensPolygon.WETH][LenderMappingsPolygon.AAVE_V3] = AaveV3PolygonAssets.WETH_A_TOKEN;
        collateralTokens[TokensPolygon.WMATIC][LenderMappingsPolygon.AAVE_V3] = AaveV3PolygonAssets.WMATIC_A_TOKEN;

        debtTokens[TokensPolygon.USDC][LenderMappingsPolygon.AAVE_V3] = AaveV3PolygonAssets.USDC_V_TOKEN;
        debtTokens[TokensPolygon.USDT][LenderMappingsPolygon.AAVE_V3] = AaveV3PolygonAssets.USDT_V_TOKEN;
        debtTokens[TokensPolygon.WBTC][LenderMappingsPolygon.AAVE_V3] = AaveV3PolygonAssets.WBTC_V_TOKEN;
        debtTokens[TokensPolygon.WETH][LenderMappingsPolygon.AAVE_V3] = AaveV3PolygonAssets.WETH_V_TOKEN;
        debtTokens[TokensPolygon.WMATIC][LenderMappingsPolygon.AAVE_V3] = AaveV3PolygonAssets.WMATIC_V_TOKEN;

        // approve pools
        address[] memory assets = new address[](5);
        assets[0] = TokensPolygon.USDC;
        assets[1] = TokensPolygon.WBTC;
        assets[2] = TokensPolygon.WETH;
        assets[3] = TokensPolygon.USDT;
        assets[4] = TokensPolygon.WMATIC;

        management.approveAddress(assets, AaveV3Polygon.POOL);
    }

    function initializeDeltaYldr() internal virtual {
        // yldr
        management.addGeneralLenderTokens(
            TokensPolygon.USDC,
            YldrPolygonAssets.USDC_A_TOKEN,
            YldrPolygonAssets.USDC_V_TOKEN,
            address(0),
            LenderMappingsPolygon.YLDR
        );
        management.addGeneralLenderTokens(
            TokensPolygon.USDT,
            YldrPolygonAssets.USDT_A_TOKEN,
            YldrPolygonAssets.USDT_V_TOKEN,
            address(0),
            LenderMappingsPolygon.YLDR
        );
        management.addGeneralLenderTokens(
            TokensPolygon.WBTC,
            YldrPolygonAssets.WBTC_A_TOKEN,
            YldrPolygonAssets.WBTC_V_TOKEN,
            address(0),
            LenderMappingsPolygon.YLDR
        );
        management.addGeneralLenderTokens(
            TokensPolygon.WETH,
            YldrPolygonAssets.WETH_A_TOKEN,
            YldrPolygonAssets.WETH_V_TOKEN,
            address(0),
            LenderMappingsPolygon.YLDR
        );
        management.addGeneralLenderTokens(
            TokensPolygon.WMATIC,
            YldrPolygonAssets.WMATIC_A_TOKEN,
            YldrPolygonAssets.WMATIC_V_TOKEN,
            address(0),
            LenderMappingsPolygon.YLDR
        );

        collateralTokens[TokensPolygon.USDC][LenderMappingsPolygon.YLDR] = YldrPolygonAssets.USDC_A_TOKEN;
        collateralTokens[TokensPolygon.USDT][LenderMappingsPolygon.YLDR] = YldrPolygonAssets.USDT_A_TOKEN;
        collateralTokens[TokensPolygon.WBTC][LenderMappingsPolygon.YLDR] = YldrPolygonAssets.WBTC_A_TOKEN;
        collateralTokens[TokensPolygon.WETH][LenderMappingsPolygon.YLDR] = YldrPolygonAssets.WETH_A_TOKEN;
        collateralTokens[TokensPolygon.WMATIC][LenderMappingsPolygon.YLDR] = YldrPolygonAssets.WMATIC_A_TOKEN;

        debtTokens[TokensPolygon.USDC][LenderMappingsPolygon.YLDR] = YldrPolygonAssets.USDC_V_TOKEN;
        debtTokens[TokensPolygon.USDT][LenderMappingsPolygon.YLDR] = YldrPolygonAssets.USDT_V_TOKEN;
        debtTokens[TokensPolygon.WBTC][LenderMappingsPolygon.YLDR] = YldrPolygonAssets.WBTC_V_TOKEN;
        debtTokens[TokensPolygon.WETH][LenderMappingsPolygon.YLDR] = YldrPolygonAssets.WETH_V_TOKEN;
        debtTokens[TokensPolygon.WMATIC][LenderMappingsPolygon.YLDR] = YldrPolygonAssets.WMATIC_V_TOKEN;

        // approve pools
        address[] memory assets = new address[](5);
        assets[0] = TokensPolygon.USDC;
        assets[1] = TokensPolygon.WBTC;
        assets[2] = TokensPolygon.WETH;
        assets[3] = TokensPolygon.USDT;
        assets[4] = TokensPolygon.WMATIC;

        management.approveAddress(assets, YldrPolygon.POOL);
    }

    function initializeDeltaCompound() internal virtual {
        // approve pools
        address[] memory assets = new address[](5);
        assets[0] = TokensPolygon.USDC;
        assets[1] = TokensPolygon.WBTC;
        assets[2] = TokensPolygon.WETH;
        assets[3] = TokensPolygon.USDT;
        assets[4] = TokensPolygon.WMATIC;

        management.approveAddress(assets, CompoundV3Polygon.COMET_USDC);
        management.approveAddress(assets, CompoundV3Polygon.COMET_USDT);
    }

    function initializeDeltaBase() internal virtual {
        testQuoter = new PoolGetter();
        quoter = new QuoterPolygon();
    }

    function upgradeExistingDelta(address proxy, address admin, address oldModule) internal virtual {
        brokerProxyAddress = proxy;

        brokerProxy = IBrokerProxy(brokerProxyAddress);

        OneDeltaComposerPolygon _aggregator = new OneDeltaComposerPolygon();

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

    function getAssets() internal pure returns (address[] memory assetList) {
        assetList = new address[](5);
        assetList[0] = TokensPolygon.USDC;
        assetList[1] = TokensPolygon.WBTC;
        assetList[2] = TokensPolygon.WETH;
        assetList[4] = TokensPolygon.USDT;
    }

    function setUp() public virtual {
        vm.createSelectFork({blockNumber: 58645304, urlOrAlias: "https://polygon-rpc.com"});
        router = new MockRouter(1.0e18, 12);
        intitializeFullDelta();
        management.setValidSingleTarget(address(router), true);
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

        approveBorrowDelegation(user, borrowAsset, borrowAmount, lenderId);

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

    function getBorrowBalance(address user, address asset, uint16 lenderId) internal view returns (uint256) {
        if (lenderId < LenderMappingsPolygon.MAX_AAVE_V2_ID) {
            return IERC20All(debtTokens[asset][lenderId]).balanceOf(user);
        } else {
            if (lenderId == LenderMappingsPolygon.COMPOUND_V3_USDCE) return IComet(CompoundV3Polygon.COMET_USDC).borrowBalanceOf(user);
            if (lenderId == LenderMappingsPolygon.COMPOUND_V3_USDT) return IComet(CompoundV3Polygon.COMET_USDT).borrowBalanceOf(user);
        }
        return 0;
    }

    function getCollateralBalance(address user, address asset, uint16 lenderId) internal view returns (uint256) {
        if (lenderId < LenderMappingsPolygon.MAX_AAVE_V2_ID) {
            return IERC20All(collateralTokens[asset][lenderId]).balanceOf(user);
        } else {
            if (lenderId == LenderMappingsPolygon.COMPOUND_V3_USDCE) return IComet(CompoundV3Polygon.COMET_USDC).userCollateral(user, asset).balance;
            if (lenderId == LenderMappingsPolygon.COMPOUND_V3_USDT) return IComet(CompoundV3Polygon.COMET_USDT).userCollateral(user, asset).balance;
        }
        return 0;
    }

    function approveWithdrawal(address user, address asset, uint256 amount, uint16 lenderId) internal {
        vm.startPrank(user);
        if (lenderId < LenderMappingsPolygon.MAX_AAVE_V2_ID) {
            IERC20All(collateralTokens[asset][lenderId]).approve(address(brokerProxyAddress), amount);
        } else {
            if (lenderId == LenderMappingsPolygon.COMPOUND_V3_USDCE) IComet(CompoundV3Polygon.COMET_USDC).allow(brokerProxyAddress, true);
            if (lenderId == LenderMappingsPolygon.COMPOUND_V3_USDT) IComet(CompoundV3Polygon.COMET_USDT).allow(brokerProxyAddress, true);
        }
        vm.stopPrank();
    }

    function approveBorrowDelegation(address user, address asset, uint256 amount, uint16 lenderId) internal {
        vm.startPrank(user);
        if (lenderId < LenderMappingsPolygon.MAX_AAVE_V2_ID) {
            IERC20All(debtTokens[asset][lenderId]).approveDelegation(address(brokerProxyAddress), amount);
        } else {
            if (lenderId == LenderMappingsPolygon.COMPOUND_V3_USDCE) IComet(CompoundV3Polygon.COMET_USDC).allow(brokerProxyAddress, true);
            if (lenderId == LenderMappingsPolygon.COMPOUND_V3_USDT) IComet(CompoundV3Polygon.COMET_USDT).allow(brokerProxyAddress, true);
        }
        vm.stopPrank();
    }

    /** HELPER FUNCTIONS */

    /** OPEN */

    function getOpenExactInSingle(address tokenIn, address tokenOut, uint16 lenderId) internal view returns (bytes memory data) {
        uint16 fee = DEX_FEE_LOW;
        uint8 poolId = DexMappingsPolygon.UNI_V3;
        address pool = testQuoter.v3TypePool(tokenIn, tokenOut, fee, poolId);
        (uint8 actionId, , uint8 endId) = getOpenExactInFlags();
        return abi.encodePacked(tokenIn, actionId, poolId, pool, fee, tokenOut, lenderId, endId);
    }

    function getOpenExactInSingle_izi(address tokenIn, address tokenOut, uint16 lenderId) internal view returns (bytes memory data) {
        uint16 fee = uint16(DEX_FEE_LOW_HIGH);
        uint8 poolId = DexMappingsPolygon.IZUMI;
        address pool = testQuoter.getiZiPool(tokenIn, tokenOut, fee);
        (uint8 actionId, , uint8 endId) = getOpenExactInFlags();
        return abi.encodePacked(tokenIn, actionId, poolId, pool, fee, tokenOut, lenderId, endId);
    }

    function getSpotExactInSingle_izi(address tokenIn, address tokenOut) internal view returns (bytes memory data) {
        uint16 fee = uint16(DEX_FEE_LOW_HIGH);
        uint8 poolId = DexMappingsPolygon.IZUMI;
        address pool = testQuoter.getiZiPool(tokenIn, tokenOut, fee);
        return abi.encodePacked(tokenIn, uint8(0), poolId, pool, fee, tokenOut);
    }

    function getSpotExactOutSingle_izi(address tokenIn, address tokenOut) internal view returns (bytes memory data) {
        uint16 fee = uint16(DEX_FEE_LOW_HIGH);
        uint8 poolId = DexMappingsPolygon.IZUMI;
        address pool = testQuoter.getiZiPool(tokenIn, tokenOut, fee);
        return abi.encodePacked(tokenOut, uint8(0), poolId, pool, fee, tokenIn);
    }

    function getOpenExactOutSingle(address tokenIn, address tokenOut, uint16 lenderId) internal view returns (bytes memory data) {
        uint16 fee = DEX_FEE_LOW;
        uint8 poolId = DexMappingsPolygon.UNI_V3;
        address pool = testQuoter.v3TypePool(tokenIn, tokenOut, fee, poolId);
        (uint8 actionId, , uint8 endId) = getOpenExactOutFlags();
        return abi.encodePacked(tokenOut, actionId, poolId, pool, fee, tokenIn, lenderId, endId);
    }

    function getOpenExactInMulti(address tokenIn, address tokenOut, uint16 lenderId) internal view returns (bytes memory data) {
        uint16 fee = DEX_FEE_LOW;
        (uint8 actionId, uint8 midId, uint8 endId) = getOpenExactInFlags();
        uint8 poolId = DexMappingsPolygon.IZUMI;
        address pool = testQuoter.getiZiPool(tokenIn, TokensPolygon.USDT, fee);
        bytes memory firstPart = abi.encodePacked(tokenIn, actionId, poolId, pool, fee, TokensPolygon.USDT);
        fee = uint16(DEX_FEE_STABLES);
        poolId = DexMappingsPolygon.SUSHI_V3;
        pool = testQuoter.v3TypePool(TokensPolygon.USDT, tokenOut, fee, poolId);
        return abi.encodePacked(firstPart, midId, poolId, pool, fee, tokenOut, lenderId, endId);
    }

    function getOpenExactOutMulti(address tokenIn, address tokenOut, uint16 lenderId) internal view returns (bytes memory data) {
        uint16 fee = uint16(DEX_FEE_STABLES);
        (uint8 actionId, uint8 midId, uint8 endId) = getOpenExactOutFlags();
        uint8 poolId = DexMappingsPolygon.SUSHI_V3;
        address pool = testQuoter.v3TypePool(tokenOut, TokensPolygon.USDT, fee, poolId);
        bytes memory firstPart = abi.encodePacked(tokenOut, actionId, poolId, pool, fee, TokensPolygon.USDT);
        fee = DEX_FEE_LOW;
        poolId = DexMappingsPolygon.IZUMI;
        pool = testQuoter.getiZiPool(TokensPolygon.USDT, tokenIn, fee);
        return abi.encodePacked(firstPart, midId, poolId, pool, fee, tokenIn, lenderId, endId);
    }

    /** CLOSE */

    function getCloseExactOutSingle(address tokenIn, address tokenOut, uint16 lenderId) internal view returns (bytes memory data) {
        uint16 fee = DEX_FEE_LOW;
        uint8 poolId = DexMappingsPolygon.UNI_V3;
        address pool = testQuoter.v3TypePool(tokenIn, tokenOut, fee, poolId);
        (uint8 actionId, , uint8 endId) = getCloseExactOutFlags();
        return abi.encodePacked(tokenOut, actionId, poolId, pool, fee, tokenIn, lenderId, endId);
    }

    function getCloseExactInSingle(address tokenIn, address tokenOut, uint16 lenderId) internal view returns (bytes memory data) {
        uint16 fee = DEX_FEE_LOW;
        uint8 poolId = DexMappingsPolygon.UNI_V3;
        address pool = testQuoter.v3TypePool(tokenIn, tokenOut, fee, poolId);
        (uint8 actionId, , uint8 endId) = getCloseExactInFlags();
        return abi.encodePacked(tokenIn, actionId, poolId, pool, fee, tokenOut, lenderId, endId);
    }

    function getCloseExactInMulti(address tokenIn, address tokenOut, uint16 lenderId) internal view returns (bytes memory data) {
        uint16 fee = DEX_FEE_LOW;
        (uint8 actionId, uint8 midId, uint8 endId) = getCloseExactInFlags();
        uint8 poolId = DexMappingsPolygon.IZUMI;
        address pool = testQuoter.getiZiPool(TokensPolygon.USDT, tokenIn, fee);
        bytes memory firstPart = abi.encodePacked(tokenIn, actionId, poolId, pool, fee, TokensPolygon.USDT);
        fee = uint16(DEX_FEE_STABLES);
        poolId = DexMappingsPolygon.SUSHI_V3;
        pool = testQuoter.v3TypePool(TokensPolygon.USDT, tokenOut, fee, poolId);
        return abi.encodePacked(firstPart, midId, poolId, pool, fee, tokenOut, lenderId, endId);
    }

    function getCloseExactOutMulti(address tokenIn, address tokenOut, uint16 lenderId) internal view returns (bytes memory data) {
        uint16 fee = uint16(DEX_FEE_STABLES);
        (uint8 actionId, uint8 midId, uint8 endId) = getCloseExactOutFlags();
        uint8 poolId = DexMappingsPolygon.SUSHI_V3;
        address pool = testQuoter.v3TypePool(TokensPolygon.USDT, tokenOut, fee, poolId);
        bytes memory firstPart = abi.encodePacked(tokenOut, actionId, poolId, pool, fee, TokensPolygon.USDT);
        fee = DEX_FEE_LOW;
        poolId = DexMappingsPolygon.IZUMI;
        pool = testQuoter.getiZiPool(TokensPolygon.USDT, tokenIn, fee);
        return abi.encodePacked(firstPart, midId, poolId, pool, fee, tokenIn, lenderId, endId);
    }

    /** COLLATERAL SWAP */

    function getCollateralSwapExactInSingle(address tokenIn, address tokenOut, uint16 lenderId) internal view returns (bytes memory data) {
        uint16 fee = DEX_FEE_LOW;
        uint8 poolId = DexMappingsPolygon.UNI_V3;
        address pool = testQuoter.v3TypePool(tokenIn, tokenOut, fee, poolId);
        (uint8 actionId, , uint8 endId) = getCollateralSwapExactInFlags();
        return abi.encodePacked(tokenIn, actionId, poolId, pool, fee, tokenOut, lenderId, endId);
    }

    function getCollateralSwapExactOutSingle(address tokenIn, address tokenOut, uint16 lenderId) internal view returns (bytes memory data) {
        uint16 fee = DEX_FEE_LOW;
        uint8 poolId = DexMappingsPolygon.UNI_V3;
        address pool = testQuoter.v3TypePool(tokenIn, tokenOut, fee, poolId);
        (uint8 actionId, , uint8 endId) = getCollateralSwapExactOutFlags();
        return abi.encodePacked(tokenOut, actionId, poolId, pool, fee, tokenIn, lenderId, endId);
    }

    function getCollateralSwapExactInMulti(address tokenIn, address tokenOut, uint16 lenderId) internal view returns (bytes memory data) {
        uint16 fee = DEX_FEE_LOW_MEDIUM;
        (uint8 actionId, uint8 midId, uint8 endId) = getCollateralSwapExactInFlags();
        uint8 poolId = DexMappingsPolygon.UNI_V3;
        address pool = testQuoter.v3TypePool(tokenIn, TokensPolygon.WETH, fee, poolId);
        bytes memory firstPart = abi.encodePacked(tokenIn, actionId, poolId, pool, fee, TokensPolygon.WETH);
        fee = DEX_FEE_LOW;
        poolId = DexMappingsPolygon.SUSHI_V3;
        pool = testQuoter.v3TypePool(tokenOut, TokensPolygon.WETH, fee, poolId);
        return abi.encodePacked(firstPart, midId, poolId, pool, fee, tokenOut, lenderId, endId);
    }

    function getCollateralSwapExactOutMulti(address tokenIn, address tokenOut, uint16 lenderId) internal view returns (bytes memory data) {
        uint16 fee = DEX_FEE_LOW_MEDIUM;
        (uint8 actionId, uint8 midId, uint8 endId) = getCollateralSwapExactOutFlags();
        uint8 poolId = DexMappingsPolygon.UNI_V3;
        address pool = testQuoter.v3TypePool(tokenOut, TokensPolygon.WETH, fee, poolId);
        bytes memory firstPart = abi.encodePacked(tokenOut, actionId, poolId, pool, fee, TokensPolygon.WETH);
        fee = DEX_FEE_LOW;
        poolId = DexMappingsPolygon.SUSHI_V3;
        pool = testQuoter.v3TypePool(tokenIn, TokensPolygon.WETH, fee, poolId);
        return abi.encodePacked(firstPart, midId, poolId, pool, fee, tokenIn, lenderId, endId);
    }

    /** DEBT SWAP */

    function getDebtSwapExactInSingle(address tokenIn, address tokenOut, uint16 lenderId) internal view returns (bytes memory data) {
        uint16 fee = DEX_FEE_LOW_MEDIUM;
        uint8 poolId = DexMappingsPolygon.UNI_V3;
        address pool = testQuoter.v3TypePool(tokenOut, tokenIn, fee, poolId);
        (uint8 actionId, , uint8 endId) = getDebtSwapExactInFlags();
        return abi.encodePacked(tokenIn, actionId, poolId, pool, fee, tokenOut, lenderId, endId);
    }

    function getDebtSwapExactOutSingle(address tokenIn, address tokenOut, uint16 lenderId) internal view returns (bytes memory data) {
        uint16 fee = DEX_FEE_LOW_MEDIUM;
        uint8 poolId = DexMappingsPolygon.UNI_V3;
        address pool = testQuoter.v3TypePool(tokenOut, tokenIn, fee, poolId);
        (uint8 actionId, , uint8 endId) = getDebtSwapExactOutFlags();
        return abi.encodePacked(tokenOut, actionId, poolId, pool, fee, tokenIn, lenderId, endId);
    }

    function getDebtSwapExactInMulti(address tokenIn, address tokenOut, uint16 lenderId) internal view returns (bytes memory data) {
        uint16 fee = DEX_FEE_LOW;
        (uint8 actionId, uint8 midId, uint8 endId) = getDebtSwapExactInFlags();
        uint8 poolId = DexMappingsPolygon.RETRO;
        address pool = testQuoter.v3TypePool(tokenIn, TokensPolygon.USDT, fee, poolId);
        bytes memory firstPart = abi.encodePacked(tokenIn, actionId, poolId, pool, fee, TokensPolygon.USDT);
        fee = DEX_FEE_LOW;
        poolId = DexMappingsPolygon.RETRO;
        pool = testQuoter.v3TypePool(tokenOut, TokensPolygon.USDT, fee, poolId);
        return abi.encodePacked(firstPart, midId, poolId, pool, fee, tokenOut, lenderId, endId);
    }

    function getDebtSwapExactOutMulti(address tokenIn, address tokenOut, uint16 lenderId) internal view returns (bytes memory data) {
        uint16 fee = DEX_FEE_LOW;
        (uint8 actionId, uint8 midId, uint8 endId) = getDebtSwapExactOutFlags();
        uint8 poolId = DexMappingsPolygon.RETRO;
        address pool = testQuoter.v3TypePool(tokenOut, TokensPolygon.USDT, fee, poolId);
        bytes memory firstPart = abi.encodePacked(tokenOut, actionId, poolId, pool, fee, TokensPolygon.USDT);
        fee = DEX_FEE_LOW;
        poolId = DexMappingsPolygon.RETRO;
        pool = testQuoter.v3TypePool(tokenIn, TokensPolygon.USDT, fee, poolId);
        return abi.encodePacked(firstPart, midId, poolId, pool, fee, tokenIn, lenderId, endId);
    }

    /** OPEN */

    function getOpenExactInSingleV2(address tokenIn, address tokenOut, uint16 lenderId) internal view returns (bytes memory data) {
        uint8 poolId = DexMappingsPolygon.QUICK_V2;
        (uint8 actionId, , uint8 endId) = getOpenExactInFlags();
        address pool = testQuoter.v2TypePairAddress(tokenIn, tokenOut, poolId);
        return abi.encodePacked(tokenIn, actionId, poolId, pool, tokenOut, lenderId, endId);
    }

    function getOpenExactOutSingleV2(address tokenIn, address tokenOut, uint16 lenderId) internal view returns (bytes memory data) {
        uint8 poolId = DexMappingsPolygon.QUICK_V2;
        (uint8 actionId, , uint8 endId) = getOpenExactOutFlags();
        address pool = testQuoter.v2TypePairAddress(tokenIn, tokenOut, poolId);
        return abi.encodePacked(tokenOut, actionId, poolId, pool, tokenIn, lenderId, endId);
    }

    function getOpenExactInMultiV2(address tokenIn, address tokenOut, uint16 lenderId) internal view returns (bytes memory data) {
        (uint8 actionId, uint8 midId, uint8 endId) = getOpenExactInFlags();
        uint8 poolId = DexMappingsPolygon.QUICK_V2;
        address pool = testQuoter.v2TypePairAddress(tokenIn, TokensPolygon.USDT, poolId);
        bytes memory firstPart = abi.encodePacked(tokenIn, actionId, poolId, pool, TokensPolygon.USDT);
        poolId = DexMappingsPolygon.QUICK_V2;
        pool = testQuoter.v2TypePairAddress(TokensPolygon.USDT, tokenOut, poolId);
        return abi.encodePacked(firstPart, midId, poolId, pool, tokenOut, lenderId, endId);
    }

    function getOpenExactOutMultiV2(address tokenIn, address tokenOut, uint16 lenderId) internal view returns (bytes memory data) {
        (uint8 actionId, uint8 midId, uint8 endId) = getOpenExactOutFlags();
        uint8 poolId = DexMappingsPolygon.QUICK_V2;
        address pool = testQuoter.v2TypePairAddress(TokensPolygon.USDT, tokenOut, poolId);
        bytes memory firstPart = abi.encodePacked(tokenOut, actionId, poolId, pool, TokensPolygon.USDT);
        pool = testQuoter.v2TypePairAddress(tokenIn, TokensPolygon.USDT, poolId);
        return abi.encodePacked(firstPart, midId, poolId, pool, tokenIn, lenderId, endId);
    }

    /** CLOSE */

    function getCloseExactOutSingleV2(address tokenIn, address tokenOut, uint16 lenderId) internal view returns (bytes memory data) {
        uint8 poolId = DexMappingsPolygon.QUICK_V2;
        address pool = testQuoter.v2TypePairAddress(tokenIn, tokenOut, poolId);
        (uint8 actionId, , uint8 endId) = getCloseExactOutFlags();
        return abi.encodePacked(tokenOut, actionId, poolId, pool, tokenIn, lenderId, endId);
    }

    function getCloseExactInSingleV2(address tokenIn, address tokenOut, uint16 lenderId) internal view returns (bytes memory data) {
        uint8 poolId = DexMappingsPolygon.QUICK_V2;
        address pool = testQuoter.v2TypePairAddress(tokenIn, tokenOut, poolId);
        (uint8 actionId, , uint8 endId) = getCloseExactInFlags();
        return abi.encodePacked(tokenIn, actionId, poolId, pool, tokenOut, lenderId, endId);
    }

    function getCloseExactInMultiV2(address tokenIn, address tokenOut, uint16 lenderId) internal view returns (bytes memory data) {
        (uint8 actionId, uint8 midId, uint8 endId) = getCloseExactInFlags();
        uint8 poolId = DexMappingsPolygon.QUICK_V2;
        address pool = testQuoter.v2TypePairAddress(tokenIn, TokensPolygon.USDT, poolId);
        bytes memory firstPart = abi.encodePacked(tokenIn, actionId, poolId, pool, TokensPolygon.USDT);
        poolId = DexMappingsPolygon.QUICK_V2;
        pool = testQuoter.v2TypePairAddress(tokenOut, TokensPolygon.USDT, poolId);
        return abi.encodePacked(firstPart, midId, poolId, pool, tokenOut, lenderId, endId);
    }

    function getCloseExactOutMultiV2(address tokenIn, address tokenOut, uint16 lenderId) internal view returns (bytes memory data) {
        (uint8 actionId, uint8 midId, uint8 endId) = getCloseExactOutFlags();
        uint8 poolId = DexMappingsPolygon.QUICK_V2;
        address pool = testQuoter.v2TypePairAddress(tokenOut, TokensPolygon.USDT, poolId);
        bytes memory firstPart = abi.encodePacked(tokenOut, actionId, poolId, pool, TokensPolygon.USDT);
        poolId = DexMappingsPolygon.QUICK_V2;
        pool = testQuoter.v2TypePairAddress(tokenIn, TokensPolygon.USDT, poolId);
        return abi.encodePacked(firstPart, midId, poolId, pool, tokenIn, lenderId, endId);
    }

    /** COLLATERAL SWAP */

    function getCollateralSwapExactInSingleV2(address tokenIn, address tokenOut, uint16 lenderId) internal view returns (bytes memory data) {
        uint8 poolId = DexMappingsPolygon.QUICK_V2;
        address pool = testQuoter.v2TypePairAddress(tokenIn, tokenOut, poolId);
        (uint8 actionId, , uint8 endId) = getCollateralSwapExactInFlags();
        return abi.encodePacked(tokenIn, actionId, poolId, pool, tokenOut, lenderId, endId);
    }

    function getCollateralSwapExactOutSingleV2(address tokenIn, address tokenOut, uint16 lenderId) internal view returns (bytes memory data) {
        uint8 poolId = DexMappingsPolygon.QUICK_V2;
        address pool = testQuoter.v2TypePairAddress(tokenIn, tokenOut, poolId);
        (uint8 actionId, , uint8 endId) = getCollateralSwapExactOutFlags();
        return abi.encodePacked(tokenOut, actionId, poolId, pool, tokenIn, lenderId, endId);
    }

    function getCollateralSwapExactInMultiV2(address tokenIn, address tokenOut, uint16 lenderId) internal view returns (bytes memory data) {
        (uint8 actionId, uint8 midId, uint8 endId) = getCollateralSwapExactInFlags();
        uint8 poolId = DexMappingsPolygon.QUICK_V2;
        address pool = testQuoter.v2TypePairAddress(tokenIn, TokensPolygon.WETH, poolId);
        bytes memory firstPart = abi.encodePacked(tokenIn, actionId, poolId, pool, TokensPolygon.WETH);
        poolId = DexMappingsPolygon.QUICK_V2;
        pool = testQuoter.v2TypePairAddress(tokenOut, TokensPolygon.WETH, poolId);
        return abi.encodePacked(firstPart, midId, poolId, pool, tokenOut, lenderId, endId);
    }

    function getCollateralSwapExactOutMultiV2(address tokenIn, address tokenOut, uint16 lenderId) internal view returns (bytes memory data) {
        (uint8 actionId, uint8 midId, uint8 endId) = getCollateralSwapExactOutFlags();
        uint8 poolId = DexMappingsPolygon.QUICK_V2;
        address pool = testQuoter.v2TypePairAddress(tokenOut, TokensPolygon.WETH, poolId);
        bytes memory firstPart = abi.encodePacked(tokenOut, actionId, poolId, pool, TokensPolygon.WETH);
        poolId = DexMappingsPolygon.QUICK_V2;
        pool = testQuoter.v2TypePairAddress(tokenIn, TokensPolygon.WETH, poolId);
        return abi.encodePacked(firstPart, midId, poolId, pool, tokenIn, lenderId, endId);
    }

    /** DEBT SWAP */

    function getDebtSwapExactInSingleV2(address tokenIn, address tokenOut, uint16 lenderId) internal view returns (bytes memory data) {
        uint8 poolId = DexMappingsPolygon.QUICK_V2;
        address pool = testQuoter.v2TypePairAddress(tokenIn, tokenOut, poolId);
        (uint8 actionId, , uint8 endId) = getDebtSwapExactInFlags();
        return abi.encodePacked(tokenIn, actionId, poolId, pool, tokenOut, lenderId, endId);
    }

    function getDebtSwapExactOutSingleV2(address tokenIn, address tokenOut, uint16 lenderId) internal view returns (bytes memory data) {
        uint8 poolId = DexMappingsPolygon.QUICK_V2;
        address pool = testQuoter.v2TypePairAddress(tokenIn, tokenOut, poolId);
        (uint8 actionId, , uint8 endId) = getDebtSwapExactOutFlags();
        return abi.encodePacked(tokenOut, actionId, poolId, pool, tokenIn, lenderId, endId);
    }

    function getDebtSwapExactInMultiV2(address tokenIn, address tokenOut, uint16 lenderId) internal view returns (bytes memory data) {
        (uint8 actionId, uint8 midId, uint8 endId) = getDebtSwapExactInFlags();
        uint8 poolId = DexMappingsPolygon.QUICK_V2;
        address pool = testQuoter.v2TypePairAddress(tokenIn, TokensPolygon.WETH, poolId);
        bytes memory firstPart = abi.encodePacked(tokenIn, actionId, poolId, pool, TokensPolygon.WETH);
        poolId = DexMappingsPolygon.QUICK_V2;
        pool = testQuoter.v2TypePairAddress(tokenOut, TokensPolygon.WETH, poolId);
        return abi.encodePacked(firstPart, midId, poolId, pool, tokenOut, lenderId, endId);
    }

    function getDebtSwapExactOutMultiV2(address tokenIn, address tokenOut, uint16 lenderId) internal view returns (bytes memory data) {
        (uint8 actionId, uint8 midId, uint8 endId) = getDebtSwapExactOutFlags();
        uint8 poolId = DexMappingsPolygon.QUICK_V2;
        address pool = testQuoter.v2TypePairAddress(tokenOut, TokensPolygon.WETH, poolId);
        bytes memory firstPart = abi.encodePacked(tokenOut, actionId, poolId, pool, TokensPolygon.WETH);
        poolId = DexMappingsPolygon.QUICK_V2;
        pool = testQuoter.v2TypePairAddress(tokenIn, TokensPolygon.WETH, poolId);
        return abi.encodePacked(firstPart, midId, poolId, pool, tokenIn, lenderId, endId);
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

    function compoundUSDCEOrAave(uint16 lenderId) internal pure returns (bool a) {
        return
            lenderId == LenderMappingsPolygon.YLDR ||
            lenderId == LenderMappingsPolygon.AAVE_V3 ||
            lenderId == LenderMappingsPolygon.COMPOUND_V3_USDCE;
    }
}
