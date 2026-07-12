# Chainlink VRF Flow Notes

## 0. Overview of Workflow
```
1. Request transaction
────────────────────────────────

Raffle Consumer
    |
    | requestRandomWords(request)
    v
VRF Coordinator
    |
    | records request
    | emits request event
    v
Blockchain logs


2. Offchain observation
────────────────────────────────

VRF Node / Job
    |
    | monitors Coordinator events
    | finds matching keyHash/job
    | waits requestConfirmations
    | generates randomness + proof
    v


3. Fulfillment transaction
────────────────────────────────

VRF Node
    |
    | submits proof + response
    v
VRF Coordinator
    |
    | verifies proof onchain
    | derives/verifies random output
    v
Consumer.rawFulfillRandomWords(...)
    |
    | checks msg.sender == Coordinator
    v
Raffle.fulfillRandomWords(...)
```
## 1. Why On-chain Randomness Is Hard
Blockchain execution is deterministic, and onchain data is visible.Block producers may also influence transaction ordering or block inclusion.
so contracts cannot independently and safely generate unpredictable randomness from onchain data.
## 2. Roles and Architecture
```
Raffle emits/submits a request
→ offchain VRF nodes observe and process the request
→ node submits randomness and proof to Coordinator
→ Coordinator verifies the proof
→ Coordinator invokes the consumer callback path
```
Raffle Contract
- request randomness (`requestRandomWords()`)
- Receive and consume verified randomness (`fulfillRandomWords()`)
- Derive a winner from the returned random word (`pickWinner()`)

VRF Coordinator
- Receive and records randomness request from consumer contracts
- Verifies the randomness proof submitted by VRF service
- Delivers the verified result through the consumer callback path

Chainlink VRF
- generate randomness and matching proof
## 3. Request / Fulfillment Lifecycle
```
User
 |
 |
Raffle
 |
 | requestRandomWords()
 |
 ↓
VRF Coordinator
 |
 |
Chainlink VRF
 |
 | random + proof
 |
 ↓
VRF Coordinator
 | external call
 | rawFulfillRandomWords(requestId, randomWords)
 ↓
VRFConsumerBaseV2Plus
 | verifies callback caller
 | checks msg.sender == trusted Coordinator
 ↓
Raffle.fulfillRandomWords()
```
- Raffle sends request information (`subscriptionId`, `keyHash`, `callbackGasLimit`, `numWords`, `extraArgs`) to VRF Coordinator by calling `requestRandomWords()`
- VRF Coordinator gets request from Raffle
- Chainlink VRF generates randomness and cryptographic proof
- VRF Coordinator verifies the proof onchain
- VRF Coordinator sends callback to Raffle (VRF does not return randomness in the same transaction. It uses an asynchronous request-response lifecycle) by external call `rawFulfillRandomWords()`
## 4. Raffle State Transition During VRF
The state is `OPEN` when the raffle constrct is created and `CALCULATING` when `pickWinner()` (moment when contract sends request to VRF) is called, and `OPEN` again after winner is picked. 

This state machine preserves the integrity of the raffle lifecycle and prevents the participant set from changing while randomness is pending.
```
(MAYBE DIFFERENT AS PROCESS)
OPEN

 |
 | performUpkeep
 |
 ↓

CALCULATING

 |
 | fulfillRandomWords
 |
 ↓

OPEN
```
`performUpkeep()` validates the draw conditions, changes the state from OPEN to CALCULATING, and submits the VRF request.

`fulfillRandomWords()` selects the winner and changes the state from CALCULATING back to OPEN.
- In this work flow, the players can not enter raffle (`enterRaffle()`) when the raffle is in `CALCULATING` state (that is when `pickWinner()` is called)
- The winner calculation still depends on `players.length`, changes of `players` array (allows players enter) will affect the winner calculation 
- Therefore after the randomness request is submitted, the raffle must freeze the player set until fulfillment arrives
## 5. Trust Boundary and Security Considerations
- Trusted callback: 
  - `fulfillRandomWords()` is an internal callback hook and cannot be called directly from outside. 
  - The VRF Coordinator calls `rawFulfillRandomWords()` on the inherited base contract.
  - The base contract verifies the caller and then dispatches to `fulfillRandomWords()`.. 
  - If anyone can call (external) `fulfillRandomWords()`, it will create a attack vector
- `fulfillRandomWords()` simplicity: The VRF sevice does not retry a failed fulfillment callback if `fulfillRandomWords` reverts. Keep `fulfillRandomWords()` simple and unlikely to revert, and consider taking more complex follow-on actions in separate calls
- `requestId` matching: `requestId` ensures randomness outcome matches request, and this is especially important when multiple requests can be in flight concurrently.
## 6. Code Mapping in Raffle
- `contract Raffle is VRFConsumerBaseV2Plus`: This makes Raffle a VRF consumer and provides callback verification through the base contract.
- `s_vrfCoordinator.requestRandomWords(...)`: This starts the asynchronous randomness request lifecycle.
- `fulfillRandomWords(...)`: This function is called by the VRF Coordinator after randomness fulfillment.
## 7. Design Questions / Open Questions
- How does VRF cryptographic proof guarantee randomness authenticity?
- Why is VRF proof verification centralized in the Coordinator instead of being repeated in every consumer contract?
- What assumptions does the consumer make about the configured Coordinator address?
- What happens if `callbackGasLimit` is too low?