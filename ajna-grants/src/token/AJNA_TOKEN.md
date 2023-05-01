# Ajna Token

Ajna ERC20 Token contract

| Deployment | Address |
| ------: | ------- |
| Mainnet | [0x9a96ec9B57Fb64FbC60B423d1f4da7691Bd35079](https://etherscan.io/address/0x9a96ec9b57fb64fbc60b423d1f4da7691bd35079) |
| Goerli  | [0xaadebCF61AA7Da0573b524DE57c67aDa797D46c5](https://goerli.etherscan.io/address/0xaadebCF61AA7Da0573b524DE57c67aDa797D46c5) |

<br>

## Design

### **Immutable implementation of [OpenZeppelin ERC20](https://docs.openzeppelin.com/contracts/4.x/api/token/erc20) with the following extensions:**
* [ERC20Votes](https://docs.openzeppelin.com/contracts/4.x/api/token/erc20#ERC20Votes)
    - Implements delegation, voting weights, and voting power calculations in the style of Compound governance
    - Used by Uniswap, Compound, Tally
* [ERC20Burnable](https://docs.openzeppelin.com/contracts/4.x/api/token/erc20#ERC20Burnable)
    - Allows the burning of tokens. This would be useful with the reserve pool to burn Ajna tokens for a given pool’s quote tokens in a standardized way.
* [ERC20Permit](https://docs.openzeppelin.com/contracts/4.x/api/token/erc20#ERC20Permit)
    - Useful UX improvement that allows users to transfer tokens with a signature argument to transfer as opposed to having to execute separate approve and transfer transactions.

### **External Methods:**
* approve
    - Allows an external address to spend a user’s tokens
* burn
    - Sends a user’s tokens to the 0x0 address
* burnFrom
    - External address sends a user’s tokens to the 0x0 address    
* delegate
    - Delegates votes from sender to delegatee
* delegateBySig
    - Delegates votes from signer to delegatee
* decreaseAllowance
    - Decrease the amount of tokens an external address is allowed to spend for a user
* increaseAllowance
    - Increase the amount of tokens an external address is allowed to spend for a user
* permit
    - Approve an external address to spend a user’s tokens by signature
* transfer
    - Transfer a user’s tokens to another address
* transferFrom
    - Transfer tokens from one address to another
* transferFromWithPermit
    - Transfer tokens from one address to another using Permit and avoiding a separate approval tx

## Deployment

See [README.md](../../README.md) for instructions using the `Makefile` target.

Output should provide the token address, confirm the amount minted and where it was sent:
```
== Logs ==
  AJNA token deployed to 0xef11D1c2aA48826D4c41e54ab82D1Ff5Ad8A64Ca
  Minting 2000000000 AJNA token to 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266
```

Record the token address, exporting to your environment as `AJNA_TOKEN`.

Run the following to validate AJNA token balance:
```
cast call ${AJNA_TOKEN} "balanceOf(address)" ${DEPLOY_ADDRESS} --rpc-url ${ETH_RPC_URL}
```