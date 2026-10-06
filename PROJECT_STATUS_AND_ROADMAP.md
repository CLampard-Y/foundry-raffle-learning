# Project Status and Improvement Roadmap

Updated: **2026-10-06 (Asia/Shanghai)**. T2's verified test changes are committed as **`ab42ee0`** (2026-10-05 17:44:22 +08:00); verification was performed before that commit. The September 28 planning review used `01a26a9`; T1's reproducibility evidence remains tied to `70d1941`. A pre-T3 planning review on 2026-10-05 at `eef8499` revised T3–T5 and the risk register (§3.1). **CW-A (test-evidence fixes) was completed on 2026-10-06 and committed as `5d9c667` (2026-10-06 18:04:06 +08:00; test files only); verification was performed on the working tree before that commit.**

## 1. Purpose and ownership

This roadmap defines the project's scope, milestones, risk decisions and learning outcomes. The authoritative next-task queue is [records/PENDING_WORK_CHECKLIST.md](records/PENDING_WORK_CHECKLIST.md); [records/records.md](records/records.md) preserves dated execution evidence. README is the public summary. Avoid maintaining the same checkbox lists in all four places.

The intended outcome is an explainable Solidity/Foundry testnet project with defensible accounting, failure-path tests, reproducible builds and traceable external integration. Production engineering principles guide the work; running an unrestricted real-money lottery is outside scope.

> 中文：整体方向合理：核心功能 → 安全/测试 → 外部集成 → 项目收尾。调整重点是补足验证深度、把外部服务限制与合约能力分开，并给可选工作设置明确停止条件。

## 2. Current position and evidence

**Assessment:** local implementation, T1 reproducibility checks, scoped T2 accounting verification, and snapshot integration are recorded. T2 is closed within the aggregate-only model; the per-actor stateful reference ledger is explicitly deferred. CW-A is closed: the false-green fulfillment test now asserts post-state, and the invariant withdraw handler is steered with an `afterInvariant` reachability guard. T3 is next and now includes a binding capacity decision (D1): an exploratory probe found the settlement callback fails from 74 players under the configured 500000 gas. Optional fork deployment remains separate.

| Area | Evidence and boundary | State |
| --- | --- | --- |
| Raffle and pull payment | `OPEN → CALCULATING → OPEN`; fulfillment credits claims; separate CEI withdrawal; rejecting receivers no longer block settlement through payout | Implemented / locally tested |
| Accounting | Reserved prizes, repeated-winner accumulation, delayed-round withdrawal, and exact credit/withdrawal event assertions | Scoped T2 complete locally |
| Stateful invariants | Solvency, actual claim-sum reconciliation, entry/withdrawal conservation, and balance = liabilities + independently modeled pot | Four invariants locally tested; zero-start/no-untracked-ETH model; per-actor reference ledger deferred. Withdraw steering plus an `afterInvariant` guard (≥ 1 successful withdrawal per run) make the withdrawal path observable (CW-A) |
| Callback capacity | Exploratory probe (2026-10-05, not committed): success at ≤ 73 players, failure at ≥ 74 under a cold-storage model; failure leaves `CALCULATING` permanently | Planning evidence only; T3.1 test and D1 decision pending |
| Owner/coordinator powers | Inherited `setCoordinator` (owner or coordinator) plus unchecked request ID lets the owner choose any round's winner | Identified by review; executable characterization pending (T3.2) |
| Configuration/deployment | Four HelperConfig tests; integrated local deployment/ownership/consumer test | Locally tested; some signer cases remain |
| Build and test lanes | Foundry `v1.7.1` selected in CI; Solc `0.8.35` and EVM settings pinned; local checks reproduced at `70d1941` without Sepolia credentials; 47 passed at `eef8499` | T1 locally verified; hosted CI run `37448187929` passed at `ba12f31` (T1.1; RPC-free lane only) |
| Sepolia preflight | September 26 snapshot at `11787627`; 18 LINK, expected owner, two historical consumers, unresolved pending requests | Recorded historical evidence; refresh before broadcast |
| Deployment simulation | September 27 at source `3d9c19e`: CREATE and `addConsumer` succeeded | Non-broadcast only |
| Fork tests | September 28, block `11792671`, 3 passed | Snapshot config/subscription/constructor checks only |
| Persistent fork deployment | No recorded script broadcast/receipt postconditions | Optional pending |
| Public deployment / live VRF | No recorded successful current-project deployment and live round | Pending |
| Automated scheduling | No recorded live trigger; legacy Automation sunset notice applies | Optional; not a closure gate |
| Security review | Tests and code inspection exist; no formal audit is claimed | Focused review/evidence notes pending |

### Verification ledger

Current RPC-free baseline: **47 passed, 0 failed, 0 skipped** (T2 closure; rerun at `eef8499` on 2026-10-05). The table below is the historical planning-review run at `01a26a9`, 2026-09-28:

| Command | Result |
| --- | --- |
| `forge fmt --check` | Passed |
| `forge build --sizes` | Passed; existing build cache reused |
| `forge test --no-match-path 'test/fork/**'` | 38 passed, 0 failed, 0 skipped: 32 Raffle, 4 HelperConfig, 1 deployment, 1 invariant |
| Invariant within the local run | 128 runs, depth 64, 8,192 handler calls, zero reverts |
| `forge --version` | 1.7.1, commit `4072e48705af9d93e3c0f6e29e93b5e9a40caed8` |

Commands used `/home/ZKdev/.foundry/bin/forge` on this server. No fork RPC check, broadcast or coverage rerun was performed in this planning review. The recorded September 22 coverage was 81.75% aggregate lines / 89.29% branches, with 100% reported Raffle execution coverage; that is historical, not a new full-suite measurement. The September 28 fork result is also a separate recorded run, not part of the 38 local tests above.

**T1 follow-up (2026-09-29, `70d1941`):** Foundry/Solc and EVM settings are pinned, CI excludes fork tests, and the fork suite fails at setup instead of skipping when its RPC is absent. A fresh local checkout with initialized submodules and empty Sepolia values passed formatting, an uncached build, filtered local tests and coverage (38 passed, 0 failed, 0 skipped); only three OpenZeppelin future-keyword warnings remain. A configured fork run separately recorded 3 passed, 0 skipped. See [records](records/records.md). This is local/fork evidence, not live VRF fulfillment; the hosted CI run was recorded later (T1.1, 2026-10-06, run `37448187929` at `ba12f31`).

**T2 closure (2026-10-05):** the scoped regressions, four aggregate invariants, and exact `WinningCredited` assertion passed the RPC-free local suite; formatting and build-size checks passed. Commands/results and the deferred per-actor model are recorded in [records](records/records.md). No new fork, coverage, broadcast, or live VRF evidence is implied.

**CW-A closure (2026-10-06):** `test_fulfillmentConsumesRequest_WhenRequestIsValid` now asserts `OPEN`, empty players, winner, claim and settlement timestamp, and was shown to fail when the callback reverts (mutation, since restored). The invariant `withdraw` handler scans from the seeded actor to the next actor with a claim, and `afterInvariant` requires at least one successful withdrawal per run. RPC-free suite: 47 passed, 0 failed, 0 skipped; `forge fmt --check` passed; the 128-run guard passed for the default seed and seeds 42, 1234 and 7. Single-run samples of effective actions are in [records](records/records.md). These are local results from the working tree later committed as `5d9c667`; they have not run on hosted CI and are not callback-gas evidence (warm storage; T3.1).

## 3. Review of the previous plan

| Finding | Why it matters | Adjustment |
| --- | --- | --- |
| Deployment dominated the remaining queue | Solvency alone can pass while individual claims are incorrectly lost | Add bounded independent accounting verification before the live milestone |
| Callback scale was not an explicit task | Fulfillment clears an uncapped player array under a fixed callback gas limit; the safe range is not established | Characterize gas-limited success and failure; change design only if evidence requires it |
| Automation was part of the only live-completion definition | Legacy service availability is an external dependency that has changed | Separate manual-triggered live VRF from optional external scheduling |
| Fork testing and fork deployment shared one evidence label | Constructor/config checks do not establish signed script execution and registration | Use B1 snapshot and optional B2 deployment |
| Documentation files were prerequisites for evidence levels | A result is evidence even before a new Markdown file exists | Separate execution evidence from documentation closure; permit compact existing sections |
| Closed preflight boxes implied durable readiness | Funding, owners, consumers, nonces and service support change | Preserve dated checks and add a fresh pre-broadcast gate |
| Roadmap duplicated the operational checklist | Divergent copies were already stale | Keep milestones here and detailed tasks in the pending checklist |
| “Missing key” was treated as tested | Actual HelperConfig test sets key to zero; missing/malformed inputs are distinct | Correct the historical test checklist; don't claim nonexistent tests |

This is a risk-based planning review, not independent security certification.

### 3.1 2026-10-05 pre-T3 review

Inputs: `protocol_test_engineer` (mock semantics, throwaway gas probe, baseline rerun), `protocol_security_auditor` (read-only risk coverage), `web3_docs_researcher` (external facts). Revision `eef8499`; no tracked code changed, no RPC/broadcast.

| Finding | Evidence | Plan change |
| --- | --- | --- |
| Callback failure is certain at some N; only the threshold was unknown | Probe: success ≤ 73, failure ≥ 74 players at 500000 gas; ~5,600 gas per cold cleared slot. Failed callbacks are billed and never retried (official VRF docs; vendored coordinator) | R4 promoted from "fix only if reproduced" to **D1 decision before T4**; recommended player cap with margin |
| Same-transaction Foundry tests overstate capacity by >5× | Warm slots: probe passed N = 400 in one transaction | Mandatory cold-slot methodology (`vm.cool` / `--isolate`) for T3 gas tests |
| The original sample points (1, 20, 100) could not locate the boundary | 100 fails cold, passes warm | Boundary pair N/N+1 plus one demo-size margin case |
| Owner can choose the winner, even while `OPEN` with no request | `setCoordinator` is owner-callable and not `virtual`; `fulfillRandomWords` ignores request ID and state | R5 impact stated; executable owner-override test; accepted trust assumption for this milestone |
| Anyone can spend the subscription's LINK each interval at ~zero net cost | Permissionless `performUpkeep`, 30 s Sepolia interval, LINK billed per fulfillment | New R15; bounded/dedicated subscription and teardown in T4 |
| "Dedicated account" conflicts with reusing a subscription it does not own | `DeployRaffle` calls `addConsumer` with the deployer key | New R16; explicit D2 signer/subscription decision in T4 |
| Pending requests lock `removeConsumer`/`cancelSubscription` on the shared subscription | Vendored `VRFCoordinatorV2_5` `PendingRequestExists` | Strengthens the case for a dedicated demo subscription |
| ~~Hosted CI never ran the T2 commits~~ (closed 2026-10-06) | Run `37448187929` at `ba12f31` concluded `success`, 47 passed | None; see [records](records/records.md) |
| Automation citation is a dead link; Etherscan `osaka` acceptance undocumented; Solc `0.8.35` has a legacy-pipeline bug | Research 2026-10-05 | Citation replaced; Sourcify fallback in Gate 5A; optional `0.8.37` in Deferred (no triggering construct in `src/`) |
| Checklist baseline still claimed 38 tests / 1 invariant / missing credit-event assertion | README and records already show 47 / 4 / asserted | Baseline table corrected |
| Completed-work review (2026-10-06): no recorded result false, no secret leaked; one false-green fulfillment test; invariant runs can perform zero withdrawals; in-script Sepolia subscription creation would yield a wrong ID; fork test and constants pinned to historical subscription state; false NatSpec rationale; floating pragma | Test-engineer seed probes (42, 1234); auditor trace of `SubscriptionAPI` ID derivation vs `forge script` simulation | Checklist **CW**: CW-A test fixes now; CW-B source edits bundled with D1; CW-C script/config/fork change set with D2 |

Confirmed unchanged: T3 → T4 → 5A ordering, manual-trigger C1, the 500000 limit being within the 2,500,000 Sepolia maximum, HelperConfig Sepolia values, and the deferral of timeout/refund/request-ID redesign.

> 中文：本轮评审的核心结论：(1) callback 失败不再是"可能"，约 74 人即失败，T4 前必须做容量决策；(2) Foundry 同一交易内测试会因 warm slot 严重高估容量；(3) owner 可指定赢家，需要测试证明并作为信任假设记录；(4) 无许可 `performUpkeep` 可消耗共享订阅 LINK，推荐专用订阅。

## 4. Milestones and completion boundaries

| Milestone | Deliverable | Exit criterion | Status / task mapping |
| --- | --- | --- | --- |
| M0 — Core implementation | Raffle state machine, subscription scripts, pull-payment settlement | Core flow and payout regression tests | Complete locally |
| M1 — Verification and reproducibility | Explicit build/CI baseline, stronger accounting tests, callback and privilege characterization, capacity decision | Required local tests pass; D1 recorded and any fix regression-tested and re-reviewed; material findings addressed or explicitly bounded | T1 locally verified, hosted run recorded (T1.1); scoped T2 closed; CW-A closed locally (`5d9c667`); T3 + D1 pending |
| M2 — External compatibility | Pinned fork evidence; signer/subscription decision; fresh configuration/owner/funding check; reviewed deployment simulation of the post-D1 revision | Snapshot and current assumptions recorded separately | B1 recorded; T4 (+D2) pending; B2 optional |
| M3 — Live integration | One real Sepolia VRF round and withdrawal with manual upkeep trigger | Public receipts tie final source/config to successful callback and accounting | Pending: Gate 5A |
| M4 — Explainable closure | Concise testing/security evidence, residual risks and operational procedure | User can explain major design/failure paths; documentation matches final revision | Start alongside M1, finish through T5 |
| M5 — Optional automation | A supported external service triggers a live round | Separate scheduler execution evidence and operational cost justified | Conditional: Gate 5B |

M1 and M2 are not rigidly sequential, but D1 must precede T4 and any fork deployment intended as rehearsal, because a cap changes the deployed bytecode. Finish M1 and fresh T4 checks before M3. A decision to end at local/fork evidence because external validation is blocked is valid educational closure when clearly labelled; it is not a live deployment claim.

### Why manual upkeep is the current default

Chainlink's [CRE migration notice](https://docs.chain.link/cre/reference/cla-migration-ts), rechecked 2026-10-05, states Automation v2.1 was deprecated on July 31, 2026 (testnet: June 24, 2026) and directs users to CRE; the earlier Automation introduction URL now returns 404, and the Sepolia Automation app no longer offers registration. The recommendation here is to validate the existing contract through a manual call to permissionless `performUpkeep`, then observe real VRF fulfillment. No scheduler integration is needed for that contract path.

CRE adoption would introduce a separate external workflow and maintenance commitment. Evaluate it only after M3 if automation remains a meaningful goal. “Automation-compatible functions” and “live automated operation” must remain separate claims.

### Evidence vocabulary

- **IMPLEMENTED:** code exists; no implied execution evidence.
- **A — LOCALLY TESTED:** named local checks passed at an identified revision, within their stated model.
- **B1 — FORK SNAPSHOT:** pinned external state assertions passed without skips.
- **B2 — FORK DEPLOYMENT:** local fork transactions and script postconditions established.
- **C1 — LIVE VRF ROUND:** deployment through real fulfillment/withdrawal has public receipts; trigger mode recorded.
- **C2 — AUTOMATED EXECUTION:** separate evidence of an external scheduler triggering the round.
- **REVIEWED:** specify reviewer, revision, scope, findings and limitations; not equivalent to audited or secure.
- **PROPOSED / UNVERIFIED:** planned work or a claim lacking the required evidence.

These labels are not a cumulative safety rating. Coverage and test counts measure parts of verification, not security completeness.

## 5. Required standard, conditional work and non-goals

**Required for the planned controlled live demo:** correct claims/accounting, guarded round transitions, callback evidence at the supported scale, tested trust boundary, reproducible artifacts, current signer/subscription assumptions, partial-deployment handling, one traceable real VRF round, and a short response procedure for stalls.

**Before any broader public operation:** revisit uncapped entry/callback capacity, independent security review, privileged-key policy, monitoring and loss/recovery assumptions. Documenting a risk is not the same as enforcing an onchain limit. Testnet assets limit economic exposure; they do not eliminate failure modes.

**Conditional rather than automatic work:** standalone funding/interaction script support; absent/malformed key and other extra configuration tests when that workflow is changed; forced ETH and cross-function malicious receiver scenarios; request-ID tracking; alternate withdrawal recipients; supported external scheduling. Select each against a concrete risk or use case, not coverage percentage.

**Separate design scope:** timeout/refund/retry behavior. Current [VRF security guidance](https://docs.chain.link/vrf/v2-5/security) cautions against re-request/cancellation and explains that failed callbacks are not retried. Any recovery design must address fairness, late callbacks and claim liabilities; adding a generic retry is not an acceptable shortcut.

**Outside this repository milestone:** proxy upgrades, governance frameworks, production lottery operations, generalized deployment infrastructure, ZK circuits, RWA tokenization, custom cryptography and compliance architecture. These require separate requirements and threat models.

## 6. Risk and decision register

| ID | Evidence / risk | Current handling and reassessment trigger |
| --- | --- | --- |
| R1 | Rejecting winner previously blocked push-payment settlement | Mitigated locally by pull payments and regression tests; preserve coverage |
| R2 | Aggregate totals can be correct without correct individual allocation | T2 verifies aggregate reconciliation/conservation and retains individual unit/fuzz regressions; per-actor stateful reference ledger deferred on 2026-10-05, not claimed as verified |
| R3 | Missing or failed fulfillment leaves `CALCULATING` permanently; the round pot is locked; failed callbacks are billed and never retried | T3.1 asserts the exact failed state; T4 defines stop/inspect response; the owner override (R5) is the only exit and is not a fair recovery; recovery redesign separate |
| R4 | Uncapped player array is cleared under fixed callback gas; probe: failure at ≥ 74 players (cold model, 500000, pinned build); griefable for ~0.74 Sepolia ETH | **D1 before T4:** recommended enforced cap with margin (Builder → regression → re-review), or recorded acceptance; same-transaction tests are invalid evidence |
| R5 | Inherited `setCoordinator` callable by owner or current coordinator; with R6 this lets the owner choose any round's winner and take the pot, even while `OPEN` with no request | T3.2 tests the boundary and the override sequence; accepted owner-trust assumption for this testnet milestone (not `virtual`; removal is a redesign); state it in T5; never use it to complete the live demo |
| R6 | Callback ignores request ID/state validation and assumes a nonempty word array | Trusted coordinator + one request at a time is the current model; exercised by the T3.2 override test; validation alone would not stop R5 (the request ID is public); revisit before concurrent requests, migration or recovery |
| R7 | Permanently rejecting winner cannot withdraw its own claim | Accepted limitation for this testnet milestone; claim remains reserved and later rounds proceed; alternate recipient conditional |
| R8 | Shared static subscription includes historical pending requests, which also block `removeConsumer`/`cancelSubscription` | T4 D2 recommends a dedicated bounded subscription; reuse remains allowed only with deployer = subscription owner and recorded budget |
| R9 | Deployment and consumer registration are separate transactions | Simulation catches a wrong-signer `addConsumer` before broadcast; CW-C adds post-deploy assertions and an explicit-address recovery path; do not enter until membership is confirmed |
| R10 | Fork tests previously skipped silently when RPC was absent | T1 excludes them from default CI and fails the explicit fork lane at setup without RPC; require 3 passed, 0 skipped for fork evidence |
| R11 | Toolchain/build settings were not pinned consistently | T1 pins Foundry/Solc/settings and records fresh-checkout local results; T1.1 recorded one hosted run (`37448187929` at `ba12f31`, 2026-10-06); Solc `0.8.37` optional (legacy-pipeline bug in `0.8.35` not triggered in `src/`) |
| R12 | Legacy Automation sunset and no live scheduler evidence | Manual-triggered C1 is default; supported automation is conditional C2 |
| R13 | Handler tops up the mock subscription and settles immediately | Closed model documented; T2 includes a delayed-round unit regression; don't claim stateful latency or live billing coverage |
| R14 | Notes and README lag execution evidence | T5 reconciles summaries; dated records remain evidence, not automatically current truth |
| R15 | Permissionless `performUpkeep` lets anyone spend one request's LINK per interval (30 s on Sepolia) at ~zero net cost; exhaustion stalls every consumer on that subscription | T4 bounds budget via dedicated/limited subscription, reviews the interval and defines teardown; no code change required for the testnet demo |
| R16 | Consumer registration requires the subscription owner; the deployer key also becomes Raffle owner | T4 D2 records deployer/owner/subscription alignment; testnet-only key, keystore preferred |

Official addresses/API reference for T4: [VRF supported networks](https://docs.chain.link/vrf/v2-5/supported-networks). This documentation review does not refresh the actual subscription state or establish node availability.

## 7. Learning outcomes and stopping rule

Each milestone should leave one useful artifact and an explanation the user can give independently:

| Work | Observable learning evidence | Transfer to later Solidity / ZK / RWA work |
| --- | --- | --- |
| T2 accounting | Explain the ghost pot, aggregate conservation, exact credit events, and the deferred per-actor verification boundary | Asset/liability reconciliation and scoped model-based testing |
| T3 callback/privileges | Trace rollback versus callback failure; explain why warm-slot tests mislead; justify D1; show how an authorized caller can still break fairness | Async oracle/verifier boundaries, access control and liveness reasoning |
| M2/M3 integration | Explain snapshot versus live behavior; inspect receipts and partial deployment | Reproducible deployments and separating onchain evidence from external assumptions |
| M4 closure | Explain trust model, residual risks and one incident response without reading AI prose | Reviewable design decisions and technical communication |

These are transferable foundations, not evidence that a raffle validates reserves, legal ownership or ZK soundness. Later projects need their own invariants and offchain/proof trust models.

Use focused, reviewable changes: write expected behavior and a counterexample, implement a minimal test/change, run relevant checks, and record the insight. Reserve independent challenge for meaningful contract changes; avoid turning every documentation edit into a full audit cycle.

Finish this repository when required local hardening and the chosen integration milestone have evidence, the user can explain the design, and residual limits are explicit. Do not indefinitely expand tests or optional services. Choose a separate next project only then; no fixed weekly-hours or career deadline is assumed.

## 8. Development history and evidence links

| Period / commit | Established progress |
| --- | --- |
| July–August; `d10503d` | Core flow and consistent network-specific deployment identity |
| `c19b75f` through `4c7c872` | Pull-payment remediation, withdrawal/reentrancy and multi-round reserve regressions |
| `c640ed7`, `d4edba4` | Handler followed by executable solvency invariant |
| `258b41b`, `f568559` | Separated fulfillment/withdrawal/request-consumption test responsibilities |
| `a2655d9`, `7063450` | HelperConfig tests and lint/invariant timestamp handling |
| `3d9c19e`, `49490b4` | Recorded Sepolia preflight and non-broadcast simulation |
| `01a26a9` | Three pinned Sepolia fork tests and recorded results |
| 2026-09-28 planning review | Current local tests rerun; checklist/roadmap separated; accounting, callback, reproducibility and automation scope revised |
| `70d1941`, 2026-09-29 | T1 toolchain/test-lane changes; fresh-checkout local verification recorded separately from fork evidence |
| `ab42ee0`, 2026-10-05 | Scoped T2 closed locally; aggregate pot model and credit-event assertion verified before commit; per-actor stateful ledger deferred |
| `eef8499` + planning review, 2026-10-05 | Pre-T3 review: capacity probe (73/74), owner-override, LINK-drain and signer findings; T3/T4 restructured around D1/D2 |
| `5d9c667`, 2026-10-06 | CW-A: fulfillment test asserts post-state (shown to fail on a reverting callback); invariant `withdraw` steered with an `afterInvariant` withdrawal guard; test-only |

Relevant implementation: [Raffle](src/Raffle.sol), [deployment](script/DeployRaffle.s.sol), [configuration](script/HelperConfig.s.sol), [interactions](script/Interactions.s.sol).

Relevant tests: [Raffle unit/fuzz](test/unit/RaffleTest.t.sol), [HelperConfig](test/unit/HelperConfigTest.t.sol), [local deployment](test/integration/DeployRaffleTest.t.sol), [invariant](test/invariant/RaffleInvariantTest.t.sol), [fork](test/fork/SepoliaForkTest.t.sol).

Execution evidence: [records](records/records.md). Next tasks: [pending checklist](records/PENDING_WORK_CHECKLIST.md). Historical test planning: [TEST_CHECKLIST.md](TEST_CHECKLIST.md). Build/test workflow: [CI](.github/workflows/test.yml).

For future updates, change milestone state here, task state in the pending checklist, and dated evidence in records. Do not relabel proposed tests, old RPC snapshots or simulations as new live verification.
