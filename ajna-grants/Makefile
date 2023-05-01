
# include .env file and export its env vars
# (-include to ignore error if it does not exist)
-include .env

all: clean install build

# Clean the repo
clean  :; forge clean

# Install the Modules
install :; git submodule update --init --recursive

# Builds
build  :; forge clean && forge build --optimize --optimizer-runs 1000000

# Tests
tests                  :; forge clean && forge test --mt test --optimize --optimizer-runs 1000000 -v # --ffi # enable if you need the `ffi` cheat code on HEVM
test-with-gas-report   :; forge test --optimize --optimizer-runs 1000000 --no-match-test 'invariant|test_regression|fuzz' --gas-report
test-invariant		   :; forge clean && forge t --mt invariant
coverage               :; forge coverage

# Generate Gas Snapshots
snapshot :; forge clean && forge snapshot --optimize --optimize-runs 1000000

# Deployment
deploy-ajnatoken:
	eval MINT_TO_ADDRESS=${mintto}
	forge script script/AjnaToken.s.sol:DeployAjnaToken \
		--rpc-url ${ETH_RPC_URL} --sender ${DEPLOY_ADDRESS} --keystore ${DEPLOY_KEY} --broadcast -vvv
deploy-grantfund:
	eval AJNA_TOKEN=${ajna}
	forge script script/GrantFund.s.sol:DeployGrantFund \
		--rpc-url ${ETH_RPC_URL} --sender ${DEPLOY_ADDRESS} --keystore ${DEPLOY_KEY} --broadcast -vvv
