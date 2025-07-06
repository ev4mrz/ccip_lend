# CCIP Cross-Chain Lending Protocol

A decentralized cross-chain lending protocol that enables users to deposit tokens on Ethereum and borrow on Mantle using Chainlink CCIP with automated repayment processing.

## Features

- 🌉 Cross-chain lending: Deposit on Ethereum, borrow on Mantle
- 🔄 Automated returns via Chainlink Automation
- 💰 70% LTV ratio
- 📊 USD-based calculations
- 🛡️ Multi-layer security

## Architecture

- **Sender Contract** (Ethereum Sepolia): Handles deposits and automated returns
- **Receiver Contract** (Mantle Testnet): Handles borrowing and repayments

## Smart Contracts

```
src/
├── Deposit.sol     # Sender contract
├── Protocol.sol    # Receiver contract
└── TeslaToken.sol  # Test ERC20 token

script/
├── DeployDeposit.s.sol
├── DeployProtocol.s.sol
└── TeslaDeploy.s.sol
```

## Setup

### Prerequisites
- [Foundry](https://book.getfoundry.sh/getting-started/installation)
- Testnet ETH and LINK tokens

### Environment Variables
```env
PRIVATE_KEY=0x...
ROUTER_CCIP_ETH=0x0BF3dE8c5D3e8A2B34D2BEeB17ABfCeBaf363A59
ROUTER_CCIP_MANTLE=0x...
LINK_TOKEN_ETH=0x779877A7B0D9E8603169DdbD7836e478b4624789
LINK_TOKEN_MANTLE=0x...
CHAIN_SELECTOR_ETH=16015286601757825753
CHAIN_SELECTOR_MANTLE=5224473277236331520
```

### Installation
```bash
git clone <repository>
cd ccip_lend
forge install
```

## Deployment

```bash
# Deploy Sender (Ethereum Sepolia)
forge script script/DeployDeposit.s.sol --rpc-url $ETH_RPC_URL --broadcast

# Deploy Receiver (Mantle Testnet)
forge script script/DeployProtocol.s.sol --rpc-url $MANTLE_RPC_URL --broadcast

# Deploy Test Token
forge script script/TeslaDeploy.s.sol --rpc-url $MANTLE_RPC_URL --broadcast
```

## Usage

### 1. Deposit and Borrow
```solidity
// Approve and deposit
IERC20(depositToken).approve(senderAddress, amount);
sender.deposit(depositToken, amount, borrowToken, chainSelector, receiverAddress, duration);
```

### 2. Repay Loan
```solidity
// Approve and repay (amount calculated automatically with interest)
IERC20(repayToken).approve(receiverAddress, repayAmount);
receiver.refund(repayToken, chainSelector, senderAddress);
```

### 3. Automatic Return
Chainlink Automation automatically returns deposited tokens after repayment confirmation.

## Configuration

1. Fund contracts with LINK tokens for CCIP fees
2. Set up [Chainlink Automation](https://automation.chain.link/) for Sender contract
3. Fund Receiver contract with lending tokens

## Interest Model

- **Rate**: 0.01% per day
- **Formula**: `finalAmount = principal + (principal × days × 0.01%)`

## Testing

```bash
forge test
```

## Networks

| Network | Chain Selector | Router |
|---------|----------------|--------|
| Ethereum Sepolia | 16015286601757825753 | 0x0BF3dE8c5D3e8A2B34D2BEeB17ABfCeBaf363A59 |
| Mantle Testnet | 5224473277236331520 | [CCIP Directory](https://docs.chain.link/ccip/directory) |

## Resources

- [Chainlink CCIP Docs](https://docs.chain.link/ccip)
- [Chainlink Automation](https://docs.chain.link/automation)
- [Foundry Book](https://book.getfoundry.sh/)

## License

MIT License

---

**⚠️ Educational project - use at your own risk**