// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Client} from "@chainlink/contracts-ccip/libraries/Client.sol";
import {CCIPReceiver} from "@chainlink/contracts-ccip/applications/CCIPReceiver.sol";
import {AggregatorV3Interface} from "@chainlink/contracts/v0.8/shared/interfaces/AggregatorV3Interface.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {OwnerIsCreator} from "@chainlink/contracts/v0.8/shared/access/OwnerIsCreator.sol";

contract Receiver is CCIPReceiver, OwnerIsCreator {

    error InvalidPriceFeedData();
    error InsufficientTokenBalance();
    error TokenTransferFailed();
    

    event MessageReceived(
        bytes32 indexed messageId, // The unique ID of the message.
        uint64 indexed sourceChainSelector, // The chain selector of the source chain.
        address sender, // The address of the sender from the source chain.
        address user, // The user who made the deposit
        address depositToken, // The token that was deposited
        uint256 usdValue, // USD value of the deposit
        address borrowToken // Token to borrow
    );
    
    // Allowlist mappings for security
    mapping(uint64 => bool) public allowlistedSourceChains;
    
    // Storage for the last received message details
    struct MessageDetails {
        bytes32 messageId;
        uint64 sourceChainSelector;
        address sender;
        address user;
        address depositToken;
        uint256 usdValue;
        address borrowToken;
        uint256 timestamp;
    }
    
    MessageDetails public lastReceivedMessage;

    mapping(address => uint256) public tokenBalances;

    constructor(address router) CCIPReceiver(router) OwnerIsCreator() {}
    
    // Security functions as per CCIP documentation
    function allowlistSourceChain(uint64 _sourceChainSelector, bool allowed) external onlyOwner {
        allowlistedSourceChains[_sourceChainSelector] = allowed;
    }

    // Modifier to check if source chain and sender are allowed
    modifier onlyAllowlisted(uint64 _sourceChainSelector, address _sender) {
        require(allowlistedSourceChains[_sourceChainSelector], "Source chain not allowed");

    }
    
    function getTokenAmountFromUSD(address token, uint256 usdValue) public view returns (uint256) {
        // hardcoded price feed for MNT
        AggregatorV3Interface priceFeed = AggregatorV3Interface(0x4c8962833Db7206fd45671e9DC806e4FcC0dCB78);
        require(address(priceFeed) != address(0), "Price feed not set for this token");

        (, int256 price, , , ) = priceFeed.latestRoundData();
        if (price <= 0) {
            revert InvalidPriceFeedData();
        }

        uint256 tokenAmount = (usdValue * 1e18) / uint256(price);
        return tokenAmount;
    }

    /// @notice Handle a received message and transfer equivalent tokens
    function _ccipReceive(Client.Any2EVMMessage memory any2EvmMessage) internal override 
        onlyAllowlisted(any2EvmMessage.sourceChainSelector, abi.decode(any2EvmMessage.sender, (address))) {
        // Decode the message data
        (
            address user,
            address depositToken,
            uint256 usdValue,
            address borrowToken,
            uint256 time
        ) = abi.decode(any2EvmMessage.data, (address, address, uint256, address, uint256));
        
        // Store message details
        lastReceivedMessage = MessageDetails({
            messageId: any2EvmMessage.messageId,
            sourceChainSelector: any2EvmMessage.sourceChainSelector,
            sender: abi.decode(any2EvmMessage.sender, (address)),
            user: user,
            depositToken: depositToken,
            usdValue: usdValue,
            borrowToken: borrowToken,
            timestamp: block.timestamp
        });
        
        // Calculate equivalent amount in borrow token with borrow ratio
        uint256 borrowAmount = getTokenAmountFromUSD(borrowToken, usdValue * 70 / 100); // 70% LTV
        
        // Check if contract has enough tokens
        if (IERC20(borrowToken).balanceOf(address(this)) < borrowAmount) {
            revert InsufficientTokenBalance();
        }
        
        // Transfer tokens to user
        IERC20 token = IERC20(borrowToken);
        bool success = token.transfer(user, borrowAmount);
        if (!success) {
            revert TokenTransferFailed();
        }
        
        // Emit events
        emit MessageReceived(
            any2EvmMessage.messageId,
            any2EvmMessage.sourceChainSelector,
            abi.decode(any2EvmMessage.sender, (address)),
            user,
            depositToken,
            usdValue,
            borrowToken
        );
        
    }

    /// @notice Get the details of the last received message
    function getLastReceivedMessageDetails() public view returns (MessageDetails memory) {
        return lastReceivedMessage;
    }

    function calculateRefundAmount(uint256 borrowAmount, uint256 timeInSeconds) public pure returns (uint256) {
        // Calculate interest: borrowAmount + (borrowAmount * time * 0.2% per day)
        // Assuming timeInSeconds is the loan duration
        uint256 dailyRate = 0.1; // 0.01% 
        uint256 daysElapsed = timeInSeconds / 86400; // seconds in a day
        uint256 interest = (borrowAmount * daysElapsed * dailyRate) / 1000;
        return borrowAmount + interest;
    }
    
}


