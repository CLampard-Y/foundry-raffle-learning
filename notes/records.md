# Records

## 8.17
### 1. Sort Out
sort out the current state of the repo and next steps
- Core contract function already implemeneed
- Current phase is testing & security hardening

### 2. Testing
The suite already covers:
- Core contract (`Raffle.sol`)
- Deployment scripts (`DeployRaffle.s.sol`)
- Fork tests (specify the owner of the subscription, the contract owner, and the consumer)
- Rejecting winner failure (leaving the raffle in `CALCULATING`)

### 3. Next Steps
#### (P0) Improve to prevent rejecting winner failure
`test_fulfillmentLeavesRoundUnsettled_WhenWinnerRejectesEth` already proves: a malicious winner can make the callback settlement roll back and leave the raffle in `CALCULATING`.

The next test work should accompany the proposed pull-payment remediation (Highest-priority tests before Sepolia deployment):
- 1. (BUG) Rejecting winnner cannot block round finalization.
- 2. Winner receives the correct claimable amount.
- 3. (Successful withdrawal) clears the claim.
- 4. (Failed withdrawal) preserves the claim.
- 5. Zero-claim and double withdrawal revert.
- 6. Withdrawal reentrancy cannot extract extra ETH.
- 7. A new round settles while previous winnings remain unclaimed.
- 8. Previous reserved winnings are excluded from the new prize.

Follow this sequence:
existing characterization test -> first failing post-fix test -> minimal pull-payment fix -> remaining tests


- Improve the coverage of `HelperConfig` and `Interactions`

## 8.17~8.21
- (Done) Rejecting winnner cannot block round finalization.
- (Done) Winner receives the correct claimable amount.
- (Done) (Successful withdrawal) clears the claim.
- (Done) (Failed withdrawal) preserves the claim.
- (Done) Zero-claim and double withdrawal revert.

## 8.21
- (Done) Withdrawal reentrancy cannot extract extra ETH.

## 8.31
- (Done) New round settles while excluding previous reserve winnings.

## 9.1
### Accounting invariant (stateful invariant test)
Goal: total outstanding claims <= address(raffle).balance
Path:
    1. Design handler that can repeatedly enter, settle and withdraw while claims matain.
    2. dd
QA:
- 1. Why handler is needed?
  > Directly fuzzing `Raffle` would mostly generates invalid calls. A handler converts random input into valid state transitions.
- 2. Why hashing instead of directly casting `actorSeed`?
  > Directly casting still syntactically generates valid EVM addresses, but Foundry fuzzers usually test boundary values such as 0,1,2, etc, it is less representative of ordinary user accounts.

## 9.9 ~ 9.11
### Test Overview & Merge & Remove
Goal: As the work flow (seperate `withdrawWinnings` and `performUpkeep` functions) changed, the stale test should be adjuested.
#### Remain unchanged
- Constructor configuration
- `enterRaffle`
- `checkUpkeep`
- `performUpkeep` (below functions need to review repeatedly)
  - `test_performUpkeepEmitsRequestId_WhenUpkeepNeeded` (use `vm.recordLogs`)
  - `test_performUpkeepRequestsRandomWords_WithExpectedConfig`

#### `test_fulfillRandomWordsSettlesRaffle_WhenRequestIsValid`
Previous test does three things:
- 1. Selects the winner;
- 2. Credits the winner;
- 3. Immediately withdraws the claim.

Split it into two focused tests:
- `test_fulfillRandomWordsSelectsWinnerCreditsClaimAndReopensRaffle_WhenRequestIsValid`: Focus on selecting and crediting winner, while reopening the raffle.
- `test_withdrawWinningsPaysClaimAndClearsAccounting`: Focus on withdrawing the claim and clearing the accounting.

#### `testFuzz_fulfillmentSelectsExpectedPlayerAndSettles_WhenRequestIsValid`
Previous test verifies:
- expected winner selection
- raffle reset (reopen, clears accounting)
- winner balance does not change immediately
lacks:
- claimable winnings of winner
- total outstanding claims
- raffle balance
