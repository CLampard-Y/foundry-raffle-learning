# Foundry Raffle Learning Project

A Solidity + Foundry learning project based on Cyfrin Updraft Smart Contract Lottery.

This project is used to study:
- Raffle state machine
- Chainlink VRF request/fulfill flow
- Chainlink Automation check/perform flow
- mock-based local testing
- Foundry deployment scripts

## About
This code is to create a proveably random smart contract lottery.

## What we want it to do?
1. Users should be able to enter the raffle by paying for a ticket. The ticket fees are going to be the prize the winner receives.
2. The lottery should automatically and programmatically draw a winner after a certain period.
3. Chainlink VRF should generate a provably random number.
4. Chainlink Automation should trigger the lottery draw regularly.

## Non-Claims

- Not audited
- Not production-ready
- Not for real lottery operations
- No mainnet deployment