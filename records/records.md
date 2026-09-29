# Records

> Dated execution and learning history. Older entries may contain preliminary interpretations; use current code and [PENDING_WORK_CHECKLIST.md](PENDING_WORK_CHECKLIST.md) for current tasks. The 8.17 deployment-identity test was local integration, not a public-chain fork test. The 9.16–9.19 credential test covers a zero key, not an absent key.

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
Change name into `testFuzz_fulfillmentSelectsWinnerAndCreditsClaim_WhenRequestIsValid`

## 9.14 ~ 9.15
#### `test_fulfillmentCreditsClaimWithoutPushingEth_WhenWinnerRejectsEth`
- Separate VRF request-consumption behavior (`test_fulfillmentConsumesRequest_WhenRequestIsValid`) from the rejecting-winner test.

#### `test_WithdrawWinningsReverts_WhenClaimAlreadyWithdrawn`
Change name into `test_withdrawWinningReverts_OnDoubleWithdrawal`
Current test proves both (mix two requirements):
- 1. the first withdrawal clears the claim -> `test_withdrawWinningsClearsClaim_WhenCallerHasClaim`
- 2. the second withdrawal reverts -> `test_withdrawWinningsReverts_OnDoubleWithdrawal`
Added coverage:
- 1. withdraw event emitted.

## 9.16 ~ 9.19
### `script/HelperConfig.s.sol`
#### Unsupported chain Id test

#### Local cache configuration test
QA
- 1. Which Two return fields prove that mock contracts were not redeployed?
  > `localNetworkConfig.vrfCoordinator` and `localNetworkConfig.link` (address of `linkToken`)
- 2. Why both lookups use the same `HelperConfig` instance?
  > (If create second instance) it would test two independent cashes rather than repeated lookup behavior.

#### Sepolia configuration values
QA
- 1. Does this test need to deploy mocks?
  > No
- 2. Which fields in `NetworkConfig` are relevent to Sepolia deployment?
  > `vrfCoordinator`, `gasLane`, `subscriptionId`, `callbackGasLimit`, `link`
- 3. Where can you obtain the actual values required to verify?
  > `getConfigByChainId()` returns the actual values.
- 4. Why should this test call `getConfigByChainId()` directly instead of changing `block.chainid` ?
  > Changing `block.chainid` directly would change the state of contract and test, which is not desired.

#### Missing Sepolia deployer key
QA
- 1. Why using `vm.chainId()` to edit the chain ID?
  > `getDeployerKey()` read Sepolia deployer key only when chain id is Sepolia.
- 2. Pay attention to the use of `vm.setEnv()`

## 9.20 ~ 9.21
Sepolia preflight and small repository-status cleanup
### Repository status documentation update
#### `PROJECT_STATUS_AND_ROADMAP.md`
- Baseline update
- Invariant changes (stateful verification) update
- The number of tests update

## 9.22 ~ 9.26
### Gate 2 — Sepolia read-only preflight
##### Step 1: Configure the RPC Endpoint
```shell
# In your local shell.
export SEPOLIA_RPC_URL='https://your-sepolia-rpc-endpoint'

# Run the first read-only check.
# Expected output: 11155111
/home/ZKdev/.foundry/bin/cast chain-id --rpc-url "$SEPOLIA_RPC_URL"
```
Proves:
- The RPC endpoint reaches Sepolia

##### Step2: Verify Coordinator & Link Address Contain Runtime Bytecode
```shell
  # Perform read-only RPC checks.
  COORDINATOR_ADDRESS=0x9DdfaCa8183c41ad55329BdeeD9F6A8d53168B1B
  LINK_ADDRESS=0x779877A7B0D9E8603169DdbD7836e478b4624789

  # cast code <address>
  # Performs a read-only `eth_getCode` RPC request.
  coordinator_code=$(
    /home/ZKdev/.foundry/bin/cast code \
    --rpc-url "$SEPOLIA_RPC_URL" \
    "$COORDINATOR_ADDRESS"
  )

  link_code=$(
    /home/ZKdev/.foundry/bin/cast code \
    --rpc-url "$SEPOLIA_RPC_URL" \
    "$LINK_ADDRESS"
  )

  if [[ "$coordinator_code" == "0x" ]]; then
      echo "coordinator: no runtime bytecode"
  else
      coordinator_bytes=$(((${#coordinator_code} - 2) / 2))
      echo "coordinator runtime bytes: $coordinator_bytes"
  fi

  if [[ "$link_code" == "0x" ]]; then
      echo "LINK token: no runtime bytecode"
  else
      link_bytes=$(((${#link_code} - 2) / 2))
      echo "LINK token runtime bytes: $link_bytes"
  fi
```
Proves:
- The configured coordinator address has deployed code.
- The configured LINK address has deployed code.
Not proves:
- The gas lane, subscription, subscription owner configured correctly.
- Raffle is registered as a consumer.

##### Step3: Check Whether settings match ducumented Eth Sepolia setup
Document website: https://docs.chain.link/vrf/v2-5/supported-networks
- VRF Coordinator
```shell
/home/ZKdev/.foundry/bin/cast code \
  0x9DdfaCa8183c41ad55329BdeeD9F6A8d53168B1B \
  --rpc-url "$SEPOLIA_RPC_URL" | cut -c 1-20

source .env
/home/ZKdev/.foundry/bin/cast code   0x9DdfaCa8183c41ad55329BdeeD9F6A8d53168B1B  \ --rpc-url "$SEPOLIA_RPC_URL" | cut -c 1-20
```
- LINK Token
```shell
.env
/home/ZKdev/.foundry/bin/cast code \
    0x779877A7B0D9E8603169DdbD7836e478b4624789 \
    --rpc-url "$SEPOLIA_RPC_URL" | cut -c 1-20
```
- Gas Lane
- `nativePayment` setting

##### Step4: Check VRF Subscription
Verify the following values:
- `balance`
- `nativeBalance`
- `reqCount`
- `owner`
- `consumers`

```solidity
getSubscription(uint256 subscriptionId)
returns (
  uint96 balance,
  uint96 nativeBalance,
  uint64 reqCount,
  address owner,
  address[] consumers
)

pendingRequestExists(uint256 subscriptionId)
returns (
  bool
)
```

```shell
/home/ZKdev/.foundry/bin/cast call \
  # vrfCoordinator
  0x9DdfaCa8183c41ad55329BdeeD9F6A8d53168B1B \
  "getSubscription(uint256)(uint96,uint96,uint64,address,address[])" \
  # subscriptionId
  38935307025656909513953714257720199287951776187933259851240202794364574788117 \
  --rpc-url "$SEPOLIA_RPC_URL"

/home/ZKdev/.foundry/bin/cast call \
  # vrfCoordinator
  0x9DdfaCa8183c41ad55329BdeeD9F6A8d53168B1B \
  "pendingRequestExists(uint256)(bool)" \
  # subscriptionId
  38935307025656909513953714257720199287951776187933259851240202794364574788117 \
  --rpc-url "$SEPOLIA_RPC_URL"

# Verify the owner of the subscription
/home/ZKdev/.foundry/bin/cast wallet address \
  --private-key "$SEPOLIA_PRIVATE_KEY"
```

##### Step5(Minimum-Acceptable-Stage) Verify Existing Consumer of the Subscription

- Verified on Sepolia: both registered consumers ([0x8a23...f410](https://sepolia.etherscan.io/address/0x8a23ca647d6edcbf28b335aa2e564e2165dff410), [0x014e...00d6](https://sepolia.etherscan.io/address/0x014ec4e62841ccdcd65658aa4f479f6afd3b00d6)) are historical `SubscriptionConsumer` test contracts deployed by the subscription owner. Both contain runtime bytecode and return the configured subscription ID from `s_subscriptionId()`.
- Gate 2 RPC evidence (2026-09-26 17:21 UTC):
  - Sepolia chain ID `11155111`;
  - coordinator and LINK addresses contain runtime code. Subscription reads were pinned to block `11787627`;
  - the owner matched the address derived from `SEPOLIA_PRIVATE_KEY`. [Official Sepolia VRF parameters](https://docs.chain.link/vrf/v2-5/supported-networks).

  ```text
  getSubscription: balance=18000000000000000000 juels (18 LINK), nativeBalance=0, reqCount=0
  owner=0x1B2bBE13FFd0c4f2654D401d102C1CdC749Dea41
  consumers=[0x8a23ca647D6EDCbf28b335Aa2E564E2165DFf410, 0x014eC4E62841ccdCD65658aa4f479f6AfD3b00d6]
  pendingRequestExists=true
  ```

  The old pending request(s) remain unresolved; the exact request IDs were not traced.
- Decision: **reuse** this subscription for the educational Sepolia smoke test and leave the old consumers registered
  (The coordinator permits adding a new consumer and making requests while another request is pending; pending requests prevent removing consumers or cancelling the subscription).
- Before live deployment:
  - recheck owner, LINK balance, pending status, and consumer list;
  - confirm the new Raffle is added after deployment.
  - If isolation or cleanup becomes necessary later, trace the old requests or create and fund a dedicated subscription, then update `HelperConfig` with its ID.

## 9.27 ~ 9.28
### Gate 3 - Sepolia non-broadcast deployment simulation
```shell
source .env

forge script script/DeployRaffle.s.sol:DeployRaffle \
  --rpc-url "$SEPOLIA_RPC_URL" \
  -vvvv
```
Context:
- 2026-09-27 05:06 UTC
- Source commit `3d9c19e`
- Forge `1.7.1`, Sepolia chain ID `11155111`
- Command without `--broadcast`

Resolved configuration:
- Sender: `0x1B2bBE13FFd0c4f2654D401d102C1CdC749Dea41` (relative address to `SEPOLIA_PRIVATE_KEY`)
- Raffle address: `0x3416390e9084B0341B11D03D2006139B0fd06FF0`
- VRF coordinator: `0x9DdfaCa8183c41ad55329BdeeD9F6A8d53168B1B`
- Chain: Sepolia (11155111)
- Raffle constructor:
  - `entranceFee` = 0.01 ETH;
  - `interval` = 30 seconds;
  - `vrfCoordinator` = 0x9DdfaCa8183c41ad55329BdeeD9F6A8d53168B1B;
  - `gasLane` = 0x787d74caea10b2b357790d5b5247c2f63d1d91572a9846f780606e4d953677ae;
  - `subscriptionId` = 38935307025656909513953714257720199287951776187933259851240202794364574788117;
  - `callbackGasLimit` = 500000;
  - `LINK` = 0x779877A7B0D9E8603169DdbD7836e478b4624789;

Simulated call sequence:
1. Sender, nonce 18 → CREATE Raffle at simulated address (0x3416390e9084B0341B11D03D2006139B0fd06FF0).
2. Same sender, nonce 19 → coordinator.addConsumer (subscriptionId, simulated Raffle address) . Simulated SubscriptionConsumerAdded event observed.

Result
- Simulation succeeded without a revert;
- No `createSubscription` or `fundSubscription` call was attempted;
- No transaction was broadcast;
- No public receipt;
- Simulated Raffle address had no on-chain code.

### Gate 4 - Optional Sepolia fork validation
Goal: Verify whether the same project behave as expected when a test or local deployment uses a reproducible snapshot of the real coordinator, LINK token and subscription.
Biggest difference with Gate 5: Fork contains the coordinator's code and the subscription state as selected block. You may change copu-for example, add newly deployed Raffle as a consumer, but the public Sepolia subscription reamin unchanged.
#### Step 1: Select a fixed block
```shell
# Read-only preflight checks.

# Block number is contract's position in the chain.
# Result (fixed block number): 11792671
/home/ZKdev/.foundry/bin/cast block-number finalized \
  --rpc-url "$SEPOLIA_RPC_URL"

# Verify the block number.
# Hash is the fingerprint of the particular block.
# Result (block hash): 0xbc521f049b0b2e3595c2af9b562a84c288db18214ed2fdc0d67d0774a43ce5f7

/home/ZKdev/.foundry/bin/cast block 11792671 \
  --field hash \
  --rpc-url "$SEPOLIA_RPC_URL"
```
#### Step 2: Verify the readness of subscription
```shell
/home/ZKdev/.foundry/bin/cast call \
  0x9DdfaCa8183c41ad55329BdeeD9F6A8d53168B1B \
  "getSubscription(uint256)(uint96,uint96,uint64,address,address[])" \
  38935307025656909513953714257720199287951776187933259851240202794364574788117 \
  --rpc-url "$SEPOLIA_RPC_URL" \
  --block 11792671

# Result:
# 18000000000000000000 [1.8e19]
# 0
# 0
# 0x1B2bBE13FFd0c4f2654D401d102C1CdC749Dea41
# [0x8a23ca647D6EDCbf28b335Aa2E564E2165DFf410, 0x014eC4E62841ccdCD65658aa4f479f6AfD3b00d6]

/home/ZKdev/.foundry/bin/cast call \
  0x9DdfaCa8183c41ad55329BdeeD9F6A8d53168B1B \
  "getSubscription(uint256)(uint96,uint96,uint64,address,address[])" \
  38935307025656909513953714257720199287951776187933259851240202794364574788117 \
  --rpc-url "$SEPOLIA_RPC_URL" \
  --block 11792671
```
- Success means the RPC can retrieve the subscription's state at the pinned block.
- The result (five parameters) is the same as the result of the `getSubscription` call at the pinned block.
#### Step 3: Sepolia fork test (Gate 4A)
**Coordinator and LINK**
- Requirement: `HelperConfig` resolves the expected address; both addresses have non-empty runtime code.
- Proves: Configuration is valid.
- Not proves: Code presence alone does not establish contract identity.

**Subscription**
- Requirement: Call `getSubscription()` on the fork; inspect owner, LINK/native balances, and consumers (`DeployRaffleTest` verify deployment using expected config, and this verify fixed block Sepolia fork deployed using expected config) .
- Proves: The configured subscription exists with the expected copied state.

**Constructor compatibility**
- Requirement: Construct a `Raffle` using the resolved configuration and check observable initial behavior.
- Proves: Inputs can initialize the Raffle on the fork as expected.
- Not proves: Does not prove VRF nodes will fulfill a request.

**Gate 4A evidence (2026-09-28 UTC):** Sepolia RPC fork at block `11792671` (chain ID `11155111`; block hash recorded above). Run `/home/ZKdev/.foundry/bin/forge test --match-path test/fork/SepoliaForkTest.t.sol -vv`: 3 passed, 0 failed, 0 skipped. `forge fmt --check test/fork/SepoliaForkTest.t.sol` passed. The tests checked configured coordinator/LINK addresses and code presence, copied subscription state, and Raffle constructor initialization. RPC endpoint details and secrets are not recorded. This is snapshot evidence only, not live VRF fulfillment or consumer registration.

### Planning review and local verification

Source baseline: `01a26a9`; Foundry `1.7.1`. This was a documentation review, not implementation of the newly proposed tasks.

- `forge fmt --check` and `forge build --sizes` passed (build cache reused).
- `forge test --no-match-path 'test/fork/**'`: 38 passed, 0 failed, 0 skipped; invariant: 128 runs × 64 calls, zero reverts.
- No fresh fork/RPC check, coverage run, or broadcast was performed.

Decision:
- Prioritize accounting reconciliation, callback-gas and privilege checks, and reproducible builds.
- Keep fork deployment and external scheduling optional;
- refresh subscription state before any public broadcast.
- Scope and next tasks: [roadmap](../PROJECT_STATUS_AND_ROADMAP.md) and [pending checklist](PENDING_WORK_CHECKLIST.md).
