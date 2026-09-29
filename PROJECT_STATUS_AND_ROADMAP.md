# Project Status and Improvement Roadmap

Updated: **2026-09-29 (Asia/Shanghai)**. Current implementation baseline: **`70d1941`**. The September 28 planning review below used `01a26a9`; T1's later local evidence is recorded separately.

## 1. Purpose and ownership

This roadmap defines the project's scope, milestones, risk decisions and learning outcomes. The authoritative next-task queue is [records/PENDING_WORK_CHECKLIST.md](records/PENDING_WORK_CHECKLIST.md); [records/records.md](records/records.md) preserves dated execution evidence. README is the public summary. Avoid maintaining the same checkbox lists in all four places.

The intended outcome is an explainable Solidity/Foundry testnet project with defensible accounting, failure-path tests, reproducible builds and traceable external integration. Production engineering principles guide the work; running an unrestricted real-money lottery is outside scope.

> 中文：整体方向合理：核心功能 → 安全/测试 → 外部集成 → 项目收尾。调整重点是补足验证深度、把外部服务限制与合约能力分开，并给可选工作设置明确停止条件。

## 2. Current position and evidence

**Assessment:** local implementation, T1 reproducibility checks, and snapshot integration are recorded. Focused accounting and callback/privilege verification remain before a live testnet round. Optional fork deployment is useful practice, but not automatically the highest-value remaining task.

| Area | Evidence and boundary | State |
| --- | --- | --- |
| Raffle and pull payment | `OPEN → CALCULATING → OPEN`; fulfillment credits claims; separate CEI withdrawal; rejecting receivers no longer block settlement through payout | Implemented / locally tested |
| Accounting | Previous claims excluded from later prizes; individual withdrawal cases tested | Locally tested; repeated-winner and delayed-round depth pending |
| Stateful invariant | `totalOutstandingClaims <= balance`; 128 × 64 actions | Locally tested; independent conservation/reconciliation still needed |
| Configuration/deployment | Four HelperConfig tests; integrated local deployment/ownership/consumer test | Locally tested; some signer cases remain |
| Build and test lanes | Foundry `v1.7.1` selected in CI; Solc `0.8.35` and EVM settings pinned; local checks reproduced at `70d1941` without Sepolia credentials | T1 locally verified; hosted CI run not evidenced |
| Sepolia preflight | September 26 snapshot at `11787627`; 18 LINK, expected owner, two historical consumers, unresolved pending requests | Recorded historical evidence; refresh before broadcast |
| Deployment simulation | September 27 at source `3d9c19e`: CREATE and `addConsumer` succeeded | Non-broadcast only |
| Fork tests | September 28, block `11792671`, 3 passed | Snapshot config/subscription/constructor checks only |
| Persistent fork deployment | No recorded script broadcast/receipt postconditions | Optional pending |
| Public deployment / live VRF | No recorded successful current-project deployment and live round | Pending |
| Automated scheduling | No recorded live trigger; legacy Automation sunset notice applies | Optional; not a closure gate |
| Security review | Tests and code inspection exist; no formal audit is claimed | Focused review/evidence notes pending |

### Verification ledger

Historical planning-review checks at `01a26a9`, 2026-09-28:

| Command | Result |
| --- | --- |
| `forge fmt --check` | Passed |
| `forge build --sizes` | Passed; existing build cache reused |
| `forge test --no-match-path 'test/fork/**'` | 38 passed, 0 failed, 0 skipped: 32 Raffle, 4 HelperConfig, 1 deployment, 1 invariant |
| Invariant within the local run | 128 runs, depth 64, 8,192 handler calls, zero reverts |
| `forge --version` | 1.7.1, commit `4072e48705af9d93e3c0f6e29e93b5e9a40caed8` |

Commands used `/home/ZKdev/.foundry/bin/forge` on this server. No fork RPC check, broadcast or coverage rerun was performed in this planning review. The recorded September 22 coverage was 81.75% aggregate lines / 89.29% branches, with 100% reported Raffle execution coverage; that is historical, not a new full-suite measurement. The September 28 fork result is also a separate recorded run, not part of the 38 local tests above.

**T1 follow-up (2026-09-29, `70d1941`):** Foundry/Solc and EVM settings are pinned, CI excludes fork tests, and the fork suite fails at setup instead of skipping when its RPC is absent. A fresh local checkout with initialized submodules and empty Sepolia values passed formatting, an uncached build, filtered local tests and coverage (38 passed, 0 failed, 0 skipped); only three OpenZeppelin future-keyword warnings remain. A configured fork run separately recorded 3 passed, 0 skipped. See [records](records/records.md). This is local/fork evidence, not a hosted CI run or live VRF fulfillment.

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

This is a risk-based planning review, not independent security certification. Callback capacity is an open validation question, not a reproduced exploit in this review.

## 4. Milestones and completion boundaries

| Milestone | Deliverable | Exit criterion | Status / task mapping |
| --- | --- | --- | --- |
| M0 — Core implementation | Raffle state machine, subscription scripts, pull-payment settlement | Core flow and payout regression tests | Complete locally |
| M1 — Verification and reproducibility | Explicit build/CI baseline, stronger accounting tests, callback and privilege characterization | Required local tests pass; material findings addressed or explicitly bounded for this testnet scope | T1 locally verified; T2–T3 pending |
| M2 — External compatibility | Pinned fork evidence; fresh configuration/owner/funding check; reviewed deployment simulation | Snapshot and current assumptions recorded separately | B1 recorded; T4 refresh pending; B2 optional |
| M3 — Live integration | One real Sepolia VRF round and withdrawal with manual upkeep trigger | Public receipts tie final source/config to successful callback and accounting | Pending: Gate 5A |
| M4 — Explainable closure | Concise testing/security evidence, residual risks and operational procedure | User can explain major design/failure paths; documentation matches final revision | Start alongside M1, finish through T5 |
| M5 — Optional automation | A supported external service triggers a live round | Separate scheduler execution evidence and operational cost justified | Conditional: Gate 5B |

M1 and M2 are not rigidly sequential: one bounded fork deployment can continue while focused tests are added. Finish M1 and fresh T4 checks before M3. A decision to end at local/fork evidence because external validation is blocked is valid educational closure when clearly labelled; it is not a live deployment claim.

### Why manual upkeep is the current default

The official [Chainlink Automation page](https://docs.chain.link/chainlink-automation/introduction), checked September 28, 2026, lists v2.1 testnet sunset on June 24, 2026 and mainnet sunset on July 31, 2026. It directs users toward CRE. The recommendation here is to validate the existing contract through a manual call to permissionless `performUpkeep`, then observe real VRF fulfillment. No scheduler integration is needed for that contract path.

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
| R2 | Outstanding claims may be solvent without correct individual allocation | T2 adds expected per-actor claims, reconciliation and conservation; current inequality remains useful but incomplete |
| R3 | Missing or failed fulfillment leaves `CALCULATING`; no recovery | T3 characterizes failure, T4 defines stop/inspect response; no new entry/duplicate upkeep while pending; recovery redesign separate |
| R4 | Uncapped player array is cleared under fixed callback gas | T3 measures chosen-build behavior; if failure is found, reproduce and decide a minimal fix; demo-size intent is not enforcement |
| R5 | Inherited `setCoordinator` callable by owner or current coordinator | T3 tests boundary; no migration during pending demo request; immutable subscription may not suit a new coordinator |
| R6 | Callback ignores request ID/state validation and assumes a nonempty word array | Trusted coordinator + one request at a time is the current model; revisit before adding concurrent requests, migration or recovery |
| R7 | Permanently rejecting winner cannot withdraw its own claim | Accepted limitation for this testnet milestone; claim remains reserved and later rounds proceed; alternate recipient conditional |
| R8 | Shared static subscription includes historical pending requests | Previous reuse decision preserved; T4 refreshes funding/owner/consumer state and budget; isolate if activity cannot be bounded |
| R9 | Deployment and consumer registration are separate transactions | T4/T5A handle partial success; do not enter until membership is confirmed |
| R10 | Fork tests previously skipped silently when RPC was absent | T1 excludes them from default CI and fails the explicit fork lane at setup without RPC; require 3 passed, 0 skipped for fork evidence |
| R11 | Toolchain/build settings were not pinned consistently | T1 pins Foundry/Solc/settings and records fresh-checkout local results; hosted CI execution is not yet evidenced |
| R12 | Legacy Automation sunset and no live scheduler evidence | Manual-triggered C1 is default; supported automation is conditional C2 |
| R13 | Current invariant tops up subscription and settles immediately | Bound the model; T2 adds delayed-round regression; don't claim billing/latency coverage |
| R14 | Notes and README lag execution evidence | T5 reconciles summaries; dated records remain evidence, not automatically current truth |

Official addresses/API reference for T4: [VRF supported networks](https://docs.chain.link/vrf/v2-5/supported-networks). This documentation review does not refresh the actual subscription state or establish node availability.

## 7. Learning outcomes and stopping rule

Each milestone should leave one useful artifact and an explanation the user can give independently:

| Work | Observable learning evidence | Transfer to later Solidity / ZK / RWA work |
| --- | --- | --- |
| T2 accounting | Explain ghost totals; reproduce a lost-claim fault; reconcile individual claims and contract balance | Asset/liability conservation and independent reference models |
| T3 callback/privileges | Trace rollback versus callback failure; test allowed/forbidden callers; explain gas bounds | Async oracle/verifier boundaries, access control and liveness reasoning |
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

Relevant implementation: [Raffle](src/Raffle.sol), [deployment](script/DeployRaffle.s.sol), [configuration](script/HelperConfig.s.sol), [interactions](script/Interactions.s.sol).

Relevant tests: [Raffle unit/fuzz](test/unit/RaffleTest.t.sol), [HelperConfig](test/unit/HelperConfigTest.t.sol), [local deployment](test/integration/DeployRaffleTest.t.sol), [invariant](test/invariant/RaffleInvariantTest.t.sol), [fork](test/fork/SepoliaForkTest.t.sol).

Execution evidence: [records](records/records.md). Next tasks: [pending checklist](records/PENDING_WORK_CHECKLIST.md). Historical test planning: [TEST_CHECKLIST.md](TEST_CHECKLIST.md). Build/test workflow: [CI](.github/workflows/test.yml).

For future updates, change milestone state here, task state in the pending checklist, and dated evidence in records. Do not relabel proposed tests, old RPC snapshots or simulations as new live verification.
