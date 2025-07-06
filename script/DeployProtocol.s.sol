// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Script, console} from "forge-std/Script.sol";
import {Receiver} from "../src/Protocol.sol";

contract DeployReceiver is Script {
    
    function run() external {

        uint256 privateKey = vm.envUint("PRIVATE_KEY");
        address mantleCcipRouter = vm.envAddress("ROUTER_CCIP_MANTLE");
        uint64 ethChainSelector = uint64(vm.envUint("CHAIN_SELECTOR_ETH"));
        address linkTokenMantle = vm.envAddress("LINK_TOKEN_MANTLE");
        
        vm.startBroadcast(privateKey);
        
        Receiver receiver = new Receiver(mantleCcipRouter, linkTokenMantle);
        
        console.log("Receiver deployed to:", address(receiver));
        console.log("Owner:", receiver.owner());
        

        receiver.allowlistSourceChain(ethChainSelector, true);
        console.log("Allowlisted source chain (Ethereum):", ethChainSelector);
        
        receiver.allowlistDestinationChain(ethChainSelector, true);
        console.log("Allowlisted destination chain (Ethereum):", ethChainSelector);
        
        vm.stopBroadcast();
        
    }
} 

//0x7AC277932769018305b81e608E58c5F3730967E3

//0x0cbB6b86B790d46ba8cA15E4166f4d5E45A4Ff86