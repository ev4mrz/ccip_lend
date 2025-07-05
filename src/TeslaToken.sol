pragma solidity ^0.8.0;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract Tesla is ERC20 {
    constructor() ERC20("TeslaToken", "TSLA") {
        _mint(msg.sender, 1000000000000000000000);
    }

    function price() public view returns (uint256) {
        return 1;
}}

