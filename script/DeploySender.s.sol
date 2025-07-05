// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Script, console} from "forge-std/Script.sol";
import {Sender} from "../src/Deposit.sol";

contract DeploySender is Script {
    // Adresses Avalanche Fuji
    address constant ROUTER_CCIP_MANTLE = vm.envAddress("ROUTER_CCIP_MANTLE");
    address constant LINK_TOKEN_MANTLE = vm.envAddress("LINK_TOKEN_MANTLE");
    
    // Chain selectors
    uint64 constant CHAIN_SELECTOR_ETH = vm.envUint("CHAIN_SELECTOR_ETH");
    
    // Price feeds Avalanche Fuji (exemples)
    address constant AVAX_USD_PRICE_FEED = 0x5498BB86BC934c8D34FDA08E81D444153d0D06aD;
    address constant CCIP_BNM_FUJI = 0xD21341536c5cF5EB1bcb58f6723cE26e8D8E90e4;
    
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY_FUJI");
        
        vm.startBroadcast(deployerPrivateKey);
        

        Sender sender = new Sender(ROUTER_CCIP_MANTLE, LINK_TOKEN_MANTLE);
        
        console.log("Sender deployed to:", address(sender));
        console.log("Owner:", sender.owner());
        
        sender.allowlistDestinationChain(SEPOLIA_CHAIN_SELECTOR, true);
        console.log("Allowlisted destination chain Sepolia:", CHAIN_SELECTOR_ETH);
        
        vm.stopBroadcast();
    }
} 