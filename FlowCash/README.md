# FlowCash - Continuous Payment Streaming Protocol

FlowCash is a revolutionary smart contract built on the Stacks blockchain that enables seamless, continuous payment flows between parties. Instead of traditional lump-sum payments, FlowCash allows users to create automated payment streams that distribute funds gradually over time on a per-block basis.

## Features

### 🌊 Continuous Payment Flows
- Create payment streams that distribute tokens automatically over time
- Recipients can claim their earned tokens at any point during the flow
- Perfect for salaries, subscriptions, vesting schedules, and recurring payments

### 💰 Flexible Fund Management
- Deposit and withdraw funds from your FlowCash balance
- All funds are securely held in the smart contract
- Real-time balance tracking and availability calculations

### ⚡ Real-Time Streaming
- Payments accrue on a per-block basis
- Recipients can claim available tokens at any time
- Transparent calculation of earned vs. withdrawn tokens

### 🛡️ Built-in Security
- Multi-party authorization for flow cancellation
- Automatic processing of pending payments on cancellation
- Unused funds automatically returned to sender

## How It Works

### 1. Fund Your Account
```clarity
(deposit-funds amount)
```
Deposit STX tokens into your FlowCash account balance.

### 2. Create a Payment Flow
```clarity
(create-cash-flow receiver tokens-per-block flow-duration)
```
Create a continuous payment stream specifying:
- **receiver**: The principal who will receive the payments
- **tokens-per-block**: Amount of tokens to release per block
- **flow-duration**: Total duration in blocks

### 3. Claim Tokens
```clarity
(claim-flow-tokens flow-id)
```
Recipients can claim their earned tokens at any time during the active flow.

### 4. Cancel Flows
```clarity
(cancel-cash-flow flow-id)
```
Either party can cancel a flow, with automatic settlement of pending payments.

## Key Functions

### Public Functions

- **`deposit-funds(amount)`** - Add STX to FlowCash balance
- **`withdraw-funds(amount)`** - Withdraw STX from balance
- **`create-cash-flow(receiver, tokens-per-block, flow-duration)`** - Create a new payment stream
- **`claim-flow-tokens(flow-id)`** - Claim earned tokens from a flow
- **`cancel-cash-flow(flow-id)`** - Cancel an active payment flow

### Read-Only Functions

- **`get-flow-details(flow-id)`** - Get complete flow information
- **`get-user-balance(user)`** - Check user's available balance
- **`calculate-available-tokens(flow-id)`** - Calculate claimable tokens for a flow
- **`get-service-fee-rate()`** - Get current protocol fee rate
- **`get-minimum-flow-amount()`** - Get minimum flow amount requirement

## Fee Structure

- **Service Fee**: 3% of claimed tokens (adjustable by contract owner)
- **Minimum Flow Amount**: 1000 micro-STX (adjustable by contract owner)

## Use Cases

### 💼 Payroll & Salaries
Stream employee salaries continuously rather than monthly payments, improving cash flow for both parties.

### 📺 Subscription Services
Create ongoing payment streams for subscription-based services with automatic token distribution.

### 🏗️ Vesting Schedules
Implement token vesting for team members, advisors, or investors with transparent, automated distribution.

### 🤝 Contractor Payments
Set up milestone-based or time-based payments for contractors and freelancers.

### 💎 DeFi Applications
Enable continuous liquidity provision rewards, staking distributions, or yield farming payments.

## Technical Details

- **Blockchain**: Stacks
- **Language**: Clarity
- **Token Standard**: STX (native Stacks tokens)
- **Block-based Timing**: Payments calculated per Stacks block

## Security Considerations

- All funds are held securely within the smart contract
- Multi-signature cancellation ensures fair settlement
- Automatic fee processing prevents manipulation
- Owner functions are restricted and transparent

## Getting Started

1. Deploy the FlowCash contract to the Stacks blockchain
2. Fund account using `deposit-funds`
3. Create first payment flow with `create-cash-flow`
4. Recipients can immediately start claiming tokens as they accrue
