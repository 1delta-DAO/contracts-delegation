// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {BaseTest} from "test/shared/BaseTest.sol";
import {Chains} from "test/data/LenderRegistry.sol";
import {ComposerPlugin, IComposerLike} from "plugins/ComposerPlugin.sol";

// solhint-disable max-line-length

interface IA {
    function upgradeAndCall(address proxy, address implementation, bytes memory data) external;
}

contract ForkTestBnbDebtSwap is BaseTest {
    IComposerLike oneDV2;
    address public constant evc = 0xb2E5a73CeE08593d1a076a2AE7A6e02925a640ea;
    address admin = 0xb63E6455858887C8F6bda75C44c41570be989597;
    address owner = 0x999999833d965c275A2C102a4Ebf222ca938546f;
    address proxy = 0x816EBC5cb8A5651C902Cb06659907A93E574Db0B;

    address mockSender = 0x2b02769c9939553312795D7693d02857456Cc498;

    uint256 internal constant forkBlock = 0;

    function setUp() public virtual {
        string memory chainName = Chains.BNB_SMART_CHAIN_MAINNET;

        _init(chainName, forkBlock, true);

        vm.label(owner, "owner");
        vm.label(admin, "admin");
        vm.label(mockSender, "MeMeMeMe");
    }

    function test_fork_collateral_swap_bnb_venus() external {
        address a;
        bytes memory data;

        // 1. Approve sUSDe for deposit vault
        (data, a) = getDataApproveSUSDe();
        deal(a, mockSender, 5000e18);
        vm.prank(mockSender);
        address(a).call(data);

        // 2. Deposit sUSDe as collateral
        (data, a) = getDataDeposit();
        vm.prank(mockSender);
        address(a).call{value: 0}(data);

        // 1. Approve sUSDe for deposit vault
        (data, a) = getDataEnableCollateralBegin();
        vm.prank(mockSender);
        address(a).call(data);
        // 3. Borrow USDT
        (data, a) = getDataBorrow();
        vm.prank(mockSender);
        address(a).call{value: 0}(data);

        // 1. Approve sUSDe for deposit vault
        (data, a) = getDataEnableCollateral();
        vm.prank(mockSender);
        address(a).call(data);

        // 1. Approve sUSDe for deposit vault
        (data, a) = getDataApproveWithdraw();
        vm.prank(mockSender);
        address(a).call(data);

        // 3. Borrow USDT
        (data, a) = getDataBorrow();
        vm.prank(mockSender);
        address(a).call{value: 0}(data);

        // 4. Debt swap USDT → USD1
        (data, a) = getDataDebtSwap();
        vm.prank(mockSender);
        address(a).call{value: 0}(data);
    }

    // Approve sUSDe to deposit vault 0x1e55a40c...
    function getDataApproveSUSDe() internal pure returns (bytes memory d, address a) {
        a = address(0x7130d2A12B9BCbFAe4f2634d864A1Ee1Ce3Ead9c);
        d =
            hex"095ea7b3000000000000000000000000882c173bc7ff3b7786ca16dfed3dfffb9ee7847b0000000000000000000000000000000000000000000000001bc16d674ec80000";
    }

    // Approve sUSDe to deposit vault 0x1e55a40c...
    function getDataApproveWithdraw() internal pure returns (bytes memory d, address a) {
        a = address(0x882C173bC7Ff3b7786CA16dfeD3DFFfb9Ee7847B);
        d =
            hex"095ea7b3000000000000000000000000816ebc5cb8a5651c902cb06659907a93e574db0b000000000000000000000000000000000000000000000000000000000ea73dae";
    }

    // Approve sUSDe to deposit vault 0x1e55a40c...
    function getDataEnableCollateralBegin() internal pure returns (bytes memory d, address a) {
        a = address(0xfD36E2c2a6789Db23113685031d7F16329158384);
        d =
            hex"c299823800000000000000000000000000000000000000000000000000000000000000200000000000000000000000000000000000000000000000000000000000000001000000000000000000000000882c173bc7ff3b7786ca16dfed3dfffb9ee7847b";
    }

    // Approve sUSDe to deposit vault 0x1e55a40c...
    function getDataEnableCollateral() internal pure returns (bytes memory d, address a) {
        a = address(0xfD36E2c2a6789Db23113685031d7F16329158384);
        d =
            hex"c2998238000000000000000000000000000000000000000000000000000000000000002000000000000000000000000000000000000000000000000000000000000000010000000000000000000000006bca74586218db34cdb402295796b79663d816e9";
    }

    // Deposit 20 sUSDe as collateral via EVC batch
    function getDataDeposit() internal pure returns (bytes memory d, address a) {
        a = address(0x882C173bC7Ff3b7786CA16dfeD3DFFfb9Ee7847B);
        d = hex"a0712d680000000000000000000000000000000000000000000000001bc16d674ec80000";
    }

    // Borrow 5 USDT via EVC batch
    function getDataBorrow() internal pure returns (bytes memory d, address a) {
        a = address(0xfD5840Cd36d94D7229439859C0112a4185BC0255);
        d = hex"c5ebeaec00000000000000000000000000000000000000000000003635c9adc5dea00000";
    }

    // Debt swap USDT → USD1 via EVC batch
    // TODO: paste full hex from apiResponse.quotes[0].tx.data (log was truncated)
    function getDataDebtSwap() internal pure returns (bytes memory d, address a) {
        a = address(0x816EBC5cb8A5651C902Cb06659907A93E574Db0B);
        d =
            hex"17d730910000000000000000000000000000000000000000000000000000000000000020000000000000000000000000000000000000000000000000000000000000030440057130d2a12b9bcbfae4f2634d864a1ee1ce3ead9c8f73b65b4caaf64fba2af91cc5d4a2a1318e5d8c60007130d2a12b9bcbfae4f2634d864a1ee1ce3ead9c8f73b65b4caaf64fba2af91cc5d4a2a1318e5d8c000000000000000000b1a2bc2ec50000029e0040017130d2a12b9bcbfae4f2634d864a1ee1ce3ead9cfca11b85ac641f1ba215259566d579a45519e50601000000000000000000b1a2bc2ec5000020fca11b85ac641f1ba215259566d579a45519e50600000000000000000000000000000000017140057130d2a12b9bcbfae4f2634d864a1ee1ce3ead9c1a3304cbef66de00fbe1548cc4c6585ad22fbcff201a3304cbef66de00fbe1548cc4c6585ad22fbcff0000000000000000000000000000000001203f0bde25b221b6d6376903eba67b79811d07e216379a3982eed6000000000000000000b1a2bc2ec5000000000000000000004a31784e6ee3a71a0ab6d6376903eba67b79811d07e216379a3982eed6816ebc5cb8a5651c902cb06659907a93e574db0b7130d2a12b9bcbfae4f2634d864a1ee1ce3ead9cbb4cdb9cbd36b01bd1cbaebf2de08d9173bc095c62edaf2a56c9fb55be5f9b1399ac067f6a37013b28df0835942396b7a1b7ae1cd068728e6ddbbafd6811be5539ba6c92ff15f8270eb79fb28ad8e470afb2da14056725e3ba3a30dd846b6bbbd7886c560e09fabb73bd3ade0a17ecc321fd13a19e81ce822bfd1fc5e25a8f55c2e849492ad7966ea8a0dd9e4e04029a9e4e0502c8934406024607087f032f95e20929405b710301ff4005bb4cdb9cbd36b01bd1cbaebf2de08d9173bc095c6bca74586218db34cdb402295796b79663d816e930000f9fbb4cdb9cbd36b01bd1cbaebf2de08d9173bc095c000000000000000000000000000000002b02769c9939553312795d7693d02857456cc4986bca74586218db34cdb402295796b79663d816e930030f9f7130d2a12b9bcbfae4f2634d864a1ee1ce3ead9c000000000000000000b1a2bc2ec50000816ebc5cb8a5651c902cb06659907a93e574db0b882c173bc7ff3b7786ca16dfed3dfffb9ee7847b00000000000000000000000000000000000000000000000000000000";
        // NOTE: debt swap hex above is TRUNCATED from logs (50k char limit).
        // Re-run the TS test and paste full apiResponse.quotes[0].tx.data here.
    }
}
