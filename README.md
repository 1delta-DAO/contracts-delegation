# Margin Trading on top of Lenders with delegated borrowing
Contains contracts that allows users to create accounts from a factory. These accounts can then be used to interact with DEXes like UniswapV3 or lending protocols like CompoundV3 or Aave to create leveraged positions in a single click.

Users interact with a brokerage contract that builds margin positions using protocols like AAVE which implement delegated borrowing functions.

The directories in external-protocol contain contracts (everything from https://github.com/Uniswap/v3-core, everything https://github.com/Uniswap/v3-periphery, and everything from https://github.com/aave/aave-v3-core.git) that are written by third parties
- we do not claim ownership of these contracts
- we only use them for testing purposes
- we will not deploy any of the contracts belonging to these 3rd parties (uniswapV3 / AAVE)

Install dependencies with `yarn install`.

## Run hardhat tests

Compile with `npx hardhat compile`.

Run tests with `npx hardhat test test/1delta/...`.

Do not chnage compiler settings - `external-protocols` relies on exact bytecode matches.

## Run forge tests

### Install foundry

Foundry documentation can be found [here](https://book.getfoundry.sh/forge/index.html).

Open your terminal and type in the following command:

```
curl -L https://foundry.paradigm.xyz | bash
```

This will download foundryup. Then install Foundry by running:

```
foundryup
```

### Execute tests

Tests for Mantle: `forge test --match-test "mantle" -vv`

Tests for LB: `forge test --match-test "mantle_lb" -vv`


### Swap Architecture

#### Batching

We employ a direct batch function that allows chaining multiple operations. The batching is tiggered via `deltaCompose(bytes calldata data)` and the input data is a compact bytes array encoded as follows. 

| opId |op paramters| opId |op paramters| ...|
|--------|-----------|--------|------------|------|
| uint8 |bytes|uint8 |bytes|...|

The length is encoded as a `uint16` which is enough for swap path types described below.
The opertions are sequentially executed which prevents multicall usage (which saves gas due to the preventions of internal `delegatecall`s). 

##### Operations

| operation | id | parameters | param names |
|--------|--------|--------|--------|
| 0| Swap exact input | (uint256,address,uint16,bytes) | amount, receiver,pathLength, path|
| 1| Swap exact output | (uint256,address,uint16,bytes) |amount, receiver,pathLength, path|
| 3| Flash swap exact input | (uint256,address,uint16,bytes) |amount, receiver,pathLength, path|
| 0x13| Deposit | (address,address,uint8,uint112) |asset, receiver,lenderId, amount|
| 0x11| Borrow | (address,address,uint8,uint8,uint112) |asset, receiver,lenderId,mode, amount|
| 0x17| Withdraw | (address,address,uint8,uint112) |asset, receiver,lenderId, amount|
| 0x18| Repay | (address,address,uint8,uint8,uint112) |asset, receiver,lenderId, mode, amount|
| 0x15| Transfer in | (address,address,uint112) |asset, receiver, amount|
| 0x19| Wrap | (uint112) | amount|
| 0x20| Unwrap | (address,uint112) | receiver, minimumAmount|
| 0x22| Sweep | (address,address,uint112) |asset, receiver, minimumAmount|

#### Path encoding

We follow the general approach of encoding actionIds, dexIds and params, sandwiched by tokens. This means, that for a route of tokens, eg.g `token0->token1->token2`, we specify the route as follows:

|token in path| action|dex|parameters|token in path|action|dex|parameters|token in path|lender|payment option|
|--------|-----------|--------|------------|--------|-----------|--------|------------|--------|----------|---------|
| token0 | actionId0 | dexId0 | paramsDex0 | token1 | actionId1 | dexId1 | paramsDex1 | token2 | lenderId | payType |
| address| uint8     | uint8  | bytes      | address| uint8     | uint8  | bytes      | address| uint8    | uint8   |

The encoding of the parameters depends on the dexId provided, i.e. for Uniswap V3 types, it is the fee parameter, for curve the parameters are the swap indexes.

#### Action and pay type defininitions

The **actions** are defined as follows. The actions are only relevant for within flash swap callbacks.

|id| action|description|
|--------|-----------|--------|
| 0 | swap exact in simple  | Simple exact input swap, pay either with contract balance or from caller |
| 1 | swap exact out simple | Simple exact out swap, allows payin g through lender or via conventional transfer |
| 6 | deposit exact in | Deposits received funds, used for collateral swaps or margin open  |
| 7 | repay stable exact in | repay received funds in stable mode (if supported) |
| 8 | repay variable exact in | repay received funds in variable mode |
| 3 | deposit exact out | deposits in exact out config |
| 4 | repay stable exact out | repay received funds in stable mode   |
| 5 | repay variable exact out | repay received funds in variable mode   |

The **pay types** are defined as follows

|id| pay type|description|
|--------|-----------|--------|
| 1 | borrow stable  | borrow to pay from a lender that has stable rate borrowing |
| 2 | borrow variable | borrow  to pay with default mode (variable in most cases) |
| 3 | withdraw collateral | withdraw collateral to pay  |
| >4 | caller pays | pay from provided address (original caller or this contract)  |

#### Lender id

The `lenderId` is a network-specific identifier for a lender.

#### Case single route

- Direct transfers from caller to pool / pool to receiver are possible - this should make all of this compatible with FoT tokens
- Enabled for both exactIn / exactOut swaps

Caller --> pool --> pool --> receiver

#### Multi route

- First, tokens are transferred from caller to contract
- Then the routes are swapped internally
- Finally, the tokens are transferred to the receiver

Caller --> | pool --> pool |
           | pool --> pool | --> receiver

- This applies for exact in & exact out

#### Flash swaps

- Ideal for single route margin trades
- Allows multi-lender selection
- Gas efficient for mid-sized swaps (e.g. on uni/curve combo)

#### Flash loan 

- Can wrap any sequence of actions