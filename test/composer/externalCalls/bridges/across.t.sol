// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

import {BaseTest} from "test/shared/BaseTest.sol";
import {Test} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";
import {CallForwarder} from "contracts/1delta/composer/generic/CallForwarder.sol";
import {BaseUtils} from "contracts/1delta/composer/generic/BaseUtils.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {CalldataLib} from "contracts/utils/CalldataLib.sol";
import {Chains, Tokens} from "test/data/LenderRegistry.sol";
import {ComposerPlugin, IComposerLike} from "plugins/ComposerPlugin.sol";
import {IAcrossSpokePool} from "contracts/1delta/composer/generic/bridges/Across/IAcross.sol";
import {SweepType} from "contracts/1delta/composer/enums/MiscEnums.sol";
import {MockSpokePool} from "test/mocks/MockSpokePool.sol";

// solhint-disable max-line-length

contract AcrossTest is BaseTest {
    using CalldataLib for bytes;

    // Contract instances
    CallForwarder private callForwarder;
    IComposerLike private composer;

    // Across contracts on Arbitrum
    address public constant SPOKE_POOL = 0xe35e9842fceaCA96570B734083f4a58e8F7C5f2A;

    // Test parameters
    uint32 public constant POLYGON_CHAIN_ID = 137;
    address public constant POLYGON_USDC = 0x3c499c542cEF5E3811e1192ce70d8cC03d5c3359;
    address public USDC;
    address public WETH = 0x7ceB23fD6bC0adD59E62ac25578270cFf1b9f619; // on polygon
    address public WETH9_arb = 0x82aF49447D8a07e3bd95BD0d56f35241523fBab1;

    // Test amounts
    uint256 public BRIDGE_AMOUNT = 1000 * 1e6; // 1000 USDC

    // Fee parameters
    uint128 public FIXED_FEE = 5 * 1e5; // 0.5 USDC
    uint32 public FEE_PERCENTAGE = 10e7; // 10% (100% is 1e9)

    function setUp() public virtual {
        rpcOverrides[Chains.ARBITRUM_ONE] = "https://api.zan.top/arb-one";

        _init(Chains.ARBITRUM_ONE, 0, true);

        callForwarder = new CallForwarder();

        composer = ComposerPlugin.getComposer(Chains.ARBITRUM_ONE);

        USDC = chain.getTokenAddress(Tokens.USDC);

        _fundUserWithToken(USDC, BRIDGE_AMOUNT);

        vm.label(address(callForwarder), "CallForwarder");
        vm.label(address(composer), "Composer");
        vm.label(SPOKE_POOL, "AcrossSpokePool");
        vm.label(USDC, "Arbitrum USDC");
        vm.label(WETH, "Polygon WETH");
        vm.label(user, "User");
        vm.label(POLYGON_USDC, "Polygon USDC");
        vm.label(WETH9_arb, "Arbitrum WETH9");
    }

    function setUpUnit() internal {
        _init(Chains.ARBITRUM_ONE, 0, false);

        callForwarder = new CallForwarder();

        composer = ComposerPlugin.getComposer(Chains.ARBITRUM_ONE);

        USDC = chain.getTokenAddress(Tokens.USDC);
        WETH9_arb = 0x82aF49447D8a07e3bd95BD0d56f35241523fBab1;
        WETH = 0x7ceB23fD6bC0adD59E62ac25578270cFf1b9f619;

        vm.label(address(callForwarder), "CallForwarder");
        vm.label(address(composer), "Composer");
        vm.label(USDC, "Arbitrum USDC");
        vm.label(WETH, "Polygon WETH");
        vm.label(user, "User");
        vm.label(WETH9_arb, "Arbitrum WETH9");
    }

    function test_integ_externalCall_across_bridge_token_balance() public {
        vm.startPrank(user);
        IERC20(USDC).approve(address(composer), BRIDGE_AMOUNT);

        composer.deltaCompose(
            abi.encodePacked(
                CalldataLib.encodeTransferIn(USDC, address(callForwarder), BRIDGE_AMOUNT),
                CalldataLib.encodeExternalCall(
                    address(callForwarder),
                    0,
                    false,
                    abi.encodePacked(
                        CalldataLib.encodeApprove(USDC, SPOKE_POOL),
                        CalldataLib.encodeAcrossBridgeToken(
                            SPOKE_POOL,
                            user,
                            USDC,
                            bytes32(uint256(uint160(POLYGON_USDC))),
                            0,
                            FIXED_FEE,
                            FEE_PERCENTAGE,
                            POLYGON_CHAIN_ID,
                            6,
                            6,
                            bytes32(uint256(uint160(user))),
                            uint32(block.timestamp + 1800),
                            new bytes(0)
                        ),
                        CalldataLib.encodeSweep(USDC, user, 0, SweepType.VALIDATE)
                    )
                )
            )
        );

        vm.stopPrank();
    }

    function test_integ_externalCall_across_bridge_token_amount() public {
        vm.startPrank(user);
        IERC20(USDC).approve(address(composer), BRIDGE_AMOUNT);

        composer.deltaCompose(
            abi.encodePacked(
                CalldataLib.encodeTransferIn(USDC, address(callForwarder), BRIDGE_AMOUNT),
                CalldataLib.encodeExternalCall(
                    address(callForwarder),
                    0,
                    false,
                    abi.encodePacked(
                        CalldataLib.encodeApprove(USDC, SPOKE_POOL),
                        CalldataLib.encodeAcrossBridgeToken(
                            SPOKE_POOL,
                            user,
                            USDC,
                            bytes32(uint256(uint160(POLYGON_USDC))),
                            BRIDGE_AMOUNT - 100e6,
                            FIXED_FEE,
                            FEE_PERCENTAGE,
                            POLYGON_CHAIN_ID,
                            6,
                            6,
                            bytes32(uint256(uint160(user))),
                            uint32(block.timestamp + 1800),
                            hex"abababff"
                        ),
                        CalldataLib.encodeSweep(USDC, user, 0, SweepType.VALIDATE)
                    )
                )
            )
        );

        console.log("balance", IERC20(USDC).balanceOf(address(callForwarder)));
        vm.stopPrank();
    }

    function test_integ_externalCall_across_bridge_native_balance() public {
        deal(address(composer), 1 ether + 0.001 ether);

        vm.startPrank(user);
        composer.deltaCompose(
            abi.encodePacked(
                CalldataLib.encodeSweep(address(0), address(callForwarder), 0, SweepType.VALIDATE),
                CalldataLib.encodeExternalCall(
                    address(callForwarder),
                    0,
                    false,
                    abi.encodePacked(
                        CalldataLib.encodeAcrossBridgeNative(
                            SPOKE_POOL,
                            user,
                            WETH9_arb,
                            bytes32(uint256(uint160(WETH))),
                            0,
                            0.001 ether,
                            FEE_PERCENTAGE,
                            POLYGON_CHAIN_ID,
                            18,
                            18,
                            bytes32(uint256(uint160(user))),
                            uint32(block.timestamp + 1800),
                            new bytes(0)
                        ),
                        CalldataLib.encodeSweep(address(0), user, 0, SweepType.VALIDATE)
                    )
                )
            )
        );
        vm.stopPrank();
    }

    function test_integ_externalCall_across_bridge_native_amount() public {
        deal(address(composer), 1 ether);

        vm.startPrank(user);
        composer.deltaCompose(
            abi.encodePacked(
                CalldataLib.encodeSweep(address(0), address(callForwarder), 0, SweepType.VALIDATE),
                CalldataLib.encodeExternalCall(
                    address(callForwarder),
                    0,
                    false,
                    abi.encodePacked(
                        CalldataLib.encodeAcrossBridgeNative(
                            SPOKE_POOL,
                            user,
                            WETH9_arb,
                            bytes32(uint256(uint160(WETH))),
                            1 ether,
                            0.001 ether,
                            FEE_PERCENTAGE,
                            POLYGON_CHAIN_ID,
                            18,
                            18,
                            bytes32(uint256(uint160(user))),
                            uint32(block.timestamp + 1800),
                            new bytes(0)
                        ),
                        CalldataLib.encodeSweep(address(0), user, 0, SweepType.VALIDATE)
                    )
                )
            )
        );
        vm.stopPrank();
    }

    function init_mockSpokePool() public returns (MockSpokePool) {
        deal(address(composer), 1 ether);

        return new MockSpokePool(
            bytes32(uint256(uint160(user))),
            bytes32(uint256(uint160(user))),
            bytes32(uint256(uint160(WETH9_arb))),
            bytes32(uint256(uint160(WETH))),
            1 ether,
            POLYGON_CHAIN_ID,
            uint32(block.timestamp + 1800),
            hex"1de17a0000abcdef0000"
        );
    }

    function test_unit_externalCall_across_bridge_validate_params() public {
        setUpUnit();
        MockSpokePool spokePool = init_mockSpokePool();

        vm.startPrank(user);
        composer.deltaCompose(
            abi.encodePacked(
                CalldataLib.encodeSweep(address(0), address(callForwarder), 0, SweepType.VALIDATE),
                CalldataLib.encodeExternalCall(
                    address(callForwarder),
                    0,
                    false,
                    abi.encodePacked(
                        CalldataLib.encodeAcrossBridgeNative(
                            address(spokePool),
                            user,
                            WETH9_arb,
                            bytes32(uint256(uint160(WETH))),
                            1 ether,
                            0.001 ether,
                            FEE_PERCENTAGE,
                            POLYGON_CHAIN_ID,
                            18,
                            18,
                            bytes32(uint256(uint160(user))),
                            uint32(block.timestamp + 1800),
                            hex"1de17a0000abcdef0000"
                        ),
                        CalldataLib.encodeSweep(address(0), user, 0, SweepType.VALIDATE)
                    )
                )
            )
        );
        vm.stopPrank();
    }

    function test_integ_externalCall_across_bridge_token_scale_down() public {
        _fundUserWithToken(WETH9_arb, 1 ether);

        vm.startPrank(user);
        IERC20(WETH9_arb).approve(address(composer), 1 ether);

        composer.deltaCompose(
            abi.encodePacked(
                CalldataLib.encodeTransferIn(WETH9_arb, address(callForwarder), 1 ether),
                CalldataLib.encodeExternalCall(
                    address(callForwarder),
                    0,
                    false,
                    abi.encodePacked(
                        CalldataLib.encodeApprove(WETH9_arb, SPOKE_POOL),
                        CalldataLib.encodeAcrossBridgeToken(
                            SPOKE_POOL,
                            user,
                            WETH9_arb,
                            bytes32(uint256(uint160(POLYGON_USDC))),
                            0,
                            FIXED_FEE,
                            FEE_PERCENTAGE,
                            POLYGON_CHAIN_ID,
                            18,
                            6,
                            bytes32(uint256(uint160(user))),
                            uint32(block.timestamp + 1800),
                            new bytes(0)
                        ),
                        CalldataLib.encodeSweep(WETH9_arb, user, 0, SweepType.VALIDATE)
                    )
                )
            )
        );
        vm.stopPrank();
    }

    function test_integ_externalCall_across_bridge_token_scale_up() public {
        _fundUserWithToken(USDC, 1000 * 1e6);

        vm.startPrank(user);
        IERC20(USDC).approve(address(composer), 1000 * 1e6);

        composer.deltaCompose(
            abi.encodePacked(
                CalldataLib.encodeTransferIn(USDC, address(callForwarder), 1000 * 1e6),
                CalldataLib.encodeExternalCall(
                    address(callForwarder),
                    0,
                    false,
                    abi.encodePacked(
                        CalldataLib.encodeApprove(USDC, SPOKE_POOL),
                        CalldataLib.encodeAcrossBridgeToken(
                            SPOKE_POOL,
                            user,
                            USDC,
                            bytes32(uint256(uint160(WETH))),
                            0,
                            FIXED_FEE,
                            FEE_PERCENTAGE,
                            POLYGON_CHAIN_ID,
                            6,
                            18,
                            bytes32(uint256(uint160(user))),
                            uint32(block.timestamp + 1800),
                            new bytes(0)
                        ),
                        CalldataLib.encodeSweep(USDC, user, 0, SweepType.VALIDATE)
                    )
                )
            )
        );
        vm.stopPrank();
    }

    function decimal_adjustment_logic() public {
        uint256 absDiff = 0;
        uint256 decimalAdjustment = 0;
        uint256 fromTokenDecimals = 6;
        uint256 toTokenDecimals = 18;
        assembly {
            let decimalDiff := sub(toTokenDecimals, fromTokenDecimals)
            if xor(fromTokenDecimals, toTokenDecimals) {
                // abs(decimalDiff)
                let mask := sar(255, decimalDiff)
                absDiff := sub(xor(decimalDiff, mask), mask)

                switch absDiff
                case 12 { decimalAdjustment := 1000000000000 }
                case 11 { decimalAdjustment := 100000000000 }
                case 10 { decimalAdjustment := 10000000000 }
                case 9 { decimalAdjustment := 1000000000 }
                case 8 { decimalAdjustment := 100000000 }
                case 7 { decimalAdjustment := 10000000 }
                case 6 { decimalAdjustment := 1000000 }
                default {
                    {
                        for { let i := 0 } lt(i, absDiff) { i := add(i, 1) } { decimalAdjustment := mul(decimalAdjustment, 10) }
                    }
                }
            }
        }

        console.log("fromTokenDecimals", fromTokenDecimals);
        console.log("toTokenDecimals", toTokenDecimals);
        console.log("decimalAdjustment", decimalAdjustment);
        console.log("absDiff", absDiff);
    }
}
