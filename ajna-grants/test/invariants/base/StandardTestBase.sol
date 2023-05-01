// SPDX-License-Identifier: MIT

pragma solidity 0.8.16;

import { console } from "@std/console.sol";

import { TestBase }        from "./TestBase.sol";
import { StandardHandler } from "../handlers/StandardHandler.sol";

contract StandardTestBase is TestBase {

    uint256 internal constant NUM_ACTORS = 20;

    StandardHandler internal _standardHandler;

    function setUp() public virtual override {
        super.setUp();

        // TODO: modify this setup to enable use of random tokens not in treasury
        // calculate the number of tokens not in the treasury, to be distributed to actors
        uint256 tokensNotInTreasury = _ajna.balanceOf(_tokenDeployer) - treasury;

        _standardHandler = new StandardHandler(
            payable(address(_grantFund)),
            address(_ajna),
            _tokenDeployer,
            NUM_ACTORS,
            tokensNotInTreasury,
            address(this)
        );

        // explicitly target handler
        targetContract(address(_standardHandler));

        // skip time for snapshots and start distribution period
        vm.roll(block.number + 100);
        _grantFund.startNewDistributionPeriod();
    }

}
