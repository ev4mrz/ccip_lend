// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {USDC} from "../src/USDCToken.sol";

contract USDCDeploy is Script {

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        
        vm.startBroadcast(deployerPrivateKey);

        USDC usdc = new USDC();

        vm.stopBroadcast();

        console.log("USDCToken deployed to:", address(usdc));
    }
}

// 0x2018e3A3A9AB460bAEA6079Dc443028634C4c32c