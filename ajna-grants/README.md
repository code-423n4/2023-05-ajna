# Ajna Ecosystem Coordination
![Build Status](https://github.com/ajna-finance/ajna-grants/actions/workflows/.github/workflows/forge-test.yml/badge.svg?branch=main)

## **Contracts**

## [Grant Coordination Fund](./src/grants/GRANT_FUND.md)

## [Ajna Token](./src/token/AJNA_TOKEN.md)


<br>

## **Development**

Install Foundry [instructions](https://github.com/gakonst/foundry/blob/master/README.md#installation)  then, install the [foundry](https://github.com/gakonst/foundry) toolchain installer (`foundryup`) with:

```bash
curl -L https://foundry.paradigm.xyz | bash
```

Install `foundry` version `nightly-87bc53fc6c874bd4c92d97ed180b949e3a36d78c` (required due to breaking changes introduced in foundry-rs/foundry#4827):

```bash
foundryup -v nightly-87bc53fc6c874bd4c92d97ed180b949e3a36d78c
```

#### Project Setup
- Make a copy of .env.example and name it .env. Add the values for
  - `ETH_RPC_URL` - required by forge to fork chain
- Run
```bash
make all
```

#### Run Tests

```bash
make tests
```

#### Code Coverage
- generate basic code coverage report:
```bash
make coverage
```
- exclude tests from code coverage report:
```
apt-get install lcov
bash ./check-code-coverage.sh
```

### Contract Deployment
Ensure the following env variables are in your `.env` file or exported into your environment.
| Environment Variable | Purpose |
|----------------------|---------|
| `DEPLOY_ADDRESS`     | address from which you wish to deploy
| `DEPLOY_KEY`         | path to the JSON keystore file for the deployment address
| `ETHERSCAN_API_KEY`  | required to verify contracts
| `ETH_RPC_URL`        | node on your target deployment network


Here's an example:
```
DEPLOY_ADDRESS=0x9965507d1a55bcc2695c58ba16fb37d819b0a4dc
DEPLOY_KEY=~/hush/deployment.json
ETHERSCAN_API_KEY=55ORCKI875XKNO89475DNOCHDPINI54OFY
ETH_RPC_URL=http://127.0.0.1:8545
```

You will be prompted for your key's password interactively.

⚠ The `ETH_RPC_URL` you provide determines the deployment network for your contract.

If you wish to deploy against an `anvil` or `ganache` endpoint, edit the `Makefile`, replacing `--keystore ${DEPLOY_KEY}` with `--private-key ${DEPLOY_PRIVATE_KEY}`.  In your environment, set `DEPLOY_ADDRESS` to one of the pre-funded accounts and `DEPLOY_PRIVATE_KEY` to the unencrypted private key.


#### AJNA token
Deployment of the AJNA token requires an argument stating where minted tokens should be sent.  AJNA has already been deployed to Goerli and Mainnet; see [AJNA_TOKEN.md](src/token/AJNA_TOKEN.md#ajna-token) for addresses.  There is no reason to deploy the AJNA token to L2s or sidechains; see [MULTICHAIN_STRATEGY.md](MULTICHAIN_STRATEGY.md) for details.  Since contract verification only works on Etherscan-supported networks, the `--verify` switch has been omitted.  Upon deployment, minted tokens are transferred to a user-specified address which must be specified in make arguments.  To run a new deployment on a test network or local testchain, run:
```
make deploy-ajnatoken mintto=<MINT_TO_ADDRESS>
```
Record the address of the token upon deployment.  See [AJNA_TOKEN.md](src/token/AJNA_TOKEN.md#deployment) for validation.

#### Grant Fund
Deployment of the Grant Coordination Fund requires no constructor arguments.

Since contract source has not yet been made public, the `--verify` switch has been omitted.  To deploy, run:
```
make deploy-grantfund
```

The Grant Fund is by default deployed without any Ajna tokens in it's treasury. To add tokens, someone must call `fundTreasury()` with the amount of Ajna tokens to transfer to the Grant Fund. **WARNING**: Ajna tokens transferred directly to the treasury won't be credited to the treasury balance if `fundTreasury()` is circumvented.

See [GRANT_FUND.md](src/grants/GRANT_FUND.md#deployment) for next steps.
