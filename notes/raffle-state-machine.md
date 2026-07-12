# Raffle State Machine Notes

## Total phases
A raffle has phases:
- accepting players
- waiting for enough time to pass
- requesting randomness
- selecting winner
- resetting for the next round

## Day 1
### Concepts
- entrance fee
- players array
- events
- custom errors
- block.timestamp
- interval

## Day 2
### Concepts
- randomness request workflow
- enums
- VRF Coordinator & Chainlink offchain VRF
### Core State Machine
`OPEN` -> `CALCULATING`:
- Triggered by `performUpkeep` / randomness request path.
- New entries should be blocked.

`CALCULATING` -> `OPEN`:
- Triggered by `fulfillRandomWords`.
- Winner is already selected, players reset, timestamp reset, prize transferred.
### Q&A
- Why VRF is asynchronous randomness request lifecycle:
- The relationship between `rawFulfillRandomWords` and `fulfillRandomWords`:
- How to represent CEI pattern in `pickWinner`:

