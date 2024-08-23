// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import "./DeltaSetup.f.sol";

contract Debug is DeltaSetup {
    function setUp() public virtual override {
        vm.createSelectFork({blockNumber: 65602486, urlOrAlias: "https://mantle-mainnet.public.blastapi.io"});
        intitializeFullDelta();
    }

    function test_debug() external {
        address user = 0x91ae002a960e63Ccb0E5bDE83A8C13E51e1cB91A;
        vm.assume(user != address(0));
        address assetIn = WMNT;
        address assetOut = USDC;

        uint256 amountIn = 50000000000000000000;
        vm.deal(user, amountIn);

        bytes memory data = getCalldata();
        bytes memory test = sweep(USDC, 0x91ae002a960e63Ccb0E5bDE83A8C13E51e1cB91A, 0, SweepType.VALIDATE);
        console.logBytes(test);
        vm.prank(user);
        IERC20All(assetIn).approve(brokerProxyAddress, amountIn);

        uint256 balanceIn = user.balance;
        uint256 balanceOut = IERC20All(assetOut).balanceOf(user);

        vm.prank(user);
        IFlashAggregator(brokerProxyAddress).deltaCompose{value: amountIn}(data);

        balanceOut = IERC20All(assetOut).balanceOf(user) - balanceOut;
        balanceIn = balanceIn - user.balance;

        // swap 10, receive approx 10, but in 18 decs
        assertApproxEqAbs(38495951, balanceOut, 1);
        assertApproxEqAbs(balanceIn, amountIn, 0);
    }

    function test_debug2() external {
        address user = 0x91ae002a960e63Ccb0E5bDE83A8C13E51e1cB91A;
        vm.assume(user != address(0));
        address assetIn = USDC;
        address assetOut = WMNT;

        uint256 amountIn = 10.0e6;
        deal(assetIn, user, amountIn);

        bytes memory data = getComplexCalldata();
        vm.prank(user);
        IERC20All(assetIn).approve(brokerProxyAddress, amountIn);

        uint256 balanceIn = IERC20All(assetIn).balanceOf(user);
        uint256 balanceOut = IERC20All(assetOut).balanceOf(user);

        vm.prank(user);
        IFlashAggregator(brokerProxyAddress).deltaCompose(data);

        balanceOut = IERC20All(assetOut).balanceOf(user) - balanceOut;
        balanceIn = balanceIn - IERC20All(assetIn).balanceOf(user);

        // swap 10, receive approx 10, but in 18 decs
        assertApproxEqAbs(12912463706134820617, balanceOut, 1);
        assertApproxEqAbs(balanceIn, amountIn, 0);
    }

    function test_debug3() external {
        address user = 0x91ae002a960e63Ccb0E5bDE83A8C13E51e1cB91A;
        vm.assume(user != address(0));
        address assetIn = WMNT;
        address assetOut = USDY;

        uint256 maximumIn = 8.0e18;
        vm.deal(user, maximumIn);

        bytes memory data = getComplexCalldataExactOut();
        vm.prank(user);
        // IERC20All(assetIn).approve(brokerProxyAddress, maximumIn);

        uint256 balanceIn = IERC20All(assetIn).balanceOf(user);
        uint256 balanceOut = IERC20All(assetOut).balanceOf(user);

        vm.prank(user);
        IFlashAggregator(brokerProxyAddress).deltaCompose{value: maximumIn}(data);

        balanceOut = IERC20All(assetOut).balanceOf(user) - balanceOut;
        balanceIn = balanceIn - IERC20All(assetIn).balanceOf(user);

        // swap 10, receive approx 10, but in 18 decs
        assertApproxEqAbs(12912463706134820617, balanceOut, 1);
        assertApproxEqAbs(balanceIn, maximumIn, 0);
    }

    function test_debug4() external {
        address user = 0x91ae002a960e63Ccb0E5bDE83A8C13E51e1cB91A;
        vm.assume(user != address(0));
        address assetIn = USDC;

        uint256 amount = 8.0e18;
        vm.deal(user, amount);

        prepNativeDepo(user, amount);

        bytes memory data = getOpen();
        address debtAssetIn = debtTokens[assetIn][0];
        vm.prank(user);
        IERC20All(debtAssetIn).approveDelegation(brokerProxyAddress, 1e40);

        uint256 balanceIn = IERC20All(debtAssetIn).balanceOf(user);

        vm.prank(user);
        IFlashAggregator(brokerProxyAddress).deltaCompose(data);

        balanceIn = IERC20All(debtAssetIn).balanceOf(user) - balanceIn;

        // swap 10, receive approx 10, but in 18 decs
        // assertApproxEqAbs(12912463706134820617, balanceOut, 1);
        assertApproxEqAbs(balanceIn, 1999999, 0);
    }

    function prepNativeDepo(address user, uint256 am) internal {
        bytes memory data = deposit(WMNT, user, am, 0);
        data = abi.encodePacked(wrap(am), data);
        vm.prank(user);
        IFlashAggregator(brokerProxyAddress).deltaCompose{value: am}(data);
    }

    /** COMPOSER DATAS */

    function getCalldata() internal pure returns (bytes memory data) {
        data = hex"23000000000002b5e3af16b18800000091ae002a960e63ccb0e5bde83a8c13e51e1cb91a80000000000000000000000001cc0b670000000000022b1c8c1227a00000004278c1b0c915c4faa5fffa6cabf0219da63d7f4cb8000437a6b77f1a8ef09ac96e9cda3ed56f615802d713271009bc4e0d864854c6afb6eb9a9cdf58ac190d0df9ff090091ae002a960e63ccb0e5bde83a8c13e51e1cb91a80000000000000000000000000730fa00000000000008ac7230489e80000004278c1b0c915c4faa5fffa6cabf0219da63d7f4cb800011858d52cf57c07a018171d7a1e68dc081f17144f01f409bc4e0d864854c6afb6eb9a9cdf58ac190d0df9ff09";
    }

    function getComplexCalldata() internal pure returns (bytes memory data) {
        data = hex"0091ae002a960e63ccb0e5bde83a8c13e51e1cb91a0000000000000000194dc659d742278c000000000000000000000016e360004009bc4e0d864854c6afb6eb9a9cdf58ac190d0df90079ca455f94225a447c677ef0bf3a0c05626c090cd178c1b0c915c4faa5fffa6cabf0219da63d7f4cb8ff090091ae002a960e63ccb0e5bde83a8c13e51e1cb91a000000000000000010ce1741277aef8c00000000000000000000000f4240004009bc4e0d864854c6afb6eb9a9cdf58ac190d0df90064f9cda48949ae1823eecdd314deecd8599ceaf7cc78c1b0c915c4faa5fffa6cabf0219da63d7f4cb8ff090091ae002a960e63ccb0e5bde83a8c13e51e1cb91a0000000000000000086e1a27d3a5b919000000000000000000000007a120004009bc4e0d864854c6afb6eb9a9cdf58ac190d0df9007d78f641bd6cef5224b9b2e0bd0723eae36b8f36ae78c1b0c915c4faa5fffa6cabf0219da63d7f4cb8ff090091ae002a960e63ccb0e5bde83a8c13e51e1cb91a0000000000000000195c6eda35767f8b000000000000000000000016e360004209bc4e0d864854c6afb6eb9a9cdf58ac190d0df900017b3a4b36b0c5c95142afcd1b883ed055aa166f85006478c1b0c915c4faa5fffa6cabf0219da63d7f4cb8ff090091ae002a960e63ccb0e5bde83a8c13e51e1cb91a0000000000000000199f7548ad7f0965000000000000000000000016e360006e09bc4e0d864854c6afb6eb9a9cdf58ac190d0df900019cd55b03c64b65ba02a1d985caef63046b2d54eb00645be26527e817998a7206475496fde1e68957c5a60003e0d80d6377aadcb0a648cc157f593c60390385e7271078c1b0c915c4faa5fffa6cabf0219da63d7f4cb8ff090091ae002a960e63ccb0e5bde83a8c13e51e1cb91a000000000000000010da6027663bca3800000000000000000000000f4240006e09bc4e0d864854c6afb6eb9a9cdf58ac190d0df90003d837008202a9715b95e629d281104354f961a3ec01f45be26527e817998a7206475496fde1e68957c5a60003e92b806c34c8beea03d322942d9f271c91028f5f01f478c1b0c915c4faa5fffa6cabf0219da63d7f4cb8ff090091ae002a960e63ccb0e5bde83a8c13e51e1cb91a000000000000000010f7be7e16781c7b00000000000000000000000f4240006e09bc4e0d864854c6afb6eb9a9cdf58ac190d0df90003a81ede3710ea5249fdc1a81bb5664d004300ddb700645be26527e817998a7206475496fde1e68957c5a60003297badff77236228471f841f50a5d2d5ed943445006478c1b0c915c4faa5fffa6cabf0219da63d7f4cb8ff090091ae002a960e63ccb0e5bde83a8c13e51e1cb91a000000000000000010f84aebc4922e8500000000000000000000000f4240008209bc4e0d864854c6afb6eb9a9cdf58ac190d0df900325be26527e817998a7206475496fde1e68957c5a600006f4c4caed9e97d5a9146944af740a706cffa07d901f4cda86a272531e8640cd7f1a92c01839911b90bb00079f08764411376cce42fd05aac101494de13f1c39d78c1b0c915c4faa5fffa6cabf0219da63d7f4cb8ff090091ae002a960e63ccb0e5bde83a8c13e51e1cb91a00000000000000000884a6dffcbd7cae000000000000000000000007a120009809bc4e0d864854c6afb6eb9a9cdf58ac190d0df9009748c1a89af1102cad358549e9bb16ae5f96cddfec201eba5cc46d216ce6dc03f6a759e8e766e956ae0001e38e3a804ef845e36f277d86fb2b24b8c32b334000645be26527e817998a7206475496fde1e68957c5a60001594b231d5ac8cd9b86c89d7d326a21232176815901f478c1b0c915c4faa5fffa6cabf0219da63d7f4cb8ff090091ae002a960e63ccb0e5bde83a8c13e51e1cb91a0000000000000000088853bc77538181000000000000000000000007a120004209bc4e0d864854c6afb6eb9a9cdf58ac190d0df90000064d4c6e06711eaff5a9e2a19e750ee8b94159ab006478c1b0c915c4faa5fffa6cabf0219da63d7f4cb8ff09";
    }

    function getComplexCalldataExactOut() internal pure returns (bytes memory data) {
        data = hex"23000000000000628371c7695bc9b60191ae002a960e63ccb0e5bde83a8c13e51e1cb91a800000000000000022806b9a5450c7e000000000000018493fba64ef000000425be26527e817998a7206475496fde1e68957c5a60001de77967138622f3be5b49fa9e0777cd11c8b71b6006478c1b0c915c4faa5fffa6cabf0219da63d7f4cb8ff090191ae002a960e63ccb0e5bde83a8c13e51e1cb91a800000000000000018a3af6d6dfa84700000000000001158e460913d0000009a5be26527e817998a7206475496fde1e68957c5a600019cd55b03c64b65ba02a1d985caef63046b2d54eb006409bc4e0d864854c6afb6eb9a9cdf58ac190d0df90004aaa87a36b92344436adcd880677e6842b227d9310bb8deaddeaddeaddeaddeaddeaddeaddeaddead11110001928981fe5a4c005a126662d2bd84fbf139b51876006478c1b0c915c4faa5fffa6cabf0219da63d7f4cb8ff090191ae002a960e63ccb0e5bde83a8c13e51e1cb91a800000000000000018a194d7d77a2b7a0000000000001158e460913d000000985be26527e817998a7206475496fde1e68957c5a60001e38e3a804ef845e36f277d86fb2b24b8c32b33400064201eba5cc46d216ce6dc03f6a759e8e766e956ae00973f0047606dcad6177c13742f1854fc8c999cd2b6cda86a272531e8640cd7f1a92c01839911b90bb00003cc0f771fef9e9248ff296d127fad7bf0c69e655f0bb878c1b0c915c4faa5fffa6cabf0219da63d7f4cb8ff090191ae002a960e63ccb0e5bde83a8c13e51e1cb91a800000000000000009d11ca4f2f5fd1600000000000006f05b59d3b20000006e5be26527e817998a7206475496fde1e68957c5a600006f4c4caed9e97d5a9146944af740a706cffa07d901f4cda86a272531e8640cd7f1a92c01839911b90bb00001813d7f24df644550f824141bcdd8cb1cb0642d0601f478c1b0c915c4faa5fffa6cabf0219da63d7f4cb8ff090191ae002a960e63ccb0e5bde83a8c13e51e1cb91a800000000000000004eca542dca054d300000000000003782dace9d90000009a5be26527e817998a7206475496fde1e68957c5a60003214b8d4a67a996643cdb1bd80423a5f638cf258d01f4201eba5cc46d216ce6dc03f6a759e8e766e956ae0001551d49f0a9c3d5293293e12f36b210e0124dd4e709c4cda86a272531e8640cd7f1a92c01839911b90bb00003d114e1fdf9e4129b863a6af53806ae0f8c54ce8801f478c1b0c915c4faa5fffa6cabf0219da63d7f4cb8ff092491ae002a960e63ccb0e5bde83a8c13e51e1cb91a01000000000000628371c7695bc9b6";
    }

    function getOpen() internal pure returns (bytes memory data) {
        data = hex"0200000000000000000f188210161ee27300000000000000000000000dbba0004209bc4e0d864854c6afb6eb9a9cdf58ac190d0df9030437a6b77f1a8ef09ac96e9cda3ed56f615802d713271078c1b0c915c4faa5fffa6cabf0219da63d7f4cb800020200000000000000000bbf170a757499ff00000000000000000000000aae60004209bc4e0d864854c6afb6eb9a9cdf58ac190d0df90304cd07bcf06f3ad0eac869bdec3e9065864a34887500fa78c1b0c915c4faa5fffa6cabf0219da63d7f4cb80002020000000000000000035acc952c5bef190000000000000000000000030d40004209bc4e0d864854c6afb6eb9a9cdf58ac190d0df903011858d52cf57c07a018171d7a1e68dc081f17144f01f478c1b0c915c4faa5fffa6cabf0219da63d7f4cb80002020000000000000000035ba85534c572cb0000000000000000000000030d40009a09bc4e0d864854c6afb6eb9a9cdf58ac190d0df90304aaa87a36b92344436adcd880677e6842b227d9310bb8deaddeaddeaddeaddeaddeaddeaddeaddead11110001263fd2e2715386e6feca3f9d6de2ad94819b501f09c45be26527e817998a7206475496fde1e68957c5a60001de77967138622f3be5b49fa9e0777cd11c8b71b6006478c1b0c915c4faa5fffa6cabf0219da63d7f4cb80002";
    }
}
