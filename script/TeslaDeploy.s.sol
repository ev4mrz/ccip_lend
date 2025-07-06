// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {Tesla} from "../src/TeslaToken.sol";

contract TeslaDeploy is Script {

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        
        vm.startBroadcast(deployerPrivateKey);

        Tesla tesla = new Tesla();

        vm.stopBroadcast();

        console.log("TeslaToken deployed to:", address(tesla));
    }
}

// 0x7862656435B67E908a6339B74a7d351E23040a42