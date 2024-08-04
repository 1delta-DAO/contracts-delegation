// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import "../../contracts/1delta/modules/shared/Commands.sol";
import "../shared/interfaces/ICurvePool.sol";
import "./DeltaSetup.f.sol";
import "./utils/BalancerCaller.sol";

contract CurveTestPolygon is DeltaSetup {
    address internal constant three_pool = 0x03cD191F589d12b0582a99808cf19851E468E6B5;
    bytes32 internal constant three_pool_id = 0x03cd191f589d12b0582a99808cf19851e468e6b500010000000000000000000a;

    function test_polygon_balancer_exact_out() external {
        address user = testUser;
        uint256 amount = 0.1e8;
        uint256 maxIn = 10.0e18;
        uint gas;
        address assetIn = WETH;
        address assetOut = WBTC;
        deal(assetIn, user, 1e23);

        bytes memory dataBalancer = getSpotExactOutBalancer(assetIn, assetOut, three_pool_id);

        bytes memory data = abi.encodePacked(
            uint8(Commands.SWAP_EXACT_OUT),
            user,
            encodeSwapAmountParams(amount, maxIn, false, dataBalancer.length),
            dataBalancer
        );

        vm.prank(user);
        IERC20All(assetIn).approve(address(brokerProxyAddress), maxIn * 2);

        vm.prank(user);
        gas = gasleft();
        IFlashAggregator(brokerProxyAddress).deltaCompose(data);
        gas = gas - gasleft();
        console.log("gas", gas);
    }

    function test_polygon_balancer_exact_out_cpool() external {
        address user = testUser;
        uint256 amount = 10_000.0e18;
        uint256 maxIn = 10_100.0e18;

        address assetIn = MaticX;
        address assetOut = WMATIC;
        deal(assetIn, user, 1e23);

        bytes memory dataBalancer = getSpotExactOutBalancer(assetIn, assetOut, cs_pool_id);

        bytes memory data = abi.encodePacked(
            uint8(Commands.SWAP_EXACT_OUT),
            user,
            encodeSwapAmountParams(amount, maxIn, false, dataBalancer.length),
            dataBalancer
        );

        vm.prank(user);
        IERC20All(assetIn).approve(address(brokerProxyAddress), maxIn * 2);

        uint256 balanceOut = IERC20All(assetOut).balanceOf(user);
        uint256 balanceIn = IERC20All(assetIn).balanceOf(user);

        vm.prank(user);
        uint gas = gasleft();
        IFlashAggregator(brokerProxyAddress).deltaCompose(data);
        gas = gas - gasleft();
        console.log("gas", gas);

        balanceOut = IERC20All(assetOut).balanceOf(user) - balanceOut;
        balanceIn = balanceIn - IERC20All(assetIn).balanceOf(user);
        console.log("balanceOut", balanceOut);
        console.log("balanceIn", balanceIn);
    }

    function test_balancer_swap_quote_three_pool() external {
        address payable user = payable(testUser);
        BalancerCaller bc = new BalancerCaller();
        address assetIn = WETH;
        address assetOut = WBTC;
        uint256 amount = 1e8;
        deal(assetIn, user, amount);
        bytes memory queryCall;
        {
            SingleSwap memory data = SingleSwap({
                poolId: three_pool_id,
                kind: SwapKind.GIVEN_OUT,
                assetIn: assetIn,
                assetOut: assetOut,
                amount: amount,
                userData: new bytes(0)
            });
            console.logBytes(data.userData);
            FundManagement memory f = FundManagement({
                sender: user,
                fromInternalBalance: false,
                recipient: user, //
                toInternalBalance: false
            });
            queryCall = abi.encodeWithSelector(BalancerCaller.querySwap.selector, data, f);
        }

        uint256 gas = gasleft();
        (bool s, bytes memory ret) = address(bc).call(queryCall);
        console.log("gas cost", gas - gasleft());

        console.log("success", s);
        console.log(abi.decode(ret, (uint256)));
        gas = gasleft();

        bytes32 pId = three_pool_id;
        bytes32 d0;
        bytes32 d1;
        bytes32 d2;
        bytes32 d3;
        gas = gasleft();
        assembly {
            let ptr := mload(0x40)
            // query batch swap
            mstore(ptr, 0xf84d066e00000000000000000000000000000000000000000000000000000000)
            mstore(add(ptr, 0x4), 1)
            mstore(add(ptr, 0x24), 0xe0)
            mstore(add(ptr, 0x44), 0x1e0) // FundManagement struct
            mstore(add(ptr, 0x64), user) // sender
            mstore(add(ptr, 0x84), 0) // fromInternalBalance
            mstore(add(ptr, 0xA4), user) // recipient
            mstore(add(ptr, 0xC4), 0) // toInternalBalance
            mstore(add(ptr, 0xE4), 1)
            mstore(add(ptr, 0x104), 0x20) // SingleSwap struct
            mstore(add(ptr, 0x124), pId) // poolId
            mstore(add(ptr, 0x144), 0) // userDataLength
            mstore(add(ptr, 0x164), 1) // swapKind
            mstore(add(ptr, 0x184), amount) // amount
            mstore(add(ptr, 0x1A4), 0xa0)
            mstore(add(ptr, 0x1C4), 0)
            mstore(add(ptr, 0x1E4), 2)
            mstore(add(ptr, 0x204), assetIn) // assetIn
            mstore(add(ptr, 0x224), assetOut) // assetOut

            s := call(
                gas(),
                BALANCER_VAULT,
                0x0,
                ptr,
                0x244,
                ptr,
                0x80 // return is always array of two
            )
            d0 := mload(ptr)
            d1 := mload(add(ptr, 0x20))
            d2 := mload(add(ptr, 0x40))
            d3 := mload(add(ptr, 0x60))
        }
        console.log("success assembnly", s, gas - gasleft());
        console.logBytes32(d0);
        console.logBytes32(d1);
        console.logBytes32(d2);
        console.logBytes32(d3);
    }

    address internal constant cs_pool = 0xcd78A20c597E367A4e478a2411cEB790604D7c8F;
    bytes32 internal constant cs_pool_id = 0xcd78a20c597e367a4e478a2411ceb790604d7c8f000000000000000000000c22;

    function test_balancer_swap_quote_csp() external {
        address payable user = payable(testUser);
        BalancerCaller bc = new BalancerCaller();

        address assetIn = WMATIC;
        address assetOut = MaticX;

        uint256 amount = 1e18;
        deal(assetIn, user, amount);
        bytes memory queryCall;
        {
            SingleSwap memory data = SingleSwap({
                poolId: cs_pool_id,
                kind: SwapKind.GIVEN_OUT,
                assetIn: assetIn,
                assetOut: assetOut,
                amount: amount,
                userData: new bytes(0)
            });
            console.logBytes(data.userData);
            FundManagement memory f = FundManagement({
                sender: user,
                fromInternalBalance: false,
                recipient: user, //
                toInternalBalance: false
            });
            queryCall = abi.encodeWithSelector(BalancerCaller.querySwap.selector, data, f);
        }
        uint256 gas = gasleft();
        (bool s, bytes memory ret) = address(bc).call(queryCall);
        console.log("gas cost", gas - gasleft());

        console.log("success", s);
        console.log(abi.decode(ret, (uint256)));
        gas = gasleft();
        uint dd;
        assembly {
            let ptr := mload(0x40)
            s := staticcall(
                gas(),
                bc,
                add(queryCall, 0x20),
                mload(queryCall), //
                ptr,
                0x20
            )
            dd := mload(ptr)
        }
        console.log("gas cost", gas - gasleft());
        console.log("dd", dd, s);
        bytes32 pId = cs_pool_id;
        bytes32 d0;
        bytes32 d1;
        bytes32 d2;
        bytes32 d3;
        gas = gasleft();
        assembly {
            let ptr := mload(0x40)
            // query batch swap
            mstore(ptr, 0xf84d066e00000000000000000000000000000000000000000000000000000000)
            mstore(add(ptr, 0x4), 1)
            mstore(add(ptr, 0x24), 0xe0)
            mstore(add(ptr, 0x44), 0x1e0)
            mstore(add(ptr, 0x64), user)
            mstore(add(ptr, 0x84), 0)
            mstore(add(ptr, 0xA4), user)
            mstore(add(ptr, 0xC4), 0)
            mstore(add(ptr, 0xE4), 1)
            mstore(add(ptr, 0x104), 0x20)
            mstore(add(ptr, 0x124), pId)
            mstore(add(ptr, 0x144), 0)
            mstore(add(ptr, 0x164), 1)
            mstore(add(ptr, 0x184), amount)
            mstore(add(ptr, 0x1A4), 0xa0)
            mstore(add(ptr, 0x1C4), 0)
            mstore(add(ptr, 0x1E4), 2)
            mstore(add(ptr, 0x204), assetIn)
            mstore(add(ptr, 0x224), assetOut)

            s := call(
                gas(),
                BALANCER_VAULT,
                0x0,
                ptr,
                0x244,
                ptr,
                0x80 // return is always array of two
            )
            d0 := mload(ptr)
            d1 := mload(add(ptr, 0x20))
            d2 := mload(add(ptr, 0x40))
            d3 := mload(add(ptr, 0x60))
        }
        console.log("success assembnly", s, gas - gasleft());
        console.logBytes32(d0);
        console.logBytes32(d1);
        console.logBytes32(d2);
        console.logBytes32(d3);
    }

    function test_balancer_swap_exec_csp() external {
        address payable user = payable(testUser);
        FakeVault fv = new FakeVault();

        address assetIn = WMATIC;
        address assetOut = MaticX;

        uint256 amount = 1e18;

        deal(assetIn, user, amount);
        bytes memory queryCall;
        {
            SingleSwap memory data = SingleSwap({
                poolId: cs_pool_id,
                kind: SwapKind.GIVEN_OUT,
                assetIn: assetIn,
                assetOut: assetOut,
                amount: amount,
                userData: new bytes(0)
            });
            console.logBytes(data.userData);
            FundManagement memory f = FundManagement({
                sender: user,
                fromInternalBalance: false,
                recipient: user, //
                toInternalBalance: false
            });
            uint256 limit = 9999;
            uint256 deadline = type(uint).max;
            queryCall = abi.encodeWithSelector(IVault.swap.selector, data, f, limit, deadline);
        }
        uint256 gas = gasleft();
        (bool s, bytes memory ret) = address(fv).call(queryCall);
        console.log("gas cost", gas - gasleft());

        console.log("success", s);
        console.log(abi.decode(ret, (uint256)));
        gas = gasleft();
        uint dd;
        console.log("gas cost", gas - gasleft());
        console.log("dd", dd, s);
        bytes32 pId = cs_pool_id;
        bytes32 d0;
        bytes32 d1;
        bytes32 d2;
        bytes32 d3;
        gas = gasleft();
        assembly {
            let ptr := mload(0x40)
            // query batch swap
            mstore(ptr, 0xf84d066e00000000000000000000000000000000000000000000000000000000)
            mstore(add(ptr, 0x4), 1)
            mstore(add(ptr, 0x24), 0xe0)
            mstore(add(ptr, 0x44), 0x1e0)
            mstore(add(ptr, 0x64), user)
            mstore(add(ptr, 0x84), 0)
            mstore(add(ptr, 0xA4), user)
            mstore(add(ptr, 0xC4), 0)
            mstore(add(ptr, 0xE4), 1)
            mstore(add(ptr, 0x104), 0x20)
            mstore(add(ptr, 0x124), pId)
            mstore(add(ptr, 0x144), 0)
            mstore(add(ptr, 0x164), 1)
            mstore(add(ptr, 0x184), amount)
            mstore(add(ptr, 0x1A4), 0xa0)
            mstore(add(ptr, 0x1C4), 0)
            mstore(add(ptr, 0x1E4), 2)
            mstore(add(ptr, 0x204), assetIn)
            mstore(add(ptr, 0x224), assetOut)

            s := call(
                gas(),
                BALANCER_VAULT,
                0x0,
                ptr,
                0x244,
                ptr,
                0x80 // return is always array of two
            )
            d0 := mload(ptr)
            d1 := mload(add(ptr, 0x20))
            d2 := mload(add(ptr, 0x40))
            d3 := mload(add(ptr, 0x60))
        }
        console.log("success assembnly", s, gas - gasleft());
        console.logBytes32(d0);
        console.logBytes32(d1);
        console.logBytes32(d2);
        console.logBytes32(d3);
    }

    function getSpotExactOutBalancer(address tokenIn, address tokenOut, bytes32 pId) internal view returns (bytes memory data) {
        uint8 action = 0;
        return abi.encodePacked(tokenOut, action, BALANCER_V2_DEXID, pId, tokenIn, uint8(99), uint8(99));
    }
}

// 0xcd78a20c597e367a4e478a2411ceb790604d7c8f000000000000000000000c22;
// query batch swap
// 0xf84d066e00000000000000000000000000000000000000000000000000000000
// 0x0000000000000000000000000000000000000000000000000000000000000001
// 0x00000000000000000000000000000000000000000000000000000000000000e0
// 0x00000000000000000000000000000000000000000000000000000000000001e0
// 0x0000000000000000000000005f6f935a9a69f886dc0147904d0f455abac67e14
// 0x0000000000000000000000000000000000000000000000000000000000000000
// 0x0000000000000000000000005f6f935a9a69f886dc0147904d0f455abac67e14
// 0x0000000000000000000000000000000000000000000000000000000000000000
// 0x0000000000000000000000000000000000000000000000000000000000000001
// 0x0000000000000000000000000000000000000000000000000000000000000020
// 0xcd78a20c597e367a4e478a2411ceb790604d7c8f000000000000000000000c22
// 0x0000000000000000000000000000000000000000000000000000000000000000
// 0x0000000000000000000000000000000000000000000000000000000000000001
// 0x0000000000000000000000000000000000000000000000000de0b6b3a7640000
// 0x00000000000000000000000000000000000000000000000000000000000000a0
// 0x0000000000000000000000000000000000000000000000000000000000000000
// 0x0000000000000000000000000000000000000000000000000000000000000002
// 0x0000000000000000000000000d500b1d8e8ef31e21c99d1db9a6444d3adf1270
// 0x000000000000000000000000fa68fb4628dff1028cfec22b4162fccd0d45efb6

// 0x52bbbe2900000000000000000000000000000000000000000000000000000000
// 0x00000000000000000000000000000000000000000000000000000000000000e0
// 0x0000000000000000000000005f6f935a9a69f886dc0147904d0f455abac67e14
// 0x0000000000000000000000000000000000000000000000000000000000000000
// 0x0000000000000000000000005f6f935a9a69f886dc0147904d0f455abac67e14
// 0x0000000000000000000000000000000000000000000000000000000000000000
// 0x000000000000000000000000000000000000000000000000000000000000270f
// 0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
// 0xcd78a20c597e367a4e478a2411ceb790604d7c8f000000000000000000000c22
// 0x0000000000000000000000000000000000000000000000000000000000000001
// 0x0000000000000000000000000d500b1d8e8ef31e21c99d1db9a6444d3adf1270
// 0x000000000000000000000000fa68fb4628dff1028cfec22b4162fccd0d45efb6
// 0x0000000000000000000000000000000000000000000000000de0b6b3a7640000
// 0x00000000000000000000000000000000000000000000000000000000000000c0
// 0x0000000000000000000000000000000000000000000000000000000000000000
