// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import "./DeltaSetup.f.sol";
import "../../contracts/1delta/modules/shared/MetaAggregator.sol";
import "../../contracts/1delta/test/MockERC20WithPermit.sol";
import "../../contracts/1delta/test/MockRouter.sol";

contract Nothing {
    function call() external {}
}

contract MetaAggregatorTest is DeltaSetup {
    uint256 constant ERC20_PERMIT_LENGTH = 224;
    uint256 constant COMPACT_ERC20_PERMIT_LENGTH = 100;
    uint256 constant DAI_LIKE_PERMIT_LENGTH = 256;
    uint256 constant COMPACT_DAI_LIKE_PERMIT_LENGTH = 72;
    uint256 constant PERMIT2_LENGTH = 352;
    uint256 constant COMPACT_PERMIT2_LENGTH = 96;
    address constant PERMIT2 = 0x000000000022D473030F116dDEE9F6B43aC78BA3;

    function setUp() public override {
        vm.createSelectFork({blockNumber: 70125992, urlOrAlias: "https://mantle-mainnet.public.blastapi.io"});

        intitializeFullDelta();
    }

    function test_meta_aggregator() external {
        address user = testUser;
        vm.assume(user != address(0));

        DeltaMetaAggregator aggr = new DeltaMetaAggregator();
        Nothing _swapTarget = new Nothing();
        address swapTarget = address(_swapTarget);
        address token = USDT;

        deal(token, user, 20e20);

        uint256 amount = 1e6;

        vm.startPrank(user);
        IERC20All(token).approve(address(aggr), amount);

        uint256 gas = gasleft();
        aggr.swapMeta(
            "",
            abi.encodeWithSelector(Nothing.call.selector),
            token,
            amount,
            swapTarget,
            swapTarget,
            false
        );
        vm.stopPrank();

        gas = gas - gasleft();
        console.log("gas", gas);
    }

    function test_meta_aggregator_diff() external {
        address user = testUser;
        vm.assume(user != address(0));

        DeltaMetaAggregator aggr = new DeltaMetaAggregator();
        Nothing _swapTarget = new Nothing();
        Nothing _approvalTarget = new Nothing();
        address swapTarget = address(_swapTarget);
        address approvalTarget = address(_approvalTarget);
        address token = USDT;

        deal(token, user, 20e20);

        uint256 amount = 1e6;

        vm.startPrank(user);
        IERC20All(token).approve(address(aggr), amount);

        uint256 gas = gasleft();
        aggr.swapMeta(
            "",
            abi.encodeWithSelector(Nothing.call.selector), // no args
            token,
            amount,
            approvalTarget,
            swapTarget,
            false
        );
        vm.stopPrank();

        gas = gas - gasleft();
        console.log("gas", gas);
    }

    function test_meta_aggregator_erc20_permit() external {
        address user = testUser;
        vm.assume(user != address(0));

        MockERC20 tokenIn = new MockERC20("Mock", "MCK", 18);
        address assetOut = USDT;

        MockRouter router = new MockRouter(assetOut);
        DeltaMetaAggregator aggr = new DeltaMetaAggregator();

        address swapTarget = address(router);

        uint256 amountIn = 1e18;
        uint256 amountOut = 1e6;

        deal(address(tokenIn), user, amountIn);
        deal(assetOut, address(router), amountOut);
        router.setPayout(amountOut);

        bytes memory permitData = tokenIn.encodeERC20Permit(user, address(aggr), amountIn);
        bytes memory swapData = router.encodeSwap(address(tokenIn), amountIn, user);

        assertEq(permitData.length, ERC20_PERMIT_LENGTH);

        vm.startPrank(user);
        aggr.swapMeta(
            permitData,
            swapData,
            address(tokenIn),
            amountIn,
            swapTarget,
            swapTarget,
            false
        );
        vm.stopPrank();

        assertEq(tokenIn.balanceOf(user), 0);
        assertEq(IERC20All(assetOut).balanceOf(address(user)), amountOut);

        assertEq(tokenIn.balanceOf(address(router)), amountIn);
        assertEq(IERC20All(assetOut).balanceOf(address(router)), 0);

        assertEq(tokenIn.balanceOf(address(aggr)), 0);
        assertEq(IERC20All(assetOut).balanceOf(address(aggr)), 0);
    }

    function test_meta_aggregator_erc20_permit_compact() external {
        address user = testUser;
        vm.assume(user != address(0));

        MockERC20 tokenIn = new MockERC20("Mock", "MCK", 18);
        address assetOut = USDT;

        MockRouter router = new MockRouter(assetOut);
        DeltaMetaAggregator aggr = new DeltaMetaAggregator();

        address swapTarget = address(router);

        uint256 amountIn = 1e18;
        uint256 amountOut = 1e6;

        deal(address(tokenIn), user, amountIn);
        deal(assetOut, address(router), amountOut);
        router.setPayout(amountOut);

        bytes memory permitData = tokenIn.encodeCompactERC20Permit(amountIn);
        bytes memory swapData = router.encodeSwap(address(tokenIn), amountIn, user);

        assertEq(permitData.length, COMPACT_ERC20_PERMIT_LENGTH);

        vm.startPrank(user);
        aggr.swapMeta(
            permitData,
            swapData,
            address(tokenIn),
            amountIn,
            swapTarget,
            swapTarget,
            false
        );
        vm.stopPrank();

        assertEq(tokenIn.balanceOf(user), 0);
        assertEq(IERC20All(assetOut).balanceOf(address(user)), amountOut);

        assertEq(tokenIn.balanceOf(address(router)), amountIn);
        assertEq(IERC20All(assetOut).balanceOf(address(router)), 0);

        assertEq(tokenIn.balanceOf(address(aggr)), 0);
        assertEq(IERC20All(assetOut).balanceOf(address(aggr)), 0);
    }

    function test_meta_aggregator_dai_like_permit() external {
        address user = testUser;
        vm.assume(user != address(0));

        MockERC20 tokenIn = new MockERC20("Mock", "MCK", 18);
        address assetOut = USDT;

        MockRouter router = new MockRouter(assetOut);
        DeltaMetaAggregator aggr = new DeltaMetaAggregator();

        address swapTarget = address(router);

        uint256 amountIn = 1e18;
        uint256 amountOut = 1e6;

        deal(address(tokenIn), user, amountIn);
        deal(assetOut, address(router), amountOut);
        router.setPayout(amountOut);

        bytes memory permitData = tokenIn.encodeDaiLikePermit(user, address(aggr));
        bytes memory swapData = router.encodeSwap(address(tokenIn), amountIn, user);

        assertEq(permitData.length, DAI_LIKE_PERMIT_LENGTH);

        vm.startPrank(user);
        aggr.swapMeta(
            permitData,
            swapData,
            address(tokenIn),
            amountIn,
            swapTarget,
            swapTarget,
            false
        );
        vm.stopPrank();

        assertEq(tokenIn.balanceOf(user), 0);
        assertEq(IERC20All(assetOut).balanceOf(address(user)), amountOut);

        assertEq(tokenIn.balanceOf(address(router)), amountIn);
        assertEq(IERC20All(assetOut).balanceOf(address(router)), 0);

        assertEq(tokenIn.balanceOf(address(aggr)), 0);
        assertEq(IERC20All(assetOut).balanceOf(address(aggr)), 0);
    }

    function test_meta_aggregator_dai_like_permit_compact() external {
        address user = testUser;
        vm.assume(user != address(0));

        MockERC20 tokenIn = new MockERC20("Mock", "MCK", 18);
        address assetOut = USDT;

        MockRouter router = new MockRouter(assetOut);
        DeltaMetaAggregator aggr = new DeltaMetaAggregator();

        address swapTarget = address(router);

        uint256 amountIn = 1e18;
        uint256 amountOut = 1e6;

        deal(address(tokenIn), user, amountIn);
        deal(assetOut, address(router), amountOut);
        router.setPayout(amountOut);

        bytes memory permitData = tokenIn.encodeCompactDaiLikePermit();
        bytes memory swapData = router.encodeSwap(address(tokenIn), amountIn, user);

        assertEq(permitData.length, COMPACT_DAI_LIKE_PERMIT_LENGTH);

        vm.startPrank(user);
        aggr.swapMeta(
            permitData,
            swapData,
            address(tokenIn),
            amountIn,
            swapTarget,
            swapTarget,
            false
        );
        vm.stopPrank();

        assertEq(tokenIn.balanceOf(user), 0);
        assertEq(IERC20All(assetOut).balanceOf(address(user)), amountOut);

        assertEq(tokenIn.balanceOf(address(router)), amountIn);
        assertEq(IERC20All(assetOut).balanceOf(address(router)), 0);

        assertEq(tokenIn.balanceOf(address(aggr)), 0);
        assertEq(IERC20All(assetOut).balanceOf(address(aggr)), 0);
    }

    function test_meta_aggregator_permit2() external {
        setUp();
        address user = 0x334d52E24d452fa20489f07Bd943b7cF943Cb881;
        vm.assume(user != address(0));

        address assetIn = WMNT;
        address assetOut = USDT;

        MockRouter router = new MockRouter(assetOut);
        DeltaMetaAggregator aggr = DeltaMetaAggregator(payable(0x12bb99c93D6A72b49a4E090be0721B98E6d2Af99));
        address swapTarget = address(router);

        uint256 amountIn = 1e16;
        uint256 amountOut = 1e6;

        deal(assetIn, user, amountIn);
        deal(assetOut, address(router), amountOut);
        router.setPayout(amountOut);

        uint256 assetInBalanceBefore = IERC20All(assetIn).balanceOf(user);
        uint256 assetOutBalanceBefore = IERC20All(assetOut).balanceOf(user);

        // solhint-disable-next-line max-line-length
        bytes memory permitData = hex"000000000000000000000000334d52e24d452fa20489f07bd943b7cf943cb88100000000000000000000000078c1b0c915c4faa5fffa6cabf0219da63d7f4cb8000000000000000000000000000000000000000000000000002386f26fc100000000000000000000000000000000000000000000000000000000000067051096000000000000000000000000000000000000000000000000000000000000000000000000000000000000000012bb99c93d6a72b49a4e090be0721b98e6d2af990000000000000000000000000000000000000000000000000000000067051096000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000000403c9491b4c75f294dccefcdd06ddb79594091042e4e3ac8706df8178aac49e4e96fff87b395daa59b287b81e6c827652c58cfadbd9a6c3f5b18f5dae4323394f8";
        bytes memory swapData = router.encodeSwap(assetIn, amountIn, user);

        assertEq(permitData.length, PERMIT2_LENGTH);

        vm.startPrank(user);
        IERC20All(assetIn).approve(PERMIT2, type(uint256).max);
        aggr.swapMeta(
            permitData,
            swapData,
            assetIn,
            amountIn,
            swapTarget,
            swapTarget,
            false
        );
        vm.stopPrank();

        assertEq(IERC20All(assetIn).balanceOf(user), assetInBalanceBefore - amountIn);
        assertEq(IERC20All(assetOut).balanceOf(user), amountOut + assetOutBalanceBefore);

        assertEq(IERC20All(assetIn).balanceOf(address(router)), amountIn);
        assertEq(IERC20All(assetOut).balanceOf(address(router)), 0);

        assertEq(IERC20All(assetIn).balanceOf(address(aggr)), 0);
        assertEq(IERC20All(assetOut).balanceOf(address(aggr)), 0);
    }

    function test_meta_aggregator_permit2_compact() external {
        setUp();
        address user = 0x334d52E24d452fa20489f07Bd943b7cF943Cb881;
        vm.assume(user != address(0));

        address assetIn = WMNT;
        address assetOut = USDT;

        MockRouter router = new MockRouter(assetOut);
        DeltaMetaAggregator aggr = DeltaMetaAggregator(payable(0x12bb99c93D6A72b49a4E090be0721B98E6d2Af99));
        address swapTarget = address(router);

        uint256 amountIn = 1e16;
        uint256 amountOut = 1e6;

        deal(assetIn, user, amountIn);
        deal(assetOut, address(router), amountOut);
        router.setPayout(amountOut);

        uint256 assetInBalanceBefore = IERC20All(assetIn).balanceOf(user);
        uint256 assetOutBalanceBefore = IERC20All(assetOut).balanceOf(user);

        // solhint-disable-next-line max-line-length
        bytes memory permitData = hex"000000000000000000000000002386f26fc100006705116900000000670511691229c02fa9f78e03729e2f404ffc69f245cba2f1f21c5b85c429d2944e98e4b326f559a7a30a09e7afbed8032d68d1e2c6f594c231c9e817ccd48e695a89a9ac";
        bytes memory swapData = router.encodeSwap(assetIn, amountIn, user);

        assertEq(permitData.length, COMPACT_PERMIT2_LENGTH);

        vm.startPrank(user);
        IERC20All(assetIn).approve(PERMIT2, type(uint256).max);
        aggr.swapMeta(
            permitData,
            swapData,
            assetIn,
            amountIn,
            swapTarget,
            swapTarget,
            false
        );
        vm.stopPrank();

        assertEq(IERC20All(assetIn).balanceOf(user), assetInBalanceBefore - amountIn);
        assertEq(IERC20All(assetOut).balanceOf(user), amountOut + assetOutBalanceBefore);

        assertEq(IERC20All(assetIn).balanceOf(address(router)), amountIn);
        assertEq(IERC20All(assetOut).balanceOf(address(router)), 0);

        assertEq(IERC20All(assetIn).balanceOf(address(aggr)), 0);
        assertEq(IERC20All(assetOut).balanceOf(address(aggr)), 0);
    }

    function test_meta_aggregator_transfer_from_exploit() external {
        address user = testUser;
        address exploiter = 0xc0ffee254729296a45a3885639AC7E10F9d54979;
        vm.assume(user != address(0) && exploiter != address(0));

        MockERC20 tokenIn = new MockERC20("Mock", "MCK", 18);
        DeltaMetaAggregator aggr = new DeltaMetaAggregator();

        address swapTarget = address(tokenIn);
        uint256 amountIn = 1e18;

        deal(address(tokenIn), user, amountIn);

        vm.startPrank(user);
        tokenIn.approve(address(aggr), amountIn);
        vm.stopPrank();

        vm.startPrank(exploiter);
        bytes memory swapData = tokenIn.encodeTransferFrom(user, exploiter, amountIn);
        vm.expectRevert(0xee68db59); // custom error 0xee68db59
        aggr.swapMeta(
            "",
            swapData,
            address(tokenIn),
            amountIn,
            swapTarget,
            swapTarget,
            false
        );
        vm.stopPrank();
    }

    function test_meta_aggregator_permit2_exploit() external {
        address user = testUser;
        address exploiter = 0xc0ffee254729296a45a3885639AC7E10F9d54979;
        vm.assume(user != address(0) && exploiter != address(0));

        MockERC20 tokenIn = new MockERC20("Mock", "MCK", 18);
        DeltaMetaAggregator aggr = new DeltaMetaAggregator();

        address swapTarget = PERMIT2;
        uint256 amountIn = 1e18;

        vm.startPrank(exploiter);
        bytes memory swapData = tokenIn.encodePermit2TransferFrom(user, exploiter, amountIn, address(tokenIn));
        vm.expectRevert(0xee68db59); // custom error 0xee68db59
        aggr.swapMeta(
            "",
            swapData,
            address(0),
            0,
            swapTarget,
            swapTarget,
            false
        );
        vm.stopPrank();
    }

    function test_meta_aggregator_contract_exploit() external {
        address user = testUser;
        address exploiter = 0xc0ffee254729296a45a3885639AC7E10F9d54979;
        vm.assume(user != address(0) && exploiter != address(0));

        MockERC20 tokenIn = new MockERC20("Mock", "MCK", 18);
        MockRouter router = new MockRouter(address(tokenIn));
        DeltaMetaAggregator aggr = new DeltaMetaAggregator();

        address swapTarget = address(tokenIn);
        uint256 amountIn = 1e18;

        deal(address(tokenIn), user, amountIn);

        vm.startPrank(user);
        tokenIn.approve(address(aggr), amountIn);
        vm.stopPrank();

        vm.startPrank(exploiter);
        bytes memory swapData = router.encodeSwap(address(tokenIn), amountIn, exploiter);
        vm.expectRevert(); // ERC20: transfer amount exceeds balance
        aggr.swapMeta(
            "",
            swapData,
            address(tokenIn),
            amountIn,
            swapTarget,
            swapTarget,
            false
        );
        vm.stopPrank();
    }
}
