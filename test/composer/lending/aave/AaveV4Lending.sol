// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {IERC20All} from "test/shared/interfaces/IERC20All.sol";
import {BaseTest} from "test/shared/BaseTest.sol";
import {Chains, Tokens, Lenders} from "test/data/LenderRegistry.sol";
import "contracts/utils/CalldataLib.sol";
import {ComposerPlugin, IComposerLike} from "test/shared/composers/ComposerPlugin.sol";

// Minimal Aave V4 interfaces for testing

interface IHub {
    function getAssetId(address underlying) external view returns (uint256);
}

interface ISpoke {
    function getReserveId(address hub, uint256 assetId) external view returns (uint256);
    function getReserveCount() external view returns (uint256);

    function getUserSuppliedAssets(uint256 reserveId, address user) external view returns (uint256);
    function getUserTotalDebt(uint256 reserveId, address user) external view returns (uint256);

    function setUserPositionManager(address positionManager, bool approve) external;
    function setUsingAsCollateral(uint256 reserveId, bool usingAsCollateral, address onBehalfOf) external;
    function getUserReserveStatus(
        uint256 reserveId,
        address userAddress
    )
        external
        view
        returns (bool isCollateral, bool isBorrowed);

    function DOMAIN_SEPARATOR() external view returns (bytes32);
}

interface ITakerPositionManager {
    function approveWithdraw(address spoke, uint256 reserveId, address spender, uint256 amount) external;
    function approveBorrow(address spoke, uint256 reserveId, address spender, uint256 amount) external;
    function borrowAllowance(address spoke, uint256 reserveId, address owner, address spender) external view returns (uint256);
    function DOMAIN_SEPARATOR() external view returns (bytes32);
    function BORROW_PERMIT_TYPEHASH() external view returns (bytes32);
}

interface IConfigPositionManager {
    function setCanSetUsingAsCollateralPermission(address spoke, address delegatee, bool status) external;
    function DOMAIN_SEPARATOR() external view returns (bytes32);
    function SET_CAN_SET_USING_AS_COLLATERAL_PERMISSION_PERMIT_TYPEHASH() external view returns (bytes32);
}

contract AaveV4LendingTest is BaseTest {
    IComposerLike oneDV2;

    // Aave V4 Ethereum mainnet addresses
    address constant CORE_HUB = 0xCca852Bc40e560adC3b1Cc58CA5b55638ce826c9;
    address constant MAIN_SPOKE = 0x94e7A5dCbE816e498b89aB752661904E2F56c485;

    // Position managers activated on Main Spoke at block 24727090
    address constant GIVER_PM = 0x17A54b8d6D9C68e7fa1C7112AC998EA1BA51d11e;
    address constant TAKER_PM = 0x6c044c0D3801499bCAbfAd458B70880bc518e9F7;
    address constant CONFIG_PM = 0x51305839CE822a7b4b12AA7D86eA7005052d575c;

    address constant MORPHO_BLUE = 0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb;

    // EIP-712 type hashes for PM setup
    bytes32 constant SET_USER_PM_TYPEHASH = 0xba01f7bf3d3674c63670ec4a78b0d56aac1ad6e8c84468920b9e61bfe0b9851a;
    bytes32 constant PM_UPDATE_TYPEHASH = 0x187dbd227227274b90655fb4011fc21dd749e8966fc040bd91e0b92609202565;

    address internal USDC;
    address internal WETH;

    ISpoke spoke = ISpoke(MAIN_SPOKE);
    IHub hub = IHub(CORE_HUB);

    uint256 usdcReserveId;
    uint256 wethReserveId;

    uint256 internal constant forkBlock = 0;

    function setUp() public virtual {
        string memory chainName = Chains.ETHEREUM_MAINNET;

        _init(chainName, forkBlock, true);

        USDC = chain.getTokenAddress(Tokens.USDC);
        WETH = chain.getTokenAddress(Tokens.WETH);

        oneDV2 = ComposerPlugin.getComposer(chainName);

        // Resolve reserve IDs dynamically
        uint256 usdcAssetId = hub.getAssetId(USDC);
        usdcReserveId = spoke.getReserveId(CORE_HUB, usdcAssetId);

        uint256 wethAssetId = hub.getAssetId(WETH);
        wethReserveId = spoke.getReserveId(CORE_HUB, wethAssetId);

        vm.label(GIVER_PM, "GIVER_PM");
        vm.label(TAKER_PM, "TAKER_PM");
        vm.label(CONFIG_PM, "CONFIG_PM");
        vm.label(MORPHO_BLUE, "MORPHO_BLUE");
        vm.label(CORE_HUB, "CORE_HUB");
        vm.label(MAIN_SPOKE, "MAIN_SPOKE");
        vm.label(USDC, "USDC");
        vm.label(WETH, "WETH");
        vm.label(address(oneDV2), "oneDV2");
        vm.label(address(hub), "hub");
        vm.label(address(spoke), "spoke");
        vm.label(user, "user");
    }

    // ═══════════════════════════════════════════════════
    // Deposit
    // ═══════════════════════════════════════════════════

    function test_v4_deposit_basic() external {
        deal(USDC, user, 1000e6);
        uint256 amount = 100e6;

        vm.prank(user);
        IERC20All(USDC).approve(address(oneDV2), type(uint256).max);

        // User must approve GiverPM as position manager on spoke
        vm.prank(user);
        spoke.setUserPositionManager(GIVER_PM, true);

        uint256 supplyBefore = spoke.getUserSuppliedAssets(usdcReserveId, user);
        uint256 balanceBefore = IERC20All(USDC).balanceOf(user);

        bytes memory transferTo = CalldataLib.encodeTransferIn(USDC, address(oneDV2), amount);
        bytes memory d = CalldataLib.encodeAaveV4Deposit(USDC, amount, user, usdcReserveId, MAIN_SPOKE, GIVER_PM);

        vm.prank(user);
        oneDV2.deltaCompose(abi.encodePacked(transferTo, d));

        uint256 supplyAfter = spoke.getUserSuppliedAssets(usdcReserveId, user);
        uint256 balanceAfter = IERC20All(USDC).balanceOf(user);

        assertApproxEqAbs(supplyAfter - supplyBefore, amount, 1);
        assertApproxEqAbs(balanceBefore - balanceAfter, amount, 1);
    }

    // ═══════════════════════════════════════════════════
    // Borrow
    // ═══════════════════════════════════════════════════

    function test_v4_borrow_basic() external {
        // Deposit WETH as collateral
        _depositViaComposer(WETH, user, 10 ether);
        _enableCollateral(wethReserveId, user);

        uint256 amountToBorrow = 100e6;

        // User must approve TakerPM and grant borrow allowance to the composer
        vm.prank(user);
        spoke.setUserPositionManager(TAKER_PM, true);
        vm.prank(user);
        ITakerPositionManager(TAKER_PM).approveBorrow(MAIN_SPOKE, usdcReserveId, address(oneDV2), type(uint256).max);

        uint256 debtBefore = spoke.getUserTotalDebt(usdcReserveId, user);
        uint256 balanceBefore = IERC20All(USDC).balanceOf(user);

        bytes memory d = CalldataLib.encodeAaveV4Borrow(USDC, amountToBorrow, user, usdcReserveId, MAIN_SPOKE, TAKER_PM);

        vm.prank(user);
        oneDV2.deltaCompose(d);

        uint256 debtAfter = spoke.getUserTotalDebt(usdcReserveId, user);
        uint256 balanceAfter = IERC20All(USDC).balanceOf(user);

        assertApproxEqAbs(debtAfter - debtBefore, amountToBorrow, 1);
        assertApproxEqAbs(balanceAfter - balanceBefore, amountToBorrow, 1);
    }

    // ═══════════════════════════════════════════════════
    // Withdraw
    // ═══════════════════════════════════════════════════

    function test_v4_withdraw_basic() external {
        _depositViaComposer(USDC, user, 1000e6);

        uint256 amountToWithdraw = 100e6;

        // User must approve TakerPM and grant withdraw allowance to the composer
        vm.prank(user);
        spoke.setUserPositionManager(TAKER_PM, true);
        vm.prank(user);
        ITakerPositionManager(TAKER_PM).approveWithdraw(MAIN_SPOKE, usdcReserveId, address(oneDV2), type(uint256).max);

        uint256 supplyBefore = spoke.getUserSuppliedAssets(usdcReserveId, user);
        uint256 balanceBefore = IERC20All(USDC).balanceOf(user);

        bytes memory d = CalldataLib.encodeAaveV4Withdraw(USDC, amountToWithdraw, user, usdcReserveId, MAIN_SPOKE, TAKER_PM);

        vm.prank(user);
        oneDV2.deltaCompose(d);

        uint256 supplyAfter = spoke.getUserSuppliedAssets(usdcReserveId, user);
        uint256 balanceAfter = IERC20All(USDC).balanceOf(user);

        assertApproxEqAbs(supplyBefore - supplyAfter, amountToWithdraw, 1);
        assertApproxEqAbs(balanceAfter - balanceBefore, amountToWithdraw, 1);
    }

    // ═══════════════════════════════════════════════════
    // Repay
    // ═══════════════════════════════════════════════════

    function test_v4_repay_basic() external {
        _depositViaComposer(WETH, user, 10 ether);
        _enableCollateral(wethReserveId, user);
        _borrowViaComposer(USDC, user, 100e6);

        vm.prank(user);
        IERC20All(USDC).approve(address(oneDV2), type(uint256).max);

        uint256 amountToRepay = 50e6;

        uint256 debtBefore = spoke.getUserTotalDebt(usdcReserveId, user);
        uint256 balanceBefore = IERC20All(USDC).balanceOf(user);

        bytes memory transferTo = CalldataLib.encodeTransferIn(USDC, address(oneDV2), amountToRepay);
        bytes memory d = CalldataLib.encodeAaveV4Repay(USDC, amountToRepay, user, usdcReserveId, MAIN_SPOKE, GIVER_PM);

        vm.prank(user);
        oneDV2.deltaCompose(abi.encodePacked(transferTo, d));

        uint256 debtAfter = spoke.getUserTotalDebt(usdcReserveId, user);
        uint256 balanceAfter = IERC20All(USDC).balanceOf(user);

        assertApproxEqAbs(debtBefore - debtAfter, amountToRepay, 1);
        assertApproxEqAbs(balanceBefore - balanceAfter, amountToRepay, 1);
    }

    // ═══════════════════════════════════════════════════
    // Max amount tests
    // ═══════════════════════════════════════════════════

    function test_v4_repay_tryMax() external {
        _depositViaComposer(WETH, user, 10 ether);
        _enableCollateral(wethReserveId, user);
        _borrowViaComposer(USDC, user, 100e6);

        vm.prank(user);
        IERC20All(USDC).approve(address(oneDV2), type(uint256).max);

        // Transfer less than debt
        uint256 amountToRepay = 50e6;

        bytes memory transferTo = CalldataLib.encodeTransferIn(USDC, address(oneDV2), amountToRepay);
        bytes memory d = CalldataLib.encodeAaveV4Repay(USDC, type(uint112).max, user, usdcReserveId, MAIN_SPOKE, GIVER_PM);
        bytes memory sweep = CalldataLib.encodeSweep(USDC, user, 0, SweepType.VALIDATE);

        uint256 debtBefore = spoke.getUserTotalDebt(usdcReserveId, user);
        uint256 balanceBefore = IERC20All(USDC).balanceOf(user);

        vm.prank(user);
        oneDV2.deltaCompose(abi.encodePacked(transferTo, d, sweep));

        // Composer should have no leftover
        assertApproxEqAbs(IERC20All(USDC).balanceOf(address(oneDV2)), 0, 0);

        uint256 debtAfter = spoke.getUserTotalDebt(usdcReserveId, user);
        uint256 balanceAfter = IERC20All(USDC).balanceOf(user);

        assertApproxEqAbs(debtBefore - debtAfter, amountToRepay, 1);
        assertApproxEqAbs(balanceBefore - balanceAfter, amountToRepay, 1);
    }

    function test_v4_withdraw_max() external {
        uint256 depositAmount = 500e6;
        _depositViaComposer(USDC, user, depositAmount);

        // User must approve TakerPM and grant withdraw allowance to the composer
        vm.prank(user);
        spoke.setUserPositionManager(TAKER_PM, true);
        vm.prank(user);
        ITakerPositionManager(TAKER_PM).approveWithdraw(MAIN_SPOKE, usdcReserveId, address(oneDV2), type(uint256).max);

        uint256 supplyBefore = spoke.getUserSuppliedAssets(usdcReserveId, user);

        bytes memory d = CalldataLib.encodeAaveV4Withdraw(USDC, type(uint112).max, user, usdcReserveId, MAIN_SPOKE, TAKER_PM);

        vm.prank(user);
        oneDV2.deltaCompose(d);

        uint256 supplyAfter = spoke.getUserSuppliedAssets(usdcReserveId, user);
        uint256 balanceAfter = IERC20All(USDC).balanceOf(user);

        assertEq(supplyAfter, 0, "supply should be zero after max withdraw");
        assertApproxEqAbs(balanceAfter, depositAmount, 1);
    }

    function test_v4_set_collateral_via_composer() external {
        _depositViaComposer(WETH, user, 10 ether);

        // Setup: user approves ConfigPM and grants composer collateral-toggle rights
        vm.startPrank(user);
        spoke.setUserPositionManager(CONFIG_PM, true);
        IConfigPositionManager(CONFIG_PM).setCanSetUsingAsCollateralPermission(MAIN_SPOKE, address(oneDV2), true);
        vm.stopPrank();

        (bool colBefore,) = spoke.getUserReserveStatus(wethReserveId, user);
        assertFalse(colBefore, "should not be collateral yet");

        bytes memory d = CalldataLib.encodeAaveV4SetCollateral(wethReserveId, true, MAIN_SPOKE, CONFIG_PM);

        vm.prank(user);
        oneDV2.deltaCompose(d);

        (bool colAfter,) = spoke.getUserReserveStatus(wethReserveId, user);
        assertTrue(colAfter, "should be collateral now");
    }

    function test_v4_disable_collateral_via_composer() external {
        _depositViaComposer(WETH, user, 10 ether);
        _enableCollateral(wethReserveId, user);

        vm.startPrank(user);
        spoke.setUserPositionManager(CONFIG_PM, true);
        IConfigPositionManager(CONFIG_PM).setCanSetUsingAsCollateralPermission(MAIN_SPOKE, address(oneDV2), true);
        vm.stopPrank();

        (bool colBefore,) = spoke.getUserReserveStatus(wethReserveId, user);
        assertTrue(colBefore, "should be collateral");

        bytes memory d = CalldataLib.encodeAaveV4SetCollateral(wethReserveId, false, MAIN_SPOKE, CONFIG_PM);

        vm.prank(user);
        oneDV2.deltaCompose(d);

        (bool colAfter,) = spoke.getUserReserveStatus(wethReserveId, user);
        assertFalse(colAfter, "should not be collateral");
    }

    function test_v4_borrow_permit_via_composer() external {
        _depositViaComposer(WETH, user, 10 ether);
        _enableCollateral(wethReserveId, user);

        // User approves TakerPM as position manager (pre-requisite)
        vm.prank(user);
        spoke.setUserPositionManager(TAKER_PM, true);

        // Build EIP-712 BorrowPermit signature
        ITakerPositionManager taker = ITakerPositionManager(TAKER_PM);
        bytes32 domainSeparator = taker.DOMAIN_SEPARATOR();
        bytes32 borrowTypeHash = taker.BORROW_PERMIT_TYPEHASH();

        uint256 amount = type(uint256).max;
        uint256 nonce = 0; // first keyed nonce (key=0, seq=0)
        uint256 deadline = block.timestamp + 1 hours;

        bytes32 structHash =
            keccak256(abi.encode(borrowTypeHash, MAIN_SPOKE, usdcReserveId, user, address(oneDV2), amount, nonce, deadline));
        bytes32 digest = keccak256(abi.encodePacked("\x19\x01", domainSeparator, structHash));

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(userPrivateKey, digest);
        // compact sig: vs = (v - 27) << 255 | s
        bytes32 vs = bytes32((uint256(v - 27) << 255) | uint256(s));

        // Encode permit + borrow in one composer call
        bytes memory permitOp = CalldataLib.encodeAaveV4BorrowPermit(
            TAKER_PM,
            MAIN_SPOKE,
            usdcReserveId,
            amount,
            nonce,
            uint32(deadline + 1), // deadline+1 convention
            r,
            vs
        );

        uint256 amountToBorrow = 100e6;
        bytes memory borrowOp = CalldataLib.encodeAaveV4Borrow(USDC, amountToBorrow, user, usdcReserveId, MAIN_SPOKE, TAKER_PM);

        uint256 debtBefore = spoke.getUserTotalDebt(usdcReserveId, user);

        vm.prank(user);
        oneDV2.deltaCompose(abi.encodePacked(permitOp, borrowOp));

        uint256 debtAfter = spoke.getUserTotalDebt(usdcReserveId, user);
        assertApproxEqAbs(debtAfter - debtBefore, amountToBorrow, 1);
    }

    function test_v4_config_permit_via_composer() external {
        _depositViaComposer(WETH, user, 10 ether);

        // User approves ConfigPM as position manager (pre-requisite)
        vm.prank(user);
        spoke.setUserPositionManager(CONFIG_PM, true);

        // Build EIP-712 SetCanSetUsingAsCollateralPermissionPermit signature
        IConfigPositionManager config = IConfigPositionManager(CONFIG_PM);
        bytes32 domainSeparator = config.DOMAIN_SEPARATOR();
        bytes32 typeHash = config.SET_CAN_SET_USING_AS_COLLATERAL_PERMISSION_PERMIT_TYPEHASH();

        uint256 nonce = 0;
        uint256 deadline = block.timestamp + 1 hours;

        bytes32 structHash = keccak256(abi.encode(typeHash, MAIN_SPOKE, user, address(oneDV2), true, nonce, deadline));
        bytes32 digest = keccak256(abi.encodePacked("\x19\x01", domainSeparator, structHash));

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(userPrivateKey, digest);
        bytes32 vs = bytes32((uint256(v - 27) << 255) | uint256(s));

        // Compose: config permit + set collateral
        bytes memory permitOp =
            CalldataLib.encodeAaveV4ConfigPermit(CONFIG_PM, MAIN_SPOKE, true, nonce, uint32(deadline + 1), r, vs);

        bytes memory setColOp = CalldataLib.encodeAaveV4SetCollateral(wethReserveId, true, MAIN_SPOKE, CONFIG_PM);

        (bool colBefore,) = spoke.getUserReserveStatus(wethReserveId, user);
        assertFalse(colBefore);

        vm.prank(user);
        oneDV2.deltaCompose(abi.encodePacked(permitOp, setColOp));

        (bool colAfter,) = spoke.getUserReserveStatus(wethReserveId, user);
        assertTrue(colAfter);
    }

    function test_v4_deposit_enable_collateral_borrow_composite() external {
        deal(WETH, user, 10 ether);
        deal(USDC, user, 0);

        // Pre-approve PMs and permissions (simulating prior tx or via permits)
        vm.startPrank(user);
        IERC20All(WETH).approve(address(oneDV2), type(uint256).max);
        spoke.setUserPositionManager(GIVER_PM, true);
        spoke.setUserPositionManager(TAKER_PM, true);
        spoke.setUserPositionManager(CONFIG_PM, true);
        ITakerPositionManager(TAKER_PM).approveBorrow(MAIN_SPOKE, usdcReserveId, address(oneDV2), type(uint256).max);
        IConfigPositionManager(CONFIG_PM).setCanSetUsingAsCollateralPermission(MAIN_SPOKE, address(oneDV2), true);
        vm.stopPrank();

        uint256 depositAmount = 5 ether;
        uint256 borrowAmount = 1000e6;

        // Compose: transferIn + deposit + setCollateral + borrow
        bytes memory ops = abi.encodePacked(
            CalldataLib.encodeTransferIn(WETH, address(oneDV2), depositAmount),
            CalldataLib.encodeAaveV4Deposit(WETH, depositAmount, user, wethReserveId, MAIN_SPOKE, GIVER_PM),
            CalldataLib.encodeAaveV4SetCollateral(wethReserveId, true, MAIN_SPOKE, CONFIG_PM),
            CalldataLib.encodeAaveV4Borrow(USDC, borrowAmount, user, usdcReserveId, MAIN_SPOKE, TAKER_PM)
        );

        vm.prank(user);
        oneDV2.deltaCompose(ops);

        assertApproxEqAbs(spoke.getUserSuppliedAssets(wethReserveId, user), depositAmount, 1);
        (bool isCol,) = spoke.getUserReserveStatus(wethReserveId, user);
        assertTrue(isCol);
        assertApproxEqAbs(spoke.getUserTotalDebt(usdcReserveId, user), borrowAmount, 1);
        assertApproxEqAbs(IERC20All(USDC).balanceOf(user), borrowAmount, 1);
    }

    // deposit 10 ether of WETH, flash loan 10 ether of WETH, and borrow 10 ether of USDC
    function test_v4_flash_loan_weth_via_morpho_flash() external {
        uint256 depositAmount = 10 ether;
        uint256 flashAmount = 10 ether;
        uint256 deadline = block.timestamp + 1 hours;

        deal(WETH, user, depositAmount);

        vm.prank(user);
        IERC20All(WETH).approve(address(oneDV2), depositAmount);

        bytes memory ops = _buildLoopCalldata(depositAmount, flashAmount, deadline);

        vm.prank(user);
        oneDV2.deltaCompose(ops);

        assertApproxEqAbs(
            spoke.getUserSuppliedAssets(wethReserveId, user), depositAmount + flashAmount, 1, "supply should be deposit + flash"
        );
        assertApproxEqAbs(spoke.getUserTotalDebt(wethReserveId, user), flashAmount, 1, "debt should equal flash amount");
        (bool isCol,) = spoke.getUserReserveStatus(wethReserveId, user);
        assertTrue(isCol, "WETH should be collateral");
        assertEq(IERC20All(WETH).balanceOf(user), 0, "user should have no WETH left");
        assertEq(IERC20All(WETH).balanceOf(address(oneDV2)), 0, "composer should have no WETH left");
    }

    // ═══════════════════════════════════════════════════
    // Helpers
    // ═══════════════════════════════════════════════════

    function _buildLoopCalldata(uint256 depositAmount, uint256 flashAmount, uint256 deadline) internal returns (bytes memory) {
        bytes32 spokeDomain = spoke.DOMAIN_SEPARATOR();

        bytes memory permits = abi.encodePacked(
            _signPmSetup(GIVER_PM, spokeDomain, 0, deadline),
            _signPmSetup(TAKER_PM, spokeDomain, 1, deadline),
            _signPmSetup(CONFIG_PM, spokeDomain, 2, deadline),
            _signConfigPermit(deadline),
            _signBorrowPermit(wethReserveId, deadline)
        );

        bytes memory innerOps = abi.encodePacked(
            CalldataLib.encodeAaveV4Deposit(WETH, 0, user, wethReserveId, MAIN_SPOKE, GIVER_PM),
            CalldataLib.encodeAaveV4SetCollateral(wethReserveId, true, MAIN_SPOKE, CONFIG_PM),
            CalldataLib.encodeAaveV4Borrow(WETH, flashAmount, address(oneDV2), wethReserveId, MAIN_SPOKE, TAKER_PM)
        );

        return abi.encodePacked(
            CalldataLib.encodeTransferIn(WETH, address(oneDV2), depositAmount),
            permits,
            CalldataLib.encodeFlashLoan(WETH, flashAmount, MORPHO_BLUE, uint8(0), uint8(0), innerOps)
        );
    }

    function _signConfigPermit(uint256 deadline) internal returns (bytes memory) {
        bytes32 configDomain = IConfigPositionManager(CONFIG_PM).DOMAIN_SEPARATOR();
        bytes32 configTypeHash = IConfigPositionManager(CONFIG_PM).SET_CAN_SET_USING_AS_COLLATERAL_PERMISSION_PERMIT_TYPEHASH();

        bytes32 structHash = keccak256(abi.encode(configTypeHash, MAIN_SPOKE, user, address(oneDV2), true, uint256(0), deadline));
        bytes32 digest = keccak256(abi.encodePacked("\x19\x01", configDomain, structHash));

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(userPrivateKey, digest);
        bytes32 vs = bytes32((uint256(v - 27) << 255) | uint256(s));

        return CalldataLib.encodeAaveV4ConfigPermit(CONFIG_PM, MAIN_SPOKE, true, 0, uint32(deadline + 1), r, vs);
    }

    function _signBorrowPermit(uint256 reserveId, uint256 deadline) internal returns (bytes memory) {
        bytes32 takerDomain = ITakerPositionManager(TAKER_PM).DOMAIN_SEPARATOR();
        bytes32 borrowTypeHash = ITakerPositionManager(TAKER_PM).BORROW_PERMIT_TYPEHASH();

        bytes32 structHash = keccak256(
            abi.encode(borrowTypeHash, MAIN_SPOKE, reserveId, user, address(oneDV2), type(uint256).max, uint256(0), deadline)
        );
        bytes32 digest = keccak256(abi.encodePacked("\x19\x01", takerDomain, structHash));

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(userPrivateKey, digest);
        bytes32 vs = bytes32((uint256(v - 27) << 255) | uint256(s));

        return
            CalldataLib.encodeAaveV4BorrowPermit(
                TAKER_PM, MAIN_SPOKE, reserveId, type(uint256).max, 0, uint32(deadline + 1), r, vs
            );
    }

    function _signPmSetup(address pm, bytes32 spokeDomain, uint256 nonce, uint256 deadline) internal returns (bytes memory) {
        bytes32 elemHash = keccak256(abi.encode(PM_UPDATE_TYPEHASH, pm, true));
        bytes32 updatesHash = keccak256(abi.encodePacked(elemHash));

        bytes32 structHash = keccak256(abi.encode(SET_USER_PM_TYPEHASH, user, updatesHash, nonce, deadline));
        bytes32 digest = keccak256(abi.encodePacked("\x19\x01", spokeDomain, structHash));

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(userPrivateKey, digest);
        bytes32 vs = bytes32((uint256(v - 27) << 255) | uint256(s));

        return CalldataLib.encodeAaveV4PmSetupPermit(pm, MAIN_SPOKE, true, nonce, uint32(deadline + 1), r, vs);
    }

    function _depositViaComposer(address token, address userAddr, uint256 amount) internal {
        deal(token, userAddr, amount);

        uint256 reserveId = _getReserveId(token);

        vm.startPrank(userAddr);
        IERC20All(token).approve(address(oneDV2), type(uint256).max);
        spoke.setUserPositionManager(GIVER_PM, true);

        bytes memory transferTo = CalldataLib.encodeTransferIn(token, address(oneDV2), amount);
        bytes memory d = CalldataLib.encodeAaveV4Deposit(token, amount, userAddr, reserveId, MAIN_SPOKE, GIVER_PM);

        oneDV2.deltaCompose(abi.encodePacked(transferTo, d));
        vm.stopPrank();
    }

    function _borrowViaComposer(address token, address userAddr, uint256 amountToBorrow) internal {
        uint256 reserveId = _getReserveId(token);

        vm.startPrank(userAddr);
        spoke.setUserPositionManager(TAKER_PM, true);
        ITakerPositionManager(TAKER_PM).approveBorrow(MAIN_SPOKE, reserveId, address(oneDV2), type(uint256).max);

        bytes memory d = CalldataLib.encodeAaveV4Borrow(token, amountToBorrow, userAddr, reserveId, MAIN_SPOKE, TAKER_PM);
        oneDV2.deltaCompose(d);
        vm.stopPrank();
    }

    function _enableCollateral(uint256 reserveId, address userAddr) internal {
        vm.prank(userAddr);
        spoke.setUsingAsCollateral(reserveId, true, userAddr);
    }

    function _getReserveId(address token) internal view returns (uint256) {
        uint256 assetId = hub.getAssetId(token);
        return spoke.getReserveId(CORE_HUB, assetId);
    }
}
