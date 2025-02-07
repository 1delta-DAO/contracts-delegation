// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {AddressesEthereum} from "./utils/CommonAddresses.f.sol";
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

// proxy and management
import {ConfigModule} from "../../contracts/1delta/proxy/modules/ConfigModule.sol";
import {DeltaBrokerProxyGen2} from "../../contracts/1delta/proxy/DeltaBrokerGen2.sol";

// initializer

// core modules
import {EthereumManagementModule} from "../../contracts/1delta/modules/ethereum/storage/ManagementModule.sol";
import {OneDeltaComposerEthereum} from "../../contracts/1delta/modules/ethereum/Composer.sol";

// forge
import {Script, console2} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {Test} from "forge-std/Test.sol";

import {AaveV3EthereumAssets, AaveV3Ethereum} from "./utils/lender/aaveAddresses.sol";
import {SparkAddresses} from "./utils/lender/sparkAddresses.sol";
import {DexMappingsEthereum} from "./utils/DexMappings.sol";

abstract contract DeltaSetup is AddressesEthereum, ComposerUtils, Script, Test {
    address internal brokerProxyAddress;
    IBrokerProxy internal brokerProxy;
    IModuleConfig internal deltaConfig;
    IManagement internal management;
    PoolGetter testQuoter;
    QuoterPolygon quoter;
    OneDeltaComposerEthereum internal aggregator;
    MockRouter router;

    mapping(address => mapping(uint8 => address)) internal collateralTokens;
    mapping(address => mapping(uint8 => address)) internal debtTokens;

    address WETH = AaveV3EthereumAssets.WETH_UNDERLYING;
    address USDT = AaveV3EthereumAssets.USDT_UNDERLYING;
    address USDC = AaveV3EthereumAssets.USDC_UNDERLYING;
    address WBTC = AaveV3EthereumAssets.WBTC_UNDERLYING;
    address DAI = AaveV3EthereumAssets.DAI_UNDERLYING;

    /** SELECTOR GETTERS */

    function managementSelectors() internal pure returns (bytes4[] memory selectors) {
        selectors = new bytes4[](12);
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

        EthereumManagementModule _management = new EthereumManagementModule();
        OneDeltaComposerEthereum _aggregator = new OneDeltaComposerEthereum();

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

    function initializeDeltaBase() internal virtual {
        testQuoter = new PoolGetter();
        quoter = new QuoterPolygon();
    }

    function initializeDeltaAaveV3() internal virtual {
        // aave v3
        management.addGeneralLenderTokens(
            AaveV3EthereumAssets.USDC_UNDERLYING,
            AaveV3EthereumAssets.USDC_A_TOKEN,
            AaveV3EthereumAssets.USDC_V_TOKEN,
            AaveV3EthereumAssets.USDC_S_TOKEN,
            AAVE_V3
        );
        management.addGeneralLenderTokens(
            AaveV3EthereumAssets.USDT_UNDERLYING,
            AaveV3EthereumAssets.USDT_A_TOKEN,
            AaveV3EthereumAssets.USDT_V_TOKEN,
            AaveV3EthereumAssets.USDT_S_TOKEN,
            AAVE_V3
        );
        management.addGeneralLenderTokens(
            AaveV3EthereumAssets.WBTC_UNDERLYING,
            AaveV3EthereumAssets.WBTC_A_TOKEN,
            AaveV3EthereumAssets.WBTC_V_TOKEN,
            AaveV3EthereumAssets.WBTC_S_TOKEN,
            AAVE_V3
        );
        management.addGeneralLenderTokens(
            AaveV3EthereumAssets.WETH_UNDERLYING,
            AaveV3EthereumAssets.WETH_A_TOKEN,
            AaveV3EthereumAssets.WETH_V_TOKEN,
            AaveV3EthereumAssets.WETH_S_TOKEN,
            AAVE_V3
        );

        collateralTokens[AaveV3EthereumAssets.USDC_UNDERLYING][AAVE_V3] = AaveV3EthereumAssets.USDC_A_TOKEN;
        collateralTokens[AaveV3EthereumAssets.USDT_UNDERLYING][AAVE_V3] = AaveV3EthereumAssets.USDT_A_TOKEN;
        collateralTokens[AaveV3EthereumAssets.WBTC_UNDERLYING][AAVE_V3] = AaveV3EthereumAssets.WBTC_A_TOKEN;
        collateralTokens[AaveV3EthereumAssets.WETH_UNDERLYING][AAVE_V3] = AaveV3EthereumAssets.WETH_A_TOKEN;

        debtTokens[AaveV3EthereumAssets.USDC_UNDERLYING][AAVE_V3] = AaveV3EthereumAssets.USDC_V_TOKEN;
        debtTokens[AaveV3EthereumAssets.USDT_UNDERLYING][AAVE_V3] = AaveV3EthereumAssets.USDT_V_TOKEN;
        debtTokens[AaveV3EthereumAssets.WBTC_UNDERLYING][AAVE_V3] = AaveV3EthereumAssets.WBTC_V_TOKEN;
        debtTokens[AaveV3EthereumAssets.WETH_UNDERLYING][AAVE_V3] = AaveV3EthereumAssets.WETH_V_TOKEN;

        // approve pools
        address[] memory assets = new address[](4);
        assets[0] = AaveV3EthereumAssets.USDC_UNDERLYING;
        assets[1] = AaveV3EthereumAssets.WBTC_UNDERLYING;
        assets[2] = AaveV3EthereumAssets.WETH_UNDERLYING;
        assets[3] = AaveV3EthereumAssets.USDT_UNDERLYING;

        management.approveAddress(assets, AaveV3Ethereum.POOL);
    }

    function initializeDeltaSpark() internal virtual {
        // aave v3
        management.addGeneralLenderTokens(
            SparkAddresses.USDC_token,
            SparkAddresses.USDC_aToken,
            SparkAddresses.USDC_variableDebtToken,
            SparkAddresses.USDC_stableDebtToken,
            SPARK
        );
        management.addGeneralLenderTokens(
            SparkAddresses.DAI_token,
            SparkAddresses.DAI_aToken,
            SparkAddresses.DAI_variableDebtToken,
            SparkAddresses.DAI_stableDebtToken,
            SPARK
        );
        management.addGeneralLenderTokens(
            SparkAddresses.WBTC_token,
            SparkAddresses.WBTC_aToken,
            SparkAddresses.WBTC_variableDebtToken,
            SparkAddresses.WBTC_stableDebtToken,
            SPARK
        );
        management.addGeneralLenderTokens(
            SparkAddresses.WETH_token,
            SparkAddresses.WETH_aToken,
            SparkAddresses.WETH_variableDebtToken,
            SparkAddresses.WETH_stableDebtToken,
            SPARK
        );

        collateralTokens[SparkAddresses.USDC_token][SPARK] = SparkAddresses.USDC_aToken;
        collateralTokens[SparkAddresses.DAI_token][SPARK] = SparkAddresses.DAI_aToken;
        collateralTokens[SparkAddresses.WBTC_token][SPARK] = SparkAddresses.WBTC_aToken;
        collateralTokens[SparkAddresses.WETH_token][SPARK] = SparkAddresses.WETH_aToken;

        debtTokens[SparkAddresses.USDC_token][SPARK] = SparkAddresses.USDC_variableDebtToken;
        debtTokens[SparkAddresses.DAI_token][SPARK] = SparkAddresses.DAI_variableDebtToken;
        debtTokens[SparkAddresses.WBTC_token][SPARK] = SparkAddresses.WBTC_variableDebtToken;
        debtTokens[SparkAddresses.WETH_token][SPARK] = SparkAddresses.WETH_variableDebtToken;

        // approve pools
        address[] memory assets = new address[](4);
        assets[0] = SparkAddresses.USDC_token;
        assets[1] = SparkAddresses.WBTC_token;
        assets[2] = SparkAddresses.WETH_token;
        assets[3] = SparkAddresses.DAI_token;

        management.approveAddress(assets, SparkAddresses.POOL);
    }

    function initializeDeltaCompound() internal virtual {
        // approve pools
        address[] memory assets = new address[](4);
        assets[0] = USDC;
        assets[1] = WBTC;
        assets[2] = WETH;
        assets[3] = USDT;

        management.approveAddress(assets, COMET_USDC);
        management.approveAddress(assets, COMET_USDT);
    }

    function upgradeExistingDelta(address proxy, address admin, address oldModule) internal virtual {
        brokerProxyAddress = proxy;

        brokerProxy = IBrokerProxy(brokerProxyAddress);

        OneDeltaComposerEthereum _aggregator = new OneDeltaComposerEthereum();

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
        assetList[0] = AaveV3EthereumAssets.USDC_UNDERLYING;
        assetList[1] = AaveV3EthereumAssets.WBTC_UNDERLYING;
        assetList[2] = AaveV3EthereumAssets.WETH_UNDERLYING;
        assetList[4] = AaveV3EthereumAssets.USDT_UNDERLYING;
    }

    function setUp() public virtual {
        vm.createSelectFork({blockNumber: 20581600, urlOrAlias: "https://rpc.ankr.com/eth"});
        router = new MockRouter(1.0e18, 12);

        deployDelta();
        initializeDeltaBase();
        initializeDeltaCompound();
        initializeDeltaAaveV3();
        initializeDeltaSpark();

        management.setValidTarget(address(router), true);
    }

    /** DEPOSIT AND OPEN TO SPIN UP POSITIONS */

    function execDeposit(address user, address asset, uint256 depositAmount, uint8 lenderId) internal {
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

    function openSimple(address user, address asset, address borrowAsset, uint256 depositAmount, uint256 borrowAmount, uint8 lenderId) internal {
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
        uint8 lenderId
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
        uint8 lenderId
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

    function getBorrowBalance(address user, address asset, uint8 lenderId) internal view returns (uint256) {
        if (lenderId < 50) {
            return IERC20All(debtTokens[asset][lenderId]).balanceOf(user);
        } else {
            if (lenderId == 50) return IComet(COMET_USDC).borrowBalanceOf(user);
            else return IComet(COMET_USDT).borrowBalanceOf(user);
        }
    }

    function getCollateralBalance(address user, address asset, uint8 lenderId) internal view returns (uint256) {
        if (lenderId < 50) {
            return IERC20All(collateralTokens[asset][lenderId]).balanceOf(user);
        } else {
            if (lenderId == 50) return IComet(COMET_USDC).userCollateral(user, asset).balance;
            else return IComet(COMET_USDT).userCollateral(user, asset).balance;
        }
    }

    function approveWithdrawal(address user, address asset, uint256 amount, uint8 lenderId) internal {
        vm.prank(user);
        if (lenderId < 50) {
            IERC20All(collateralTokens[asset][lenderId]).approve(address(brokerProxyAddress), amount);
        } else {
            if (lenderId == 50) IComet(COMET_USDC).allow(brokerProxyAddress, true);
            if (lenderId == 51) IComet(COMET_USDT).allow(brokerProxyAddress, true);
        }
    }

    function approveBorrowDelegation(address user, address asset, uint256 amount, uint8 lenderId) internal {
        vm.prank(user);
        if (lenderId < 50) {
            IERC20All(debtTokens[asset][lenderId]).approveDelegation(address(brokerProxyAddress), amount);
        } else {
            if (lenderId == 50) IComet(COMET_USDC).allow(brokerProxyAddress, true);
            if (lenderId == 51) IComet(COMET_USDT).allow(brokerProxyAddress, true);
        }
    }

    /** HELPER FUNCTIONS */

    /** OPEN */

    function getOpenExactInSingle(address tokenIn, address tokenOut, uint8 lenderId) internal view returns (bytes memory data) {
        uint16 fee = uint16(DEX_FEE_LOW);
        uint8 poolId = DexMappingsEthereum.UNI_V3;
        address pool = testQuoter.v3TypePool(tokenIn, tokenOut, fee, poolId);
        (uint8 actionId, , uint8 endId) = getOpenExactInFlags();
        return abi.encodePacked(tokenIn, actionId, poolId, pool, fee, tokenOut, lenderId, endId);
    }

    function getOpenExactInSingle_izi(address tokenIn, address tokenOut, uint8 lenderId) internal view returns (bytes memory data) {
        uint16 fee = uint16(DEX_FEE_LOW_HIGH);
        uint8 poolId = DexMappingsEthereum.SOLIDLY_V3;
        address pool = testQuoter.getiZiPool(tokenIn, tokenOut, fee);
        (uint8 actionId, , uint8 endId) = getOpenExactInFlags();
        return abi.encodePacked(tokenIn, actionId, poolId, pool, fee, tokenOut, lenderId, endId);
    }

    function getSpotExactInSingle_izi(address tokenIn, address tokenOut) internal view returns (bytes memory data) {
        uint16 fee = uint16(DEX_FEE_LOW_HIGH);
        uint8 poolId = DexMappingsEthereum.SOLIDLY_V3;
        address pool = testQuoter.getiZiPool(tokenIn, tokenOut, fee);
        return abi.encodePacked(tokenIn, uint8(0), poolId, pool, fee, tokenOut);
    }

    function getSpotExactOutSingle_izi(address tokenIn, address tokenOut) internal view returns (bytes memory data) {
        uint16 fee = uint16(DEX_FEE_LOW_HIGH);
        uint8 poolId = DexMappingsEthereum.SOLIDLY_V3;
        address pool = testQuoter.getiZiPool(tokenIn, tokenOut, fee);
        return abi.encodePacked(tokenOut, uint8(0), poolId, pool, fee, tokenIn);
    }

    function getOpenExactOutSingle(address tokenIn, address tokenOut, uint8 lenderId) internal view returns (bytes memory data) {
        uint16 fee = uint16(DEX_FEE_LOW);
        uint8 poolId = DexMappingsEthereum.UNI_V3;
        address pool = testQuoter.v3TypePool(tokenIn, tokenOut, fee, poolId);
        (uint8 actionId, , uint8 endId) = getOpenExactOutFlags();
        return abi.encodePacked(tokenOut, actionId, poolId, pool, fee, tokenIn, lenderId, endId);
    }

    function getOpenExactInMulti(address tokenIn, address tokenOut, uint8 lenderId) internal view returns (bytes memory data) {
        uint16 fee = uint16(DEX_FEE_LOW);
        (uint8 actionId, uint8 midId, uint8 endId) = getOpenExactInFlags();
        uint8 poolId = DexMappingsEthereum.SOLIDLY_V3;
        address pool = testQuoter.getiZiPool(tokenIn, USDT, fee);
        bytes memory firstPart = abi.encodePacked(tokenIn, actionId, poolId, pool, fee, USDT);
        fee = uint16(DEX_FEE_STABLES);
        poolId = DexMappingsEthereum.SUSHI_V3;
        pool = testQuoter.v3TypePool(USDT, tokenOut, fee, poolId);
        return abi.encodePacked(firstPart, midId, poolId, pool, fee, tokenOut, lenderId, endId);
    }

    function getOpenExactOutMulti(address tokenIn, address tokenOut, uint8 lenderId) internal view returns (bytes memory data) {
        uint16 fee = uint16(DEX_FEE_STABLES);
        (uint8 actionId, uint8 midId, uint8 endId) = getOpenExactOutFlags();
        uint8 poolId = DexMappingsEthereum.SUSHI_V3;
        address pool = testQuoter.v3TypePool(tokenOut, USDT, fee, poolId);
        bytes memory firstPart = abi.encodePacked(tokenOut, actionId, poolId, pool, fee, USDT);
        fee = uint16(DEX_FEE_LOW);
        poolId = DexMappingsEthereum.SOLIDLY_V3;
        pool = testQuoter.getiZiPool(USDT, tokenIn, fee);
        return abi.encodePacked(firstPart, midId, poolId, pool, fee, tokenIn, lenderId, endId);
    }

    /** CLOSE */

    function getCloseExactOutSingle(address tokenIn, address tokenOut, uint8 lenderId) internal view returns (bytes memory data) {
        uint16 fee = uint16(DEX_FEE_LOW);
        uint8 poolId = DexMappingsEthereum.UNI_V3;
        address pool = testQuoter.v3TypePool(tokenIn, tokenOut, fee, poolId);
        (uint8 actionId, , uint8 endId) = getCloseExactOutFlags();
        return abi.encodePacked(tokenOut, actionId, poolId, pool, fee, tokenIn, lenderId, endId);
    }

    function getCloseExactInSingle(address tokenIn, address tokenOut, uint8 lenderId) internal view returns (bytes memory data) {
        uint16 fee = uint16(DEX_FEE_LOW);
        uint8 poolId = DexMappingsEthereum.UNI_V3;
        address pool = testQuoter.v3TypePool(tokenIn, tokenOut, fee, poolId);
        (uint8 actionId, , uint8 endId) = getCloseExactInFlags();
        return abi.encodePacked(tokenIn, actionId, poolId, pool, fee, tokenOut, lenderId, endId);
    }

    function getCloseExactInMulti(address tokenIn, address tokenOut, uint8 lenderId) internal view returns (bytes memory data) {
        uint16 fee = uint16(DEX_FEE_LOW);
        (uint8 actionId, uint8 midId, uint8 endId) = getCloseExactInFlags();
        uint8 poolId = DexMappingsEthereum.SOLIDLY_V3;
        address pool = testQuoter.getiZiPool(USDT, tokenIn, fee);
        bytes memory firstPart = abi.encodePacked(tokenIn, actionId, poolId, pool, fee, USDT);
        fee = uint16(DEX_FEE_STABLES);
        poolId = DexMappingsEthereum.SUSHI_V3;
        pool = testQuoter.v3TypePool(USDT, tokenOut, fee, poolId);
        return abi.encodePacked(firstPart, midId, poolId, pool, fee, tokenOut, lenderId, endId);
    }

    function getCloseExactOutMulti(address tokenIn, address tokenOut, uint8 lenderId) internal view returns (bytes memory data) {
        uint16 fee = uint16(DEX_FEE_STABLES);
        (uint8 actionId, uint8 midId, uint8 endId) = getCloseExactOutFlags();
        uint8 poolId = DexMappingsEthereum.SUSHI_V3;
        address pool = testQuoter.v3TypePool(USDT, tokenOut, fee, poolId);
        bytes memory firstPart = abi.encodePacked(tokenOut, actionId, poolId, pool, fee, USDT);
        fee = uint16(DEX_FEE_LOW);
        poolId = DexMappingsEthereum.SOLIDLY_V3;
        pool = testQuoter.getiZiPool(USDT, tokenIn, fee);
        return abi.encodePacked(firstPart, midId, poolId, pool, fee, tokenIn, lenderId, endId);
    }

    /** COLLATERAL SWAP */

    function getCollateralSwapExactInSingle(address tokenIn, address tokenOut, uint8 lenderId) internal view returns (bytes memory data) {
        uint16 fee = uint16(DEX_FEE_LOW);
        uint8 poolId = DexMappingsEthereum.UNI_V3;
        address pool = testQuoter.v3TypePool(tokenIn, tokenOut, fee, poolId);
        (uint8 actionId, , uint8 endId) = getCollateralSwapExactInFlags();
        return abi.encodePacked(tokenIn, actionId, poolId, pool, fee, tokenOut, lenderId, endId);
    }

    function getCollateralSwapExactOutSingle(address tokenIn, address tokenOut, uint8 lenderId) internal view returns (bytes memory data) {
        uint16 fee = uint16(DEX_FEE_LOW);
        uint8 poolId = DexMappingsEthereum.UNI_V3;
        address pool = testQuoter.v3TypePool(tokenIn, tokenOut, fee, poolId);
        (uint8 actionId, , uint8 endId) = getCollateralSwapExactOutFlags();
        return abi.encodePacked(tokenOut, actionId, poolId, pool, fee, tokenIn, lenderId, endId);
    }

    function getCollateralSwapExactInMulti(address tokenIn, address tokenOut, uint8 lenderId) internal view returns (bytes memory data) {
        uint16 fee = uint16(DEX_FEE_LOW_MEDIUM);
        (uint8 actionId, uint8 midId, uint8 endId) = getCollateralSwapExactInFlags();
        uint8 poolId = DexMappingsEthereum.UNI_V3;
        address pool = testQuoter.v3TypePool(tokenIn, WETH, fee, poolId);
        bytes memory firstPart = abi.encodePacked(tokenIn, actionId, poolId, pool, fee, WETH);
        fee = uint16(DEX_FEE_LOW);
        poolId = DexMappingsEthereum.SUSHI_V3;
        pool = testQuoter.v3TypePool(tokenOut, WETH, fee, poolId);
        return abi.encodePacked(firstPart, midId, poolId, pool, fee, tokenOut, lenderId, endId);
    }

    function getCollateralSwapExactOutMulti(address tokenIn, address tokenOut, uint8 lenderId) internal view returns (bytes memory data) {
        uint16 fee = uint16(DEX_FEE_LOW_MEDIUM);
        (uint8 actionId, uint8 midId, uint8 endId) = getCollateralSwapExactOutFlags();
        uint8 poolId = DexMappingsEthereum.UNI_V3;
        address pool = testQuoter.v3TypePool(tokenOut, WETH, fee, poolId);
        bytes memory firstPart = abi.encodePacked(tokenOut, actionId, poolId, pool, fee, WETH);
        fee = uint16(DEX_FEE_LOW);
        poolId = DexMappingsEthereum.SUSHI_V3;
        pool = testQuoter.v3TypePool(tokenIn, WETH, fee, poolId);
        return abi.encodePacked(firstPart, midId, poolId, pool, fee, tokenIn, lenderId, endId);
    }

    /** DEBT SWAP */

    function getDebtSwapExactInSingle(address tokenIn, address tokenOut, uint8 lenderId) internal view returns (bytes memory data) {
        uint16 fee = uint16(DEX_FEE_LOW_MEDIUM);
        uint8 poolId = DexMappingsEthereum.UNI_V3;
        address pool = testQuoter.v3TypePool(tokenOut, tokenIn, fee, poolId);
        (uint8 actionId, , uint8 endId) = getDebtSwapExactInFlags();
        return abi.encodePacked(tokenIn, actionId, poolId, pool, fee, tokenOut, lenderId, endId);
    }

    function getDebtSwapExactOutSingle(address tokenIn, address tokenOut, uint8 lenderId) internal view returns (bytes memory data) {
        uint16 fee = uint16(DEX_FEE_LOW_MEDIUM);
        uint8 poolId = DexMappingsEthereum.UNI_V3;
        address pool = testQuoter.v3TypePool(tokenOut, tokenIn, fee, poolId);
        (uint8 actionId, , uint8 endId) = getDebtSwapExactOutFlags();
        return abi.encodePacked(tokenOut, actionId, poolId, pool, fee, tokenIn, lenderId, endId);
    }

    function getDebtSwapExactInMulti(address tokenIn, address tokenOut, uint8 lenderId) internal view returns (bytes memory data) {
        uint16 fee = uint16(DEX_FEE_LOW);
        (uint8 actionId, uint8 midId, uint8 endId) = getDebtSwapExactInFlags();
        uint8 poolId = DexMappingsEthereum.PANCAKE_V3;
        address pool = testQuoter.v3TypePool(tokenIn, USDT, fee, poolId);
        bytes memory firstPart = abi.encodePacked(tokenIn, actionId, poolId, pool, fee, USDT);
        fee = uint16(DEX_FEE_LOW);
        poolId = DexMappingsEthereum.PANCAKE_V3;
        pool = testQuoter.v3TypePool(tokenOut, USDT, fee, poolId);
        return abi.encodePacked(firstPart, midId, poolId, pool, fee, tokenOut, lenderId, endId);
    }

    function getDebtSwapExactOutMulti(address tokenIn, address tokenOut, uint8 lenderId) internal view returns (bytes memory data) {
        uint16 fee = uint16(DEX_FEE_LOW);
        (uint8 actionId, uint8 midId, uint8 endId) = getDebtSwapExactOutFlags();
        uint8 poolId = DexMappingsEthereum.PANCAKE_V3;
        address pool = testQuoter.v3TypePool(tokenOut, USDT, fee, poolId);
        bytes memory firstPart = abi.encodePacked(tokenOut, actionId, poolId, pool, fee, USDT);
        fee = uint16(DEX_FEE_LOW);
        poolId = DexMappingsEthereum.PANCAKE_V3;
        pool = testQuoter.v3TypePool(tokenIn, USDT, fee, poolId);
        return abi.encodePacked(firstPart, midId, poolId, pool, fee, tokenIn, lenderId, endId);
    }

    /** OPEN */

    function getOpenExactInSingleV2(address tokenIn, address tokenOut, uint8 lenderId) internal view returns (bytes memory data) {
        uint8 poolId = DexMappingsEthereum.UNI_V2;
        (uint8 actionId, , uint8 endId) = getOpenExactInFlags();
        address pool = testQuoter.v2TypePairAddress(tokenIn, tokenOut, poolId);
        return abi.encodePacked(tokenIn, actionId, poolId, pool, tokenOut, lenderId, endId);
    }

    function getOpenExactOutSingleV2(address tokenIn, address tokenOut, uint8 lenderId) internal view returns (bytes memory data) {
        uint8 poolId = DexMappingsEthereum.UNI_V2;
        (uint8 actionId, , uint8 endId) = getOpenExactOutFlags();
        address pool = testQuoter.v2TypePairAddress(tokenIn, tokenOut, poolId);
        return abi.encodePacked(tokenOut, actionId, poolId, pool, tokenIn, lenderId, endId);
    }

    function getOpenExactInMultiV2(address tokenIn, address tokenOut, uint8 lenderId) internal view returns (bytes memory data) {
        (uint8 actionId, uint8 midId, uint8 endId) = getOpenExactInFlags();
        uint8 poolId = DexMappingsEthereum.UNI_V2;
        address pool = testQuoter.v2TypePairAddress(tokenIn, USDT, poolId);
        bytes memory firstPart = abi.encodePacked(tokenIn, actionId, poolId, pool, USDT);
        poolId = DexMappingsEthereum.UNI_V2;
        pool = testQuoter.v2TypePairAddress(USDT, tokenOut, poolId);
        return abi.encodePacked(firstPart, midId, poolId, pool, tokenOut, lenderId, endId);
    }

    function getOpenExactOutMultiV2(address tokenIn, address tokenOut, uint8 lenderId) internal view returns (bytes memory data) {
        (uint8 actionId, uint8 midId, uint8 endId) = getOpenExactOutFlags();
        uint8 poolId = DexMappingsEthereum.UNI_V2;
        address pool = testQuoter.v2TypePairAddress(USDT, tokenOut, poolId);
        bytes memory firstPart = abi.encodePacked(tokenOut, actionId, poolId, pool, USDT);
        pool = testQuoter.v2TypePairAddress(tokenIn, USDT, poolId);
        return abi.encodePacked(firstPart, midId, poolId, pool, tokenIn, lenderId, endId);
    }

    /** CLOSE */

    function getCloseExactOutSingleV2(address tokenIn, address tokenOut, uint8 lenderId) internal view returns (bytes memory data) {
        uint8 poolId = DexMappingsEthereum.UNI_V2;
        address pool = testQuoter.v2TypePairAddress(tokenIn, tokenOut, poolId);
        (uint8 actionId, , uint8 endId) = getCloseExactOutFlags();
        return abi.encodePacked(tokenOut, actionId, poolId, pool, tokenIn, lenderId, endId);
    }

    function getCloseExactInSingleV2(address tokenIn, address tokenOut, uint8 lenderId) internal view returns (bytes memory data) {
        uint8 poolId = DexMappingsEthereum.UNI_V2;
        address pool = testQuoter.v2TypePairAddress(tokenIn, tokenOut, poolId);
        (uint8 actionId, , uint8 endId) = getCloseExactInFlags();
        return abi.encodePacked(tokenIn, actionId, poolId, pool, tokenOut, lenderId, endId);
    }

    function getCloseExactInMultiV2(address tokenIn, address tokenOut, uint8 lenderId) internal view returns (bytes memory data) {
        (uint8 actionId, uint8 midId, uint8 endId) = getCloseExactInFlags();
        uint8 poolId = DexMappingsEthereum.UNI_V2;
        address pool = testQuoter.v2TypePairAddress(tokenIn, USDT, poolId);
        bytes memory firstPart = abi.encodePacked(tokenIn, actionId, poolId, pool, USDT);
        poolId = DexMappingsEthereum.UNI_V2;
        pool = testQuoter.v2TypePairAddress(tokenOut, USDT, poolId);
        return abi.encodePacked(firstPart, midId, poolId, pool, tokenOut, lenderId, endId);
    }

    function getCloseExactOutMultiV2(address tokenIn, address tokenOut, uint8 lenderId) internal view returns (bytes memory data) {
        (uint8 actionId, uint8 midId, uint8 endId) = getCloseExactOutFlags();
        uint8 poolId = DexMappingsEthereum.UNI_V2;
        address pool = testQuoter.v2TypePairAddress(tokenOut, USDT, poolId);
        bytes memory firstPart = abi.encodePacked(tokenOut, actionId, poolId, pool, USDT);
        poolId = DexMappingsEthereum.UNI_V2;
        pool = testQuoter.v2TypePairAddress(tokenIn, USDT, poolId);
        return abi.encodePacked(firstPart, midId, poolId, pool, tokenIn, lenderId, endId);
    }

    /** COLLATERAL SWAP */

    function getCollateralSwapExactInSingleV2(address tokenIn, address tokenOut, uint8 lenderId) internal view returns (bytes memory data) {
        uint8 poolId = DexMappingsEthereum.UNI_V2;
        address pool = testQuoter.v2TypePairAddress(tokenIn, tokenOut, poolId);
        (uint8 actionId, , uint8 endId) = getCollateralSwapExactInFlags();
        return abi.encodePacked(tokenIn, actionId, poolId, pool, tokenOut, lenderId, endId);
    }

    function getCollateralSwapExactOutSingleV2(address tokenIn, address tokenOut, uint8 lenderId) internal view returns (bytes memory data) {
        uint8 poolId = DexMappingsEthereum.UNI_V2;
        address pool = testQuoter.v2TypePairAddress(tokenIn, tokenOut, poolId);
        (uint8 actionId, , uint8 endId) = getCollateralSwapExactOutFlags();
        return abi.encodePacked(tokenOut, actionId, poolId, pool, tokenIn, lenderId, endId);
    }

    function getCollateralSwapExactInMultiV2(address tokenIn, address tokenOut, uint8 lenderId) internal view returns (bytes memory data) {
        (uint8 actionId, uint8 midId, uint8 endId) = getCollateralSwapExactInFlags();
        uint8 poolId = DexMappingsEthereum.UNI_V2;
        address pool = testQuoter.v2TypePairAddress(tokenIn, WETH, poolId);
        bytes memory firstPart = abi.encodePacked(tokenIn, actionId, poolId, pool, WETH);
        poolId = DexMappingsEthereum.UNI_V2;
        pool = testQuoter.v2TypePairAddress(tokenOut, WETH, poolId);
        return abi.encodePacked(firstPart, midId, poolId, pool, tokenOut, lenderId, endId);
    }

    function getCollateralSwapExactOutMultiV2(address tokenIn, address tokenOut, uint8 lenderId) internal view returns (bytes memory data) {
        (uint8 actionId, uint8 midId, uint8 endId) = getCollateralSwapExactOutFlags();
        uint8 poolId = DexMappingsEthereum.UNI_V2;
        address pool = testQuoter.v2TypePairAddress(tokenOut, WETH, poolId);
        bytes memory firstPart = abi.encodePacked(tokenOut, actionId, poolId, pool, WETH);
        poolId = DexMappingsEthereum.UNI_V2;
        pool = testQuoter.v2TypePairAddress(tokenIn, WETH, poolId);
        return abi.encodePacked(firstPart, midId, poolId, pool, tokenIn, lenderId, endId);
    }

    /** DEBT SWAP */

    function getDebtSwapExactInSingleV2(address tokenIn, address tokenOut, uint8 lenderId) internal view returns (bytes memory data) {
        uint8 poolId = DexMappingsEthereum.UNI_V2;
        address pool = testQuoter.v2TypePairAddress(tokenIn, tokenOut, poolId);
        (uint8 actionId, , uint8 endId) = getDebtSwapExactInFlags();
        return abi.encodePacked(tokenIn, actionId, poolId, pool, tokenOut, lenderId, endId);
    }

    function getDebtSwapExactOutSingleV2(address tokenIn, address tokenOut, uint8 lenderId) internal view returns (bytes memory data) {
        uint8 poolId = DexMappingsEthereum.UNI_V2;
        address pool = testQuoter.v2TypePairAddress(tokenIn, tokenOut, poolId);
        (uint8 actionId, , uint8 endId) = getDebtSwapExactOutFlags();
        return abi.encodePacked(tokenOut, actionId, poolId, pool, tokenIn, lenderId, endId);
    }

    function getDebtSwapExactInMultiV2(address tokenIn, address tokenOut, uint8 lenderId) internal view returns (bytes memory data) {
        (uint8 actionId, uint8 midId, uint8 endId) = getDebtSwapExactInFlags();
        uint8 poolId = DexMappingsEthereum.UNI_V2;
        address pool = testQuoter.v2TypePairAddress(tokenIn, WETH, poolId);
        bytes memory firstPart = abi.encodePacked(tokenIn, actionId, poolId, pool, WETH);
        poolId = DexMappingsEthereum.UNI_V2;
        pool = testQuoter.v2TypePairAddress(tokenOut, WETH, poolId);
        return abi.encodePacked(firstPart, midId, poolId, pool, tokenOut, lenderId, endId);
    }

    function getDebtSwapExactOutMultiV2(address tokenIn, address tokenOut, uint8 lenderId) internal view returns (bytes memory data) {
        (uint8 actionId, uint8 midId, uint8 endId) = getDebtSwapExactOutFlags();
        uint8 poolId = DexMappingsEthereum.UNI_V2;
        address pool = testQuoter.v2TypePairAddress(tokenOut, WETH, poolId);
        bytes memory firstPart = abi.encodePacked(tokenOut, actionId, poolId, pool, WETH);
        poolId = DexMappingsEthereum.UNI_V2;
        pool = testQuoter.v2TypePairAddress(tokenIn, WETH, poolId);
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
        uint8 lenderId
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
