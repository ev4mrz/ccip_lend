// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {IRouterClient} from "@chainlink/contracts-ccip/interfaces/IRouterClient.sol";
import {OwnerIsCreator} from "@chainlink/contracts/v0.8/shared/access/OwnerIsCreator.sol";
import {Client} from "@chainlink/contracts-ccip/libraries/Client.sol";
import {LinkTokenInterface} from "@chainlink/contracts/v0.8/shared/interfaces/LinkTokenInterface.sol";
import {AggregatorV3Interface} from "@chainlink/contracts/v0.8/shared/interfaces/AggregatorV3Interface.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract Sender is OwnerIsCreator {

    error NotEnoughBalance(uint256 currentBalance, uint256 calculatedFees); 
    error InvalidPriceFeedData();
    error TokenTransferFailed();

    event MessageSent(
        bytes32 indexed messageId, // The unique ID of the CCIP message.
        uint64 indexed destinationChainSelector, // The chain selector of the destination chain.
        uint256 amount, // The amount being sent.
        address token, // The token address being sent.
        address feeToken, // the token address used to pay CCIP fees.
        uint256 fees, // The fees paid for sending the CCIP message.
        uint256 times // The timestamp of the deposit.
    );
    

    IRouterClient private s_router;
    LinkTokenInterface private s_linkToken;
    
    mapping(address => mapping(address => uint256)) public userDeposits;
    mapping(address => AggregatorV3Interface) public priceFeeds;


    constructor(address _router, address _link) {
        s_router = IRouterClient(_router);
        s_linkToken = LinkTokenInterface(_link);
    }
    
    function addPriceFeed(address token, address priceFeed) external onlyOwner {
        priceFeeds[token] = AggregatorV3Interface(priceFeed);
    }
    
    function getTokenPriceInUSD(address token, uint256 amount) public view returns (uint256) {
        AggregatorV3Interface priceFeed = priceFeeds[token];
        require(address(priceFeed) != address(0), "Price feed not set for this token");
        
        (, int256 price, , , ) = priceFeed.latestRoundData();
        if (price <= 0) {
            revert InvalidPriceFeedData();
        }
        
        uint256 usdValue = (amount * uint256(price)) / 1e18;
        return usdValue;
    }

    
    function deposit(
        address depositToken,
        uint256 amount,
        address borrowToken,
        uint64 destinationChainSelector,
        address receiver,
        uint256 time
    ) external returns (bytes32 messageId) {

        // Transfer tokens from user to contract
        IERC20 token = IERC20(depositToken);
        bool success = token.transferFrom(msg.sender, address(this), amount);
        if (!success) {
            revert TokenTransferFailed();
        }
        
        // Convert amount to USD value
        uint256 usdValue = getTokenPriceInUSD(depositToken, amount);
        
        // Record the deposit
        userDeposits[msg.sender][depositToken] += amount;
        
        // Create CCIP message with deposit information
        Client.EVM2AnyMessage memory evm2AnyMessage = Client.EVM2AnyMessage({
            receiver: abi.encode(receiver),
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
            depositToken,
            address(s_linkToken),
            fees,
            time
        );
        
        return messageId;
    }

}
