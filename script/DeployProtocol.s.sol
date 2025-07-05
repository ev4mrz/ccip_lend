// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Script, console} from "forge-std/Script.sol";
import {Receiver} from "../src/Protocol.sol";

contract DeployReceiver is Script {
    
    function run() external {
        // Lire les variables d'environnement dans la fonction
        uint256 privateKey = vm.envUint("PRIVATE_KEY");
        address sepoliaCcipRouter = vm.envAddress("ROUTER_CCIP_ETH");
        uint64 mantleChainSelector = uint64(vm.envUint("CHAIN_SELECTOR_MANTLE"));
        
        vm.startBroadcast(privateKey);
        
        // Déployer le contrat Receiver
        Receiver receiver = new Receiver(sepoliaCcipRouter);
        
        console.log("Receiver deployed to:", address(receiver));
        console.log("Owner:", receiver.owner());
        
        // Configurer les allowlists
        receiver.allowlistSourceChain(mantleChainSelector, true);
        console.log("Allowlisted source chain Mantle:", mantleChainSelector);
        
        vm.stopBroadcast();
        
    }
} 