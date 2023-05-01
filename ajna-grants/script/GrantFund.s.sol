// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import { Script }  from "forge-std/Script.sol";
import { console } from "forge-std/console.sol";

import { IERC20 }    from "@oz/token/ERC20/IERC20.sol";

import { GrantFund } from "src/grants/GrantFund.sol";
import { Maths }     from "src/grants/libraries/Maths.sol";

contract DeployGrantFund is Script {
    uint256 constant TREASURY_PCT_OF_AJNA_SUPPLY = 0.3 * 1e18;

    function run() public {
        IERC20 ajna = IERC20(vm.envAddress("AJNA_TOKEN"));
        console.log("Deploying GrantFund to chain");

        vm.startBroadcast();
        uint256 treasury = Maths.wmul(ajna.totalSupply(), TREASURY_PCT_OF_AJNA_SUPPLY);
        address grantFund = address(new GrantFund());
        vm.stopBroadcast();

        console.log("GrantFund deployed to %s", grantFund);
        console.log("Please transfer %s AJNA (%s WAD) into the treasury", treasury / 1e18, treasury);
    }
}
