// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {AddressesMantle, IFactoryFeeGetter} from "./utils/CommonAddresses.f.sol";
import {QuoterMantle} from "../../contracts/1delta/quoter/Mantle.sol";
import {PoolGetter} from "../../contracts/1delta/quoter/poolGetter/Mantle.sol";
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

// lenders
import {LendleMantleAssets, LendleMantle} from "./utils/lender/lendleAddresses.sol";
import {AureliusMantleAssets, AureliusMantle} from "./utils/lender/aureliusAddresses.sol";

// mappings
import {TokensMantle} from "./utils/tokens.sol";
import {DexMappingsMantle} from "./utils/DexMappings.sol";
import {LenderMappingsMantle} from "./utils/LenderMappings.sol";
import {FlashMappingsMantle} from "./utils/FlashMappings.sol";

// proxy and management
import {ConfigModule} from "../../contracts/1delta/proxy/modules/ConfigModule.sol";
import {DeltaBrokerProxyGen2} from "../../contracts/1delta/proxy/DeltaBrokerGen2.sol";

// initializer

// core modules
import {ManagementModule} from "../../contracts/1delta/modules/shared/storage/ManagementModule.sol";
import {OneDeltaComposerMantle} from "../../contracts/1delta/modules/mantle/Composer.sol";

// forge
import {Script, console2} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {Test} from "forge-std/Test.sol";

contract DeltaSetup is AddressesMantle, ComposerUtils, Script, Test {
    address internal brokerProxyAddress;
    IBrokerProxy internal brokerProxy;
    IModuleConfig internal deltaConfig;
    IManagement internal management;
    PoolGetter testQuoter;
    QuoterMantle quoter;
    OneDeltaComposerMantle internal aggregator;

    mapping(address => mapping(uint16 => address)) internal collateralTokens;
    mapping(address => mapping(uint16 => address)) internal debtTokens;

    /** SELECTOR GETTERS */

    function managementSelectors() internal pure returns (bytes4[] memory selectors) {
        selectors = new bytes4[](14);
        // setters
        selectors[0] = IManagement.getLendingPool.selector;
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
        selectors[12] = IManagement.addLendingPool.selector;
        selectors[13] = IManagement.setValidSingleTarget.selector;
        return selectors;
    }

    function initializeSelectors() internal pure returns (bytes4[] memory selectors) {
        selectors = new bytes4[](1);
        selectors[0] = IInitialize.initMarginTrader.selector;
        return selectors;
    }

    function flashAggregatorSelectors() internal pure returns (bytes4[] memory selectors) {
        selectors = new bytes4[](24);
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
        selectors[23] = IFlashAggregator.bitCall.selector;
        return selectors;
    }

    /** DEPLOY PROZY AND MODULES */

    function deployDelta() internal virtual {
        ConfigModule _config = new ConfigModule();
        brokerProxyAddress = address(new DeltaBrokerProxyGen2(address(this), address(_config)));

        brokerProxy = IBrokerProxy(brokerProxyAddress);

        ManagementModule _management = new ManagementModule();
        OneDeltaComposerMantle _aggregator = new OneDeltaComposerMantle();

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

        OneDeltaComposerMantle _aggregator = new OneDeltaComposerMantle();

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
        quoter = new QuoterMantle();
    }

    function initializeDeltaLendle() internal virtual {
        // lendle
        management.addGeneralLenderTokens(
            TokensMantle.USDC,
            LendleMantleAssets.USDC_A_TOKEN,
            LendleMantleAssets.USDC_V_TOKEN,
            LendleMantleAssets.USDC_S_TOKEN,
            LenderMappingsMantle.LENDLE_ID
        );
        management.addGeneralLenderTokens(
            TokensMantle.USDT,
            LendleMantleAssets.USDT_A_TOKEN,
            LendleMantleAssets.USDT_V_TOKEN,
            LendleMantleAssets.USDT_S_TOKEN,
            LenderMappingsMantle.LENDLE_ID
        );
        management.addGeneralLenderTokens(
            TokensMantle.WBTC,
            LendleMantleAssets.WBTC_A_TOKEN,
            LendleMantleAssets.WBTC_V_TOKEN,
            LendleMantleAssets.WBTC_S_TOKEN,
            LenderMappingsMantle.LENDLE_ID
        );
        management.addGeneralLenderTokens(
            TokensMantle.WETH,
            LendleMantleAssets.WETH_A_TOKEN,
            LendleMantleAssets.WETH_V_TOKEN,
            LendleMantleAssets.WETH_S_TOKEN,
            LenderMappingsMantle.LENDLE_ID
        );
        management.addGeneralLenderTokens(
            TokensMantle.WMNT,
            LendleMantleAssets.WMNT_A_TOKEN,
            LendleMantleAssets.WMNT_V_TOKEN,
            LendleMantleAssets.WMNT_S_TOKEN,
            LenderMappingsMantle.LENDLE_ID
        );

        collateralTokens[TokensMantle.USDC][LenderMappingsMantle.LENDLE_ID] = LendleMantleAssets.USDC_A_TOKEN;
        collateralTokens[TokensMantle.USDT][LenderMappingsMantle.LENDLE_ID] = LendleMantleAssets.USDT_A_TOKEN;
        collateralTokens[TokensMantle.WBTC][LenderMappingsMantle.LENDLE_ID] = LendleMantleAssets.WBTC_A_TOKEN;
        collateralTokens[TokensMantle.WETH][LenderMappingsMantle.LENDLE_ID] = LendleMantleAssets.WETH_A_TOKEN;
        collateralTokens[TokensMantle.WMNT][LenderMappingsMantle.LENDLE_ID] = LendleMantleAssets.WMNT_A_TOKEN;

        debtTokens[TokensMantle.USDC][LenderMappingsMantle.LENDLE_ID] = LendleMantleAssets.USDC_V_TOKEN;
        debtTokens[TokensMantle.USDT][LenderMappingsMantle.LENDLE_ID] = LendleMantleAssets.USDT_V_TOKEN;
        debtTokens[TokensMantle.WBTC][LenderMappingsMantle.LENDLE_ID] = LendleMantleAssets.WBTC_V_TOKEN;
        debtTokens[TokensMantle.WETH][LenderMappingsMantle.LENDLE_ID] = LendleMantleAssets.WETH_V_TOKEN;
        debtTokens[TokensMantle.WMNT][LenderMappingsMantle.LENDLE_ID] = LendleMantleAssets.WMNT_V_TOKEN;

        // approve pools
        address[] memory assets = new address[](5);
        assets[0] = TokensMantle.USDC;
        assets[1] = TokensMantle.WBTC;
        assets[2] = TokensMantle.WETH;
        assets[3] = TokensMantle.WMNT;
        assets[4] = TokensMantle.USDT;
        management.approveAddress(assets, LendleMantle.POOL);
    }

    function initializeDeltaAurelius() internal virtual {
        // aurelius
        management.addGeneralLenderTokens(
            TokensMantle.USDC,
            AureliusMantleAssets.USDC_A_TOKEN,
            AureliusMantleAssets.USDC_V_TOKEN,
            AureliusMantleAssets.USDC_S_TOKEN,
            LenderMappingsMantle.AURELIUS_ID
        );
        management.addGeneralLenderTokens(
            TokensMantle.USDT,
            AureliusMantleAssets.USDT_A_TOKEN,
            AureliusMantleAssets.USDT_V_TOKEN,
            AureliusMantleAssets.USDT_S_TOKEN,
            LenderMappingsMantle.AURELIUS_ID
        );
        management.addGeneralLenderTokens(
            TokensMantle.WBTC,
            AureliusMantleAssets.WBTC_A_TOKEN,
            AureliusMantleAssets.WBTC_V_TOKEN,
            AureliusMantleAssets.WBTC_S_TOKEN,
            LenderMappingsMantle.AURELIUS_ID
        );
        management.addGeneralLenderTokens(
            TokensMantle.WETH,
            AureliusMantleAssets.WETH_A_TOKEN,
            AureliusMantleAssets.WETH_V_TOKEN,
            AureliusMantleAssets.WETH_S_TOKEN,
            LenderMappingsMantle.AURELIUS_ID
        );
        management.addGeneralLenderTokens(
            TokensMantle.WMNT,
            AureliusMantleAssets.WMNT_A_TOKEN,
            AureliusMantleAssets.WMNT_V_TOKEN,
            AureliusMantleAssets.WMNT_S_TOKEN,
            LenderMappingsMantle.AURELIUS_ID
        );

        collateralTokens[TokensMantle.USDC][LenderMappingsMantle.AURELIUS_ID] = AureliusMantleAssets.USDC_A_TOKEN;
        collateralTokens[TokensMantle.USDT][LenderMappingsMantle.AURELIUS_ID] = AureliusMantleAssets.USDT_A_TOKEN;
        collateralTokens[TokensMantle.WBTC][LenderMappingsMantle.AURELIUS_ID] = AureliusMantleAssets.WBTC_A_TOKEN;
        collateralTokens[TokensMantle.WETH][LenderMappingsMantle.AURELIUS_ID] = AureliusMantleAssets.WETH_A_TOKEN;
        collateralTokens[TokensMantle.WMNT][LenderMappingsMantle.AURELIUS_ID] = AureliusMantleAssets.WMNT_A_TOKEN;

        debtTokens[TokensMantle.USDC][LenderMappingsMantle.AURELIUS_ID] = AureliusMantleAssets.USDC_V_TOKEN;
        debtTokens[TokensMantle.USDT][LenderMappingsMantle.AURELIUS_ID] = AureliusMantleAssets.USDT_V_TOKEN;
        debtTokens[TokensMantle.WBTC][LenderMappingsMantle.AURELIUS_ID] = AureliusMantleAssets.WBTC_V_TOKEN;
        debtTokens[TokensMantle.WETH][LenderMappingsMantle.AURELIUS_ID] = AureliusMantleAssets.WETH_V_TOKEN;
        debtTokens[TokensMantle.WMNT][LenderMappingsMantle.AURELIUS_ID] = AureliusMantleAssets.WMNT_V_TOKEN;

        // approve pools
        address[] memory assets = new address[](5);
        assets[0] = TokensMantle.USDC;
        assets[1] = TokensMantle.WBTC;
        assets[2] = TokensMantle.WETH;
        assets[3] = TokensMantle.WMNT;
        assets[4] = TokensMantle.USDT;
        management.approveAddress(assets, AureliusMantle.POOL);

        address[] memory usdyAssets = new address[](1);
        usdyAssets[0] = TokensMantle.USDY;
        management.approveAddress(usdyAssets, TokensMantle.mUSD);
    }

    function getAssets() internal pure returns (address[] memory assetList) {
        assetList = new address[](5);
        assetList[0] = TokensMantle.USDC;
        assetList[1] = TokensMantle.WBTC;
        assetList[2] = TokensMantle.WETH;
        assetList[3] = TokensMantle.WMNT;
        assetList[4] = TokensMantle.USDT;
    }

    function setUp() public virtual {
        vm.createSelectFork({blockNumber: 62219594, urlOrAlias: "https://mantle-mainnet.public.blastapi.io"});

        intitializeFullDelta();
    }

    function intitializeFullDelta() internal virtual {
        deployDelta();
        initializeDeltaLendle();
        initializeDeltaAurelius();
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
        uint8 poolId = DexMappingsMantle.AGNI;
        address pool = testQuoter.v3TypePool(tokenIn, tokenOut, fee, poolId);
        (uint8 actionId, , uint8 endId) = getOpenExactInFlags();
        return abi.encodePacked(tokenIn, actionId, poolId, pool, fee, tokenOut, lenderId, endId);
    }

    function getOpenExactInSingle_izi(address tokenIn, address tokenOut, uint16 lenderId) internal view returns (bytes memory data) {
        uint16 fee = uint16(DEX_FEE_LOW_HIGH);
        uint8 poolId = DexMappingsMantle.IZUMI;
        address pool = testQuoter.getiZiPool(tokenIn, tokenOut, fee);
        (uint8 actionId, , uint8 endId) = getOpenExactInFlags();
        return abi.encodePacked(tokenIn, actionId, poolId, pool, fee, tokenOut, lenderId, endId);
    }

    function getSpotExactInSingle_izi(address tokenIn, address tokenOut) internal view returns (bytes memory data) {
        uint16 fee = uint16(DEX_FEE_LOW_HIGH);
        uint8 poolId = DexMappingsMantle.IZUMI;
        address pool = testQuoter.getiZiPool(tokenIn, tokenOut, fee);
        return abi.encodePacked(tokenIn, uint8(0), poolId, pool, fee, tokenOut);
    }

    function getSpotExactOutSingle_izi(address tokenIn, address tokenOut) internal view returns (bytes memory data) {
        uint16 fee = uint16(DEX_FEE_LOW_HIGH);
        uint8 poolId = DexMappingsMantle.IZUMI;
        address pool = testQuoter.getiZiPool(tokenIn, tokenOut, fee);
        return abi.encodePacked(tokenOut, uint8(0), poolId, pool, fee, tokenIn);
    }

    function getOpenExactOutSingle(address tokenIn, address tokenOut, uint16 lenderId) internal view returns (bytes memory data) {
        uint16 fee = DEX_FEE_LOW;
        uint8 poolId = DexMappingsMantle.AGNI;
        address pool = testQuoter.v3TypePool(tokenIn, tokenOut, fee, poolId);
        (uint8 actionId, , uint8 endId) = getOpenExactOutFlags();
        return abi.encodePacked(tokenOut, actionId, poolId, pool, fee, tokenIn, lenderId, endId);
    }

    function getOpenExactInMulti(address tokenIn, address tokenOut, uint16 lenderId) internal view returns (bytes memory data) {
        uint16 fee = DEX_FEE_LOW;
        (uint8 actionId, uint8 midId, uint8 endId) = getOpenExactInFlags();
        uint8 poolId = DexMappingsMantle.IZUMI;
        address pool = testQuoter.getiZiPool(tokenIn, TokensMantle.USDT, fee);
        bytes memory firstPart = abi.encodePacked(tokenIn, actionId, poolId, pool, fee, TokensMantle.USDT);
        fee = DEX_FEE_STABLES;
        poolId = DexMappingsMantle.FUSION_X;
        pool = testQuoter.v3TypePool(TokensMantle.USDT, tokenOut, fee, poolId);
        return abi.encodePacked(firstPart, midId, poolId, pool, fee, tokenOut, lenderId, endId);
    }

    function getOpenExactOutMulti(address tokenIn, address tokenOut, uint16 lenderId) internal view returns (bytes memory data) {
        uint16 fee = DEX_FEE_STABLES;
        (uint8 actionId, uint8 midId, uint8 endId) = getOpenExactOutFlags();
        uint8 poolId = DexMappingsMantle.FUSION_X;
        address pool = testQuoter.v3TypePool(tokenOut, TokensMantle.USDT, fee, poolId);
        bytes memory firstPart = abi.encodePacked(tokenOut, actionId, poolId, pool, fee, TokensMantle.USDT);
        fee = DEX_FEE_LOW;
        poolId = DexMappingsMantle.IZUMI;
        pool = testQuoter.getiZiPool(TokensMantle.USDT, tokenIn, fee);
        return abi.encodePacked(firstPart, midId, poolId, pool, fee, tokenIn, lenderId, endId);
    }

    /** CLOSE */

    function getCloseExactOutSingle(address tokenIn, address tokenOut, uint16 lenderId) internal view returns (bytes memory data) {
        uint16 fee = DEX_FEE_LOW;
        uint8 poolId = DexMappingsMantle.AGNI;
        address pool = testQuoter.v3TypePool(tokenIn, tokenOut, fee, poolId);
        (uint8 actionId, , uint8 endId) = getCloseExactOutFlags();
        return abi.encodePacked(tokenOut, actionId, poolId, pool, fee, tokenIn, lenderId, endId);
    }

    function getCloseExactInSingle(address tokenIn, address tokenOut, uint16 lenderId) internal view returns (bytes memory data) {
        uint16 fee = DEX_FEE_LOW;
        uint8 poolId = DexMappingsMantle.AGNI;
        address pool = testQuoter.v3TypePool(tokenIn, tokenOut, fee, poolId);
        (uint8 actionId, , uint8 endId) = getCloseExactInFlags();
        return abi.encodePacked(tokenIn, actionId, poolId, pool, fee, tokenOut, lenderId, endId);
    }

    function getCloseExactInMulti(address tokenIn, address tokenOut, uint16 lenderId) internal view returns (bytes memory data) {
        uint16 fee = DEX_FEE_LOW;
        (uint8 actionId, uint8 midId, uint8 endId) = getCloseExactInFlags();
        uint8 poolId = DexMappingsMantle.IZUMI;
        address pool = testQuoter.getiZiPool(TokensMantle.USDT, tokenIn, fee);
        bytes memory firstPart = abi.encodePacked(tokenIn, actionId, poolId, pool, fee, TokensMantle.USDT);
        fee = DEX_FEE_STABLES;
        poolId = DexMappingsMantle.FUSION_X;
        pool = testQuoter.v3TypePool(TokensMantle.USDT, tokenOut, fee, poolId);
        return abi.encodePacked(firstPart, midId, poolId, pool, fee, tokenOut, lenderId, endId);
    }

    function getCloseExactOutMulti(address tokenIn, address tokenOut, uint16 lenderId) internal view returns (bytes memory data) {
        uint16 fee = DEX_FEE_STABLES;
        (uint8 actionId, uint8 midId, uint8 endId) = getCloseExactOutFlags();
        uint8 poolId = DexMappingsMantle.FUSION_X;
        address pool = testQuoter.v3TypePool(TokensMantle.USDT, tokenOut, fee, poolId);
        bytes memory firstPart = abi.encodePacked(tokenOut, actionId, poolId, pool, fee, TokensMantle.USDT);
        fee = DEX_FEE_LOW;
        poolId = DexMappingsMantle.IZUMI;
        pool = testQuoter.getiZiPool(TokensMantle.USDT, tokenIn, fee);
        return abi.encodePacked(firstPart, midId, poolId, pool, fee, tokenIn, lenderId, endId);
    }

    /** COLLATERAL SWAP */

    function getCollateralSwapExactInSingle(address tokenIn, address tokenOut, uint16 lenderId) internal view returns (bytes memory data) {
        uint16 fee = DEX_FEE_LOW;
        uint8 poolId = DexMappingsMantle.AGNI;
        address pool = testQuoter.v3TypePool(tokenIn, tokenOut, fee, poolId);
        (uint8 actionId, , uint8 endId) = getCollateralSwapExactInFlags();
        return abi.encodePacked(tokenIn, actionId, poolId, pool, fee, tokenOut, lenderId, endId);
    }

    function getCollateralSwapExactOutSingle(address tokenIn, address tokenOut, uint16 lenderId) internal view returns (bytes memory data) {
        uint16 fee = DEX_FEE_LOW;
        uint8 poolId = DexMappingsMantle.AGNI;
        address pool = testQuoter.v3TypePool(tokenIn, tokenOut, fee, poolId);
        (uint8 actionId, , uint8 endId) = getCollateralSwapExactOutFlags();
        return abi.encodePacked(tokenOut, actionId, poolId, pool, fee, tokenIn, lenderId, endId);
    }

    function getCollateralSwapExactInMulti(address tokenIn, address tokenOut, uint16 lenderId) internal view returns (bytes memory data) {
        uint16 fee = DEX_FEE_LOW_MEDIUM;
        (uint8 actionId, uint8 midId, uint8 endId) = getCollateralSwapExactInFlags();
        uint8 poolId = DexMappingsMantle.AGNI;
        address pool = testQuoter.v3TypePool(tokenIn, TokensMantle.WETH, fee, poolId);
        bytes memory firstPart = abi.encodePacked(tokenIn, actionId, poolId, pool, fee, TokensMantle.WETH);
        fee = DEX_FEE_LOW;
        poolId = DexMappingsMantle.FUSION_X;
        pool = testQuoter.v3TypePool(tokenOut, TokensMantle.WETH, fee, poolId);
        return abi.encodePacked(firstPart, midId, poolId, pool, fee, tokenOut, lenderId, endId);
    }

    function getCollateralSwapExactOutMulti(address tokenIn, address tokenOut, uint16 lenderId) internal view returns (bytes memory data) {
        uint16 fee = DEX_FEE_LOW_MEDIUM;
        (uint8 actionId, uint8 midId, uint8 endId) = getCollateralSwapExactOutFlags();
        uint8 poolId = DexMappingsMantle.AGNI;
        address pool = testQuoter.v3TypePool(tokenOut, TokensMantle.WETH, fee, poolId);
        bytes memory firstPart = abi.encodePacked(tokenOut, actionId, poolId, pool, fee, TokensMantle.WETH);
        fee = DEX_FEE_LOW;
        poolId = DexMappingsMantle.FUSION_X;
        pool = testQuoter.v3TypePool(tokenIn, TokensMantle.WETH, fee, poolId);
        return abi.encodePacked(firstPart, midId, poolId, pool, fee, tokenIn, lenderId, endId);
    }

    /** DEBT SWAP */

    function getDebtSwapExactInSingle(address tokenIn, address tokenOut, uint16 lenderId) internal view returns (bytes memory data) {
        uint16 fee = DEX_FEE_LOW_MEDIUM;
        uint8 poolId = DexMappingsMantle.AGNI;
        address pool = testQuoter.v3TypePool(tokenOut, tokenIn, fee, poolId);
        (uint8 actionId, , uint8 endId) = getDebtSwapExactInFlags();
        return abi.encodePacked(tokenIn, actionId, poolId, pool, fee, tokenOut, lenderId, endId);
    }

    function getDebtSwapExactOutSingle(address tokenIn, address tokenOut, uint16 lenderId) internal view returns (bytes memory data) {
        uint16 fee = DEX_FEE_LOW_MEDIUM;
        uint8 poolId = DexMappingsMantle.AGNI;
        address pool = testQuoter.v3TypePool(tokenOut, tokenIn, fee, poolId);
        (uint8 actionId, , uint8 endId) = getDebtSwapExactOutFlags();
        return abi.encodePacked(tokenOut, actionId, poolId, pool, fee, tokenIn, lenderId, endId);
    }

    function getDebtSwapExactInMulti(address tokenIn, address tokenOut, uint16 lenderId) internal view returns (bytes memory data) {
        uint16 fee = DEX_FEE_LOW;
        (uint8 actionId, uint8 midId, uint8 endId) = getDebtSwapExactInFlags();
        uint8 poolId = DexMappingsMantle.BUTTER;
        address pool = testQuoter.v3TypePool(tokenIn, TokensMantle.USDT, fee, poolId);
        bytes memory firstPart = abi.encodePacked(tokenIn, actionId, poolId, pool, fee, TokensMantle.USDT);
        fee = DEX_FEE_LOW;
        poolId = DexMappingsMantle.BUTTER;
        pool = testQuoter.v3TypePool(tokenOut, TokensMantle.USDT, fee, poolId);
        return abi.encodePacked(firstPart, midId, poolId, pool, fee, tokenOut, lenderId, endId);
    }

    function getDebtSwapExactOutMulti(address tokenIn, address tokenOut, uint16 lenderId) internal view returns (bytes memory data) {
        uint16 fee = DEX_FEE_LOW;
        (uint8 actionId, uint8 midId, uint8 endId) = getDebtSwapExactOutFlags();
        uint8 poolId = DexMappingsMantle.BUTTER;
        address pool = testQuoter.v3TypePool(tokenOut, TokensMantle.USDT, fee, poolId);
        bytes memory firstPart = abi.encodePacked(tokenOut, actionId, poolId, pool, fee, TokensMantle.USDT);
        fee = DEX_FEE_LOW;
        poolId = DexMappingsMantle.BUTTER;
        pool = testQuoter.v3TypePool(tokenIn, TokensMantle.USDT, fee, poolId);
        return abi.encodePacked(firstPart, midId, poolId, pool, fee, tokenIn, lenderId, endId);
    }

    /** OPEN */

    function getOpenExactInSingleV2(address tokenIn, address tokenOut, uint16 lenderId) internal view returns (bytes memory data) {
        uint8 poolId = DexMappingsMantle.MERCHANT_MOE;
        (uint8 actionId, , uint8 endId) = getOpenExactInFlags();
        address pool = testQuoter.v2TypePairAddress(tokenIn, tokenOut, poolId);
        return abi.encodePacked(tokenIn, actionId, poolId, pool, MERCHANT_MOE_FEE_DENOM, tokenOut, lenderId, endId);
    }

    function getOpenExactOutSingleV2(address tokenIn, address tokenOut, uint16 lenderId) internal view returns (bytes memory data) {
        uint8 poolId = DexMappingsMantle.MERCHANT_MOE;
        (uint8 actionId, , uint8 endId) = getOpenExactOutFlags();
        address pool = testQuoter.v2TypePairAddress(tokenIn, tokenOut, poolId);
        return abi.encodePacked(tokenOut, actionId, poolId, pool, MERCHANT_MOE_FEE_DENOM, tokenIn, lenderId, endId);
    }

    function getOpenExactInMultiV2(address tokenIn, address tokenOut, uint16 lenderId) internal view returns (bytes memory data) {
        (uint8 actionId, uint8 midId, uint8 endId) = getOpenExactInFlags();
        uint8 poolId = DexMappingsMantle.MERCHANT_MOE;
        address pool = testQuoter.v2TypePairAddress(tokenIn, TokensMantle.USDT, poolId);
        bytes memory firstPart = abi.encodePacked(tokenIn, actionId, poolId, pool, MERCHANT_MOE_FEE_DENOM, TokensMantle.USDT);
        poolId = DexMappingsMantle.MERCHANT_MOE;
        pool = testQuoter.v2TypePairAddress(TokensMantle.USDT, tokenOut, poolId);
        return abi.encodePacked(firstPart, midId, poolId, pool, MERCHANT_MOE_FEE_DENOM, tokenOut, lenderId, endId);
    }

    function getOpenExactOutMultiV2(address tokenIn, address tokenOut, uint16 lenderId) internal view returns (bytes memory data) {
        (uint8 actionId, uint8 midId, uint8 endId) = getOpenExactOutFlags();
        uint8 poolId = DexMappingsMantle.MERCHANT_MOE;
        address pool = testQuoter.v2TypePairAddress(TokensMantle.USDT, tokenOut, poolId);
        bytes memory firstPart = abi.encodePacked(tokenOut, actionId, poolId, pool, MERCHANT_MOE_FEE_DENOM, TokensMantle.USDT);
        pool = testQuoter.v2TypePairAddress(tokenIn, TokensMantle.USDT, poolId);
        return abi.encodePacked(firstPart, midId, poolId, pool, MERCHANT_MOE_FEE_DENOM, tokenIn, lenderId, endId);
    }

    /** CLOSE */

    function getCloseExactOutSingleV2(address tokenIn, address tokenOut, uint16 lenderId) internal view returns (bytes memory data) {
        uint8 poolId = DexMappingsMantle.MERCHANT_MOE;
        address pool = testQuoter.v2TypePairAddress(tokenIn, tokenOut, poolId);
        (uint8 actionId, , uint8 endId) = getCloseExactOutFlags();
        return abi.encodePacked(tokenOut, actionId, poolId, pool, MERCHANT_MOE_FEE_DENOM, tokenIn, lenderId, endId);
    }

    function getCloseExactInSingleV2(address tokenIn, address tokenOut, uint16 lenderId) internal view returns (bytes memory data) {
        uint8 poolId = DexMappingsMantle.MERCHANT_MOE;
        address pool = testQuoter.v2TypePairAddress(tokenIn, tokenOut, poolId);
        (uint8 actionId, , uint8 endId) = getCloseExactInFlags();
        return abi.encodePacked(tokenIn, actionId, poolId, pool, MERCHANT_MOE_FEE_DENOM, tokenOut, lenderId, endId);
    }

    function getCloseExactInMultiV2(address tokenIn, address tokenOut, uint16 lenderId) internal view returns (bytes memory data) {
        (uint8 actionId, uint8 midId, uint8 endId) = getCloseExactInFlags();
        uint8 poolId = DexMappingsMantle.MERCHANT_MOE;
        address pool = testQuoter.v2TypePairAddress(tokenIn, TokensMantle.USDT, poolId);
        bytes memory firstPart = abi.encodePacked(tokenIn, actionId, poolId, pool, MERCHANT_MOE_FEE_DENOM, TokensMantle.USDT);
        poolId = DexMappingsMantle.MERCHANT_MOE;
        pool = testQuoter.v2TypePairAddress(tokenOut, TokensMantle.USDT, poolId);
        return abi.encodePacked(firstPart, midId, poolId, pool, MERCHANT_MOE_FEE_DENOM, tokenOut, lenderId, endId);
    }

    function getCloseExactOutMultiV2(address tokenIn, address tokenOut, uint16 lenderId) internal view returns (bytes memory data) {
        (uint8 actionId, uint8 midId, uint8 endId) = getCloseExactOutFlags();
        uint8 poolId = DexMappingsMantle.MERCHANT_MOE;
        address pool = testQuoter.v2TypePairAddress(tokenOut, TokensMantle.USDT, poolId);
        bytes memory firstPart = abi.encodePacked(tokenOut, actionId, poolId, pool, MERCHANT_MOE_FEE_DENOM, TokensMantle.USDT);
        poolId = DexMappingsMantle.MERCHANT_MOE;
        pool = testQuoter.v2TypePairAddress(tokenIn, TokensMantle.USDT, poolId);
        return abi.encodePacked(firstPart, midId, poolId, pool, MERCHANT_MOE_FEE_DENOM, tokenIn, lenderId, endId);
    }

    /** COLLATERAL SWAP */

    function getCollateralSwapExactInSingleV2(address tokenIn, address tokenOut, uint16 lenderId) internal view returns (bytes memory data) {
        uint8 poolId = DexMappingsMantle.MERCHANT_MOE;
        address pool = testQuoter.v2TypePairAddress(tokenIn, tokenOut, poolId);
        (uint8 actionId, , uint8 endId) = getCollateralSwapExactInFlags();
        return abi.encodePacked(tokenIn, actionId, poolId, pool, MERCHANT_MOE_FEE_DENOM, tokenOut, lenderId, endId);
    }

    function getCollateralSwapExactOutSingleV2(address tokenIn, address tokenOut, uint16 lenderId) internal view returns (bytes memory data) {
        uint8 poolId = DexMappingsMantle.MERCHANT_MOE;
        address pool = testQuoter.v2TypePairAddress(tokenIn, tokenOut, poolId);
        (uint8 actionId, , uint8 endId) = getCollateralSwapExactOutFlags();
        return abi.encodePacked(tokenOut, actionId, poolId, pool, MERCHANT_MOE_FEE_DENOM, tokenIn, lenderId, endId);
    }

    function getCollateralSwapExactInMultiV2(address tokenIn, address tokenOut, uint16 lenderId) internal view returns (bytes memory data) {
        (uint8 actionId, uint8 midId, uint8 endId) = getCollateralSwapExactInFlags();
        uint8 poolId = DexMappingsMantle.MERCHANT_MOE;
        address pool = testQuoter.v2TypePairAddress(tokenIn, TokensMantle.METH, poolId);
        bytes memory firstPart = abi.encodePacked(tokenIn, actionId, poolId, pool, MERCHANT_MOE_FEE_DENOM, TokensMantle.METH);
        poolId = DexMappingsMantle.MERCHANT_MOE;
        pool = testQuoter.v2TypePairAddress(tokenOut, TokensMantle.METH, poolId);
        return abi.encodePacked(firstPart, midId, poolId, pool, MERCHANT_MOE_FEE_DENOM, tokenOut, lenderId, endId);
    }

    function getCollateralSwapExactOutMultiV2(address tokenIn, address tokenOut, uint16 lenderId) internal view returns (bytes memory data) {
        (uint8 actionId, uint8 midId, uint8 endId) = getCollateralSwapExactOutFlags();
        uint8 poolId = DexMappingsMantle.MERCHANT_MOE;
        address pool = testQuoter.v2TypePairAddress(tokenOut, TokensMantle.METH, poolId);
        bytes memory firstPart = abi.encodePacked(tokenOut, actionId, poolId, pool, MERCHANT_MOE_FEE_DENOM, TokensMantle.METH);
        poolId = DexMappingsMantle.MERCHANT_MOE;
        pool = testQuoter.v2TypePairAddress(tokenIn, TokensMantle.METH, poolId);
        return abi.encodePacked(firstPart, midId, poolId, pool, MERCHANT_MOE_FEE_DENOM, tokenIn, lenderId, endId);
    }

    /** DEBT SWAP */

    function getDebtSwapExactInSingleV2(address tokenIn, address tokenOut, uint16 lenderId) internal view returns (bytes memory data) {
        uint8 poolId = DexMappingsMantle.MERCHANT_MOE;
        address pool = testQuoter.v2TypePairAddress(tokenIn, tokenOut, poolId);
        (uint8 actionId, , uint8 endId) = getDebtSwapExactInFlags();
        return abi.encodePacked(tokenIn, actionId, poolId, pool, MERCHANT_MOE_FEE_DENOM, tokenOut, lenderId, endId);
    }

    function getDebtSwapExactOutSingleV2(address tokenIn, address tokenOut, uint16 lenderId) internal view returns (bytes memory data) {
        uint8 poolId = DexMappingsMantle.MERCHANT_MOE;
        address pool = testQuoter.v2TypePairAddress(tokenIn, tokenOut, poolId);
        (uint8 actionId, , uint8 endId) = getDebtSwapExactOutFlags();
        return abi.encodePacked(tokenOut, actionId, poolId, pool, MERCHANT_MOE_FEE_DENOM, tokenIn, lenderId, endId);
    }

    function getDebtSwapExactInMultiV2(address tokenIn, address tokenOut, uint16 lenderId) internal view returns (bytes memory data) {
        (uint8 actionId, uint8 midId, uint8 endId) = getDebtSwapExactInFlags();
        uint8 poolId = DexMappingsMantle.MERCHANT_MOE;
        address pool = testQuoter.v2TypePairAddress(tokenIn, TokensMantle.METH, poolId);
        bytes memory firstPart = abi.encodePacked(tokenIn, actionId, poolId, pool, MERCHANT_MOE_FEE_DENOM, TokensMantle.METH);
        poolId = DexMappingsMantle.MERCHANT_MOE;
        pool = testQuoter.v2TypePairAddress(tokenOut, TokensMantle.METH, poolId);
        return abi.encodePacked(firstPart, midId, poolId, pool, MERCHANT_MOE_FEE_DENOM, tokenOut, lenderId, endId);
    }

    function getDebtSwapExactOutMultiV2(address tokenIn, address tokenOut, uint16 lenderId) internal view returns (bytes memory data) {
        (uint8 actionId, uint8 midId, uint8 endId) = getDebtSwapExactOutFlags();
        uint8 poolId = DexMappingsMantle.MERCHANT_MOE;
        address pool = testQuoter.v2TypePairAddress(tokenOut, TokensMantle.METH, poolId);
        bytes memory firstPart = abi.encodePacked(tokenOut, actionId, poolId, pool, MERCHANT_MOE_FEE_DENOM, TokensMantle.METH);
        poolId = DexMappingsMantle.MERCHANT_MOE;
        pool = testQuoter.v2TypePairAddress(tokenIn, TokensMantle.METH, poolId);
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

    function isAave(uint16 lenderId) internal pure returns (bool a) {
        return lenderId == LenderMappingsMantle.LENDLE_ID || lenderId == LenderMappingsMantle.AURELIUS_ID;
    }

    // lender indexes prevent forge to bug out when using parameters

    function validLenderIndex(uint8 i) internal pure returns (bool) {
        return uint256(i) < 2;
    }

    function getLenderByIndex(uint8 i) internal view returns (uint16) {
        return lenderIds[i];
    }

    function isCompoundV3(uint16 lenderId) internal pure returns (bool a) {
        return lenderId == LenderMappingsMantle.COMPOUND_V3_USDE_ID;
    }

    uint16[] internal lenderIds = [LenderMappingsMantle.LENDLE_ID, LenderMappingsMantle.AURELIUS_ID];
    address[] internal users = [testUser, 0xe75358526Ef4441Db03cCaEB9a87F180fAe80eb9];

    /** HELPER FOR ALL IN */

    function _deposit(address asset, address user, uint256 amount, uint16 lenderId) internal {
        deal(asset, user, amount);

        vm.prank(user);
        IERC20All(asset).approve(brokerProxyAddress, amount);
        bytes memory transferData = transferIn(asset, brokerProxyAddress, amount);
        bytes memory data = deposit(asset, user, amount, lenderId);
        vm.prank(user);
        IFlashAggregator(brokerProxyAddress).deltaCompose(abi.encodePacked(transferData, data));
    }
}
