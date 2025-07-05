// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Script, console} from "forge-std/Script.sol";
import {Sender} from "../src/Deposit.sol";

contract DeploySender is Script {
    
    function run() external {

        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address routerCcipMantle = vm.envAddress("ROUTER_CCIP_MANTLE");
        address linkTokenMantle = vm.envAddress("LINK_TOKEN_MANTLE");
        uint64 chainSelectorEth = uint64(vm.envUint("CHAIN_SELECTOR_ETH"));
        
        vm.startBroadcast(deployerPrivateKey);
        
        Sender sender = new Sender(routerCcipMantle, linkTokenMantle);
        
        console.log("Sender deployed to:", address(sender));
        console.log("Owner:", sender.owner());
        
        sender.allowlistDestinationChain(chainSelectorEth, true);
        console.log("Allowlisted destination chain ETH:", chainSelectorEth);
        
        vm.stopBroadcast();
        
    }
} 