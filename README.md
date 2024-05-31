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

#### Path encoding

We follow the general approach of encoding actionIds, dexIds and params, sandwiched by tokens. This means, that for a route of tokens, eg.g `token0->token1->token2`, we specify the route as follows:

`token0 | actionId0 | dexId0 | paramsDex0 | token1 | actionId1 | dexId1 | paramsDex1 | token2 | lenderId | payType`
`address| uint8     | uint8  | bytes      | address| uint8     | uint8  | bytes      | address| uint8    | uint8`

The encoding of the parameters depends on the dexId provided, i.e. for Uniswap V3 types, it is the fee parameter, for curve the parameters are the swap indexes.

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
- 