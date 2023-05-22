# Zipped Contracts

Compressed contracts that automatically self-extract when called. Useful for cheaply deploying contracts that are always called off-chain in an `eth_call` context. There are many examples of these contracts used in modern protocols/dapps: "lens"-type contracts, quoters, NFT metadata, etc.

There is also a companion web app for deploying zipped contracts from your browser @ [bytecode.zip](https://bytecode.zip).

## Overview
Zipped contracts are essentially normal contracts that are compressed off-chain using [zlib DEFLATE](https://www.ietf.org/rfc/rfc1951.txt) then deployed on-chain inside of a self-extracting wrapper. Any call to the wrapper contract will trigger the wrapper's minimal fallback that forwards the call to the canonical `Z` runtime contract. The runtime contract decompresses the zipped contract, deploys it, then forwards the original call to the deployed instance. The result is bubbled up inside of a `revert()` payload to undo the deployment and avoid permanently modifying state.

All this witchcraft means that, from an `eth_call` context, interacting with a zipped contract is [very similar](#interacting-with-zipped-contracts) to any other contract!

![architecture](./arch.drawio.png)

## Case Studies
Most contracts can expect to see ~50% size/deployment cost reduction, and better for text-heavy applications. I applied this technology to some known off-chain contracts for comparison. No modifications were made to them.

| contract | current bytecode size | zipped bytecode size | savings/reduction |
|----------|-----------------------|----------------------|--------------------|
| Uniswap V3 Quoter          | [`4631`](https://goerli.etherscan.io/address/0xb27308f9F90D607463bb33eA1BeBb41C27CE5AB6) | [`2241`](https://goerli.etherscan.io/address/0x23206a7794369b2bf5e5c57d62566710b459776b) | 51% |
| [shields.build](https://shields.build) SVG Metadata | [`23732`](https://etherscan.io/address/0xfaDb4b43671Aa379D443Ffc4ec98d2aF2808eBe5) | [`8206`](https://goerli.etherscan.io/address/0xba04a9229af8ba43d9b4b23d9948c18a7fcc0083) | 65% |


## Interacting with Zipped Contracts
The self-extracting wrapper will perform the just-in-time decompression behind the scenes, so you can just directly call a function on the deployed zipped contract as if it were the unzipped contract. However, there are some things to be mindful of:

- Decompressing is a *very* expensive operation (upwards of 23M gas), so you should only call these contracts in the context of an `eth_call`, i.e., not in a transaction that will be mined.
- The runtime will need to (temporarily) deploy the unzipped contract. This means that calls to the zipped contract inside of a `staticcall()` context will revert. If you are calling a zipped contract through another contract, either use a low-level `call()` construct or cast the interface of the zipped contract to one with non-`view` function declarations to prevent a `staticcall()` from occurring.
- Zipped contracts cannot have their source/ABI verified on etherscan at the moment. If you want users to be able to interact with zipped contracts through etherscan, consider deploying a minimal contract with the same interface that forwards calls to the zipped version.
- Zipped contracts do not support `payable` functions.

## ZCALL vs ZRUN Contracts
There are two types of zipped contracts supported by the runtime. The simpler, and probably more popular, choice is ZCALL, which follows the flow described earlier. You don't have to do anything special to write ZCALL contracts; they just work. The ZCALL approach is designed to provide cheaper deployments.

ZRUN contracts, on the other-hand, are designed to bypass maximum bytecode size constraints. There is a well-known ~24KB bytecode size limit for deployable contracts on Ethereum that many projects bump into. ZRUN contracts artificially extend this ceiling, but to accomplish this, your contract must be written very deliberately:
    1. You must perform all your logic inside the constructor.
    2. You must manually ABI-encode and `return()` your return data in the constructor.

This means ZRUN contracts only have one entry-point/function, which is their constructor. They also cannot support callbacks (directly) because they will never have code at their deployed address.

## Deploying Zipped Contracts
There are foundry [scripts](./script/) included in this repo that you can use to deploy your contracts as self-extracting zipped contracts (or you can use [bytecode.zip](https://bytecode.zip)).

## Self-Extracting ZCALL contracts


### Creating

## Self-Extracting ZRUN contracts

### Creating

## `Z` Runtime Deployed Addresses
This is the canonical runtime for zipped contracts, which handles decompression, execution, and cleanup.
You probably won't need to interact with this contract directly if you're using the self-extracting wrapper.

| network | address |
|---------|---------|
| Ethereum mainnet | ??? |
| Goerli           | [`0x3198E681FB81462aeB42DD15b0C7BBe51D38750f`](https://etherscan.io/address/0x3198E681FB81462aeB42DD15b0C7BBe51D38750f) |
| Sepolia          | [`0x551F0E213dcb71f676558D8B0AB559d1cDD103F2`](https://etherscan.io/address/0x551F0E213dcb71f676558D8B0AB559d1cDD103F2) |

## Project Setup and Test

It's a foundry project. You know the drill.

```bash
$> git clone git@github.com:merklejerk/zipped-contracts.git && cd zipped-contracts
$> forge install
$> forge test -vvv
```

- Around 50% savings for conventional opcode-heavy bytecode , even more for text/bitmap-heavy.
- Around 50% savings for conventional opcode-heavy bytecode , even more for text/bitmap-heavy.
    - Millions of gas.
    - Doesn't matter much for eth_call contexts.
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



