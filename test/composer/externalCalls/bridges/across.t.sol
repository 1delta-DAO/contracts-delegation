// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

import {BaseTest} from "test/shared/BaseTest.sol";
import {Test} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";
import {CallForwarder} from "contracts/1delta/composer/generic/CallForwarder.sol";
import {BaseUtils} from "contracts/1delta/composer/generic/BaseUtils.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {CalldataLib} from "test/composer/utils/CalldataLib.sol";
import {Chains, Tokens} from "test/data/LenderRegistry.sol";
import {ComposerPlugin, IComposerLike} from "plugins/ComposerPlugin.sol";
import {IAcrossSpokePool} from "contracts/1delta/composer/generic/bridges/Across/IAcross.sol";
import {SweepType} from "contracts/1delta/composer/enums/MiscEnums.sol";

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

    function setUp() public {
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

    function test_across_bridge_token_balance() public {
        bytes memory message = new bytes(0);
        uint32 deadline = 1800;

        bytes memory forwarderCalldata = abi.encodePacked(
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
                bytes32(uint256(uint160(user))),
                deadline,
                message
            ),
            CalldataLib.encodeSweep(USDC, user, 0, SweepType.VALIDATE)
        );

        bytes memory composerCalldata = abi.encodePacked(
            CalldataLib.encodeTransferIn(USDC, address(callForwarder), BRIDGE_AMOUNT),
            CalldataLib.encodeExternalCall(address(callForwarder), 0, false, forwarderCalldata)
        );

        vm.startPrank(user);

        // Approve USDC to the CallForwarder
        IERC20(USDC).approve(address(composer), BRIDGE_AMOUNT);

        composer.deltaCompose(composerCalldata);

        vm.stopPrank();
    }

    function test_across_bridge_token_amount() public {
        bytes memory message = hex"abababff";
        uint32 deadline = 1800;

        bytes memory forwarderCalldata = abi.encodePacked(
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
                bytes32(uint256(uint160(user))),
                deadline,
                message
            ),
            //CalldataLib.encodeApprove(WETH9_arb, SPOKE_POOL),
            CalldataLib.encodeSweep(USDC, user, 0, SweepType.VALIDATE)
        );

        bytes memory composerCalldata = abi.encodePacked(
            CalldataLib.encodeTransferIn(USDC, address(callForwarder), BRIDGE_AMOUNT),
            CalldataLib.encodeExternalCall(address(callForwarder), 0, false, forwarderCalldata)
        );

        vm.startPrank(user);

        // Approve USDC to the CallForwarder
        IERC20(USDC).approve(address(composer), BRIDGE_AMOUNT);

        composer.deltaCompose(composerCalldata);

        uint256 balance = IERC20(USDC).balanceOf(address(callForwarder));
        console.log("balance", balance);

        vm.stopPrank();
    }

    function test_across_bridge_native_balance() public {
        uint256 eth_amount = 1 ether;
        uint128 fee = 0.001 ether;
        uint32 deadline = 1800;

        bytes memory message = new bytes(0);

        deal(address(composer), eth_amount + fee);

        bytes memory forwarderCalldata = abi.encodePacked(
            CalldataLib.encodeAcrossBridgeNative(
                SPOKE_POOL,
                user,
                WETH9_arb,
                bytes32(uint256(uint160(WETH))),
                0,
                fee,
                FEE_PERCENTAGE,
                POLYGON_CHAIN_ID,
                bytes32(uint256(uint160(user))),
                deadline,
                message
            ),
            CalldataLib.encodeSweep(address(0), user, 0, SweepType.VALIDATE) // sweep any remaining ETH
        );

        bytes memory composerCalldata = abi.encodePacked(
            CalldataLib.encodeSweep(address(0), address(callForwarder), 0, SweepType.VALIDATE), // transfer all eth to call forwarder
            CalldataLib.encodeExternalCall(address(callForwarder), 0, false, forwarderCalldata)
        );

        vm.startPrank(user);

        composer.deltaCompose(composerCalldata);

        vm.stopPrank();
    }

    function test_across_bridge_native_amount() public {
        uint256 eth_amount = 1 ether;
        uint128 fee = 0.001 ether;
        uint32 deadline = 1800;
        bytes memory message = new bytes(0);

        deal(address(composer), eth_amount);

        bytes memory forwarderCalldata = abi.encodePacked(
            CalldataLib.encodeAcrossBridgeNative(
                SPOKE_POOL,
                user,
                WETH9_arb,
                bytes32(uint256(uint160(WETH))),
                eth_amount,
                fee,
                FEE_PERCENTAGE,
                POLYGON_CHAIN_ID,
                bytes32(uint256(uint160(user))),
                deadline,
                message
            ),
            CalldataLib.encodeSweep(address(0), user, 0, SweepType.VALIDATE) // sweep any remaining ETH
        );

        bytes memory composerCalldata = abi.encodePacked(
            CalldataLib.encodeSweep(address(0), address(callForwarder), 0, SweepType.VALIDATE), // transfer all eth to call forwarder
            CalldataLib.encodeExternalCall(address(callForwarder), 0, false, forwarderCalldata)
        );

        vm.startPrank(user);

        composer.deltaCompose(composerCalldata);

        vm.stopPrank();
    }

    function test_across_bridge_validate_params() public {
        uint256 eth_amount = 1 ether;
        uint128 fee = 0.001 ether;
        uint32 deadline = 1800;
        bytes memory message = hex"1de17a0000abcdef0000";

        deal(address(composer), eth_amount);
        mockSpokePool spokePool = new mockSpokePool(
            bytes32(uint256(uint160(user))),
            bytes32(uint256(uint160(user))),
            bytes32(uint256(uint160(WETH9_arb))),
            bytes32(uint256(uint160(WETH))),
            eth_amount,
            POLYGON_CHAIN_ID,
            deadline,
            message
        );

        bytes memory forwarderCalldata = abi.encodePacked(
            CalldataLib.encodeAcrossBridgeNative(
                address(spokePool),
                user,
                WETH9_arb,
                bytes32(uint256(uint160(WETH))),
                eth_amount,
                fee,
                FEE_PERCENTAGE,
                POLYGON_CHAIN_ID,
                bytes32(uint256(uint160(user))),
                deadline,
                message
            ),
            CalldataLib.encodeSweep(address(0), user, 0, SweepType.VALIDATE) // sweep any remaining ETH
        );

        bytes memory composerCalldata = abi.encodePacked(
            CalldataLib.encodeSweep(address(0), address(callForwarder), 0, SweepType.VALIDATE), // transfer all eth to call forwarder
            CalldataLib.encodeExternalCall(address(callForwarder), 0, false, forwarderCalldata)
        );

        vm.startPrank(user);

        composer.deltaCompose(composerCalldata);

        vm.stopPrank();
    }
}

contract mockSpokePool {
    constructor(
        bytes32 _depositor,
        bytes32 _recipient,
        bytes32 _inputToken,
        bytes32 _outputToken,
        uint256 _inputAmount,
        uint256 _destinationChainId,
        uint32 _fillDeadline,
        bytes memory _message
    ) {
        depositor = _depositor;
        recipient = _recipient;
        inputToken = _inputToken;
        outputToken = _outputToken;
        inputAmount = _inputAmount;
        destinationChainId = _destinationChainId;
        fillDeadline = _fillDeadline;
        message = keccak256(_message);
    }

    bytes32 public depositor;
    bytes32 public recipient;
    bytes32 public inputToken;
    bytes32 public outputToken;
    uint256 public inputAmount;
    uint256 public destinationChainId;
    uint32 public fillDeadline;
    bytes32 public message;

    function deposit(
        bytes32 _depositor,
        bytes32 _recipient,
        bytes32 _inputToken,
        bytes32 _outputToken,
        uint256 _inputAmount,
        uint256 _outputAmount,
        uint256 _destinationChainId,
        bytes32 _exclusiveRelayer,
        uint32 _quoteTimestamp,
        uint32 _fillDeadline,
        uint32 _exclusivityDeadline,
        bytes memory _message
    )
        external
        payable
        returns (bytes memory)
    {
        // check fill deadline
        require(_fillDeadline == fillDeadline + block.timestamp, "fill deadline mismatch");

        require(_depositor == depositor, "depositor mismatch");
        require(_recipient == recipient, "recipient mismatch");
        require(_inputToken == inputToken, "inputToken mismatch");
        require(_outputToken == outputToken, "outputToken mismatch");
        require(_inputAmount == inputAmount, "inputAmount mismatch");
        require(_destinationChainId == destinationChainId, "destinationChainId mismatch");
        require(message == keccak256(_message), "message mismatch");
        return new bytes(0);
    }
}
