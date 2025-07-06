// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {IRouterClient} from "@chainlink/contracts-ccip/interfaces/IRouterClient.sol";
import {OwnerIsCreator} from "@chainlink/contracts/v0.8/shared/access/OwnerIsCreator.sol";
import {Client} from "@chainlink/contracts-ccip/libraries/Client.sol";
import {LinkTokenInterface} from "@chainlink/contracts/v0.8/shared/interfaces/LinkTokenInterface.sol";
import {AggregatorV3Interface} from "@chainlink/contracts/v0.8/shared/interfaces/AggregatorV3Interface.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IPriceFeed {
    function getPrice() external view returns (uint256);
}

contract Sender is OwnerIsCreator {

    error NotEnoughBalance(uint256 currentBalance, uint256 calculatedFees); 
    error InvalidPriceFeedData();
    error TokenTransferFailed();
    error DestinationChainNotAllowed(uint64 destinationChainSelector);

    event MessageSent(
        bytes32 indexed messageId, // The unique ID of the CCIP message.
        uint64 indexed destinationChainSelector, // The chain selector of the destination chain.
        uint256 amount, // The amount of deposit token.
        address token, // The token address to lend.
        address feeToken, // the token address used to pay CCIP fees.
        uint256 fees, // The fees paid for sending the CCIP message.
        uint256 times // The timestamp of the lend.
    );
    

    IRouterClient private s_router;
    LinkTokenInterface private s_linkToken;
    
    // Allowlist for destination chains
    mapping(uint64 => bool) public allowlistedDestinationChains;
    
    mapping(address => mapping(address => uint256)) public userDeposits;
    mapping(address => AggregatorV3Interface) public priceFeeds;


    modifier onlyAllowlistedDestination(uint64 _destinationChainSelector) {
        if (!allowlistedDestinationChains[_destinationChainSelector]) {
            revert DestinationChainNotAllowed(_destinationChainSelector);
        }
        _;
    }

    constructor(address _router, address _link) {
        s_router = IRouterClient(_router);
        s_linkToken = LinkTokenInterface(_link);
    }
    
    // Security function for destination chains
    function allowlistDestinationChain(uint64 _destinationChainSelector, bool allowed) external onlyOwner {
        allowlistedDestinationChains[_destinationChainSelector] = allowed;
    }
    
    function getTokenPriceInUSD(address token, uint256 amount) public view returns (uint256) {
        
        uint256 usdValue = (amount * IPriceFeed(token).getPrice()) / 1e18;
        return usdValue;
    }


    function deposit(
        address depositToken,
        uint256 amount,
        address borrowToken,
        uint64 destinationChainSelector,
        address receiver,
        uint256 time
    ) external onlyAllowlistedDestination(destinationChainSelector) returns (bytes32 messageId) {

        // Transfer tokens from user to contract
        if (!IERC20(depositToken).transferFrom(msg.sender, address(this), amount)) {
            revert TokenTransferFailed();
        }
        
        // Record the deposit
        userDeposits[msg.sender][depositToken] += amount;
        
        // Send CCIP message and return messageId
        return _sendCCIPMessage(
            depositToken,
            amount,
            borrowToken,
            destinationChainSelector,
            receiver,
            time
        );
    }

    function _sendCCIPMessage(
        address depositToken,
        uint256 amount,
        address borrowToken,
        uint64 destinationChainSelector,
        address receiver,
        uint256 time
    ) internal returns (bytes32 messageId) {
        // Convert amount to USD value
        uint256 usdValue = getTokenPriceInUSD(depositToken, amount);
        
        // Create CCIP message with deposit information
        Client.EVM2AnyMessage memory evm2AnyMessage = Client.EVM2AnyMessage({
            receiver: abi.encode(receiver), // Receiver address (Protocol contract)
            data: abi.encode(msg.sender, depositToken, usdValue, borrowToken, time),
            tokenAmounts: new Client.EVMTokenAmount[](0),
            extraArgs: Client._argsToBytes(
                Client.GenericExtraArgsV2({
                    gasLimit: 200_000,
                    allowOutOfOrderExecution: true
                })
            ),
            feeToken: address(s_linkToken)
        });
        
        // Calculate and pay fees
        uint256 fees = s_router.getFee(destinationChainSelector, evm2AnyMessage);
        
        if (fees > s_linkToken.balanceOf(address(this))) {
            revert NotEnoughBalance(s_linkToken.balanceOf(address(this)), fees);
        }
        
        s_linkToken.approve(address(s_router), fees);
        
        // Send the message
        messageId = s_router.ccipSend(destinationChainSelector, evm2AnyMessage);
        
        emit MessageSent(
            messageId,
            destinationChainSelector,
            amount,
            borrowToken,
            address(s_linkToken),
            fees,
            time
        );
        
        return messageId;
    }

    /// @notice Handle received refund confirmation from destination chain
    function _ccipReceive(Client.Any2EVMMessage memory any2EvmMessage) internal override 
        onlyAllowlistedSource(any2EvmMessage.sourceChainSelector) {
        
        // Decode the refund message data
        (
            address user,
            string memory message,
            uint256 refundAmount,
            uint256 timestamp
        ) = abi.decode(any2EvmMessage.data, (address, string, uint256, uint256));
        
        // Store refund message details
        lastReceivedRefund = RefundMessageDetails({
            messageId: any2EvmMessage.messageId,
            sourceChainSelector: any2EvmMessage.sourceChainSelector,
            user: user,
            message: message,
            refundAmount: refundAmount,
            timestamp: timestamp
        });
        
        // Check if this is a refund confirmation
        if (keccak256(abi.encodePacked(message)) == keccak256(abi.encodePacked("REFUND_CONFIRMED"))) {
            // Return all deposits to the user
            _returnUserDeposits(user);
        }
        
        emit RefundMessageReceived(
            any2EvmMessage.messageId,
            any2EvmMessage.sourceChainSelector,
            user,
            message,
            refundAmount,
            block.timestamp
        );
    }

    /// @notice Internal function to return all deposits to a user
    function _returnUserDeposits(address user) internal {
        // This is a simplified version - in practice you might want to iterate through known tokens
        // For now, we'll emit an event and provide a manual function
        emit DepositsReturned(user, address(0), 0, block.timestamp);
    }

    /// @notice Manual function to return specific token deposits to user (called after refund confirmation)
    function returnUserDeposits(address user, address token) external onlyOwner {
        uint256 depositAmount = userDeposits[user][token];
        
        if (depositAmount == 0) {
            revert NoDepositsToReturn();
        }
        
        // Check if contract has enough tokens
        if (IERC20(token).balanceOf(address(this)) < depositAmount) {
            revert TokenTransferFailed();
        }
        
        // Clear the deposit record
        userDeposits[user][token] = 0;
        
        // Transfer tokens back to user
        if (!IERC20(token).transfer(user, depositAmount)) {
            revert TokenTransferFailed();
        }
        
        emit DepositsReturned(user, token, depositAmount, block.timestamp);
    }

    /// @notice Get user deposit amount for a specific token
    function getUserDeposit(address user, address token) external view returns (uint256) {
        return userDeposits[user][token];
    }

    /// @notice Get details of the last received refund message
    function getLastReceivedRefund() external view returns (RefundMessageDetails memory) {
        return lastReceivedRefund;
    }

    /// @notice Emergency function to withdraw contract balance (only owner)
    function emergencyWithdraw(address token, uint256 amount) external onlyOwner {
        IERC20(token).transfer(owner(), amount);
    }
}
