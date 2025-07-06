// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Script, console} from "forge-std/Script.sol";
import {Sender} from "../src/Deposit.sol";

contract DeploySender is Script {
    
    function run() external {

        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address routerCcipETH = vm.envAddress("ROUTER_CCIP_ETH");
        address linkTokenETH = vm.envAddress("LINK_TOKEN_ETH");
        uint64 chainSelectorMantle = uint64(vm.envUint("CHAIN_SELECTOR_MANTLE"));
        
        vm.startBroadcast(deployerPrivateKey);
        
        Sender sender = new Sender(routerCcipETH, linkTokenETH);
        
        console.log("Sender deployed to:", address(sender));
        console.log("Owner:", sender.owner());
        

        sender.allowlistDestinationChain(chainSelectorMantle, true);
        console.log("Allowlisted destination chain (Mantle):", chainSelectorMantle);
        

        sender.allowlistSourceChain(chainSelectorMantle, true);
        console.log("Allowlisted source chain (Mantle):", chainSelectorMantle);
        
        vm.stopBroadcast();
        
    }
} 

// 0x8c73e29BAF7c95cC7b5a5923b51be4405fCBedC8


//0xDDbBa6ea31AD2Ba03F6C50f6F8E7C3F1271B5A10