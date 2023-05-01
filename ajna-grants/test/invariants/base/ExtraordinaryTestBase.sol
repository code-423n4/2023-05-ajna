// SPDX-License-Identifier: MIT

pragma solidity 0.8.16;

import { console } from "@std/console.sol";

import { TestBase }             from "./TestBase.sol";
import { ExtraordinaryHandler } from "../handlers/ExtraordinaryHandler.sol";

contract ExtraordinaryTestBase is TestBase {

    uint256 internal constant NUM_ACTORS = 10;

    ExtraordinaryHandler internal _extraordinaryHandler;

    function setUp() public virtual override {
        super.setUp();

        // TODO: modify this setup to enable use of random tokens not in treasury
        // calculate the number of tokens not in the treasury, to be distributed to actors
        uint256 tokensNotInTreasury = _ajna.balanceOf(_tokenDeployer) - treasury;

        _extraordinaryHandler = new ExtraordinaryHandler(
            payable(address(_grantFund)),
            address(_ajna),
            _tokenDeployer,
            NUM_ACTORS,
            tokensNotInTreasury,
            address(this)
        );

        // explicitly target handler
        targetContract(address(_extraordinaryHandler));

        // roll 100 blocks to allow for actor distribution
        vm.roll(block.number + 100);
    }

}
