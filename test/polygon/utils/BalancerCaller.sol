// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {console} from "forge-std/console.sol";

enum SwapKind {
    GIVEN_IN,
    GIVEN_OUT
}

/**
 * @dev Data for each individual swap executed by `batchSwap`. The asset in and out fields are indexes into the
 * `assets` array passed to that function, and ETH assets are converted to WETH.
 *
 * If `amount` is zero, the multihop mechanism is used to determine the actual amount based on the amount in/out
 * from the previous swap, depending on the swap kind.
 *
 * The `userData` field is ignored by the Vault, but forwarded to the Pool in the `onSwap` hook, and may be
 * used to extend swap behavior.
 */
struct BatchSwapStep {
    bytes32 poolId;
    uint256 assetInIndex;
    uint256 assetOutIndex;
    uint256 amount;
    bytes userData;
}

struct SingleSwap {
    bytes32 poolId;
    SwapKind kind;
    address assetIn;
    address assetOut;
    uint256 amount;
    bytes userData;
}

struct FundManagement {
    address sender;
    bool fromInternalBalance;
    address payable recipient;
    bool toInternalBalance;
}

interface IVault {
    /**
     * @dev Simulates a call to `batchSwap`, returning an array of Vault asset deltas. Calls to `swap` cannot be
     * simulated directly, but an equivalent `batchSwap` call can and will yield the exact same result.
     *
     * Each element in the array corresponds to the asset at the same index, and indicates the number of tokens (or ETH)
     * the Vault would take from the sender (if positive) or send to the recipient (if negative). The arguments it
     * receives are the same that an equivalent `batchSwap` call would receive.
     *
     * Unlike `batchSwap`, this function performs no checks on the sender or recipient field in the `funds` struct.
     * This makes it suitable to be called by off-chain applications via eth_call without needing to hold tokens,
     * approve them for the Vault, or even know a user's address.
     *
     * Note that this function is not 'view' (due to implementation details): the client code must explicitly execute
     * eth_call instead of eth_sendTransaction.
     */
    function queryBatchSwap(
        SwapKind kind,
        BatchSwapStep[] memory swaps,
        address[] memory assets,
        FundManagement memory funds
    )
        external
        returns (int256[] memory assetDeltas);

    function swap(
        SingleSwap memory singleSwap,
        FundManagement memory funds,
        uint256 limit,
        uint256 deadline
    )
        external
        payable
        returns (uint256 amountCalculated);
}

contract BalancerCaller {
    FakeVault fv;

    //
    constructor() {
        fv = new FakeVault();
    }

    address internal constant BALANCER_V2_VAULT = 0xBA12222222228d8Ba445958a75a0704d566BF2C8;

    function querySwap(SingleSwap memory singleSwap, FundManagement memory funds) external returns (uint256) {
        // The Vault only supports batch swap queries, so we need to convert the swap call into an equivalent batch
        // swap. The result will be identical.

        // The main difference between swaps and batch swaps is that batch swaps require an assets array. We're going
        // to place the asset in at index 0, and asset out at index 1.
        address[] memory assets = new address[](2);
        assets[0] = singleSwap.assetIn;
        assets[1] = singleSwap.assetOut;

        BatchSwapStep[] memory swaps = new BatchSwapStep[](1);
        swaps[0] =
            BatchSwapStep({poolId: singleSwap.poolId, assetInIndex: 0, assetOutIndex: 1, amount: singleSwap.amount, userData: singleSwap.userData});
        int256[] memory assetDeltas = IVault(BALANCER_V2_VAULT).queryBatchSwap(singleSwap.kind, swaps, assets, funds);

        // Batch swaps return the full Vault asset deltas, which in the special case of a single step swap contains more
        // information than we need (as the amount in is known in a GIVEN_IN swap, and the amount out is known in a
        // GIVEN_OUT swap). We extract the information we're interested in.
        if (singleSwap.kind == SwapKind.GIVEN_IN) {
            // The asset out will have a negative Vault delta (the assets are coming out of the Pool and the user is
            // receiving them), so make it positive to match the `swap` interface.

            return uint256(-assetDeltas[1]);
        } else {
            // The asset in will have a positive Vault delta (the assets are going into the Pool and the user is
            // sending them), so we don't need to do anything.
            return uint256(assetDeltas[0]);
        }
    }

    function querySwap2(SingleSwap memory singleSwap, FundManagement memory funds) external returns (uint256) {
        // The Vault only supports batch swap queries, so we need to convert the swap call into an equivalent batch
        // swap. The result will be identical.

        // The main difference between swaps and batch swaps is that batch swaps require an assets array. We're going
        // to place the asset in at index 0, and asset out at index 1.
        address[] memory assets = new address[](2);
        assets[0] = singleSwap.assetIn;
        assets[1] = singleSwap.assetOut;

        BatchSwapStep[] memory swaps = new BatchSwapStep[](1);
        swaps[0] =
            BatchSwapStep({poolId: singleSwap.poolId, assetInIndex: 0, assetOutIndex: 1, amount: singleSwap.amount, userData: singleSwap.userData});
        int256[] memory assetDeltas = IVault(address(fv)).queryBatchSwap(singleSwap.kind, swaps, assets, funds);

        // Batch swaps return the full Vault asset deltas, which in the special case of a single step swap contains more
        // information than we need (as the amount in is known in a GIVEN_IN swap, and the amount out is known in a
        // GIVEN_OUT swap). We extract the information we're interested in.
        if (singleSwap.kind == SwapKind.GIVEN_IN) {
            // The asset out will have a negative Vault delta (the assets are coming out of the Pool and the user is
            // receiving them), so make it positive to match the `swap` interface.

            return uint256(-assetDeltas[1]);
        } else {
            // The asset in will have a positive Vault delta (the assets are going into the Pool and the user is
            // sending them), so we don't need to do anything.
            return uint256(assetDeltas[0]);
        }
    }
}

contract FakeVault {
    fallback() external payable {
        bytes calldata data = msg.data;

        console.logBytes(data);
    }
}
