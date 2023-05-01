// SPDX-License-Identifier: MIT

pragma solidity 0.8.16;

import { Test }   from "@std/Test.sol";

import { GrantFund }        from "../../../src/grants/GrantFund.sol";

import { IAjnaToken }          from "../../utils/IAjnaToken.sol";
import { GrantFundTestHelper } from "../../utils/GrantFundTestHelper.sol";

contract TestBase is Test, GrantFundTestHelper {
    IAjnaToken        internal  _ajna;
    GrantFund         internal  _grantFund;

    // token deployment variables
    address internal _tokenDeployer = 0x666cf594fB18622e1ddB91468309a7E194ccb799;
    uint256 public   _startBlock    = 16354861; // at this block on mainnet, all ajna tokens belongs to _tokenDeployer

    // initial treasury value
    uint256 treasury = 500_000_000 * 1e18;

    uint256 public currentBlock;

    function setUp() public virtual {
        vm.createSelectFork(vm.envString("ETH_RPC_URL"), _startBlock);

        // provide cheatcode access to the standard funding handler
        vm.allowCheatcodes(0x4447E7a83995B5cCDCc9A6cd8Bc470305C940DA3);

        // Ajna Token contract address on mainnet
        _ajna = IAjnaToken(0x9a96ec9B57Fb64FbC60B423d1f4da7691Bd35079);

        // deploy growth fund contract
        _grantFund = new GrantFund();

        vm.startPrank(_tokenDeployer);

        // initial minter distributes treasury to grantFund
        _ajna.approve(address(_grantFund), treasury);
        _grantFund.fundTreasury(treasury);

        // exclude unrelated contracts
        excludeContract(address(_ajna));

        vm.makePersistent(address(_grantFund));

        currentBlock = block.number;
    }

    function setCurrentBlock(uint256 currentBlock_) external {
        currentBlock = currentBlock_;
    }

}
