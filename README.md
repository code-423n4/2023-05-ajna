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
- Submit findings [using the C4 form](https://code4rena.com/contests/2023-05-Ajna-Protocol/submit)
- [Read our guidelines for more details](https://docs.code4rena.com/roles/wardens)
- Starts May 03, 2023 20:00 UTC 
- Ends May 11, 2023 20:00 UTC 

## Automated Findings / Publicly Known Issues

Automated findings output for the contest can be found [here](https://gist.github.com/CloudEllie/a4655b833548ed9a86a63eb7292bcc0f).

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

# Deployment (by contract)

| Contract             | Networks                                                                                                      |
|----------------------|---------------------------------------------------------------------------------------------------------------|
| `RewardsManager.sol` | Ethereum mainnet, Arbitrum, Optimism, Binance Smart Chain, Polygon, Fantom, Tron, Avalanche                   |
| `PositionManager.sol`| Ethereum mainnet, Arbitrum, Optimism, Binance Smart Chain, Polygon, Fantom, Tron, Avalanche                   |
| `GrantFund.sol`      | Ethereum mainnet                                                                                              |

# Scope
### Files in scope
|File|[SLOC](#nowhere "(nSLOC, SLOC, Lines)")|Description|Libraries|
|:-|:-:|:-|:-|
|_Contracts (3)_|
|[ajna-grants/src/grants/GrantFund.sol](https://github.com/code-423n4/2023-05-ajna/blob/main/ajna-grants/src/grants/GrantFund.sol)|[32](#nowhere "(nSLOC:28, SLOC:32, Lines:70)")|| `@oz/*`|
|[ajna-core/src/PositionManager.sol](https://github.com/code-423n4/2023-05-ajna/blob/main/ajna-core/src/PositionManager.sol) [🖥](#nowhere "Uses Assembly") [Σ](#nowhere "Unchecked Blocks")|[186](#nowhere "(nSLOC:165, SLOC:186, Lines:537)")|This contract holds the LP position of lenders and gives them an ERC721 token representing their position in exchange| `@openzeppelin/*`|
|[ajna-core/src/RewardsManager.sol](https://github.com/code-423n4/2023-05-ajna/blob/main/ajna-core/src/RewardsManager.sol) [Σ](#nowhere "Unchecked Blocks")|[386](#nowhere "(nSLOC:324, SLOC:386, Lines:823)")|This contract provides rewards (in Ajna token) to Ajna lenders who lock up their ERC721 position from the PositionManager.sol contract| `@openzeppelin/*`|
|_Abstracts (3)_|
|[ajna-grants/src/grants/base/Funding.sol](https://github.com/code-423n4/2023-05-ajna/blob/main/ajna-grants/src/grants/base/Funding.sol) [🖥](#nowhere "Uses Assembly") [🧮](#nowhere "Uses Hash-Functions") [Σ](#nowhere "Unchecked Blocks")|[66](#nowhere "(nSLOC:48, SLOC:66, Lines:160)")|| `@oz/*`|
|[ajna-grants/src/grants/base/ExtraordinaryFunding.sol](https://github.com/code-423n4/2023-05-ajna/blob/main/ajna-grants/src/grants/base/ExtraordinaryFunding.sol) [🧮](#nowhere "Uses Hash-Functions")|[102](#nowhere "(nSLOC:89, SLOC:102, Lines:309)")|| `@oz/*`|
|[ajna-grants/src/grants/base/StandardFunding.sol](https://github.com/code-423n4/2023-05-ajna/blob/main/ajna-grants/src/grants/base/StandardFunding.sol) [🧮](#nowhere "Uses Hash-Functions") [Σ](#nowhere "Unchecked Blocks")|[372](#nowhere "(nSLOC:307, SLOC:372, Lines:1026)")|| `@oz/*`|
|_Libraries (1)_|
|[ajna-grants/src/grants/libraries/Maths.sol](https://github.com/code-423n4/2023-05-ajna/blob/main/ajna-grants/src/grants/libraries/Maths.sol)|[38](#nowhere "(nSLOC:38, SLOC:38, Lines:58)")|||
|_Interfaces (4)_|
|[ajna-grants/src/grants/interfaces/IGrantFund.sol](https://github.com/code-423n4/2023-05-ajna/blob/main/ajna-grants/src/grants/interfaces/IGrantFund.sol)|[21](#nowhere "(nSLOC:14, SLOC:21, Lines:66)")|||
|[ajna-grants/src/grants/interfaces/IFunding.sol](https://github.com/code-423n4/2023-05-ajna/blob/main/ajna-grants/src/grants/interfaces/IFunding.sol)|[35](#nowhere "(nSLOC:35, SLOC:35, Lines:96)")|||
|[ajna-grants/src/grants/interfaces/IExtraordinaryFunding.sol](https://github.com/code-423n4/2023-05-ajna/blob/main/ajna-grants/src/grants/interfaces/IExtraordinaryFunding.sol)|[41](#nowhere "(nSLOC:22, SLOC:41, Lines:150)")|||
|[ajna-grants/src/grants/interfaces/IStandardFunding.sol](https://github.com/code-423n4/2023-05-ajna/blob/main/ajna-grants/src/grants/interfaces/IStandardFunding.sol)|[112](#nowhere "(nSLOC:75, SLOC:112, Lines:384)")|||
|Total (over 11 files):| [1391](#nowhere "(nSLOC:1145, SLOC:1391, Lines:3679)") ||


### All other source contracts (out of scope)
|File|[SLOC](#nowhere "(nSLOC, SLOC, Lines)")|Description|Libraries|
|:-|:-:|:-|:-|
|_Contracts (7)_|
|[ajna-grants/src/token/AjnaToken.sol](https://github.com/code-423n4/2023-05-ajna/blob/main/ajna-grants/src/token/AjnaToken.sol)|[25](#nowhere "(nSLOC:23, SLOC:25, Lines:61)")|| `@oz/*`|
|[ajna-grants/src/token/BurnWrapper.sol](https://github.com/code-423n4/2023-05-ajna/blob/main/ajna-grants/src/token/BurnWrapper.sol)|[27](#nowhere "(nSLOC:27, SLOC:27, Lines:60)")|| `@oz/*`|
|[ajna-core/src/ERC20PoolFactory.sol](https://github.com/code-423n4/2023-05-ajna/blob/main/ajna-core/src/ERC20PoolFactory.sol) [🧮](#nowhere "Uses Hash-Functions") [🌀](#nowhere "create/create2")|[38](#nowhere "(nSLOC:36, SLOC:38, Lines:80)")|| `@clones/*`|
|[ajna-core/src/ERC721PoolFactory.sol](https://github.com/code-423n4/2023-05-ajna/blob/main/ajna-core/src/ERC721PoolFactory.sol) [🧮](#nowhere "Uses Hash-Functions") [🌀](#nowhere "create/create2") [♻️](#nowhere "TryCatch Blocks") [Σ](#nowhere "Unchecked Blocks")|[59](#nowhere "(nSLOC:57, SLOC:59, Lines:126)")|| `@clones/*` `@openzeppelin/*`|
|[ajna-core/src/ERC20Pool.sol](https://github.com/code-423n4/2023-05-ajna/blob/main/ajna-core/src/ERC20Pool.sol)|[261](#nowhere "(nSLOC:229, SLOC:261, Lines:504)")|| `@openzeppelin/*`|
|[ajna-core/src/PoolInfoUtils.sol](https://github.com/code-423n4/2023-05-ajna/blob/main/ajna-core/src/PoolInfoUtils.sol)|[307](#nowhere "(nSLOC:193, SLOC:307, Lines:524)")|||
|[ajna-core/src/ERC721Pool.sol](https://github.com/code-423n4/2023-05-ajna/blob/main/ajna-core/src/ERC721Pool.sol) [Σ](#nowhere "Unchecked Blocks")|[321](#nowhere "(nSLOC:277, SLOC:321, Lines:629)")|||
|_Abstracts (4)_|
|[ajna-core/src/base/PoolDeployer.sol](https://github.com/code-423n4/2023-05-ajna/blob/main/ajna-core/src/base/PoolDeployer.sol)|[19](#nowhere "(nSLOC:19, SLOC:19, Lines:70)")|||
|[ajna-core/src/base/FlashloanablePool.sol](https://github.com/code-423n4/2023-05-ajna/blob/main/ajna-core/src/base/FlashloanablePool.sol) [🧮](#nowhere "Uses Hash-Functions")|[49](#nowhere "(nSLOC:37, SLOC:49, Lines:94)")|| `@openzeppelin/*`|
|[ajna-core/src/base/PermitERC721.sol](https://github.com/code-423n4/2023-05-ajna/blob/main/ajna-core/src/base/PermitERC721.sol) [🖥](#nowhere "Uses Assembly") [🧮](#nowhere "Uses Hash-Functions") [🔖](#nowhere "Handles Signatures: ecrecover")|[72](#nowhere "(nSLOC:68, SLOC:72, Lines:125)")|| `@openzeppelin/*`|
|[ajna-core/src/base/Pool.sol](https://github.com/code-423n4/2023-05-ajna/blob/main/ajna-core/src/base/Pool.sol)|[458](#nowhere "(nSLOC:402, SLOC:458, Lines:957)")|| `@clones/*` `@openzeppelin/*`|
|_Libraries (12)_|
|[ajna-core/src/libraries/internal/Maths.sol](https://github.com/code-423n4/2023-05-ajna/blob/main/ajna-core/src/libraries/internal/Maths.sol)|[47](#nowhere "(nSLOC:47, SLOC:47, Lines:73)")|||
|[ajna-core/src/libraries/internal/Buckets.sol](https://github.com/code-423n4/2023-05-ajna/blob/main/ajna-core/src/libraries/internal/Buckets.sol)|[69](#nowhere "(nSLOC:41, SLOC:69, Lines:153)")|||
|[ajna-core/src/libraries/external/PositionNFTSVG.sol](https://github.com/code-423n4/2023-05-ajna/blob/main/ajna-core/src/libraries/external/PositionNFTSVG.sol)|[108](#nowhere "(nSLOC:108, SLOC:108, Lines:178)")|| `@openzeppelin/*` `@base64-sol/*`|
|[ajna-core/src/libraries/internal/Loans.sol](https://github.com/code-423n4/2023-05-ajna/blob/main/ajna-core/src/libraries/internal/Loans.sol)|[122](#nowhere "(nSLOC:106, SLOC:122, Lines:266)")|||
|[ajna-core/src/libraries/external/LPActions.sol](https://github.com/code-423n4/2023-05-ajna/blob/main/ajna-core/src/libraries/external/LPActions.sol) [Σ](#nowhere "Unchecked Blocks")|[140](#nowhere "(nSLOC:113, SLOC:140, Lines:280)")|||
|[ajna-core/src/libraries/internal/Deposits.sol](https://github.com/code-423n4/2023-05-ajna/blob/main/ajna-core/src/libraries/internal/Deposits.sol)|[186](#nowhere "(nSLOC:149, SLOC:186, Lines:393)")|||
|[ajna-core/src/libraries/external/PoolCommons.sol](https://github.com/code-423n4/2023-05-ajna/blob/main/ajna-core/src/libraries/external/PoolCommons.sol)|[218](#nowhere "(nSLOC:178, SLOC:218, Lines:424)")|| `@prb-math/*`|
|[ajna-core/src/libraries/external/SettlerActions.sol](https://github.com/code-423n4/2023-05-ajna/blob/main/ajna-core/src/libraries/external/SettlerActions.sol)|[260](#nowhere "(nSLOC:230, SLOC:260, Lines:483)")|||
|[ajna-core/src/libraries/external/BorrowerActions.sol](https://github.com/code-423n4/2023-05-ajna/blob/main/ajna-core/src/libraries/external/BorrowerActions.sol)|[261](#nowhere "(nSLOC:227, SLOC:261, Lines:480)")|||
|[ajna-core/src/libraries/external/KickerActions.sol](https://github.com/code-423n4/2023-05-ajna/blob/main/ajna-core/src/libraries/external/KickerActions.sol)|[270](#nowhere "(nSLOC:227, SLOC:270, Lines:507)")|||
|[ajna-core/src/libraries/external/LenderActions.sol](https://github.com/code-423n4/2023-05-ajna/blob/main/ajna-core/src/libraries/external/LenderActions.sol) [Σ](#nowhere "Unchecked Blocks")|[393](#nowhere "(nSLOC:349, SLOC:393, Lines:739)")|||
|[ajna-core/src/libraries/external/TakerActions.sol](https://github.com/code-423n4/2023-05-ajna/blob/main/ajna-core/src/libraries/external/TakerActions.sol)|[423](#nowhere "(nSLOC:354, SLOC:423, Lines:778)")|| `@prb-math/*`|
|_Interfaces (43)_|
|[ajna-core/src/interfaces/pool/commons/IPoolBorrowerActions.sol](https://github.com/code-423n4/2023-05-ajna/blob/main/ajna-core/src/interfaces/pool/commons/IPoolBorrowerActions.sol)|[4](#nowhere "(nSLOC:4, SLOC:4, Lines:17)")|||
|[ajna-core/src/interfaces/pool/erc20/IERC20PoolImmutables.sol](https://github.com/code-423n4/2023-05-ajna/blob/main/ajna-core/src/interfaces/pool/erc20/IERC20PoolImmutables.sol)|[4](#nowhere "(nSLOC:4, SLOC:4, Lines:16)")|||
|[ajna-core/src/interfaces/pool/erc721/IERC721PoolErrors.sol](https://github.com/code-423n4/2023-05-ajna/blob/main/ajna-core/src/interfaces/pool/erc721/IERC721PoolErrors.sol)|[4](#nowhere "(nSLOC:4, SLOC:4, Lines:14)")|||
|[ajna-core/src/interfaces/pool/erc721/IERC721PoolImmutables.sol](https://github.com/code-423n4/2023-05-ajna/blob/main/ajna-core/src/interfaces/pool/erc721/IERC721PoolImmutables.sol)|[4](#nowhere "(nSLOC:4, SLOC:4, Lines:16)")|||
|[ajna-core/src/interfaces/pool/commons/IPoolSettlerActions.sol](https://github.com/code-423n4/2023-05-ajna/blob/main/ajna-core/src/interfaces/pool/commons/IPoolSettlerActions.sol)|[7](#nowhere "(nSLOC:4, SLOC:7, Lines:21)")|||
|[ajna-core/src/interfaces/rewards/IRewardsManagerDerivedState.sol](https://github.com/code-423n4/2023-05-ajna/blob/main/ajna-core/src/interfaces/rewards/IRewardsManagerDerivedState.sol)|[7](#nowhere "(nSLOC:4, SLOC:7, Lines:21)")|||
|[ajna-core/src/interfaces/pool/IPoolFactory.sol](https://github.com/code-423n4/2023-05-ajna/blob/main/ajna-core/src/interfaces/pool/IPoolFactory.sol)|[8](#nowhere "(nSLOC:8, SLOC:8, Lines:43)")|||
|[ajna-core/src/interfaces/pool/commons/IPoolImmutables.sol](https://github.com/code-423n4/2023-05-ajna/blob/main/ajna-core/src/interfaces/pool/commons/IPoolImmutables.sol)|[8](#nowhere "(nSLOC:8, SLOC:8, Lines:35)")|||
|[ajna-core/src/interfaces/pool/erc20/IERC20PoolLenderActions.sol](https://github.com/code-423n4/2023-05-ajna/blob/main/ajna-core/src/interfaces/pool/erc20/IERC20PoolLenderActions.sol)|[8](#nowhere "(nSLOC:4, SLOC:8, Lines:22)")|||
|[ajna-core/src/interfaces/pool/erc20/IERC20Taker.sol](https://github.com/code-423n4/2023-05-ajna/blob/main/ajna-core/src/interfaces/pool/erc20/IERC20Taker.sol)|[8](#nowhere "(nSLOC:4, SLOC:8, Lines:18)")|||
|[ajna-core/src/interfaces/pool/erc721/IERC721Taker.sol](https://github.com/code-423n4/2023-05-ajna/blob/main/ajna-core/src/interfaces/pool/erc721/IERC721Taker.sol)|[8](#nowhere "(nSLOC:4, SLOC:8, Lines:18)")|||
|[ajna-core/src/interfaces/rewards/IRewardsManagerErrors.sol](https://github.com/code-423n4/2023-05-ajna/blob/main/ajna-core/src/interfaces/rewards/IRewardsManagerErrors.sol)|[8](#nowhere "(nSLOC:8, SLOC:8, Lines:33)")|||
|[ajna-core/src/interfaces/pool/erc20/IERC20PoolFactory.sol](https://github.com/code-423n4/2023-05-ajna/blob/main/ajna-core/src/interfaces/pool/erc20/IERC20PoolFactory.sol)|[9](#nowhere "(nSLOC:5, SLOC:9, Lines:30)")|||
|[ajna-core/src/interfaces/position/IPositionManagerErrors.sol](https://github.com/code-423n4/2023-05-ajna/blob/main/ajna-core/src/interfaces/position/IPositionManagerErrors.sol)|[9](#nowhere "(nSLOC:9, SLOC:9, Lines:39)")|||
|[ajna-core/src/interfaces/pool/IERC3156FlashBorrower.sol](https://github.com/code-423n4/2023-05-ajna/blob/main/ajna-core/src/interfaces/pool/IERC3156FlashBorrower.sol)|[10](#nowhere "(nSLOC:4, SLOC:10, Lines:23)")|||
|[ajna-core/src/interfaces/position/IPositionManagerState.sol](https://github.com/code-423n4/2023-05-ajna/blob/main/ajna-core/src/interfaces/position/IPositionManagerState.sol)|[10](#nowhere "(nSLOC:8, SLOC:10, Lines:24)")|||
|[ajna-core/src/interfaces/pool/erc721/IERC721PoolFactory.sol](https://github.com/code-423n4/2023-05-ajna/blob/main/ajna-core/src/interfaces/pool/erc721/IERC721PoolFactory.sol)|[12](#nowhere "(nSLOC:7, SLOC:12, Lines:46)")|||
|[ajna-core/src/interfaces/pool/erc721/IERC721PoolLenderActions.sol](https://github.com/code-423n4/2023-05-ajna/blob/main/ajna-core/src/interfaces/pool/erc721/IERC721PoolLenderActions.sol)|[13](#nowhere "(nSLOC:5, SLOC:13, Lines:36)")|||
|[ajna-core/src/interfaces/position/IPositionManager.sol](https://github.com/code-423n4/2023-05-ajna/blob/main/ajna-core/src/interfaces/position/IPositionManager.sol)|[14](#nowhere "(nSLOC:14, SLOC:14, Lines:22)")|||
|[ajna-core/src/interfaces/rewards/IRewardsManager.sol](https://github.com/code-423n4/2023-05-ajna/blob/main/ajna-core/src/interfaces/rewards/IRewardsManager.sol)|[14](#nowhere "(nSLOC:14, SLOC:14, Lines:19)")|||
|[ajna-core/src/interfaces/pool/erc20/IERC20PoolEvents.sol](https://github.com/code-423n4/2023-05-ajna/blob/main/ajna-core/src/interfaces/pool/erc20/IERC20PoolEvents.sol)|[15](#nowhere "(nSLOC:15, SLOC:15, Lines:37)")|||
|[ajna-core/src/interfaces/pool/commons/IPoolKickerActions.sol](https://github.com/code-423n4/2023-05-ajna/blob/main/ajna-core/src/interfaces/pool/commons/IPoolKickerActions.sol)|[16](#nowhere "(nSLOC:7, SLOC:16, Lines:52)")|||
|[ajna-core/src/interfaces/pool/erc20/IERC20PoolBorrowerActions.sol](https://github.com/code-423n4/2023-05-ajna/blob/main/ajna-core/src/interfaces/pool/erc20/IERC20PoolBorrowerActions.sol)|[16](#nowhere "(nSLOC:5, SLOC:16, Lines:41)")|||
|[ajna-core/src/interfaces/pool/erc721/IERC721PoolBorrowerActions.sol](https://github.com/code-423n4/2023-05-ajna/blob/main/ajna-core/src/interfaces/pool/erc721/IERC721PoolBorrowerActions.sol)|[16](#nowhere "(nSLOC:5, SLOC:16, Lines:41)")|||
|[ajna-core/src/interfaces/pool/IERC3156FlashLender.sol](https://github.com/code-423n4/2023-05-ajna/blob/main/ajna-core/src/interfaces/pool/IERC3156FlashLender.sol)|[17](#nowhere "(nSLOC:7, SLOC:17, Lines:43)")|||
|[ajna-core/src/interfaces/pool/commons/IPoolDerivedState.sol](https://github.com/code-423n4/2023-05-ajna/blob/main/ajna-core/src/interfaces/pool/commons/IPoolDerivedState.sol)|[17](#nowhere "(nSLOC:9, SLOC:17, Lines:58)")|||
|[ajna-core/src/interfaces/pool/commons/IPoolTakerActions.sol](https://github.com/code-423n4/2023-05-ajna/blob/main/ajna-core/src/interfaces/pool/commons/IPoolTakerActions.sol)|[17](#nowhere "(nSLOC:6, SLOC:17, Lines:51)")|||
|[ajna-core/src/interfaces/pool/erc721/IERC721PoolState.sol](https://github.com/code-423n4/2023-05-ajna/blob/main/ajna-core/src/interfaces/pool/erc721/IERC721PoolState.sol)|[17](#nowhere "(nSLOC:8, SLOC:17, Lines:53)")|||
|[ajna-core/src/interfaces/pool/erc20/IERC20Pool.sol](https://github.com/code-423n4/2023-05-ajna/blob/main/ajna-core/src/interfaces/pool/erc20/IERC20Pool.sol)|[18](#nowhere "(nSLOC:16, SLOC:18, Lines:37)")|||
|[ajna-core/src/interfaces/pool/erc721/IERC721PoolEvents.sol](https://github.com/code-423n4/2023-05-ajna/blob/main/ajna-core/src/interfaces/pool/erc721/IERC721PoolEvents.sol)|[20](#nowhere "(nSLOC:20, SLOC:20, Lines:49)")|||
|[ajna-core/src/interfaces/pool/erc721/IERC721Pool.sol](https://github.com/code-423n4/2023-05-ajna/blob/main/ajna-core/src/interfaces/pool/erc721/IERC721Pool.sol)|[22](#nowhere "(nSLOC:19, SLOC:22, Lines:37)")|||
|[ajna-core/src/interfaces/pool/commons/IPoolLenderActions.sol](https://github.com/code-423n4/2023-05-ajna/blob/main/ajna-core/src/interfaces/pool/commons/IPoolLenderActions.sol)|[23](#nowhere "(nSLOC:8, SLOC:23, Lines:77)")|||
|[ajna-core/src/interfaces/rewards/IRewardsManagerOwnerActions.sol](https://github.com/code-423n4/2023-05-ajna/blob/main/ajna-core/src/interfaces/rewards/IRewardsManagerOwnerActions.sol)|[23](#nowhere "(nSLOC:8, SLOC:23, Lines:68)")|||
|[ajna-core/src/interfaces/position/IPositionManagerDerivedState.sol](https://github.com/code-423n4/2023-05-ajna/blob/main/ajna-core/src/interfaces/position/IPositionManagerDerivedState.sol)|[25](#nowhere "(nSLOC:9, SLOC:25, Lines:75)")|||
|[ajna-core/src/interfaces/pool/commons/IPoolLPActions.sol](https://github.com/code-423n4/2023-05-ajna/blob/main/ajna-core/src/interfaces/pool/commons/IPoolLPActions.sol)|[28](#nowhere "(nSLOC:9, SLOC:28, Lines:76)")|||
|[ajna-core/src/interfaces/position/IPositionManagerEvents.sol](https://github.com/code-423n4/2023-05-ajna/blob/main/ajna-core/src/interfaces/position/IPositionManagerEvents.sol)|[30](#nowhere "(nSLOC:30, SLOC:30, Lines:71)")|||
|[ajna-core/src/interfaces/rewards/IRewardsManagerEvents.sol](https://github.com/code-423n4/2023-05-ajna/blob/main/ajna-core/src/interfaces/rewards/IRewardsManagerEvents.sol)|[31](#nowhere "(nSLOC:31, SLOC:31, Lines:75)")|||
|[ajna-core/src/interfaces/rewards/IRewardsManagerState.sol](https://github.com/code-423n4/2023-05-ajna/blob/main/ajna-core/src/interfaces/rewards/IRewardsManagerState.sol)|[34](#nowhere "(nSLOC:22, SLOC:34, Lines:81)")|||
|[ajna-core/src/interfaces/position/IPositionManagerOwnerActions.sol](https://github.com/code-423n4/2023-05-ajna/blob/main/ajna-core/src/interfaces/position/IPositionManagerOwnerActions.sol)|[43](#nowhere "(nSLOC:33, SLOC:43, Lines:109)")|||
|[ajna-core/src/interfaces/pool/commons/IPoolErrors.sol](https://github.com/code-423n4/2023-05-ajna/blob/main/ajna-core/src/interfaces/pool/commons/IPoolErrors.sol)|[44](#nowhere "(nSLOC:44, SLOC:44, Lines:222)")|||
|[ajna-core/src/interfaces/pool/IPool.sol](https://github.com/code-423n4/2023-05-ajna/blob/main/ajna-core/src/interfaces/pool/IPool.sol)|[47](#nowhere "(nSLOC:39, SLOC:47, Lines:62)")|||
|[ajna-core/src/interfaces/pool/commons/IPoolState.sol](https://github.com/code-423n4/2023-05-ajna/blob/main/ajna-core/src/interfaces/pool/commons/IPoolState.sol)|[142](#nowhere "(nSLOC:39, SLOC:142, Lines:446)")|||
|[ajna-core/src/interfaces/pool/commons/IPoolEvents.sol](https://github.com/code-423n4/2023-05-ajna/blob/main/ajna-core/src/interfaces/pool/commons/IPoolEvents.sol)|[145](#nowhere "(nSLOC:145, SLOC:145, Lines:370)")|||
|_Structs (1)_|
|[ajna-core/src/interfaces/pool/commons/IPoolInternals.sol](https://github.com/code-423n4/2023-05-ajna/blob/main/ajna-core/src/interfaces/pool/commons/IPoolInternals.sol)|[33](#nowhere "(nSLOC:33, SLOC:33, Lines:127)")|||
|_Constants (1)_|
|[ajna-core/src/libraries/helpers/PoolHelper.sol](https://github.com/code-423n4/2023-05-ajna/blob/main/ajna-core/src/libraries/helpers/PoolHelper.sol)|[199](#nowhere "(nSLOC:136, SLOC:199, Lines:405)")|| `@prb-math/*`|
|_Other (2)_|
|[ajna-core/src/libraries/helpers/SafeTokenNamer.sol](https://github.com/code-423n4/2023-05-ajna/blob/main/ajna-core/src/libraries/helpers/SafeTokenNamer.sol)|[45](#nowhere "(nSLOC:45, SLOC:45, Lines:102)")|||
|[ajna-core/src/libraries/helpers/RevertsHelper.sol](https://github.com/code-423n4/2023-05-ajna/blob/main/ajna-core/src/libraries/helpers/RevertsHelper.sol)|[64](#nowhere "(nSLOC:46, SLOC:64, Lines:110)")|||
|Total (over 70 files):| [5449](#nowhere "(nSLOC:4417, SLOC:5449, Lines:11472)") ||


## External imports
* **@base64-sol/base64.sol**
  * ~~[ajna-core/src/libraries/external/PositionNFTSVG.sol](https://github.com/code-423n4/2023-05-ajna/blob/main/ajna-core/src/libraries/external/PositionNFTSVG.sol)~~
* **@clones/Clone.sol**
  * ~~[ajna-core/src/base/Pool.sol](https://github.com/code-423n4/2023-05-ajna/blob/main/ajna-core/src/base/Pool.sol)~~
* **@clones/ClonesWithImmutableArgs.sol**
  * ~~[ajna-core/src/ERC20PoolFactory.sol](https://github.com/code-423n4/2023-05-ajna/blob/main/ajna-core/src/ERC20PoolFactory.sol)~~
  * ~~[ajna-core/src/ERC721PoolFactory.sol](https://github.com/code-423n4/2023-05-ajna/blob/main/ajna-core/src/ERC721PoolFactory.sol)~~
* **@openzeppelin/contracts/interfaces/IERC1271.sol**
  * ~~[ajna-core/src/base/PermitERC721.sol](https://github.com/code-423n4/2023-05-ajna/blob/main/ajna-core/src/base/PermitERC721.sol)~~
* **@openzeppelin/contracts/security/ReentrancyGuard.sol**
  * [ajna-core/src/PositionManager.sol](https://github.com/code-423n4/2023-05-ajna/blob/main/ajna-core/src/PositionManager.sol)
  * [ajna-core/src/RewardsManager.sol](https://github.com/code-423n4/2023-05-ajna/blob/main/ajna-core/src/RewardsManager.sol)
  * ~~[ajna-core/src/base/Pool.sol](https://github.com/code-423n4/2023-05-ajna/blob/main/ajna-core/src/base/Pool.sol)~~
* **@openzeppelin/contracts/token/ERC20/ERC20.sol**
  * [ajna-core/src/PositionManager.sol](https://github.com/code-423n4/2023-05-ajna/blob/main/ajna-core/src/PositionManager.sol)
* **@openzeppelin/contracts/token/ERC20/IERC20.sol**
  * ~~[ajna-core/src/ERC20Pool.sol](https://github.com/code-423n4/2023-05-ajna/blob/main/ajna-core/src/ERC20Pool.sol)~~
  * [ajna-core/src/PositionManager.sol](https://github.com/code-423n4/2023-05-ajna/blob/main/ajna-core/src/PositionManager.sol)
  * [ajna-core/src/RewardsManager.sol](https://github.com/code-423n4/2023-05-ajna/blob/main/ajna-core/src/RewardsManager.sol)
  * ~~[ajna-core/src/base/FlashloanablePool.sol](https://github.com/code-423n4/2023-05-ajna/blob/main/ajna-core/src/base/FlashloanablePool.sol)~~
  * ~~[ajna-core/src/base/Pool.sol](https://github.com/code-423n4/2023-05-ajna/blob/main/ajna-core/src/base/Pool.sol)~~
* **@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol**
  * ~~[ajna-core/src/ERC20Pool.sol](https://github.com/code-423n4/2023-05-ajna/blob/main/ajna-core/src/ERC20Pool.sol)~~
  * [ajna-core/src/PositionManager.sol](https://github.com/code-423n4/2023-05-ajna/blob/main/ajna-core/src/PositionManager.sol)
  * [ajna-core/src/RewardsManager.sol](https://github.com/code-423n4/2023-05-ajna/blob/main/ajna-core/src/RewardsManager.sol)
  * ~~[ajna-core/src/base/FlashloanablePool.sol](https://github.com/code-423n4/2023-05-ajna/blob/main/ajna-core/src/base/FlashloanablePool.sol)~~
  * ~~[ajna-core/src/base/Pool.sol](https://github.com/code-423n4/2023-05-ajna/blob/main/ajna-core/src/base/Pool.sol)~~
* **@openzeppelin/contracts/token/ERC721/ERC721.sol**
  * [ajna-core/src/PositionManager.sol](https://github.com/code-423n4/2023-05-ajna/blob/main/ajna-core/src/PositionManager.sol)
  * ~~[ajna-core/src/base/PermitERC721.sol](https://github.com/code-423n4/2023-05-ajna/blob/main/ajna-core/src/base/PermitERC721.sol)~~
* **@openzeppelin/contracts/token/ERC721/IERC721.sol**
  * [ajna-core/src/RewardsManager.sol](https://github.com/code-423n4/2023-05-ajna/blob/main/ajna-core/src/RewardsManager.sol)
* **@openzeppelin/contracts/utils/Address.sol**
  * ~~[ajna-core/src/base/PermitERC721.sol](https://github.com/code-423n4/2023-05-ajna/blob/main/ajna-core/src/base/PermitERC721.sol)~~
* **@openzeppelin/contracts/utils/introspection/IERC165.sol**
  * ~~[ajna-core/src/ERC721PoolFactory.sol](https://github.com/code-423n4/2023-05-ajna/blob/main/ajna-core/src/ERC721PoolFactory.sol)~~
* **@openzeppelin/contracts/utils/Multicall.sol**
  * [ajna-core/src/PositionManager.sol](https://github.com/code-423n4/2023-05-ajna/blob/main/ajna-core/src/PositionManager.sol)
  * ~~[ajna-core/src/base/Pool.sol](https://github.com/code-423n4/2023-05-ajna/blob/main/ajna-core/src/base/Pool.sol)~~
* **@openzeppelin/contracts/utils/Strings.sol**
  * ~~[ajna-core/src/libraries/external/PositionNFTSVG.sol](https://github.com/code-423n4/2023-05-ajna/blob/main/ajna-core/src/libraries/external/PositionNFTSVG.sol)~~
* **@openzeppelin/contracts/utils/structs/EnumerableSet.sol**
  * [ajna-core/src/PositionManager.sol](https://github.com/code-423n4/2023-05-ajna/blob/main/ajna-core/src/PositionManager.sol)
* **@oz/governance/utils/IVotes.sol**
  * [ajna-grants/src/grants/base/Funding.sol](https://github.com/code-423n4/2023-05-ajna/blob/main/ajna-grants/src/grants/base/Funding.sol)
* **@oz/security/ReentrancyGuard.sol**
  * [ajna-grants/src/grants/base/Funding.sol](https://github.com/code-423n4/2023-05-ajna/blob/main/ajna-grants/src/grants/base/Funding.sol)
* **@oz/token/ERC20/ERC20.sol**
  * ~~[ajna-grants/src/token/AjnaToken.sol](https://github.com/code-423n4/2023-05-ajna/blob/main/ajna-grants/src/token/AjnaToken.sol)~~
  * ~~[ajna-grants/src/token/BurnWrapper.sol](https://github.com/code-423n4/2023-05-ajna/blob/main/ajna-grants/src/token/BurnWrapper.sol)~~
* **@oz/token/ERC20/extensions/draft-ERC20Permit.sol**
  * ~~[ajna-grants/src/token/AjnaToken.sol](https://github.com/code-423n4/2023-05-ajna/blob/main/ajna-grants/src/token/AjnaToken.sol)~~
  * ~~[ajna-grants/src/token/BurnWrapper.sol](https://github.com/code-423n4/2023-05-ajna/blob/main/ajna-grants/src/token/BurnWrapper.sol)~~
* **@oz/token/ERC20/extensions/ERC20Burnable.sol**
  * ~~[ajna-grants/src/token/AjnaToken.sol](https://github.com/code-423n4/2023-05-ajna/blob/main/ajna-grants/src/token/AjnaToken.sol)~~
  * ~~[ajna-grants/src/token/BurnWrapper.sol](https://github.com/code-423n4/2023-05-ajna/blob/main/ajna-grants/src/token/BurnWrapper.sol)~~
* **@oz/token/ERC20/extensions/ERC20Votes.sol**
  * ~~[ajna-grants/src/token/AjnaToken.sol](https://github.com/code-423n4/2023-05-ajna/blob/main/ajna-grants/src/token/AjnaToken.sol)~~
* **@oz/token/ERC20/extensions/ERC20Wrapper.sol**
  * ~~[ajna-grants/src/token/BurnWrapper.sol](https://github.com/code-423n4/2023-05-ajna/blob/main/ajna-grants/src/token/BurnWrapper.sol)~~
* **@oz/token/ERC20/extensions/IERC20Metadata.sol**
  * ~~[ajna-grants/src/token/BurnWrapper.sol](https://github.com/code-423n4/2023-05-ajna/blob/main/ajna-grants/src/token/BurnWrapper.sol)~~
* **@oz/token/ERC20/IERC20.sol**
  * [ajna-grants/src/grants/GrantFund.sol](https://github.com/code-423n4/2023-05-ajna/blob/main/ajna-grants/src/grants/GrantFund.sol)
  * [ajna-grants/src/grants/base/ExtraordinaryFunding.sol](https://github.com/code-423n4/2023-05-ajna/blob/main/ajna-grants/src/grants/base/ExtraordinaryFunding.sol)
  * [ajna-grants/src/grants/base/StandardFunding.sol](https://github.com/code-423n4/2023-05-ajna/blob/main/ajna-grants/src/grants/base/StandardFunding.sol)
  * ~~[ajna-grants/src/token/BurnWrapper.sol](https://github.com/code-423n4/2023-05-ajna/blob/main/ajna-grants/src/token/BurnWrapper.sol)~~
* **@oz/token/ERC20/utils/SafeERC20.sol**
  * [ajna-grants/src/grants/GrantFund.sol](https://github.com/code-423n4/2023-05-ajna/blob/main/ajna-grants/src/grants/GrantFund.sol)
  * [ajna-grants/src/grants/base/StandardFunding.sol](https://github.com/code-423n4/2023-05-ajna/blob/main/ajna-grants/src/grants/base/StandardFunding.sol)
* **@oz/utils/Address.sol**
  * [ajna-grants/src/grants/base/Funding.sol](https://github.com/code-423n4/2023-05-ajna/blob/main/ajna-grants/src/grants/base/Funding.sol)
* **@oz/utils/math/SafeCast.sol**
  * [ajna-grants/src/grants/base/ExtraordinaryFunding.sol](https://github.com/code-423n4/2023-05-ajna/blob/main/ajna-grants/src/grants/base/ExtraordinaryFunding.sol)
  * [ajna-grants/src/grants/base/Funding.sol](https://github.com/code-423n4/2023-05-ajna/blob/main/ajna-grants/src/grants/base/Funding.sol)
  * [ajna-grants/src/grants/base/StandardFunding.sol](https://github.com/code-423n4/2023-05-ajna/blob/main/ajna-grants/src/grants/base/StandardFunding.sol)
* **@prb-math/contracts/PRBMathSD59x18.sol**
  * ~~[ajna-core/src/libraries/external/PoolCommons.sol](https://github.com/code-423n4/2023-05-ajna/blob/main/ajna-core/src/libraries/external/PoolCommons.sol)~~
  * ~~[ajna-core/src/libraries/external/TakerActions.sol](https://github.com/code-423n4/2023-05-ajna/blob/main/ajna-core/src/libraries/external/TakerActions.sol)~~
  * ~~[ajna-core/src/libraries/helpers/PoolHelper.sol](https://github.com/code-423n4/2023-05-ajna/blob/main/ajna-core/src/libraries/helpers/PoolHelper.sol)~~
* **@prb-math/contracts/PRBMathUD60x18.sol**
  * ~~[ajna-core/src/libraries/external/PoolCommons.sol](https://github.com/code-423n4/2023-05-ajna/blob/main/ajna-core/src/libraries/external/PoolCommons.sol)~~

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

# Previous Audits
- [Sherlock report](https://github.com/ajna-finance/audits/tree/main/sherlock)
- [Trail of Bits report](https://github.com/ajna-finance/audits/tree/main/tob)


# Tests
## Quickstart command
`export ETH_RPC_URL='<RPC_URL_HERE>' && export QUOTE_PRECISION=18 && export COLLATERAL_PRECISION=18 && export BUCKET_INDEX_ERC20=2570 && export BUCKET_INDEX_ERC721=850 && export NO_OF_BUCKETS=3 && rm -Rf 2023-05-ajna || true && git clone https://github.com/code-423n4/2023-05-ajna.git -j8 --recurse-submodules && cd 2023-05-ajna && foundryup -v nightly-87bc53fc6c874bd4c92d97ed180b949e3a36d78c && cd ajna-grants && make test-with-gas-report && cd .. && cd ajna-core && make test-with-gas-report && cd ..`

**NOTE**:
- install `foundry` by running `foundryup -v nightly-87bc53fc6c874bd4c92d97ed180b949e3a36d78c` (this version is required due to breaking changes introduced in foundry-rs/foundry#4827)
- Follow instructions in each sub repo -> Make a copy of .env.example and name it .env add the values for
  - `ETHERSCAN_TOKEN` - required by brownie to verify contract sources
  - `WEB3_INFURA_PROJECT_ID` - required by brownie to fork chain
  - `ETH_RPC_URL` - required by forge to fork chain
  - `QUOTE_PRECISION` - required by invariant tests
  - `COLLATERAL_PRECISION` - required by invariant tests
  - `BUCKET_INDEX_ERC20` - required by invariant tests
  - `BUCKET_INDEX_ERC721` - required by invariant tests
  - `NO_OF_BUCKETS` - required by invariant tests

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

## Known slither issues

| Issue                                      | File Effected                         | Reason / Explanation |
|--------------------------------------------|---------------------------------------|---------------------|
| Arbitrary from in transferFrom             | src/base/FlashloanablePool.sol#48-52 | Implemented as designed so auctions can be atomically swapped |
| Incorrect ERC20 function interface         | src/interfaces/pool/IPool.sol#57-61  | Non-issue believe to be slither related |
| Dangerous strict equalities                | src/base/Pool.sol#384                | Implemented as designed to restrict contract surface area |
| Dead code                                  | src/base/FlashloanablePool.sol#89-93 | dead code is from the abstract contract, implemented by concrete contracts |
| State variables that could be declared immutable | src/ERC20PoolFactory.sol#25    | Limits Ajna to specific chain, no action |
| State variables that could be declared immutable | src/base/PoolDeployer.sol#19   | Limits Ajna to specific chain, no action |

| Known Contracts That Exceed Spurious Dragon Req |
|-------------------------------------------------|
| src/ERC20PoolFactory.sol                        |
| src/ERC20Pool.sol                               |
| src/RewardsManager.sol                          |
| src/PositionManager.sol                         |
| src/ERC721PoolFactory.sol                       |
| src/ERC721Pool.sol                              |
