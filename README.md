# 💰 Automated Treasury Management

## Overview

**Automated Treasury Management** is a decentralized autonomous organization (DAO) treasury smart contract that automates yield optimization across multiple DeFi protocols. The contract intelligently manages idle funds by deploying them to yield farms, claiming rewards, and reallocating assets based on governance decisions.

### Key Features

🏦 **Treasury Management** - Deposit and withdraw funds to/from the DAO treasury  
🌾 **Yield Farm Integration** - Register and invest in multiple yield-generating protocols  
🎯 **Reward Claiming** - Automatically claim and reinvest rewards from yield farms  
🗳️ **Governance Control** - Create reallocation proposals and vote on fund distribution  
💱 **Fund Reallocation** - Dynamically move funds between yield farms based on performance  
📊 **Transparency** - Read-only functions to query treasury state, allocations, and yields  

## Smart Contract Architecture

### Core Data Structures

- **treasury-deposits**: Tracks individual user deposits
- **fund-allocations**: Manages capital allocation across yield farms
- **reward-pool**: Accumulates and tracks claimed rewards per farm
- **governance-proposals**: Stores active and executed reallocation proposals
- **yield-farms**: Registry of available yield farm protocols with APY data

### Main Functions

#### Treasury Operations
- `deposit-to-treasury (amount)` - Add funds to the treasury
- `withdraw-from-treasury (amount)` - Withdraw funds from treasury

#### Investment Management
- `invest-in-farm (farm-id, amount)` - Deploy capital to a yield farm
- `claim-rewards (farm-id)` - Claim and reinvest rewards (10% of allocated amount)
- `register-yield-farm (farm-id, farm-name, apy)` - Register a new yield farm

#### Governance
- `create-reallocation-proposal (new-farm-id, amount)` - Propose fund reallocation
- `vote-on-proposal (proposal-id, vote-for)` - Cast governance vote
- `execute-proposal (proposal-id)` - Execute approved proposal (requires 2+ votes)
- `reallocate-funds (from-farm-id, to-farm-id, amount)` - Move funds between farms

#### Read-Only (Query Functions)
- `get-treasury-balance` - View total treasury balance
- `get-total-invested` - View total capital deployed
- `get-fund-allocation (farm-id)` - Query allocation for specific farm
- `get-fund-rewards (farm-id)` - View accumulated rewards per farm
- `get-proposal (proposal-id)` - Inspect proposal details
- `get-yield-farm (farm-id)` - View farm registry entry
- `get-user-deposit (user)` - Check individual user deposits
- `get-governance-threshold` - View voting threshold

## Usage Instructions

### 1. **Initialize the Contract**
```clarity
;; Deploy the contract on Stacks network
(contract-call? .automated-treasury ...)
```

### 2. **Register Yield Farms**
```clarity
;; Register a yield farm with APY data
(contract-call? .automated-treasury 
  register-yield-farm
  u1
  "Aave"
  u15)
```

### 3. **Deposit Funds**
```clarity
;; Users deposit to treasury
(contract-call? .automated-treasury 
  deposit-to-treasury
  u1000000)
```

### 4. **Invest in Yield Farms**
```clarity
;; Deploy capital to earn yield
(contract-call? .automated-treasury 
  invest-in-farm
  u1
  u500000)
```

### 5. **Claim Rewards**
```clarity
;; Claim accrued rewards (auto-calculates as 10% APY)
(contract-call? .automated-treasury 
  claim-rewards
  u1)
```

### 6. **Create Governance Proposal**
```clarity
;; Propose moving funds to higher-yield farm
(contract-call? .automated-treasury 
  create-reallocation-proposal
  u2
  u250000)
```

### 7. **Vote on Proposal**
```clarity
;; Cast governance vote
(contract-call? .automated-treasury 
  vote-on-proposal
  u0
  true)
```

### 8. **Execute Approved Proposal**
```clarity
;; Execute if voting threshold met (≥2 votes)
(contract-call? .automated-treasury 
  execute-proposal
  u0)
```

### 9. **Reallocate Funds**
```clarity
;; Move capital between farms based on governance decision
(contract-call? .automated-treasury 
  reallocate-funds
  u1
  u2
  u250000)
```

### 10. **Query Treasury State**
```clarity
;; Check treasury balance
(contract-call? .automated-treasury 
  get-treasury-balance)

;; View total invested
(contract-call? .automated-treasury 
  get-total-invested)

;; Check specific farm allocation
(contract-call? .automated-treasury 
  get-fund-allocation
  u1)
```

## Learning Outcomes

This MVP teaches:

✅ **Yield Optimization** - Strategies for maximizing returns across DeFi protocols  
✅ **Multi-Protocol Interaction** - Integrating with multiple yield sources  
✅ **Treasury Automation** - Programmatic fund management for DAOs  
✅ **DeFi Composition** - Building complex DeFi workflows on-chain  
✅ **Governance Systems** - Vote-based resource allocation mechanisms  
✅ **Clarity Smart Contracts** - Best practices for Stacks blockchain development  

## Error Handling

The contract includes comprehensive error codes:

- `u100` - Unauthorized (requires contract owner)
- `u101` - Insufficient funds
- `u102` - Invalid amount (must be > 0)
- `u103` - Proposal not found
- `u104` - Invalid proposal (insufficient votes)
- `u105` - Already voted on proposal

## Testing

Run the test suite:

```bash
npm test
```

Validate contract syntax:

```bash
clarinet check
```

## Deployment

Deploy to Testnet:

```bash
clarinet console --testnet
```

## Future Enhancements

- 🔄 Multi-token support (not just STX)
- ⏰ Automated reward claiming (time-based triggers)
- 📈 Advanced yield optimization algorithms
- 🌐 Cross-chain fund management
- 🔐 Multi-sig governance
- 💎 Staking rewards for governors

## License

MIT

---

**Built with ❤️ for Stacks DeFi**
