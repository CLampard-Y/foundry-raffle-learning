# Chainlink Automation Flow Notes

## 1. Problem Automation Solves
When Raffle contract satisfies the condition to pick a winner, it needs someone to trigger the `pickWinner()` function. However, Relying on a manual trigger executed by Owner may cause centralization, latency and availability such issues.

Automation in charge of monitoring conditons and triggering `pickWinner()` function, making the contract more decentralized and efficient. However Automation is only "trigger", it is "contract logic" that ensures the security of the contract. 

## 2. Time-based vs Custom Logic Automation
| Type | Where to define condition | Whether used by `Raffle` |
| --- | --- | --- |
| Time-based | Cron schedule / UI | Not main contract logic |
| Custom logic| `checkUpkeep()` | Main contract logic |

Time-based Automation: Setups time-based upkeep by UI, and defines execution plan by Cron expression.

Custom Logic Automation: Judges the time, state, player and balance conditions by `checkUpkeep()` function in Raffle contract.

## 3. `checkUpkeep`
What it Reads:
- timePassed
- isOpen
- hasPlayers
- hasBalance
> Based on above information, defines the `upkeepNeeded`

Will it change state?
> No, it's `public view`, it only reads and return `upkeepNeeded` and `performData` (null)

Is it security check?
> No, everyone can call `checkUpkeep()` (external) and even if Automation node call `checkUpkeep()` first, it can't be sure that the state haven't changed when `performUpkeep()` is called.

## 4. `performUpkeep`
What it does
- Re-checks the conditions (call `checkUpkeep()`)
- (If condition is met) change the state into `OPEN` and send VRF randomness request
- (If not) revert

## 5. Why performUpkeep Re-checks Conditions
Automation node stimulates `checkUpkeep()` to get `true`, which does not freeze on-chain state, contract information (players, balance, state, time conditions) may change when another transaction changes the contract state before Automation transaction really gei into block.

## 6. Raffle State Transition
```
OPEN
  |
  | checkUpkeep == true
  | performUpkeep
  v
CALCULATING
  |
  | VRF fulfillment
  v
OPEN
```
Automation change `OPEN` to `CALCULATING`, VRF callback change `CALCULATING` to `OPEN`
## 7. Parameterized Custom Error
```solidity
error Raffle__UpkeepNotNeeded(
    uint256 currentBalance,
    uint256 numPlayers,
    uint256 raffleState
);
```
- custom error without parameters only return `type`
- custom error with parameters returns `balance`, `players count` and `raffle state`, which are useful for debugging and accurate testing
## 8. Code Mapping
| Concept                        | Code                                       |
| ------------------------------ | ------------------------------------------ |
| Off-chain condition simulation | `checkUpkeep()`                            |
| On-chain enforcement           | `performUpkeep()` re-calls `checkUpkeep()` |
| State lock                     | `s_raffleState = CALCULATING`              |
| Randomness request             | `requestRandomWords(...)`                  |

## 9. Remaining Questions
