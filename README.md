# Zipped Contracts

Compressed contracts that automatically self-extract when called. Useful if you want to seriously cut deployment costs or are running into bytecode size limits for logic that only ever gets called off-chain in an eth_call context (lens-type contracts, quoters, NFT metadata, etc).

There is also a companion web app for deploying these contracts from your browser @ [bytecode.zip](https://bytecode.zip).

## Project Setup and Test

```bash
$> git clone git@github.com:merklejerk/zipped-contracts.git && cd zipped-contracts
$> forge install
$> forge test -vvv
```

## Deployed Addresses
| network | address |
|---------|---------|
| Ethereum mainnet | ??? |
| Goerli           | [`0x3198E681FB81462aeB42DD15b0C7BBe51D38750f`](https://etherscan.io/address/0x3198E681FB81462aeB42DD15b0C7BBe51D38750f) |
| Sepolia          | [`0x551F0E213dcb71f676558D8B0AB559d1cDD103F2`](https://etherscan.io/address/0x551F0E213dcb71f676558D8B0AB559d1cDD103F2) |

## Overview

- Around 50% savings for conventional opcode-heavy bytecode , even more for text/bitmap-heavy.
    - Millions of gas.
    - Doesn't matter much for eth_call contexts.
- Seamless decompression.
    - DIAGRAM.
- No verification (yet)
    - You can probably just deploy a small wrapper/forwarder contract later.
- Not compatible with staticcall.
    - Not really a problem for most eth_call contexts.
    - Uses revert mechanism to prevent permanently writing state anyway.
- No constructor args.

### Self-Extracting ZCALL contracts

#### Creating

### Self-Extracting ZRUN contracts

#### Creating

## Case Studies
Both are contracts intended to be called off-chain, via `eth_call` semantics.

| contract | current bytecode size | zipped bytecode size | savings/reduction |
|----------|-----------------------|----------------------|--------------------|
| Uniswap V3 Quoter          | [`4631`](https://goerli.etherscan.io/address/0xb27308f9F90D607463bb33eA1BeBb41C27CE5AB6) | [`2241`](https://goerli.etherscan.io/address/0x23206a7794369b2bf5e5c57d62566710b459776b) | 51% |
| [shields.build](https://shields.build) SVG Metadata | [`23732`](https://etherscan.io/address/0xfaDb4b43671Aa379D443Ffc4ec98d2aF2808eBe5) | [`8206`](https://goerli.etherscan.io/address/0xba04a9229af8ba43d9b4b23d9948c18a7fcc0083) | 65% |




