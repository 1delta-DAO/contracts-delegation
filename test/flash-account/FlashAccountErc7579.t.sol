// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import {FlashAccountErc7579} from "../../contracts/1delta/flash-account/FlashAccountErc7579.sol";
import {EntryPoint} from "account-abstraction/core/EntryPoint.sol";
import {PackedUserOperation} from "account-abstraction/core/UserOperationLib.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IPool} from "aave-v3-core/interfaces/IPool.sol";
import {IPoolAddressesProvider} from "aave-v3-core/interfaces/IPoolAddressesProvider.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";

contract FlashAccountErc7579Test is Test {
    using MessageHashUtils for bytes32;

    address public constant MAINNET_ENTRYPOINT_ADDRESS = 0x0000000071727De22E5E9d8BAf0edAc6f37da032;
    address public constant AAVE_POOL_ADDRESSES_PROVIDER = 0x2f39d218133AFaB8F2B819B1066c7E434Ad94E9e;
    address public constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address public constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address public constant VALIDATOR = 0x000000824dc138db84FD9109fc154bdad332Aa8E;

    address public constant ACCOUNT_FACTORY = 0x000000c3A93d2c5E02Cb053AC675665b1c4217F9;
    address public constant NEXUS_IMPLEMENTATION = 0x000000aC74357BFEa72BBD0781833631F732cf19;

    // Test user
    uint256 public constant PRIVATE_KEY = 0x1de17a;
    address public user;

    // Contracts
    FlashAccountErc7579 public module;
    EntryPoint public entryPoint;
    IPool public aavePool;
    address public account;

    function setUp() public {
        vm.createSelectFork("https://ethereum.blockpi.network/v1/rpc/public");

        user = vm.addr(PRIVATE_KEY);
        vm.deal(user, 100 ether);

        entryPoint = EntryPoint(payable(MAINNET_ENTRYPOINT_ADDRESS));
        module = new FlashAccountErc7579();
        aavePool = IPool(IPoolAddressesProvider(AAVE_POOL_ADDRESSES_PROVIDER).getPool());

        _createAndSetupAccount();
    }

    // Callback function that will be called by Aave
    // function executeOperation(
    //     address[] calldata assets,
    //     uint256[] calldata amounts,
    //     uint256[] calldata premiums,
    //     address initiator,
    //     bytes calldata params
    // ) external returns (bool) {
    //     // Verify this is called by Aave pool
    //     require(msg.sender == address(aavePool), "Caller not Aave pool");

    //     // Verify initiator is our account
    //     require(initiator == address(account), "Initiator not our account");

    //     // Here you would implement your flash loan logic
    //     // For example, swap WETH for USDC, then swap back

    //     // Approve repayment
    //     IERC20(WETH).approve(address(aavePool), amounts[0] + premiums[0]);

    //     return true;
    // }

    // function testFlashLoan() public {
    //     // Prepare flash loan parameters
    //     address[] memory assets = new address[](1);
    //     assets[0] = WETH;

    //     uint256[] memory amounts = new uint256[](1);
    //     amounts[0] = 1 ether;

    //     uint256[] memory modes = new uint256[](1);
    //     modes[0] = 0;

    //     bytes memory params = abi.encode(
    //         assets,
    //         amounts,
    //         modes,
    //         address(account),
    //         abi.encodeWithSelector(this.executeOperation.selector, assets, amounts, modes, address(account), "")
    //     );

    //     // Execute flash loan
    //     aavePool.flashLoanSimple(address(account), WETH, 1 ether, params, 0);
    // }

    function testModuleInstallation() public {
        assertTrue(module.isInitialized(address(account)));
    }

    function _createAndSetupAccount() internal {
        // install module call
        bytes memory moduleInstallCalldata = abi.encodeWithSelector(0x9517e29f, 2, address(module), "");

        // Create account with module installation
        bytes memory initData = abi.encode(NEXUS_IMPLEMENTATION, moduleInstallCalldata);

        uint128 verificationGasLimit = 1 << 24;
        uint128 callGasLimit = 1 << 24;
        uint128 maxPriorityFeePerGas = 1 << 8;
        uint128 maxFeePerGas = 1 << 8;

        initData = "";

        PackedUserOperation memory op = PackedUserOperation({
            sender: address(0),
            nonce: 0,
            initCode: abi.encodePacked(ACCOUNT_FACTORY, abi.encodeWithSelector(0xea6d13ac, initData)),
            callData: "",
            accountGasLimits: bytes32((uint256(verificationGasLimit) << 128) | callGasLimit),
            preVerificationGas: 1 << 24,
            gasFees: bytes32((uint256(maxPriorityFeePerGas) << 128) | maxFeePerGas),
            paymasterAndData: "",
            signature: ""
        });

        // Sign and execute userOp
        op.signature = _signUserOp(op);
        PackedUserOperation[] memory ops = new PackedUserOperation[](1);
        ops[0] = op;

        vm.prank(user);
        entryPoint.handleOps(ops, payable(user));

        // Get account address
        (bool success, bytes memory data) = ACCOUNT_FACTORY.call(abi.encodeWithSelector(0xfafa2b42, initData, 0));
        require(success, "Failed to create account");
        account = abi.decode(data, (address));

        // Fund account
        vm.deal(address(account), 100 ether);
    }

    function _signUserOp(PackedUserOperation memory userOp) internal view returns (bytes memory) {
        bytes32 opHash = entryPoint.getUserOpHash(userOp).toEthSignedMessageHash();
        return _signMessage(opHash);
    }

    function _signMessage(bytes32 messageHash) internal pure returns (bytes memory signature) {
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(PRIVATE_KEY, messageHash);
        signature = abi.encodePacked(r, s, v);
    }
}
