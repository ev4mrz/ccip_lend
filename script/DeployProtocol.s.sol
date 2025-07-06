// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Script, console} from "forge-std/Script.sol";
import {Receiver} from "../src/Protocol.sol";

contract DeployReceiver is Script {
    
    function run() external {
        // Lire les variables d'environnement dans la fonction
        uint256 privateKey = vm.envUint("PRIVATE_KEY");
        address mantleCcipRouter = vm.envAddress("ROUTER_CCIP_MANTLE");
        uint64 ethChainSelector = uint64(vm.envUint("CHAIN_SELECTOR_ETH"));
        
        vm.startBroadcast(privateKey);
        
        // Déployer le contrat Receiver
        Receiver receiver = new Receiver(mantleCcipRouter);
        
        console.log("Receiver deployed to:", address(receiver));
        console.log("Owner:", receiver.owner());
        
        // Configurer les allowlists
        receiver.allowlistSourceChain(ethChainSelector, true);
        console.log("Allowlisted source chain Mantle:", ethChainSelector);
        
        vm.stopBroadcast();
        
    }
} 

//0x7AC277932769018305b81e608E58c5F3730967E3