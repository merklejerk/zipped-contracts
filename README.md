# Zipped Contracts

Compressed contracts that self-extract when called. Useful if you want to seriously cut deployment costs or are running into bytecode size limits for logic that only ever gets called off-chain in an eth_call context (lens-type contracts, quoters, NFT metadata, etc).

## Deployed Addresses
| network | address |
|---------|---------|
| Ethereum mainnet | ??? |
| Goerli           | ??? |
| Sepolia          | ??? |

## Project Setup and Test

```bash
$> git clone git@github.com:merklejerk/zipped-contracts.git && cd zipped-contracts
$> forge install
$> forge test -vvv
```

## Overview

## Examples
| contract | current bytecode size | zipped bytecode size | deployment savings ($) |
|----------|-----------------------|----------------------|--------------------|
| Uniswap V3 Quoter | ?? | ?? | $?? |
| shields.build SVG render contract | ?? | ?? | $?? |

