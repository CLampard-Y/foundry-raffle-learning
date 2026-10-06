# Pending Work Checklist

Updated: **2026-10-05 (Asia/Shanghai)**. T1 implementation baseline: `70d1941`; scoped T2 test baseline: `ab42ee0`; T3–T5 revised by the 2026-10-05 planning review (see [roadmap §3.1](../PROJECT_STATUS_AND_ROADMAP.md#31-2026-10-05-pre-t3-review)).

This is the authoritative queue of **remaining work**. The [roadmap](../PROJECT_STATUS_AND_ROADMAP.md) owns scope, milestones and risk decisions; [records](records.md) owns dated commands, results and learning notes. Historical Gate numbers are retained for traceability, not as instructions to repeat completed work.

> 中文：本清单管理接下来做什么、为何做、怎样验收；路线图管理整体阶段；records 保存证据。新增任务均为待执行，不表示本次文档评审已经实现。

## Completed baseline

| Evidence                  | Established result                                                                                                                                                     | Boundary                                                                                      |
| ------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------- |
| Local suite               | 47 passed, 0 failed, 0 skipped (T2 closure 2026-10-05; rerun at `eef8499` during the planning review): 34 Raffle, 4 HelperConfig, 1 deployment, 8 invariant-file tests | RPC/fork tests excluded; hosted CI has not run the T2 commits                                 |
| Invariants                | Four aggregate properties (solvency, claim-sum reconciliation, conservation, balance = liabilities + modeled pot); 128 runs, depth 64, zero reverts                    | Zero-start/no-forced-ETH closed model; handler settles immediately; per-actor ledger deferred |
| Gate 2 preflight          | Recorded 2026-09-26, block `11787627`: code presence, owner, 18 LINK, two historical consumers, pending requests                                                       | Historical snapshot, not current funding assurance                                            |
| Gate 3 simulation         | Recorded 2026-09-27: deployment + `addConsumer` succeeded without broadcast                                                                                            | Simulated address is not a public deployment                                                  |
| Gate 4A fork tests        | Recorded 2026-09-28: 3 passed at block `11792671`                                                                                                                      | Copied config/subscription and constructor checks; no script broadcast or VRF service         |
| Callback capacity probe   | Exploratory, 2026-10-05: callback succeeds at N ≤ 73 players, fails at N ≥ 74 (fresh-transaction gas model, 500000 limit, pinned build)                                | Throwaway probe, not committed; **planning evidence only** — T3.1 must reproduce it as a test |
| Gate 4B / live deployment | No recorded completion                                                                                                                                                 | Pending/optional as specified below                                                           |

Do not reopen completed pull-payment, withdrawal-event, `WinningCredited` or HelperConfig zero-key tests. Absent/malformed credentials still differ from a zero key.

## Order and evidence labels

Recommended order (each phase ends at a reviewable commit boundary):

| #   | Phase                                               | Work                                                                                                                                                                                                       | Depends on            | Exit evidence                                           |
| --- | --------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | --------------------- | ------------------------------------------------------- |
| 0   | Plan baseline                                       | Review and commit the 2026-10-05/06 planning-doc edits                                                                                                                                                     | —                     | Docs-only commit                                        |
| 1   | **CW-A**                                            | False-green fulfillment assertions; invariant withdraw steering + `afterInvariant` reachability                                                                                                            | 0                     | RPC-free suite passes; effective action counts recorded |
| 2   | **T1.1**                                            | Push (user action) and record one hosted CI run                                                                                                                                                            | 1 (so CI covers CW-A) | Run ID, revision, result                                |
| 3   | **T3.1**                                            | Cold-model capacity boundary pair, demo-size margin, failed-callback state                                                                                                                                 | 1                     | Measured N/N+1 recorded                                 |
| 3′  | **T3.2** (parallel with 3)                          | Request rollback, `setCoordinator` boundary, owner override                                                                                                                                                | 1                     | Tests pass; trust assumption recorded                   |
| 4   | **D1**                                              | Decide cap (recommended) or accept; record in R4                                                                                                                                                           | 3                     | Decision + rationale in roadmap                         |
| 5   | **D1 change + CW-B**                                | If cap: Builder adds cap + pragma pin + NatSpec fixes → cap regression (cap passes cold, cap+1 reverts) → rerun T1 acceptance commands                                                                     | 4                     | New reviewed revision candidate                         |
| 6   | **T3.3**                                            | Independent auditor re-review of the step-5 revision (or labelled scoped review if no code changed)                                                                                                        | 5, 3′                 | Review record; findings in register                     |
| 7   | **D2** (decision can be drafted from step 3 onward) | Signer/subscription model; recommended dedicated bounded subscription                                                                                                                                      | — (finalize after 6)  | Decision recorded                                       |
| 8   | **CW-C**                                            | Subscription created/funded outside `DeployRaffle` (live testnet tx, needs explicit authorization); HelperConfig constant + test; `subscriptionId == 0` guard; post-deploy assertions; fork test re-pinned | 6, 7                  | Local suite + fork lane pass (no skips)                 |
| 9   | **T4**                                              | Official params, subscription state/budget, interval, teardown, incident procedure, keystore, fresh simulation of the final revision                                                                       | 8                     | Simulation postconditions match                         |
| 10  | Gate 4B (optional)                                  | One loopback fork rehearsal of the final revision, or a recorded skip                                                                                                                                      | 9                     | Receipts/postconditions or skip decision                |
| 11  | **Gate 5A**                                         | Live deploy → register → entry → manual upkeep → real fulfillment → withdrawal → teardown                                                                                                                  | 9 (10 optional)       | Public receipts in records                              |
| 12  | **T5**                                              | Testing/security notes (drafting starts at step 3), README reconciliation, fault-injection demo, independent explanation                                                                                   | 11 or recorded stop   | Closure record                                          |
| —   | Gate 5B                                             | Only if automation is still a concrete goal                                                                                                                                                                | 11                    | Separate decision                                       |

Hard ordering rules: D1 before any simulation or fork rehearsal (a cap changes bytecode); CW-B lands with D1 so bytecode changes once; CW-C lands as one change set with D2; nothing is broadcast before T4 passes on the final revision.

| Label                    | Meaning                                                                    | Current evidence                                          |
| ------------------------ | -------------------------------------------------------------------------- | --------------------------------------------------------- |
| A — Local                | Local behavior/build checked at an identified revision                     | Established within existing test scope; T3 strengthens it |
| B1 — Fork snapshot       | Assertions against a pinned public-chain snapshot                          | Recorded Gate 4A completion                               |
| B2 — Fork deployment     | Script transactions and postconditions on a persistent local fork          | Not established; optional Gate 4B                         |
| C1 — Live VRF round      | Public deployment, consumer setup, real fulfillment, credit and withdrawal | Not established; required for a live-integration claim    |
| C2 — Automated execution | Supported external scheduler actually triggers a round                     | Not established; optional extension to C1                 |

These are evidence labels, not safety grades. Documentation closure is separate. C1 does not require B2 or C2. A skipped fork test does not establish B1.

## CW — Corrections to completed work

Source: the 2026-10-06 review of completed M0/T1/T2/Gate 2–4A work (`protocol_test_engineer`, read-only `protocol_security_auditor`, Primary checks). No recorded result was found to be **false**, and no secret was found in tracked files or history. The items below fix evidence gaps or remove failures that would occur later. They are grouped by **when they are cheapest to do**, so that bytecode-changing edits land once and configuration edits land as one change set.

| Priority | Meaning                                                                                  |
| -------- | ---------------------------------------------------------------------------------------- |
| **MUST** | Without it, a later step fails or a recorded claim becomes wrong under a known condition |
| **HIGH** | Small cost, removes a concrete false-confidence or recovery gap                          |
| **OPT**  | Hygiene; do only if convenient                                                           |

### CW-A — Test-evidence fixes (test-only; do now, before or alongside T3)

- [x] **HIGH — Close the one false-green fulfillment test.** `test_fulfillmentConsumesRequest_WhenRequestIsValid` ([RaffleTest.t.sol:650](../test/unit/RaffleTest.t.sol#L650)) only asserts that a second fulfillment reverts `InvalidRequest`. The mock deletes the request **even when the callback fails**, so this test passes if fulfillment breaks. Add `RaffleState.OPEN` and `getPlayersLength() == 0` assertions after the first fulfillment. *Why:* every other fulfillment test already checks Raffle post-state; this one should not be the exception.
- [x] **HIGH — Make invariant activity observable.** A throwaway `afterInvariant` probe showed that with `--fuzz-seed 42` and `1234` some runs perform **zero successful withdrawals** (or settles). The `withdraw` handler only acts when `seed % 8` hits a claimant ([RaffleInvariantTest.t.sol:110-114](../test/invariant/RaffleInvariantTest.t.sol#L110-L114)); the handler call counters include early returns, so "8,192 calls, 0 reverts" does not show effective actions. Fix: let `withdraw` scan from the seeded index to the next actor with a claim, and add an `afterInvariant` requiring successful enters (and, once steered, successful withdrawals). Record effective-action counts in `records.md` instead of only the green result. *Why:* the four T2 invariants are only as strong as the state transitions they actually exercise; this turns "probably reached" into evidence. Do not hard-require settles in every run.
- [ ] **NOTE (no change now)** — Existing unit and invariant fulfillments run on warm storage (unit fuzz bound 1–20 players at [RaffleTest.t.sol:546](../test/unit/RaffleTest.t.sol#L546); invariant ≤ 63 entries per round). They remain valid for accounting but are **not** callback-gas evidence. If invariant `depth` is ever raised above ~74, settles would pass locally while failing live; keep depth below the D1 bound or use `vm.cool`.
- [ ] **OPT** — `vm.setEnv("SEPOLIA_PRIVATE_KEY", "0")` ([HelperConfigTest.t.sol:58](../test/unit/HelperConfigTest.t.sol#L58)) mutates process-wide state. Harmless today because no local test reads that key; fix only if a Sepolia `getDeployerKey()` test is added.

**Done when:** both HIGH items pass in the RPC-free suite and the record states effective enter/settle/withdraw counts.

### CW-B — Source edits bundled into the D1 Builder change (all change bytecode or its metadata)

Do these **in the same commit series as the D1 cap**, so the bytecode changes once and is reviewed, re-tested and simulated once. If D1 is (b) "accept", decide separately whether this bundle alone justifies a new revision. It is optional hardening, not a deployment blocker.

- [ ] **HIGH — Pin the pragma** in `src/Raffle.sol` from `^0.8.19` to `0.8.35` to match `foundry.toml`. *Why:* source verification on the explorer must reproduce the exact compiler and settings (`0.8.35`, `osaka`, optimizer off, `via_ir` false); a floating pragma lets another build setup silently produce different bytecode.
- [ ] **HIGH — Correct NatSpec/comments that are now false**: "implements … Chainlink Automation" ([Raffle.sol:12](../src/Raffle.sol#L12); no Automation interface, manual trigger), "Chainlink nodes will call" (~line 85; anyone calls it), "implicitly … subscription has LINK" (nothing checks it), the malformed `@param`, and the callback comment that cites reentrancy (~line 145). The real reason the callback never transfers ETH is **liveness**: a rejecting winner would revert the callback, and failed callbacks are never retried. *Why:* public verified source should not state a false security rationale; this is also your T5 explanation.
- [ ] **OPT** — Add `requestId` to `PickedWinner`/`WinningCredited`. Gate 5A can already correlate through the coordinator's `RandomWordsFulfilled(requestId, …, success)` in the same transaction, so write that correlation into the T4 monitoring procedure in any case; the event change only adds convenience.
- [ ] **OPT** — `checkUpkeep` `hasBalance` counts outstanding claims; with a non-zero fee it adds nothing beyond `hasPlayers`. Leave it, or change it to `balance > totalOutstandingClaims` if touching the function anyway.

### CW-C — Script/config/test change set for T4 (no Raffle bytecode change)

Do these as **one change set** with D2, because the subscription ID, HelperConfig constants, HelperConfig tests and fork test must agree.

- [ ] **MUST (if D2 = dedicated subscription) — Never create the Sepolia subscription inside `DeployRaffle`.** The live coordinator derives the ID from `blockhash(block.number - 1)`. `forge script` computes it during simulation and bakes that ID into the funding call, the Raffle constructor and `addConsumer`; the real create lands in a later block with a different ID. Result: an orphan subscription, reverted funding/registration and a Raffle with a permanently wrong immutable subscription ID. Fix: create and fund the subscription in a separate step (UI or standalone broadcast), read the real ID from the receipt/event, hard-code it in `HelperConfig`, and make `DeployRaffle` **revert if `subscriptionId == 0` on any non-local chain**, with a HelperConfig/deploy test for that guard.
- [ ] **MUST (at T4) — Re-pin the fork test.** [SepoliaForkTest.t.sol](../test/fork/SepoliaForkTest.t.sol) hard-codes block `11792671`, the subscription ID, owner, 18 LINK and the exact two-consumer list. A dedicated subscription does not exist at that block, so the test reverts; even with reuse, it only proves historical state. Re-pin to a recorded recent block, update the constants together with `HelperConfig.s.sol` and `HelperConfigTest.t.sol` (which deliberately duplicates the constants), and add a check that the subscription owner equals the D2 signer. Optionally assert `owner()` and the coordinator in the constructor-compatibility test.
- [ ] **HIGH — Add post-deploy assertions to `DeployRaffle`.** After `addConsumer`, require that the Raffle is in `getSubscription(subId)` consumers, that `raffle.owner()` is the signer, and that the coordinator and subscription ID match the config. *Why:* the T4 simulation then fails loudly instead of relying on someone reading the output. (Simulation already catches a wrong-signer `addConsumer` before broadcast, so R9 partial states are less likely than the register suggests, but not impossible.)
- [ ] **HIGH — Document the partial-broadcast recovery path in T4.** `AddConsumer.run()` works through DevOpsTools reading local `broadcast/`, but it picks the **most recent** `Raffle` on that chain and only works on the machine that broadcast. Prefer passing the explicit deployed address, or `forge script … --resume` with `broadcast/` and `cache/` intact.
- [ ] **HIGH — Preserve live deployment evidence.** `.gitignore` ignores all of `broadcast/`, so Sepolia receipts never reach Git. Copy tx hashes, blocks and addresses into `records.md` (minimum), or un-ignore only the reviewed `broadcast/DeployRaffle.s.sol/11155111/run-latest.json` after checking it for secrets.
- [ ] **OPT** — Pin CI actions by commit SHA instead of `@v6`/`@v1`. Exposure is small (`permissions: {}`, read-only contents, no secrets, Foundry pinned), so this is hygiene.

> 中文：已完成工作中没有发现"已记录结论是错误的"情况，也没有泄露密钥。但有三类值得修正：(A) 测试证据缺口——一个 fulfillment 测试在 callback 失败时仍会通过，invariant 在部分 seed 下没有真正执行 withdraw；(B) 会改变字节码的修正（pragma、错误注释）应与 D1 一起做，只改一次字节码；(C) 若使用专用订阅，绝不能在部署脚本里创建订阅（模拟时算出的 ID 与上链后的 ID 不同），并且 fork 测试、HelperConfig 及其测试必须作为一个整体更新。

## T1 — Reproducible builds and explicit test lanes

**Closed locally at `70d1941`** (fresh checkout, no RPC; fork lane 3 passed, 0 skipped). Details in [records](records.md).

### T1.1 — Hosted CI evidence (small follow-up)

- [ ] Push the local commits (main is ahead of `origin/main`; requires the user's own push) and record the GitHub Actions run ID, revision and result for the RPC-free lane. Pinning is only half the claim until CI has actually run the pinned toolchain; this closes R11 cheaply.

**Done when:** one hosted run on a recorded revision passes, or its failure is diagnosed and recorded.

## T2 — Independent accounting verification

**Closed within the aggregate-only scope on 2026-10-05; test changes committed as `ab42ee0`.** Dated verification is in [records](records.md). The per-actor stateful reference ledger is deferred (see the final section). Aggregate completeness does not prove individual allocation; individual entitlements remain covered by unit/fuzz tests.

> 中文：当前范围使用独立 pot 验证 aggregate accounting，逐 actor 的 stateful reference model 已延期。总金额正确不代表分配正确。

## T3 — Callback capacity, failure modes and privilege boundaries

**Required before T4.** The 2026-10-05 probe showed that callback failure is not hypothetical: `fulfillRandomWords` zeroes one storage slot per player (~5,600 gas each when cold) under a fixed 500000 callback limit, so some player count always fails. The open question is no longer *whether* to decide, but *which* bounded response to take.

### Gas-test methodology (applies to every T3 gas test)

A Foundry test function is one transaction. Player slots written by `enterRaffle` earlier in the same test are **warm**, and clearing them costs ~800 gas per player instead of ~5,600, which overstates capacity by more than 5× (the probe passed N = 400 this way). Call `vm.cool(address(raffle))` before fulfillment, or run the file with `--isolate`, and state which was used. Do not lower the outer test gas limit: the mock forwards gas with a plain `call` (no exact-gas check), so the EIP-150 63/64 rule would silently starve the callback, whereas the live coordinator reverts instead.

### T3.1 — Callback capacity and failed-callback state (do first; drives D1)

- [ ] Add a boundary characterization pair at the pinned build and configured `500000`: the largest succeeding N passes with full post-state (`OPEN`, players cleared, claim and liabilities credited) and N+1 fails. The probe found 73/74; record the actual measured pair. Label it as tied to the build settings, and do not commit a binary search.
- [ ] Add one success case at the intended demo size (e.g. 20 players) and record the gas margin against the limit.
- [ ] Detect callback success from the `RandomWordsFulfilled` `success` field **and** Raffle post-state; outer transaction success is insufficient.
- [ ] Assert the failed-callback state precisely: `success == false`; the request is deleted and re-fulfillment reverts `InvalidRequest`; state remains `CALCULATING`; players, pot and liabilities unchanged; `enterRaffle` reverts `RaffleNotOpen`; `performUpkeep` reverts `UpkeepNotNeeded`; earlier claims remain withdrawable. Record that the round pot (≥ 0.74 ETH at N = 74) is then locked with no contract recovery path except the owner override in T3.2.
- [ ] Mock-billing caveat: with HelperConfig mock prices one fulfillment consumes ~62.6 of the 100 local LINK, so a second fulfillment without top-up reverts with `InsufficientBalance` (the request survives). Fund explicitly in multi-round tests and do not mistake this for callback failure. Mock billing is not live billing.

### D1 — Capacity decision (required before T4)

Record one decision in the roadmap risk register (R4):

- **(a) Recommended — enforce a cap.** Add a constant player cap checked in `enterRaffle` with a recorded margin below the measured threshold (for example 50 against a measured 73), so that compiler-setting changes and live wrapper overhead cannot reach the cliff. Smallest change that turns an unbounded liveness cliff into an enforced bound. Bundle the CW-B source edits into the same change. Flow: `protocol_builder` change → `protocol_test_engineer` regression (cap succeeds under the cold model; cap+1 entry reverts) → `protocol_security_auditor` re-review → rerun T1 local acceptance commands. The new revision becomes the T4 simulation target.
- **(b) Accept and document.** Keep entry uncapped for this testnet milestone and record the griefing cost (~74 × 0.01 Sepolia ETH from one address) and the consequence (permanently stuck round, owner override as only exit). Valid for education, but the controlled demo is then not controlled.
- Not recommended: raising `callbackGasLimit` alone (moves the cliff, does not bound it) or replacing array clearing with a round-indexed player store (larger state redesign; separate scope).

### T3.2 — Privilege and request boundaries (independent of T3.1; can run in parallel)

- [ ] Request rollback: make `requestRandomWords` revert (preferred: owner `removeConsumer` on the mock, giving the real `InvalidConsumer` path; optional `vm.mockCallRevert`) and prove `performUpkeep` reverts with state, players and balance unchanged. One test is sufficient: this is atomic EVM rollback. An unfunded subscription does **not** revert requests in the mock or the live coordinator.
- [ ] `setCoordinator`: unauthorized caller reverts `OnlyOwnerOrCoordinator`; zero address reverts `ZeroAddress`; owner can change it (`CoordinatorSet` emitted); the old coordinator then fails `rawFulfillRandomWords` with `OnlyCoordinatorCanFulfill`.
- [ ] **Owner override characterization (new).** Prove the trust assumption executably: owner sets the coordinator to an address it controls, then calls `rawFulfillRandomWords` with a chosen word and selects the winner, both while `CALCULATING` and while `OPEN` with no VRF request. Assert the targeted player receives the whole pot. Inherited `setCoordinator` is not `virtual`, so this cannot be removed without changing the inheritance design; record it as an accepted owner-trust assumption for this milestone and note that it is also the only exit from a stuck round. (This test also covers the R6 "request ID and state ignored" assumption.)

### T3.3 — Scoped review

- [ ] If D1(a) changes production code, independent `protocol_security_auditor` re-review of that revision is **required**, not optional. Otherwise record a scoped review of accounting, callbacks and privileges labelled with reviewer, revision and limits. Record unresolved findings in the risk register.

**Done when:** the capacity boundary, failed-callback state, rollback and owner/coordinator powers have executable evidence under the cold-slot model; D1 is recorded; any resulting code change has passed regression testing and re-review. Request-ID storage remains a design decision, not an automatic addition.

> 中文：T3 的核心变化是：callback 失败已被探测证实（约 74 人即失败），所以在 T4 之前必须做出容量决策（推荐加入人数上限）。测试必须使用冷存储模型，否则会严重高估容量。owner 可以通过 `setCoordinator` 指定赢家，这是需要用测试证明并在文档中说明的信任假设。

## T4 — Refresh deployment readiness (historical Gates 2–3)

**Required immediately before public broadcast, against the post-D1 revision.** Preserve historical checks; refresh dynamic assumptions.

- [ ] Check current official [VRF parameters](https://docs.chain.link/vrf/v2-5/supported-networks) for chain `11155111` (coordinator/LINK code, gas lane, confirmations 3–200, max callback 2,500,000, LINK billing `nativePayment: false`). The 2026-10-05 research found HelperConfig matching the docs; optionally read `getRequestConfig()` on the deployed coordinator so the check is against chain state, not documentation alone.
- [ ] **D2 — Signer and subscription model (new).** `DeployRaffle` calls `addConsumer` with the deployer key, and only the subscription owner may do so. Record one model explicitly:
  - **Recommended:** a dedicated subscription created and owned by the dedicated testnet deployer, funded with a bounded LINK amount. This isolates the demo from historical pending requests and bounds R15 griefing.
  - Alternative: reuse the existing subscription with deployer = subscription owner = Raffle owner, accepting that one key controls the shared LINK and every round's outcome (R5), and that pending requests block `removeConsumer`/`cancelSubscription` (`PendingRequestExists`).
  - A "dedicated account" that does not own the reused subscription will deploy successfully and then fail registration (R9). Do not plan that combination.
  - Whatever is chosen, complete the CW-C change set (out-of-script subscription creation, `subscriptionId == 0` guard, fork-test re-pin, constant updates) before the final simulation.
- [ ] Recheck the chosen subscription's owner, consumers, LINK balance and pending requests; record date/block. Justify the funding buffer from the billing formula (gas price × (112,000 overhead + callback gas used) × 1.2, converted via the LINK/ETH feed); the worst case at the 500 gwei lane is ~0.37 ETH-equivalent per request. Historical 18 LINK is not a current guarantee.
- [ ] Bound LINK exposure (R15): anyone can enter once, wait `INTERVAL` (30 s on Sepolia) and call `performUpkeep`, spending one request's LINK per round at roughly zero net cost. Record the accepted budget, decide whether the 30 s interval is appropriate for the demo window, and define teardown (remove the consumer once no request is pending, or leave the subscription unfunded).
- [ ] State the demo operator, observation window and stalled-fulfillment response: stop further testing, inspect `RandomWordsFulfilled.success`, funding and Raffle state, and preserve evidence. Note that the owner override (T3.2) is technically available but is **not** a fair recovery; using it would invalidate the round as a VRF demonstration. Stopping the operator does not prevent public entries.
- [ ] Use a key that holds only testnet funds; prefer a Foundry keystore (`--account`) over a raw environment private key if the script is adapted; never record keys/RPC credentials in logs or Git.
- [ ] Run a fresh non-broadcast `DeployRaffle` simulation with final configuration and the D2 signer. Inspect CREATE + `addConsumer`, owner, constructor arguments and subscription. A previous simulated address is not guaranteed to be reused.
- [ ] Prepare for partial broadcast: deployment and registration are separate transactions. If deployment succeeds but registration fails, record that address and diagnose/register it with the explicit address (CW-C recovery path); do not blindly redeploy or enter before registration succeeds. Correlate live results through the coordinator's `RandomWordsFulfilled(requestId, …, success)` and the Raffle events in the same transaction.

**Done when:** current assumptions, D2 and the final simulation agree and the minimal incident procedure is written. Use synthetic keys in credential tests.

## Gate 4B — Optional bounded fork deployment

**Learning value:** persistent RPC state, signed transactions, receipts and actual coordinator permission checks. Gate 4A constructor tests do not exercise the script plus registration.

- [ ] Start local-only Anvil at block `11792671` (or a fresh block if D2 selects a new subscription); verify chain ID `11155111` so HelperConfig selects Sepolia. Confirm upstream block provenance using the recorded hash.
- [ ] Document signer and local-only funding/impersonation. Impersonation does not prove control of the real subscription owner's key.
- [ ] Broadcast only to the loopback fork endpoint, using the post-D1 revision. Read local receipts and verify deployed code, Raffle owner/coordinator/subscription and consumer membership after the script exits.
- [ ] Record sanitized commands, block, outcomes/postconditions and stop the fork. Simulated callbacks are not live VRF.

**Exit:** one successful rehearsal or an explicit decision to skip because local integration and simulation cover the immediate need. Avoid persistent fork infrastructure or another deployment framework. B2 does not establish live-service behavior.

## Gate 5A — Live Sepolia deployment and VRF round

**Required for C1; start after T1–T4.**

Chainlink's [CRE migration notice](https://docs.chain.link/cre/reference/cla-migration-ts) (rechecked 2026-10-05; the earlier Automation introduction URL now returns 404) states Automation v2.1 was deprecated on July 31, 2026 (testnet: June 24, 2026), and the Sepolia Automation app no longer offers registration. Legacy upkeep is not a milestone. The existing permissionless `performUpkeep` is called manually once eligible; VRF fulfillment must still come from the real service.

- [ ] Deploy the reviewed post-D1 revision with the D2 signer. Record chain, compiler/Foundry/settings, constructor arguments, address, deployment receipt and block.
- [ ] Check deployed getters/owner/coordinator, consumer registration receipt and current subscription funding.
- [ ] Attempt explorer source verification with exact settings/constructor arguments. Etherscan acceptance of `evmVersion=osaka` is not documented; if rejected, try Sourcify or record the blocker. Never rebuild with different settings and claim it verifies the deployed bytecode unless it is byte-identical. Deployment and source verification are separate facts.
- [ ] Enter a controlled round within the D1 bound, wait for eligibility, read `checkUpkeep`, then manually send `performUpkeep`; record request ID and transaction.
- [ ] Observe **real VRF fulfillment**, correlate request ID, inspect `RandomWordsFulfilled.success`, winner, credited amount, liabilities, cleared players and reopened state.
- [ ] Withdraw; verify event, zero claim and liability reduction. Include transaction fees when comparing winner wallet balances.
- [ ] Record hashes, blocks, addresses, revision and explorer links in `records.md`. Label trigger mode **manual** and upkeep ID **not applicable**.
- [ ] Execute the T4 teardown decision and record it.
- [ ] After integration-driven code/config changes, rerun affected tests and final local acceptance, refresh simulation, and record the revision actually deployed.

**Done when:** deployment → registration → entry → request → real fulfillment → claim → withdrawal is traceable. A stalled round remains unverified; do not fake the coordinator, use the owner override, or re-request randomness to manufacture completion.

## Gate 5B — Optional external scheduling

- [ ] Pursue only if automated operation remains a concrete goal after C1. Assess current service support (CRE), credentials, cost and maintenance; record the decision before adding dependencies.
- [ ] If implemented, prove a separate scheduler-triggered live round and record service/execution identifiers and transaction. CRE is a possible future study, not a prerequisite for repository completion.

## T5 — Documentation closure and learner ownership (historical Gate 6)

Start concise security notes during T3; finish after the selected validation milestone.

- [ ] Produce a compact testing guide and security note, as `TESTING.md` / `SECURITY_NOTES.md` or clearly linked existing sections. Cover commands/evidence limits (including the cold-slot gas methodology), assets/actors/privileges, the owner-override trust assumption, the D1 capacity decision, pull-payment remediation, that overpayment and forced ETH join the current pot, that past claims stay withdrawable while a round is stuck, residual risks and the T4 incident procedure. File count is not an acceptance criterion.
- [ ] Refresh README/roadmap status from one evidence ledger in `records.md`. Link detailed results instead of copying counters everywhere. Mark historical `TEST_CHECKLIST.md` as historical and reconcile inaccurate claims.
- [ ] Explain independently: callback-crediting liveness and the gas cliff, warm versus cold storage in tests, liabilities/prizes, CEI boundaries, fork versus live VRF, owner/coordinator privileges and failed-callback consequences.
- [ ] Demonstrate one important new regression fails against an intentionally faulty local implementation and passes after restoration (the D1 cap regression is a natural candidate). Keep fault injection out of final production code; no mutation-testing framework required.
- [ ] Record final reviewed revision, local results, chosen B/C evidence and unresolved limitations; review tracked changes for secrets and establish a reviewable commit boundary.

**Exit rule:** educational closure requires CW-A, T1–T3 (including D1), relevant T5 evidence and either C1 or an explicit decision to finish at local/fork validation with the external blocker recorded. No C1 claim without live receipts. Optional B2/C2 must not indefinitely delay closure.

## Deferred unless justified by a concrete requirement

- Per-actor stateful reference claims ledger: deferred by the T2 scope decision. Revisit if broader allocation verification or a reproduced history-dependent defect justifies it; aggregate invariants do not replace this evidence.
- Removing owner override / coordinator-migration power, timeout/refund, alternate withdrawal recipient, request-ID/state redesign: separate decisions with fairness and late-callback analysis. [VRF security guidance](https://docs.chain.link/vrf/v2-5/security) warns against cancellation/re-request patterns and says failed callbacks are not retried. A naive retry is not safe recovery.
- Solc upgrade from `0.8.35` to `0.8.37`: `0.8.35` lists `MemoryByteArrayElementDeleteClearsWholeWord` for the legacy pipeline; `src/` contains no triggering `delete` on memory byte arrays. Optional hardening, not a blocker; if adopted, rerun T1 and the T3.1 boundary since gas changes.
- Standalone subscription/funding scripts: test persistence/failure paths only if selected for real use (D2's dedicated subscription may make this relevant). A nonzero Sepolia subscription skips funding; successful deployment simulation does not test the LINK funding branch.
- Forced ETH and broader adversarial receiver sequences: extend after required accounting work, explicitly revising the closed-model assumptions.
- Upgrades, governance, generalized schedulers, formal-verification infrastructure, frontend, mainnet, ZK/RWA features and compliance systems: outside this milestone.

Carry accounting, privilege, external-dependency and evidence skills into future projects; unrelated features here are not needed to demonstrate them.
