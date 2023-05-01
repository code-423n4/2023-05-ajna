// SPDX-License-Identifier: MIT
pragma solidity 0.8.7;

import { Script }  from "forge-std/Script.sol";
import { console } from "forge-std/console.sol";

import { AjnaToken } from "../src/token/AjnaToken.sol";
import { IERC20 }    from "@oz/token/ERC20/IERC20.sol";

contract DeployAjnaToken is Script {
    function run() public {
        address mintTo = vm.envAddress("MINT_TO_ADDRESS");

        vm.startBroadcast();
        address ajna = address(new AjnaToken(mintTo));
        vm.stopBroadcast();

        console.log("AJNA token deployed to %s", ajna);
        console.log("Minting %s AJNA token to %s", (IERC20(ajna)).totalSupply() / 1e18, mintTo);
    }
}
