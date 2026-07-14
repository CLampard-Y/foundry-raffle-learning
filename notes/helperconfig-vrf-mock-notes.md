# HelperConfig and VRF Mock Notes

## Why HelperConfig exists

## Local vs Sepolia / Live Network

## Why VRFCoordinatorV2_5Mock is needed

## What Mock can/cannot do
### Overview of Model
**Real environment**
Raffle
-> Real Coordinator get the randomness request
-> Chainlink node monitors and generates randomness + proof
-> Coordinator verifies proof
-> Raffle.rawFulfillRandomWords()
-> Raffle.fulfillRandomWords()

**Mock environment**
Raffle
-> VRFCoordinatorV2_5Mock.requestRandomWords()
-> Mock stores request and emits event
-> Test manually calls Mock.fulfillRandomWords()
-> Mock generates deterministic test words
-> Raffle.rawFulfillRandomWords()
-> Raffle.fulfillRandomWords()

Mock 替代了 Chainlink node、等待 confirmations 和 cryptographic proof verification，但保留了 request、subscription、consumer authorization、callback gas、payment accounting 和 trusted callback。
## What local mock cannot prove