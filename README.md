# ✨ So you want to sponsor a contest

This `README.md` contains a set of checklists for our contest collaboration.

Your contest will use two repos: 
- **a _contest_ repo** (this one), which is used for scoping your contest and for providing information to contestants (wardens)
- **a _findings_ repo**, where issues are submitted (shared with you after the contest) 

Ultimately, when we launch the contest, this contest repo will be made public and will contain the smart contracts to be reviewed and all the information needed for contest participants. The findings repo will be made public after the contest report is published and your team has mitigated the identified issues.

Some of the checklists in this doc are for **C4 (🐺)** and some of them are for **you as the contest sponsor (⭐️)**.

---

# Contest setup

# Repo setup

## ⭐️ Sponsor: Add code to this repo

- [ ] Create a PR to this repo with the below changes:
- [ ] Provide a self-contained repository with working commands that will build (at least) all in-scope contracts, and commands that will run tests producing gas reports for the relevant contracts.
- [ ] Make sure your code is thoroughly commented using the [NatSpec format](https://docs.soliditylang.org/en/v0.5.10/natspec-format.html#natspec-format).
- [ ] Please have final versions of contracts and documentation added/updated in this repo **no less than 24 hours prior to contest start time.**
- [ ] Be prepared for a 🚨code freeze🚨 for the duration of the contest — important because it establishes a level playing field. We want to ensure everyone's looking at the same code, no matter when they look during the contest. (Note: this includes your own repo, since a PR can leak alpha to our wardens!)


---

## ⭐️ Sponsor: Edit this README

Under "SPONSORS ADD INFO HERE" heading below, include the following:

- [ ] Modify the bottom of this `README.md` file to describe how your code is supposed to work with links to any relevent documentation and any other criteria/details that the C4 Wardens should keep in mind when reviewing. ([Here's a well-constructed example.](https://github.com/code-423n4/2022-08-foundation#readme))
  - [ ] When linking, please provide all links as full absolute links versus relative links
  - [ ] All information should be provided in markdown format (HTML does not render on Code4rena.com)
- [ ] Under the "Scope" heading, provide the name of each contract and:
  - [ ] source lines of code (excluding blank lines and comments) in each
  - [ ] external contracts called in each
  - [ ] libraries used in each
- [ ] Describe any novel or unique curve logic or mathematical models implemented in the contracts
- [ ] Does the token conform to the ERC-20 standard? In what specific ways does it differ?
- [ ] Describe anything else that adds any special logic that makes your approach unique
- [ ] Identify any areas of specific concern in reviewing the code
- [ ] Optional / nice to have: pre-record a high-level overview of your protocol (not just specific smart contract functions). This saves wardens a lot of time wading through documentation.
- [ ] See also: [this checklist in Notion](https://code4rena.notion.site/Key-info-for-Code4rena-sponsors-f60764c4c4574bbf8e7a6dbd72cc49b4#0cafa01e6201462e9f78677a39e09746)
- [ ] Delete this checklist and all text above the line below when you're ready.

---

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
- [Ajna Technical Spec]()
- [ELI5](https://www.ajna.finance/)
- [Technical Diagrams]()

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
| [ajna-core/src/PositionManager.sol](ajna-core/src/PositionManager.sol) | 165 | This contract holds the LP position of lenders and gives them an ERC721 token representing their position in exchange | [`@openzeppelin/contracts/token/ERC20/ERC20.sol`](https://docs.openzeppelin.com/contracts/4.x/api/token/erc20#IERC20) [`@openzeppelin/contracts/token/ERC721/ERC721.sol`](https://docs.openzeppelin.com/contracts/4.x/api/token/erc721#IERC721) [`@openzeppelin/contracts/utils/structs/EnumerableSet.sol`](https://docs.openzeppelin.com/contracts/4.x/api/utils#EnumerableSet) [`@openzeppelin/contracts/utils/Multicall.sol`](https://docs.openzeppelin.com/contracts/4.x/utilities#multicall) [`@openzeppelin/security/ReentrancyGuard.sol`](https://docs.openzeppelin.com/contracts/4.x/api/security#ReentrancyGuard) [`@openzeppelin/contracts/token/ERC20/utilities/SafeERC20.sol`](https://docs.openzeppelin.com/contracts/4.x/api/token/erc20#SafeERC20) |
| [ajna-core/src/RewardsManager.sol](ajna-core/src/RewardsManager.sol) | 324 | This contract provides rewards (in Ajna token) to Ajna lenders who lock up their ERC721 position from the `PositionManager.sol` contract | [`@openzeppelin/contracts/token/ERC20/ERC20.sol`](https://docs.openzeppelin.com/contracts/4.x/api/token/erc20#IERC20) [`@openzeppelin/contracts/token/ERC721/ERC721.sol`](https://docs.openzeppelin.com/contracts/4.x/api/token/erc721#IERC721) [`@openzeppelin/security/ReentrancyGuard.sol`](https://docs.openzeppelin.com/contracts/4.x/api/security#ReentrancyGuard) [`@openzeppelin/contracts/token/ERC20/utilities/SafeERC20.sol`](https://docs.openzeppelin.com/contracts/4.x/api/token/erc20#SafeERC20) |
| [ajna-grants/src/grants](ajna-grants/src/grants) | 652 | This contract provides  | [`@openzeppelin/contracts/token/ERC20/ERC20.sol`](https://docs.openzeppelin.com/contracts/4.x/api/token/erc20#IERC20) [`@openzeppelin/contracts/utils/math/SafeCast.sol`](https://docs.openzeppelin.com/contracts/4.x/api/utils#SafeCast) [`@openzeppelin/security/ReentrancyGuard.sol`](https://docs.openzeppelin.com/contracts/4.x/api/security#ReentrancyGuard) [`@openzeppelin/governance/utils/IVotes.sol`](https://docs.openzeppelin.com/contracts/4.x/api/governance#Votes) | [`@openzeppelin/security/ReentrancyGuard.sol`](https://docs.openzeppelin.com/contracts/4.x/api/security#ReentrancyGuard)


## Out of scope

* ./ajna-core/src/* all other contracts ASIDE from `RewardsManager.sol` and `PositionManager.sol` (which are listed above) are out of scope for this audit.
* ./ajna-grants/token

# Additional Context

*Describe any novel or unique curve logic or mathematical models implemented in the contracts*

*Sponsor, please confirm/edit the information below.*

## Scoping Details 
```
- If you have a public code repo, please share it here:  
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

```

## Grants

## PositionManager and RewardsManager

*Provide every step required to build the project from a fresh git clone, as well as steps to run the tests with a gas report.* 

*Note: Many wardens run Slither as a first pass for testing.  Please document any known errors with no workaround.* 
