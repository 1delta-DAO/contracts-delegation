// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {AddressesArbitrum} from "./utils/CommonAddresses.f.sol";
import {AaveV3ArbitrumAssets, AaveV3Arbitrum} from "./utils/lender/aaveAddresses.sol";
import {AvalonArbitrumAssets, AvalonArbitrum} from "./utils/lender/avalonAddresses.sol";
import {VenusCoreArbitrum, VenusEtherArbitrum} from "./utils/lender/venusAddresses.sol";
import {CompoundV3Arbitrum} from "./utils/lender/compoundAddresses.sol";
import {YLDRArbitrumAssets, YLDRArbitrum} from "./utils/lender/yldrAddresses.sol";
import {TokensArbitrum} from "./utils/tokens.sol";
import "../../contracts/1delta/quoter/test/TestQuoterArbitrum.sol";
import {MockRouter} from "../../contracts/mocks/MockRouter.sol";
import {ComposerUtils, Commands} from "../shared/utils/ComposerUtils.sol";

import {ComptrollerInterface} from "./utils/lender/venus/VenusComptroller.sol";

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
import {ManagementModule} from "../../contracts/1delta/modules/shared/storage/ManagementModule.sol";
import {OneDeltaComposerArbitrum} from "../../contracts/1delta/modules/arbitrum/Composer.sol";

// forge
import {Script, console2} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {Test} from "forge-std/Test.sol";

contract DeltaSetup is AddressesArbitrum, ComposerUtils, Script, Test {
    address internal brokerProxyAddress;
    IBrokerProxy internal brokerProxy;
    IModuleConfig internal deltaConfig;
    IManagement internal management;
    TestQuoterArbitrum testQuoter;
    OneDeltaComposerArbitrum internal aggregator;
    MockRouter router;

    mapping(address => mapping(uint16 => address)) internal collateralTokens;
    mapping(address => mapping(uint16 => address)) internal debtTokens;

    /** SELECTOR GETTERS */

    function managementSelectors() internal pure returns (bytes4[] memory selectors) {
        selectors = new bytes4[](15);
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
        selectors[13] = IManagement.batchApprove.selector;
        selectors[14] = IManagement.batchAddGeneralLenderTokens.selector;
        return selectors;
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

    /** DEPLOY PROZY AND MODULES */

    function deployDelta() internal virtual {
        ConfigModule _config = new ConfigModule();
        brokerProxyAddress = address(new DeltaBrokerProxyGen2(address(this), address(_config)));

        brokerProxy = IBrokerProxy(brokerProxyAddress);

        ManagementModule _management = new ManagementModule();
        OneDeltaComposerArbitrum _aggregator = new OneDeltaComposerArbitrum();

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
        initializeDeltaAaveV3();
        initializeDeltaAvalon();
        initializeDeltaYldr();
        initializeDeltaCompound();
        initializeDeltaVenus();
        // console.log("--- initialized lenders ---");
    }

    function initializeDeltaAaveV3() internal virtual {
        // aave v3
        management.addGeneralLenderTokens(
            TokensArbitrum.USDC,
            AaveV3ArbitrumAssets.USDC_A_TOKEN,
            AaveV3ArbitrumAssets.USDC_V_TOKEN,
            address(0),
            AAVE_V3
        );
        management.addGeneralLenderTokens(
            TokensArbitrum.USDT,
            AaveV3ArbitrumAssets.USDT_A_TOKEN,
            AaveV3ArbitrumAssets.USDT_V_TOKEN,
            address(0),
            AAVE_V3
        );
        management.addGeneralLenderTokens(
            TokensArbitrum.WBTC,
            AaveV3ArbitrumAssets.WBTC_A_TOKEN,
            AaveV3ArbitrumAssets.WBTC_V_TOKEN,
            address(0),
            AAVE_V3
        );
        management.addGeneralLenderTokens(
            TokensArbitrum.WETH,
            AaveV3ArbitrumAssets.WETH_A_TOKEN,
            AaveV3ArbitrumAssets.WETH_V_TOKEN,
            address(0),
            AAVE_V3
        );

        collateralTokens[TokensArbitrum.USDC][AAVE_V3] = AaveV3ArbitrumAssets.USDC_A_TOKEN;
        collateralTokens[TokensArbitrum.USDT][AAVE_V3] = AaveV3ArbitrumAssets.USDT_A_TOKEN;
        collateralTokens[TokensArbitrum.WBTC][AAVE_V3] = AaveV3ArbitrumAssets.WBTC_A_TOKEN;
        collateralTokens[TokensArbitrum.WETH][AAVE_V3] = AaveV3ArbitrumAssets.WETH_A_TOKEN;

        debtTokens[TokensArbitrum.USDC][AAVE_V3] = AaveV3ArbitrumAssets.USDC_V_TOKEN;
        debtTokens[TokensArbitrum.USDT][AAVE_V3] = AaveV3ArbitrumAssets.USDT_V_TOKEN;
        debtTokens[TokensArbitrum.WBTC][AAVE_V3] = AaveV3ArbitrumAssets.WBTC_V_TOKEN;
        debtTokens[TokensArbitrum.WETH][AAVE_V3] = AaveV3ArbitrumAssets.WETH_V_TOKEN;

        // approve pools
        address[] memory assets = new address[](4);
        assets[0] = TokensArbitrum.USDC;
        assets[1] = TokensArbitrum.WBTC;
        assets[2] = TokensArbitrum.WETH;
        assets[3] = TokensArbitrum.USDT;

        management.approveAddress(assets, AaveV3Arbitrum.POOL);
    }

    function initializeDeltaAvalon() internal virtual {
        // aave v3
        management.addGeneralLenderTokens(
            TokensArbitrum.USDC,
            AvalonArbitrumAssets.USDC_A_TOKEN,
            AvalonArbitrumAssets.USDC_V_TOKEN,
            address(0),
            AVALON
        );
        management.addGeneralLenderTokens(
            TokensArbitrum.USDT,
            AvalonArbitrumAssets.USDT_A_TOKEN,
            AvalonArbitrumAssets.USDT_V_TOKEN,
            address(0),
            AVALON
        );
        management.addGeneralLenderTokens(
            TokensArbitrum.WBTC,
            AvalonArbitrumAssets.WBTC_A_TOKEN,
            AvalonArbitrumAssets.WBTC_V_TOKEN,
            address(0),
            AVALON
        );
        management.addGeneralLenderTokens(
            TokensArbitrum.WETH,
            AvalonArbitrumAssets.WETH_A_TOKEN,
            AvalonArbitrumAssets.WETH_V_TOKEN,
            address(0),
            AVALON
        );

        collateralTokens[TokensArbitrum.USDC][AVALON] = AvalonArbitrumAssets.USDC_A_TOKEN;
        collateralTokens[TokensArbitrum.USDT][AVALON] = AvalonArbitrumAssets.USDT_A_TOKEN;
        collateralTokens[TokensArbitrum.WBTC][AVALON] = AvalonArbitrumAssets.WBTC_A_TOKEN;
        collateralTokens[TokensArbitrum.WETH][AVALON] = AvalonArbitrumAssets.WETH_A_TOKEN;

        debtTokens[TokensArbitrum.USDC][AVALON] = AvalonArbitrumAssets.USDC_V_TOKEN;
        debtTokens[TokensArbitrum.USDT][AVALON] = AvalonArbitrumAssets.USDT_V_TOKEN;
        debtTokens[TokensArbitrum.WBTC][AVALON] = AvalonArbitrumAssets.WBTC_V_TOKEN;
        debtTokens[TokensArbitrum.WETH][AVALON] = AvalonArbitrumAssets.WETH_V_TOKEN;

        // approve pools
        address[] memory assets = new address[](4);
        assets[0] = TokensArbitrum.USDC;
        assets[1] = TokensArbitrum.WBTC;
        assets[2] = TokensArbitrum.WETH;
        assets[3] = TokensArbitrum.USDT;

        management.approveAddress(assets, AvalonArbitrum.POOL);
    }

    function initializeDeltaVenus() internal virtual {
        collateralTokens[TokensArbitrum.USDC][VENUS] = VenusCoreArbitrum.USDC_A_TOKEN;
        collateralTokens[TokensArbitrum.USDT][VENUS] = VenusCoreArbitrum.USDT_A_TOKEN;
        collateralTokens[TokensArbitrum.WBTC][VENUS] = VenusCoreArbitrum.WBTC_A_TOKEN;
        collateralTokens[TokensArbitrum.WETH][VENUS] = VenusCoreArbitrum.WETH_A_TOKEN;

        // approve pools
        IManagement.BatchAddLenderTokensParams[] memory assets = new IManagement.BatchAddLenderTokensParams[](4);
        assets[0] = IManagement.BatchAddLenderTokensParams(TokensArbitrum.USDC, VenusCoreArbitrum.USDC_A_TOKEN, address(0), address(0), VENUS);
        assets[1] = IManagement.BatchAddLenderTokensParams(TokensArbitrum.WBTC, VenusCoreArbitrum.WBTC_A_TOKEN, address(0), address(0), VENUS);
        assets[2] = IManagement.BatchAddLenderTokensParams(TokensArbitrum.WETH, VenusCoreArbitrum.WETH_A_TOKEN, address(0), address(0), VENUS);
        assets[3] = IManagement.BatchAddLenderTokensParams(TokensArbitrum.USDT, VenusCoreArbitrum.USDT_A_TOKEN, address(0), address(0), VENUS);

        management.batchAddGeneralLenderTokens(assets);

        IManagement.ApproveParams[] memory approves = new IManagement.ApproveParams[](4);
        approves[0] = IManagement.ApproveParams(TokensArbitrum.USDC, VenusCoreArbitrum.USDC_A_TOKEN);
        approves[1] = IManagement.ApproveParams(TokensArbitrum.WBTC, VenusCoreArbitrum.WBTC_A_TOKEN);
        approves[2] = IManagement.ApproveParams(TokensArbitrum.WETH, VenusCoreArbitrum.WETH_A_TOKEN);
        approves[3] = IManagement.ApproveParams(TokensArbitrum.USDT, VenusCoreArbitrum.USDT_A_TOKEN);

        management.batchApprove(approves);
    }

    function initializeDeltaYldr() internal virtual {
        // aave v3
        management.addGeneralLenderTokens(TokensArbitrum.USDC, YLDRArbitrumAssets.USDC_A_TOKEN, YLDRArbitrumAssets.USDC_V_TOKEN, address(0), YLDR);
        management.addGeneralLenderTokens(TokensArbitrum.USDT, YLDRArbitrumAssets.USDT_A_TOKEN, YLDRArbitrumAssets.USDT_V_TOKEN, address(0), YLDR);
        management.addGeneralLenderTokens(TokensArbitrum.WBTC, YLDRArbitrumAssets.WBTC_A_TOKEN, YLDRArbitrumAssets.WBTC_V_TOKEN, address(0), YLDR);
        management.addGeneralLenderTokens(TokensArbitrum.WETH, YLDRArbitrumAssets.WETH_A_TOKEN, YLDRArbitrumAssets.WETH_V_TOKEN, address(0), YLDR);

        collateralTokens[TokensArbitrum.USDC][YLDR] = YLDRArbitrumAssets.USDC_A_TOKEN;
        collateralTokens[TokensArbitrum.USDT][YLDR] = YLDRArbitrumAssets.USDT_A_TOKEN;
        collateralTokens[TokensArbitrum.WBTC][YLDR] = YLDRArbitrumAssets.WBTC_A_TOKEN;
        collateralTokens[TokensArbitrum.WETH][YLDR] = YLDRArbitrumAssets.WETH_A_TOKEN;

        debtTokens[TokensArbitrum.USDC][YLDR] = YLDRArbitrumAssets.USDC_V_TOKEN;
        debtTokens[TokensArbitrum.USDT][YLDR] = YLDRArbitrumAssets.USDT_V_TOKEN;
        debtTokens[TokensArbitrum.WBTC][YLDR] = YLDRArbitrumAssets.WBTC_V_TOKEN;
        debtTokens[TokensArbitrum.WETH][YLDR] = YLDRArbitrumAssets.WETH_V_TOKEN;

        // approve pools
        address[] memory assets = new address[](4);
        assets[0] = TokensArbitrum.USDC;
        assets[1] = TokensArbitrum.WBTC;
        assets[2] = TokensArbitrum.WETH;
        assets[3] = TokensArbitrum.USDT;

        management.approveAddress(assets, YLDRArbitrum.POOL);
    }

    function initializeDeltaCompound() internal virtual {
        // approve pools
        address[] memory assets = new address[](5);
        assets[0] = TokensArbitrum.USDC;
        assets[1] = TokensArbitrum.WBTC;
        assets[2] = TokensArbitrum.WETH;
        assets[3] = TokensArbitrum.USDT;
        assets[4] = TokensArbitrum.WSTETH;

        management.approveAddress(assets, CompoundV3Arbitrum.COMET_USDC);
        management.approveAddress(assets, CompoundV3Arbitrum.COMET_USDT);
        management.approveAddress(assets, CompoundV3Arbitrum.COMET_WETH);
        management.approveAddress(assets, CompoundV3Arbitrum.COMET_USDCE);
    }

    function initializeDeltaBase() internal virtual {
        // quoter

        testQuoter = new TestQuoterArbitrum();
        management.clearCache();
    }

    function upgradeExistingDelta(address proxy, address admin, address oldModule) internal virtual {
        brokerProxyAddress = proxy;

        brokerProxy = IBrokerProxy(brokerProxyAddress);

        OneDeltaComposerArbitrum _aggregator = new OneDeltaComposerArbitrum();

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
        assetList[0] = TokensArbitrum.USDC;
        assetList[1] = TokensArbitrum.WBTC;
        assetList[2] = TokensArbitrum.WETH;
        assetList[4] = TokensArbitrum.USDT;
    }

    function setUp() public virtual {
        vm.createSelectFork({blockNumber: 290934482, urlOrAlias: "https://arbitrum.drpc.org"});
        router = new MockRouter(1.0e18, 12);
        intitializeFullDelta();
        management.setValidSingleTarget(address(router), true);
        // ensure test user to have native
        vm.deal(testUser, 1e18);
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

    function getBorrowBalance(address user, address asset, uint16 lenderId) internal returns (uint256) {
        if (lenderId < MAX_AAVE_V2_ID) {
            return IERC20All(debtTokens[asset][lenderId]).balanceOf(user);
        } else if (lenderId < MAX_ID_COMPOUND_V3) {
            if (lenderId == COMPOUND_V3_USDC) return IComet(CompoundV3Arbitrum.COMET_USDC).borrowBalanceOf(user);
            if (lenderId == COMPOUND_V3_USDT) return IComet(CompoundV3Arbitrum.COMET_USDT).borrowBalanceOf(user);
            if (lenderId == COMPOUND_V3_USDCE) return IComet(CompoundV3Arbitrum.COMET_USDCE).borrowBalanceOf(user);
            if (lenderId == COMPOUND_V3_WETH) return IComet(CompoundV3Arbitrum.COMET_WETH).borrowBalanceOf(user);
        } else {
            if (lenderId == VENUS) return IERC20All(collateralTokens[asset][lenderId]).borrowBalanceCurrent(user);
        }
        return 0;
    }

    function getCollateralBalance(address user, address asset, uint16 lenderId) internal returns (uint256) {
        if (lenderId < MAX_AAVE_V2_ID) {
            return IERC20All(collateralTokens[asset][lenderId]).balanceOf(user);
        } else if (lenderId < MAX_ID_COMPOUND_V3) {
            if (lenderId == COMPOUND_V3_USDC) return IComet(CompoundV3Arbitrum.COMET_USDC).userCollateral(user, asset).balance;
            if (lenderId == COMPOUND_V3_USDT) return IComet(CompoundV3Arbitrum.COMET_USDT).userCollateral(user, asset).balance;
            if (lenderId == COMPOUND_V3_WETH) return IComet(CompoundV3Arbitrum.COMET_WETH).userCollateral(user, asset).balance;
        } else {
            if (lenderId == VENUS) return IERC20All(collateralTokens[asset][lenderId]).balanceOfUnderlying(user);
        }
        return 0;
    }

    function approveWithdrawal(address user, address asset, uint256 amount, uint16 lenderId) internal {
        vm.startPrank(user);
        if (lenderId < MAX_AAVE_V2_ID) {
            IERC20All(collateralTokens[asset][lenderId]).approve(brokerProxyAddress, amount);
        } else if (lenderId < MAX_ID_COMPOUND_V3) {
            if (lenderId == COMPOUND_V3_USDC) IComet(CompoundV3Arbitrum.COMET_USDC).allow(brokerProxyAddress, true);
            if (lenderId == COMPOUND_V3_USDT) IComet(CompoundV3Arbitrum.COMET_USDT).allow(brokerProxyAddress, true);
            if (lenderId == COMPOUND_V3_WETH) IComet(CompoundV3Arbitrum.COMET_WETH).allow(brokerProxyAddress, true);
        } else {
            // need to approve max as we approve the collateral token adjusted for exchange rate
            if (lenderId == VENUS) IERC20All(collateralTokens[asset][lenderId]).approve(brokerProxyAddress, type(uint256).max);
        }
        vm.stopPrank();
    }

    function enterMarket(address user, address asset, uint16 lenderId) internal {
        vm.startPrank(user);
        if (lenderId == VENUS) {
            address[] memory enter = new address[](1);
            enter[0] = collateralTokens[asset][lenderId];
            ComptrollerInterface(VenusCoreArbitrum.COMPTROLLER).enterMarkets(enter);
        }
        vm.stopPrank();
    }

    function approveBorrowDelegation(address user, address asset, uint256 amount, uint16 lenderId) internal {
         vm.startPrank(user);
        if (lenderId < MAX_AAVE_V2_ID) {
            IERC20All(debtTokens[asset][lenderId]).approveDelegation(brokerProxyAddress, amount);
        } else if (lenderId < MAX_ID_COMPOUND_V3) {
            if (lenderId == COMPOUND_V3_USDC) IComet(CompoundV3Arbitrum.COMET_USDC).allow(brokerProxyAddress, true);
            if (lenderId == COMPOUND_V3_USDT) IComet(CompoundV3Arbitrum.COMET_USDT).allow(brokerProxyAddress, true);
            if (lenderId == COMPOUND_V3_WETH) IComet(CompoundV3Arbitrum.COMET_WETH).allow(brokerProxyAddress, true);
        } else {
            if (lenderId == VENUS) {
                ComptrollerInterface(VenusCoreArbitrum.COMPTROLLER).updateDelegate(brokerProxyAddress, true);
            }
        }
        vm.stopPrank();
    }

    /** HELPER FUNCTIONS */

    /** OPEN */

    function getOpenExactInSingle(address tokenIn, address tokenOut, uint16 lenderId) internal view returns (bytes memory data) {
        uint16 fee = DEX_FEE_STABLES;
        uint8 poolId = UNI_V3;
        address pool = testQuoter._v3TypePool(tokenIn, tokenOut, fee, poolId);
        (uint8 actionId, , uint8 endId) = getOpenExactInFlags();
        return abi.encodePacked(tokenIn, actionId, poolId, pool, fee, tokenOut, lenderId, endId);
    }

    function getOpenExactInSingle_izi(address tokenIn, address tokenOut, uint16 lenderId) internal view returns (bytes memory data) {
        uint16 fee = DEX_FEE_LOW_HIGH;
        uint8 poolId = IZUMI;
        address pool = testQuoter._getiZiPool(tokenIn, tokenOut, fee);
        (uint8 actionId, , uint8 endId) = getOpenExactInFlags();
        return abi.encodePacked(tokenIn, actionId, poolId, pool, fee, tokenOut, lenderId, endId);
    }

    function getSpotExactInSingle_izi(address tokenIn, address tokenOut) internal view returns (bytes memory data) {
        uint16 fee = DEX_FEE_LOW_HIGH;
        uint8 poolId = IZUMI;
        address pool = testQuoter._getiZiPool(tokenIn, tokenOut, fee);
        return abi.encodePacked(tokenIn, uint8(0), poolId, pool, fee, tokenOut);
    }

    function getSpotExactOutSingle_izi(address tokenIn, address tokenOut) internal view returns (bytes memory data) {
        uint16 fee = DEX_FEE_LOW_HIGH;
        uint8 poolId = IZUMI;
        address pool = testQuoter._getiZiPool(tokenIn, tokenOut, fee);
        return abi.encodePacked(tokenOut, uint8(0), poolId, pool, fee, tokenIn);
    }

    function getOpenExactOutSingle(address tokenIn, address tokenOut, uint16 lenderId) internal view returns (bytes memory data) {
        uint16 fee = DEX_FEE_LOW;
        uint8 poolId = UNI_V3;
        address pool = testQuoter._v3TypePool(tokenIn, tokenOut, fee, poolId);
        (uint8 actionId, , uint8 endId) = getOpenExactOutFlags();
        return abi.encodePacked(tokenOut, actionId, poolId, pool, fee, tokenIn, lenderId, endId);
    }

    function getOpenExactInMulti(address tokenIn, address tokenOut, uint16 lenderId) internal view returns (bytes memory data) {
        uint16 fee = DEX_FEE_LOW;
        (uint8 actionId, uint8 midId, uint8 endId) = getOpenExactInFlags();
        uint8 poolId = IZUMI;
        address pool = testQuoter._getiZiPool(tokenIn, TokensArbitrum.USDT, fee);
        bytes memory firstPart = abi.encodePacked(tokenIn, actionId, poolId, pool, fee, TokensArbitrum.USDT);
        fee = DEX_FEE_STABLES;
        poolId = SUSHI_V3;
        pool = testQuoter._v3TypePool(TokensArbitrum.USDT, tokenOut, fee, poolId);
        return abi.encodePacked(firstPart, midId, poolId, pool, fee, tokenOut, lenderId, endId);
    }

    function getOpenExactOutMulti(address tokenIn, address tokenOut, uint16 lenderId) internal view returns (bytes memory data) {
        uint16 fee = DEX_FEE_STABLES;
        (uint8 actionId, uint8 midId, uint8 endId) = getOpenExactOutFlags();
        uint8 poolId = SUSHI_V3;
        address pool = testQuoter._v3TypePool(tokenOut, TokensArbitrum.USDT, fee, poolId);
        bytes memory firstPart = abi.encodePacked(tokenOut, actionId, poolId, pool, fee, TokensArbitrum.USDT);
        fee = DEX_FEE_LOW;
        poolId = IZUMI;
        pool = testQuoter._getiZiPool(TokensArbitrum.USDT, tokenIn, fee);
        return abi.encodePacked(firstPart, midId, poolId, pool, fee, tokenIn, lenderId, endId);
    }

    /** CLOSE */

    function getCloseExactOutSingle(address tokenIn, address tokenOut, uint16 lenderId) internal view returns (bytes memory data) {
        uint16 fee = DEX_FEE_LOW;
        uint8 poolId = UNI_V3;
        address pool = testQuoter._v3TypePool(tokenIn, tokenOut, fee, poolId);
        (uint8 actionId, , uint8 endId) = getCloseExactOutFlags();
        return abi.encodePacked(tokenOut, actionId, poolId, pool, fee, tokenIn, lenderId, endId);
    }

    function getCloseExactInSingle(address tokenIn, address tokenOut, uint16 lenderId) internal view returns (bytes memory data) {
        uint16 fee = DEX_FEE_LOW;
        uint8 poolId = UNI_V3;
        address pool = testQuoter._v3TypePool(tokenIn, tokenOut, fee, poolId);
        (uint8 actionId, , uint8 endId) = getCloseExactInFlags();
        return abi.encodePacked(tokenIn, actionId, poolId, pool, fee, tokenOut, lenderId, endId);
    }

    function getCloseExactInMulti(address tokenIn, address tokenOut, uint16 lenderId) internal view returns (bytes memory data) {
        uint16 fee = DEX_FEE_LOW;
        (uint8 actionId, uint8 midId, uint8 endId) = getCloseExactInFlags();
        uint8 poolId = IZUMI;
        address pool = testQuoter._getiZiPool(TokensArbitrum.USDT, tokenIn, fee);
        bytes memory firstPart = abi.encodePacked(tokenIn, actionId, poolId, pool, fee, TokensArbitrum.USDT);
        fee = DEX_FEE_STABLES;
        poolId = SUSHI_V3;
        pool = testQuoter._v3TypePool(TokensArbitrum.USDT, tokenOut, fee, poolId);
        return abi.encodePacked(firstPart, midId, poolId, pool, fee, tokenOut, lenderId, endId);
    }

    function getCloseExactOutMulti(address tokenIn, address tokenOut, uint16 lenderId) internal view returns (bytes memory data) {
        uint16 fee = DEX_FEE_STABLES;
        (uint8 actionId, uint8 midId, uint8 endId) = getCloseExactOutFlags();
        uint8 poolId = SUSHI_V3;
        address pool = testQuoter._v3TypePool(TokensArbitrum.USDT, tokenOut, fee, poolId);
        bytes memory firstPart = abi.encodePacked(tokenOut, actionId, poolId, pool, fee, TokensArbitrum.USDT);
        fee = DEX_FEE_LOW;
        poolId = IZUMI;
        pool = testQuoter._getiZiPool(TokensArbitrum.USDT, tokenIn, fee);
        return abi.encodePacked(firstPart, midId, poolId, pool, fee, tokenIn, lenderId, endId);
    }

    /** COLLATERAL SWAP */

    function getCollateralSwapExactInSingle(address tokenIn, address tokenOut, uint16 lenderId) internal view returns (bytes memory data) {
        uint16 fee = DEX_FEE_STABLES;
        uint8 poolId = UNI_V3;
        address pool = testQuoter._v3TypePool(tokenIn, tokenOut, fee, poolId);
        (uint8 actionId, , uint8 endId) = getCollateralSwapExactInFlags();
        return abi.encodePacked(tokenIn, actionId, poolId, pool, fee, tokenOut, lenderId, endId);
    }

    function getCollateralSwapExactOutSingle(address tokenIn, address tokenOut, uint16 lenderId) internal view returns (bytes memory data) {
        uint16 fee = DEX_FEE_LOW;
        uint8 poolId = UNI_V3;
        address pool = testQuoter._v3TypePool(tokenIn, tokenOut, fee, poolId);
        (uint8 actionId, , uint8 endId) = getCollateralSwapExactOutFlags();
        return abi.encodePacked(tokenOut, actionId, poolId, pool, fee, tokenIn, lenderId, endId);
    }

    function getCollateralSwapExactInMulti(address tokenIn, address tokenOut, uint16 lenderId) internal view returns (bytes memory data) {
        uint16 fee = DEX_FEE_LOW_MEDIUM;
        (uint8 actionId, uint8 midId, uint8 endId) = getCollateralSwapExactInFlags();
        uint8 poolId = UNI_V3;
        address pool = testQuoter._v3TypePool(tokenIn, TokensArbitrum.WETH, fee, poolId);
        bytes memory firstPart = abi.encodePacked(tokenIn, actionId, poolId, pool, fee, TokensArbitrum.WETH);
        fee = DEX_FEE_LOW;
        poolId = SUSHI_V3;
        pool = testQuoter._v3TypePool(tokenOut, TokensArbitrum.WETH, fee, poolId);
        return abi.encodePacked(firstPart, midId, poolId, pool, fee, tokenOut, lenderId, endId);
    }

    function getCollateralSwapExactOutMulti(address tokenIn, address tokenOut, uint16 lenderId) internal view returns (bytes memory data) {
        uint16 fee = DEX_FEE_LOW_MEDIUM;
        (uint8 actionId, uint8 midId, uint8 endId) = getCollateralSwapExactOutFlags();
        uint8 poolId = UNI_V3;
        address pool = testQuoter._v3TypePool(tokenOut, TokensArbitrum.WETH, fee, poolId);
        bytes memory firstPart = abi.encodePacked(tokenOut, actionId, poolId, pool, fee, TokensArbitrum.WETH);
        fee = DEX_FEE_LOW;
        poolId = SUSHI_V3;
        pool = testQuoter._v3TypePool(tokenIn, TokensArbitrum.WETH, fee, poolId);
        return abi.encodePacked(firstPart, midId, poolId, pool, fee, tokenIn, lenderId, endId);
    }

    /** DEBT SWAP */

    function getDebtSwapExactInSingle(address tokenIn, address tokenOut, uint16 lenderId) internal view returns (bytes memory data) {
        uint16 fee = DEX_FEE_LOW_MEDIUM;
        uint8 poolId = UNI_V3;
        address pool = testQuoter._v3TypePool(tokenOut, tokenIn, fee, poolId);
        (uint8 actionId, , uint8 endId) = getDebtSwapExactInFlags();
        return abi.encodePacked(tokenIn, actionId, poolId, pool, fee, tokenOut, lenderId, endId);
    }

    function getDebtSwapExactOutSingle(address tokenIn, address tokenOut, uint16 lenderId) internal view returns (bytes memory data) {
        uint16 fee = DEX_FEE_LOW_MEDIUM;
        uint8 poolId = UNI_V3;
        address pool = testQuoter._v3TypePool(tokenOut, tokenIn, fee, poolId);
        (uint8 actionId, , uint8 endId) = getDebtSwapExactOutFlags();
        return abi.encodePacked(tokenOut, actionId, poolId, pool, fee, tokenIn, lenderId, endId);
    }

    function getDebtSwapExactInMulti(address tokenIn, address tokenOut, uint16 lenderId) internal view returns (bytes memory data) {
        uint16 fee = DEX_FEE_LOW;
        (uint8 actionId, uint8 midId, uint8 endId) = getDebtSwapExactInFlags();
        uint8 poolId = RAMSES;
        address pool = testQuoter._v3TypePool(tokenIn, TokensArbitrum.USDT, fee, poolId);
        bytes memory firstPart = abi.encodePacked(tokenIn, actionId, poolId, pool, fee, TokensArbitrum.USDT);
        fee = DEX_FEE_LOW;
        poolId = RAMSES;
        pool = testQuoter._v3TypePool(tokenOut, TokensArbitrum.USDT, fee, poolId);
        return abi.encodePacked(firstPart, midId, poolId, pool, fee, tokenOut, lenderId, endId);
    }

    function getDebtSwapExactOutMulti(address tokenIn, address tokenOut, uint16 lenderId) internal view returns (bytes memory data) {
        uint16 fee = DEX_FEE_LOW;
        (uint8 actionId, uint8 midId, uint8 endId) = getDebtSwapExactOutFlags();
        uint8 poolId = RAMSES;
        address pool = testQuoter._v3TypePool(tokenOut, TokensArbitrum.USDT, fee, poolId);
        bytes memory firstPart = abi.encodePacked(tokenOut, actionId, poolId, pool, fee, TokensArbitrum.USDT);
        fee = DEX_FEE_LOW;
        poolId = RAMSES;
        pool = testQuoter._v3TypePool(tokenIn, TokensArbitrum.USDT, fee, poolId);
        return abi.encodePacked(firstPart, midId, poolId, pool, fee, tokenIn, lenderId, endId);
    }

    /** OPEN */

    function getOpenExactInSingleV2(address tokenIn, address tokenOut, uint16 lenderId) internal view returns (bytes memory data) {
        uint8 poolId = CAMELOT_V2;
        (uint8 actionId, , uint8 endId) = getOpenExactInFlags();
        address pool = testQuoter._v2TypePairAddress(tokenIn, tokenOut, poolId);
        return abi.encodePacked(tokenIn, actionId, poolId, pool, tokenOut, lenderId, endId);
    }

    function getOpenExactOutSingleV2(address tokenIn, address tokenOut, uint16 lenderId) internal view returns (bytes memory data) {
        uint8 poolId = CAMELOT_V2;
        (uint8 actionId, , uint8 endId) = getOpenExactOutFlags();
        address pool = testQuoter._v2TypePairAddress(tokenIn, tokenOut, poolId);
        return abi.encodePacked(tokenOut, actionId, poolId, pool, tokenIn, lenderId, endId);
    }

    function getOpenExactInMultiV2(address tokenIn, address tokenOut, uint16 lenderId) internal view returns (bytes memory data) {
        (uint8 actionId, uint8 midId, uint8 endId) = getOpenExactInFlags();
        uint8 poolId = CAMELOT_V2;
        address pool = testQuoter._v2TypePairAddress(tokenIn, TokensArbitrum.USDT, poolId);
        bytes memory firstPart = abi.encodePacked(tokenIn, actionId, poolId, pool, TokensArbitrum.USDT);
        poolId = CAMELOT_V2;
        pool = testQuoter._v2TypePairAddress(TokensArbitrum.USDT, tokenOut, poolId);
        return abi.encodePacked(firstPart, midId, poolId, pool, tokenOut, lenderId, endId);
    }

    function getOpenExactOutMultiV2(address tokenIn, address tokenOut, uint16 lenderId) internal view returns (bytes memory data) {
        (uint8 actionId, uint8 midId, uint8 endId) = getOpenExactOutFlags();
        uint8 poolId = CAMELOT_V2;
        address pool = testQuoter._v2TypePairAddress(TokensArbitrum.USDT, tokenOut, poolId);
        bytes memory firstPart = abi.encodePacked(tokenOut, actionId, poolId, pool, TokensArbitrum.USDT);
        pool = testQuoter._v2TypePairAddress(tokenIn, TokensArbitrum.USDT, poolId);
        return abi.encodePacked(firstPart, midId, poolId, pool, tokenIn, lenderId, endId);
    }

    /** CLOSE */

    function getCloseExactOutSingleV2(address tokenIn, address tokenOut, uint16 lenderId) internal view returns (bytes memory data) {
        uint8 poolId = CAMELOT_V2;
        address pool = testQuoter._v2TypePairAddress(tokenIn, tokenOut, poolId);
        (uint8 actionId, , uint8 endId) = getCloseExactOutFlags();
        return abi.encodePacked(tokenOut, actionId, poolId, pool, tokenIn, lenderId, endId);
    }

    function getCloseExactInSingleV2(address tokenIn, address tokenOut, uint16 lenderId) internal view returns (bytes memory data) {
        uint8 poolId = CAMELOT_V2;
        address pool = testQuoter._v2TypePairAddress(tokenIn, tokenOut, poolId);
        (uint8 actionId, , uint8 endId) = getCloseExactInFlags();
        return abi.encodePacked(tokenIn, actionId, poolId, pool, tokenOut, lenderId, endId);
    }

    function getCloseExactInMultiV2(address tokenIn, address tokenOut, uint16 lenderId) internal view returns (bytes memory data) {
        (uint8 actionId, uint8 midId, uint8 endId) = getCloseExactInFlags();
        uint8 poolId = CAMELOT_V2;
        address pool = testQuoter._v2TypePairAddress(tokenIn, TokensArbitrum.USDT, poolId);
        bytes memory firstPart = abi.encodePacked(tokenIn, actionId, poolId, pool, TokensArbitrum.USDT);
        poolId = CAMELOT_V2;
        pool = testQuoter._v2TypePairAddress(tokenOut, TokensArbitrum.USDT, poolId);
        return abi.encodePacked(firstPart, midId, poolId, pool, tokenOut, lenderId, endId);
    }

    function getCloseExactOutMultiV2(address tokenIn, address tokenOut, uint16 lenderId) internal view returns (bytes memory data) {
        (uint8 actionId, uint8 midId, uint8 endId) = getCloseExactOutFlags();
        uint8 poolId = CAMELOT_V2;
        address pool = testQuoter._v2TypePairAddress(tokenOut, TokensArbitrum.USDT, poolId);
        bytes memory firstPart = abi.encodePacked(tokenOut, actionId, poolId, pool, TokensArbitrum.USDT);
        poolId = CAMELOT_V2;
        pool = testQuoter._v2TypePairAddress(tokenIn, TokensArbitrum.USDT, poolId);
        return abi.encodePacked(firstPart, midId, poolId, pool, tokenIn, lenderId, endId);
    }

    /** COLLATERAL SWAP */

    function getCollateralSwapExactInSingleV2(address tokenIn, address tokenOut, uint16 lenderId) internal view returns (bytes memory data) {
        uint8 poolId = CAMELOT_V2;
        address pool = testQuoter._v2TypePairAddress(tokenIn, tokenOut, poolId);
        (uint8 actionId, , uint8 endId) = getCollateralSwapExactInFlags();
        return abi.encodePacked(tokenIn, actionId, poolId, pool, tokenOut, lenderId, endId);
    }

    function getCollateralSwapExactOutSingleV2(address tokenIn, address tokenOut, uint16 lenderId) internal view returns (bytes memory data) {
        uint8 poolId = CAMELOT_V2;
        address pool = testQuoter._v2TypePairAddress(tokenIn, tokenOut, poolId);
        (uint8 actionId, , uint8 endId) = getCollateralSwapExactOutFlags();
        return abi.encodePacked(tokenOut, actionId, poolId, pool, tokenIn, lenderId, endId);
    }

    function getCollateralSwapExactInMultiV2(address tokenIn, address tokenOut, uint16 lenderId) internal view returns (bytes memory data) {
        (uint8 actionId, uint8 midId, uint8 endId) = getCollateralSwapExactInFlags();
        uint8 poolId = CAMELOT_V2;
        address pool = testQuoter._v2TypePairAddress(tokenIn, TokensArbitrum.WETH, poolId);
        bytes memory firstPart = abi.encodePacked(tokenIn, actionId, poolId, pool, TokensArbitrum.WETH);
        poolId = CAMELOT_V2;
        pool = testQuoter._v2TypePairAddress(tokenOut, TokensArbitrum.WETH, poolId);
        return abi.encodePacked(firstPart, midId, poolId, pool, tokenOut, lenderId, endId);
    }

    function getCollateralSwapExactOutMultiV2(address tokenIn, address tokenOut, uint16 lenderId) internal view returns (bytes memory data) {
        (uint8 actionId, uint8 midId, uint8 endId) = getCollateralSwapExactOutFlags();
        uint8 poolId = CAMELOT_V2;
        address pool = testQuoter._v2TypePairAddress(tokenOut, TokensArbitrum.WETH, poolId);
        bytes memory firstPart = abi.encodePacked(tokenOut, actionId, poolId, pool, TokensArbitrum.WETH);
        poolId = CAMELOT_V2;
        pool = testQuoter._v2TypePairAddress(tokenIn, TokensArbitrum.WETH, poolId);
        return abi.encodePacked(firstPart, midId, poolId, pool, tokenIn, lenderId, endId);
    }

    /** DEBT SWAP */

    function getDebtSwapExactInSingleV2(address tokenIn, address tokenOut, uint16 lenderId) internal view returns (bytes memory data) {
        uint8 poolId = CAMELOT_V2;
        address pool = testQuoter._v2TypePairAddress(tokenIn, tokenOut, poolId);
        (uint8 actionId, , uint8 endId) = getDebtSwapExactInFlags();
        return abi.encodePacked(tokenIn, actionId, poolId, pool, tokenOut, lenderId, endId);
    }

    function getDebtSwapExactOutSingleV2(address tokenIn, address tokenOut, uint16 lenderId) internal view returns (bytes memory data) {
        uint8 poolId = CAMELOT_V2;
        address pool = testQuoter._v2TypePairAddress(tokenIn, tokenOut, poolId);
        (uint8 actionId, , uint8 endId) = getDebtSwapExactOutFlags();
        return abi.encodePacked(tokenOut, actionId, poolId, pool, tokenIn, lenderId, endId);
    }

    function getDebtSwapExactInMultiV2(address tokenIn, address tokenOut, uint16 lenderId) internal view returns (bytes memory data) {
        (uint8 actionId, uint8 midId, uint8 endId) = getDebtSwapExactInFlags();
        uint8 poolId = CAMELOT_V2;
        address pool = testQuoter._v2TypePairAddress(tokenIn, TokensArbitrum.WETH, poolId);
        bytes memory firstPart = abi.encodePacked(tokenIn, actionId, poolId, pool, TokensArbitrum.WETH);
        poolId = CAMELOT_V2;
        pool = testQuoter._v2TypePairAddress(tokenOut, TokensArbitrum.WETH, poolId);
        return abi.encodePacked(firstPart, midId, poolId, pool, tokenOut, lenderId, endId);
    }

    function getDebtSwapExactOutMultiV2(address tokenIn, address tokenOut, uint16 lenderId) internal view returns (bytes memory data) {
        (uint8 actionId, uint8 midId, uint8 endId) = getDebtSwapExactOutFlags();
        uint8 poolId = CAMELOT_V2;
        address pool = testQuoter._v2TypePairAddress(tokenOut, TokensArbitrum.WETH, poolId);
        bytes memory firstPart = abi.encodePacked(tokenOut, actionId, poolId, pool, TokensArbitrum.WETH);
        poolId = CAMELOT_V2;
        pool = testQuoter._v2TypePairAddress(tokenIn, TokensArbitrum.WETH, poolId);
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

    function validAaveLender(uint16 id) internal pure returns (bool a) {
        a = id == 0 || id == 1 || id == 900;
    }

    function validVenusLender(uint16 id) internal pure returns (bool a) {
        a = id == 3000;
    }

    function validCompoundLender(uint16 id) internal pure returns (bool a) {
        a = id == 2000 || id == 2001 || id == 2002 || id == 2003;
    }

    function _deposit(address asset, address user, uint256 amount, uint16 lenderId) internal {
        deal(asset, user, amount);

        vm.prank(user);
        IERC20All(asset).approve(address(brokerProxyAddress), amount);

        bytes memory transfer = transferIn(
            asset,
            brokerProxyAddress,
            amount //
        );
        bytes memory data = deposit(
            asset,
            user,
            amount,
            lenderId //
        );
        data = abi.encodePacked(transfer, data);

        vm.prank(user);
        uint gas = gasleft();
        IFlashAggregator(brokerProxyAddress).deltaCompose(data);
        gas = gas - gasleft();
        console.log("gas", gas);

        enterMarket(user, asset, lenderId);
    }

    function _borrow(address borrowAsset, address user, uint256 borrowAmount, uint16 lenderId) internal {
        approveBorrowDelegation(user, borrowAsset, borrowAmount, lenderId);

        bytes memory data = borrow(
            borrowAsset,
            user,
            borrowAmount,
            lenderId, //
            DEFAULT_MODE
        );

        vm.prank(user);
        uint gas = gasleft();
        IFlashAggregator(brokerProxyAddress).deltaCompose(data);
        gas = gas - gasleft();
        console.log("gas", gas);
    }
}
