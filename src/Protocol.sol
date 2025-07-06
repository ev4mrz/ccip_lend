// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Client} from "@chainlink/contracts-ccip/libraries/Client.sol";
import {CCIPReceiver} from "@chainlink/contracts-ccip/applications/CCIPReceiver.sol";
import {AggregatorV3Interface} from "@chainlink/contracts/v0.8/shared/interfaces/AggregatorV3Interface.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {OwnerIsCreator} from "@chainlink/contracts/v0.8/shared/access/OwnerIsCreator.sol";
import {IRouterClient} from "@chainlink/contracts-ccip/interfaces/IRouterClient.sol";
import {LinkTokenInterface} from "@chainlink/contracts/v0.8/shared/interfaces/LinkTokenInterface.sol";

interface IPriceFeed {
    function getPrice() external view returns (uint256);
}

contract Receiver is CCIPReceiver, OwnerIsCreator {

    error InvalidPriceFeedData();
    error InsufficientTokenBalance();
    error TokenTransferFailed();
    error NotEnoughBalance(uint256 currentBalance, uint256 calculatedFees);
    error DestinationChainNotAllowed(uint64 destinationChainSelector);
    error NoDebtToRefund();
    error InsufficientRefundAmount(uint256 provided, uint256 required);
    

    event MessageReceived(
        bytes32 indexed messageId, // The unique ID of the message.
        uint64 indexed sourceChainSelector, // The chain selector of the source chain.
        address sender, // The address of the sender from the source chain.
        address user, // The user who made the deposit
        address depositToken, // The token that was deposited
        uint256 usdValue, // USD value of the deposit
        address borrowToken // Token to borrow
    );

    event MessageSent(
        bytes32 indexed messageId, // The unique ID of the CCIP message.
        uint64 indexed destinationChainSelector, // The chain selector of the destination chain.
        address feeToken, // the token address used to pay CCIP fees.
        uint256 fees, // The fees paid for sending the CCIP message.
        uint256 times, // The timestamp of the lend.
        string message // The message to send.
    );
    
    // Allowlist mappings for security
    mapping(uint64 => bool) public allowlistedSourceChains;
    mapping(uint64 => bool) public allowlistedDestinationChains;
    mapping(address => uint256) public refundPrices;
    mapping(address => uint256) public borrowPrices;
    mapping(address => uint256) public userDebt; // Track user debt in USD
    mapping(address => uint256) public loanTimestamp; // Track when loan was taken
    
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

    IRouterClient private s_router;
    LinkTokenInterface private s_linkToken;

    modifier onlyAllowlistedDestination(uint64 _destinationChainSelector) {
        if (!allowlistedDestinationChains[_destinationChainSelector]) {
            revert DestinationChainNotAllowed(_destinationChainSelector);
        }
        _;
    }

    constructor(address router, address linkToken) CCIPReceiver(router) OwnerIsCreator() {
        s_router = IRouterClient(router);
        s_linkToken = LinkTokenInterface(linkToken);
    }
    
    // Security functions as per CCIP documentation
    function allowlistSourceChain(uint64 _sourceChainSelector, bool allowed) external onlyOwner {
        allowlistedSourceChains[_sourceChainSelector] = allowed;
    }

    function allowlistDestinationChain(uint64 _destinationChainSelector, bool allowed) external onlyOwner {
        allowlistedDestinationChains[_destinationChainSelector] = allowed;
    }

    // Modifier to check if source chain and sender are allowed
    modifier onlyAllowlisted(uint64 _sourceChainSelector, address _sender) {
        require(allowlistedSourceChains[_sourceChainSelector], "Source chain not allowed");
        _;
    }
    
        function getTokenAmountFromUSD(address token, uint256 usdValue) public view returns (uint256) {
        
        //AggregatorV3Interface priceFeed = AggregatorV3Interface(0x4c8962833Db7206fd45671e9DC806e4FcC0dCB78);
        uint256 priceFeed = IPriceFeed(token).getPrice();
        // require(address(priceFeed) != address(0), "Price feed not set for this token");
// 
        // (, int256 price, , , ) = priceFeed.latestRoundData();
        // if (price <= 0) {
        //     revert InvalidPriceFeedData();
        // }

        uint256 tokenAmount = (usdValue * 1e18) / priceFeed;
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

        borrowPrices[borrowToken] = usdValue;
        
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

        // Store user debt and loan timestamp
        uint256 debtUSD = usdValue * 70 / 100; // 70% LTV
        userDebt[user] = calculateRefundPrice(debtUSD, time);
        loanTimestamp[user] = block.timestamp;
        
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

    function calculateRefundPrice(uint256 borrowAmount, uint256 timeInSeconds) public pure returns (uint256) {
        // Calculate interest: borrowAmount + (borrowAmount * time * 0.01% per day)
        // Assuming timeInSeconds is the loan duration
        uint256 dailyRate = 1; // 0.01% = 1/10000
        uint256 daysElapsed = timeInSeconds / 86400; // seconds in a day
        uint256 interest = (borrowAmount * daysElapsed * dailyRate) / 10000;
        return borrowAmount + interest;
    }

    function refund(
        address refundToken,
        uint64 destinationChainSelector,
        address receiver
    ) external onlyAllowlistedDestination(destinationChainSelector) returns (bytes32 messageId) {
        
        // Check if user has debt to refund
        uint256 debtAmount = userDebt[msg.sender];
        if (debtAmount == 0) {
            revert NoDebtToRefund();
        }
        
        // Calculate required refund amount in tokens
        uint256 requiredRefundAmount = getTokenAmountFromUSD(refundToken, debtAmount);
        
        // Check if user has enough tokens to refund
        if (IERC20(refundToken).balanceOf(msg.sender) < requiredRefundAmount) {
            revert InsufficientRefundAmount(
                IERC20(refundToken).balanceOf(msg.sender),
                requiredRefundAmount
            );
        }
        
        // Transfer tokens from user to contract
        if (!IERC20(refundToken).transferFrom(msg.sender, address(this), requiredRefundAmount)) {
            revert TokenTransferFailed();
        }
        
        // Clear user debt
        userDebt[msg.sender] = 0;
        loanTimestamp[msg.sender] = 0;
        
        // Send CCIP message to confirm refund
        return _sendCCIPMessage(
            "REFUND_CONFIRMED",
            receiver,
            destinationChainSelector,
            msg.sender,
            debtAmount
        );
    }

    function _sendCCIPMessage(
        string memory message,
        address receiver,
        uint64 destinationChainSelector,
        address user,
        uint256 refundAmount
    ) internal returns (bytes32 messageId) {
        
        // Create CCIP message with refund confirmation
        Client.EVM2AnyMessage memory evm2AnyMessage = Client.EVM2AnyMessage({
            receiver: abi.encode(receiver),
            data: abi.encode(user, message, refundAmount, block.timestamp),
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
            address(s_linkToken),
            fees,
            block.timestamp,
            message
        );
        
        return messageId;
    }

    function getUserDebt(address user) external view returns (uint256) {
        return userDebt[user];
    }

    function emergencyWithdraw(address token, uint256 amount) external onlyOwner {
        IERC20(token).transfer(owner(), amount);
    }
}


