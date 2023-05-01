# Ajna Protocol contest details
- Total Prize Pool: $60,500 USDC 
  - HM awards: $37,500 USDC 
  - QA report awards: $5,000 USDC 
  - Gas report awards: $2,500 USDC 
  - Bot race awards: $5,000 USDC
  - Judge awards: $6,000 USDC 
  - Lookout awards: $4,000 USDC 
  - Scout awards: $500 USDC 
- Join [C4 Discord](https://discord.gg/code4rena) to register
- Submit findings [using the C4 form](https://code4rena.com/contests/2023-05-Ajna-Protocol-contest/submit)
- [Read our guidelines for more details](https://docs.code4rena.com/roles/wardens)
- Starts May 03, 2023 20:00 UTC 
- Ends May 11, 2023 20:00 UTC 

## Automated Findings / Publicly Known Issues

Automated findings output for the contest can be found [here](add link to report) within 24 hours of contest opening.

*Note for C4 wardens: Anything included in the automated findings output is considered a publicly known issue and is ineligible for awards.*

# Overview

## About Ajna
The Ajna protocol is a non-custodial, peer-to-peer, permissionless lending, borrowing and trading system that requires no governance or external price feeds to function. The protocol consists of pools: pairings of quote tokens provided by lenders and collateral tokens provided by borrowers. Ajna is capable of accepting fungible tokens as quote tokens and both fungible and non-fungible tokens as collateral tokens.

## Resources

- [Twitter](https://mobile.twitter.com/ajnafi)
- [Website](https://www.ajna.finance/)
- [Business Logic recording](https://www.youtube.com/watch?v=LoknmCG-0kw)
- [Whitepaper](https://www.ajna.finance/)
- [Ajna Technical Spec](https://docsend.com/view/ai74yqgzjp3yydyt)
- [ELI5](https://www.ajna.finance/)
- [Technical Diagrams Pools](https://github.com/code-423n4/2023-05-ajna/tree/main/ajna-core/docs)
- [Technical Diagrams Grants](https://github.com/code-423n4/2023-05-ajna/tree/main/ajna-grants/docs)

## On-chain context

```
DEPLOYMENT: Ethereum mainnet, Arbitrum, Optimism, Binance Smart Chain, Polygon, Fantom, Tron, Avalanche
ERC20:  any - ERC20's are used in fungible, collection and subset pool types
ERC721: any - ERC721's are used in collection and subset pool types
ERC777: none
FEE-ON-TRANSFER: none
REBASING TOKENS: none
ADMIN: N/A
```

# Scope

| Contract | SLOC | Purpose | Libraries used |  
| ----------- | ----------- | ----------- | ----------- |
| [ajna-core/src/PositionManager.sol](ajna-core/src/PositionManager.sol) | 165 | This contract holds the LP position of lenders and gives them an ERC721 token representing their position in exchange | `OpenZeppelin` contracts library, version 4.8.2, commit [d00acef405](https://github.com/openzeppelin/openzeppelin-contracts/tree/d00acef4059807535af0bd0dd0ddf619747a044b)<br>[`token/ERC20/ERC20.sol`](https://docs.openzeppelin.com/contracts/4.x/api/token/erc20#IERC20)<br>[`token/ERC721/ERC721.sol`](https://docs.openzeppelin.com/contracts/4.x/api/token/erc721#IERC721)<br>[`token/ERC20/utilities/SafeERC20.sol`](https://docs.openzeppelin.com/contracts/4.x/api/token/erc20#SafeERC20)<br>[`utils/structs/EnumerableSet.sol`](https://docs.openzeppelin.com/contracts/4.x/api/utils#EnumerableSet)<br>[`utils/Multicall.sol`](https://docs.openzeppelin.com/contracts/4.x/utilities#multicall)<br>[`security/ReentrancyGuard.sol`](https://docs.openzeppelin.com/contracts/4.x/api/security#ReentrancyGuard) |
| [ajna-core/src/RewardsManager.sol](ajna-core/src/RewardsManager.sol) | 324 | This contract provides rewards (in Ajna token) to Ajna lenders who lock up their ERC721 position from the `PositionManager.sol` contract | `OpenZeppelin` contracts library, version 4.8.2, commit [d00acef405](https://github.com/openzeppelin/openzeppelin-contracts/tree/d00acef4059807535af0bd0dd0ddf619747a044b) <br>[`token/ERC20/ERC20.sol`](https://docs.openzeppelin.com/contracts/4.x/api/token/erc20#IERC20)<br>[`token/ERC721/ERC721.sol`](https://docs.openzeppelin.com/contracts/4.x/api/token/erc721#IERC721)<br>[`token/ERC20/utilities/SafeERC20.sol`](https://docs.openzeppelin.com/contracts/4.x/api/token/erc20#SafeERC20)<br>[`security/ReentrancyGuard.sol`](https://docs.openzeppelin.com/contracts/4.x/api/security#ReentrancyGuard) |
| [ajna-grants/src/grants](ajna-grants/src/grants) | 652 | This contract provides  | `OpenZeppelin` contracts library, commit [8d908fe2c2](https://github.com/OpenZeppelin/openzeppelin-contracts/tree/8d908fe2c20503b05f888dd9f702e3fa6fa65840)<br>[`token/ERC20/ERC20.sol`](https://docs.openzeppelin.com/contracts/4.x/api/token/erc20#IERC20)<br>[`utils/math/SafeCast.sol`](https://docs.openzeppelin.com/contracts/4.x/api/utils#SafeCast)<br>[`security/ReentrancyGuard.sol`](https://docs.openzeppelin.com/contracts/4.x/api/security#ReentrancyGuard)<br>[`governance/utils/IVotes.sol`](https://docs.openzeppelin.com/contracts/4.x/api/governance#Votes) |


## Out of scope

* `./ajna-core/src/*` all other contracts **ASIDE** from `RewardsManager.sol` and `PositionManager.sol` (which are listed above) are out of scope for this audit.
* `./ajna-grants/token`

## Scoping Details 
```
- If you have a public code repo, please share it here:
  - [grants](https://github.com/ajna-finance/ajna-grants)
  - [RewardsManager](https://github.com/ajna-finance/ajna-core/blob/main/src/RewardsManager.sol)
  - [PositionsManager](https://github.com/ajna-finance/ajna-core/blob/main/src/PositionsManager.sol)
- How many contracts are in scope?:   3
- Total SLoC for these contracts?:  1191
- How many external imports are there?: 22 
- How many separate interfaces and struct definitions are there for the contracts within scope?:  15 interfaces and 15 structs
- Does most of your code generally use composition or inheritance?:   Inheritance
- How many external calls?:   0
- What is the overall line coverage percentage provided by your tests?:  100
- Is there a need to understand a separate part of the codebase / get context in order to audit this part of the protocol?:   true
- Please describe required context:   It may be helpful for auditors to gain an understanding of how positions manifest themselves as LP inside of the core pool contracts via methods like `addQuoteToken()` to better understand `PositionManager.sol`. Additionally, an understanding of reserve auctions (`kickReserveAuction()` and `takeReserves()`) will assist auditors in understanding and auditing `RewardsManager.sol`. `ajna-grants/src/grants` is relatively self encapsulating.
- Does it use an oracle?:  No
- Does the token conform to the ERC20 standard?:  True -> the Ajna token
- Are there any novel or unique curve logic or mathematical models?: Listed in a whitepaper
- Does it use a timelock function?:  No
- Is it an NFT?: True -> in `PositionManager.sol` one is created of a user's position
- Does it have an AMM?: Swapping exists in the pool contracts but is out of scope for this audit
- Is it a fork of a popular project?:   False
- Does it use rollups?:   
- Is it multi-chain?:  True
- Does it use a side-chain?: False
```

# Tests

**NOTE**:
- install `foundry` by running `foundryup -v nightly-87bc53fc6c874bd4c92d97ed180b949e3a36d78c` (this version is required due to breaking changes introduced in foundry-rs/foundry#4827)

clone down and cd into the repo
```
git clone https://github.com/code-423n4/2023-05-ajna.git && cd 2023-05-ajna
```

## Grants
cd into sub repo:
```
cd ajna-grants
```
To run unit tests:
```
make tests
```
To run unit tests with gas report:
```
make test-with-gas-report
```

## PositionManager and RewardsManager
cd into sub repo:
```
cd ajna-core
```
To run unit tests:
```
make test
```
To run unit tests with gas report:
```
make test-with-gas-report
```
