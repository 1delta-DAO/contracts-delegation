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