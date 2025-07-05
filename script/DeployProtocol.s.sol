// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Script, console} from "forge-std/Script.sol";
import {Receiver} from "../src/Protocol.sol";

contract DeployReceiver is Script {
    // Adresses Ethereum Sepolia
    address constant SEPOLIA_CCIP_ROUTER = vm.envAddress("ROUTER_CCIP_ETH");
    address constant SEPOLIA_LINK_TOKEN = vm.envAddress("0x779877A7B0D9E8603169DdbD7836e478b4624789");
    
    // Chain selectors
    uint64 constant MANTLE_CHAIN_SELECTOR = vm.envUint("CHAIN_SELECTOR_MANTLE");
    
    
    function run() external {
        uint256 PrivateKey = vm.envUint("PRIVATE_KEY");
        
        vm.startBroadcast(PrivateKey);
        
        Receiver receiver = new Receiver(SEPOLIA_CCIP_ROUTER);
        
        console.log("Receiver deployed to:", address(receiver));
        console.log("Owner:", receiver.owner());
        
        // Configurer les allowlists pour Avalanche Fuji
        receiver.allowlistSourceChain(FUJI_CHAIN_SELECTOR, true);
        console.log("Allowlisted source chain Mantle:", MANTLE_CHAIN_SELECTOR);
        
        
        vm.stopBroadcast();
        
    }
} 