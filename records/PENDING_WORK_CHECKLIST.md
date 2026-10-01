# Pending Work Checklist

Updated: **2026-09-29 (Asia/Shanghai)**. T1 implementation baseline: `70d1941`; later tasks remain as specified below.

This is the authoritative queue of **remaining work**. The [roadmap](../PROJECT_STATUS_AND_ROADMAP.md) owns scope, milestones and risk decisions; [records](records.md) owns dated commands, results and learning notes. Historical Gate numbers are retained for traceability, not as instructions to repeat completed work.

> 中文：本清单管理接下来做什么、为何做、怎样验收；路线图管理整体阶段；records 保存证据。新增任务均为待执行，不表示本次文档评审已经实现。

## Completed baseline

| Evidence                  | Established result                                                                                                          | Boundary                                                                                  |
| ------------------------- | --------------------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------- |
| Local suite               | 38 passed on 2026-09-28: 32 Raffle unit/fuzz, 4 HelperConfig, 1 local integration, 1 invariant; formatting and build passed | RPC/fork tests excluded from this run                                                     |
| Invariant                 | 128 runs, depth 64, 8,192 calls, zero reverts                                                                               | Only `outstandingClaims <= balance`; handler settles immediately and tops up mock funding |
| Gate 2 preflight          | Recorded 2026-09-26, block `11787627`: code presence, owner, 18 LINK, two historical consumers, pending requests            | Historical snapshot, not current funding assurance                                        |
| Gate 3 simulation         | Recorded 2026-09-27: deployment + `addConsumer` succeeded without broadcast                                                 | Simulated address is not a public deployment                                              |
| Gate 4A fork tests        | Recorded 2026-09-28: 3 passed at block `11792671`                                                                           | Copied config/subscription and constructor checks; no script broadcast or VRF service     |
| Gate 4B / live deployment | No recorded completion                                                                                                      | Pending/optional as specified below                                                       |

Do not reopen completed pull-payment, withdrawal-event or HelperConfig zero-key tests. `WinningCredited` still lacks an exact event assertion; absent/malformed credentials differ from a zero key.

## Order and evidence labels

Recommended order: **T1 → T2 → T3 → T4 → Gate 5A → T5 closure**. Gate 4B can run alongside T2–T4 as a bounded learning exercise, or be explicitly skipped. Begin T5 security notes during T2; Gate 5B is optional.

| Label                    | Meaning                                                                    | Current evidence                                            |
| ------------------------ | -------------------------------------------------------------------------- | ----------------------------------------------------------- |
| A — Local                | Local behavior/build checked at an identified revision                     | Established within existing test scope; T1–T3 strengthen it |
| B1 — Fork snapshot       | Assertions against a pinned public-chain snapshot                          | Recorded Gate 4A completion                                 |
| B2 — Fork deployment     | Script transactions and postconditions on a persistent local fork          | Not established; optional Gate 4B                           |
| C1 — Live VRF round      | Public deployment, consumer setup, real fulfillment, credit and withdrawal | Not established; required for a live-integration claim      |
| C2 — Automated execution | Supported external scheduler actually triggers a round                     | Not established; optional extension to C1                   |

These are evidence labels, not safety grades. Documentation closure is separate. C1 does not require B2 or C2. A skipped fork test does not establish B1.

## T1 — Reproducible builds and explicit test lanes

**Required before the next public deployment.** Small configuration/CI changes; no new infrastructure.

- [x] Select/pin intended Foundry and Solc versions and record optimizer/EVM settings; use the same baseline locally and in CI. Observed Foundry is `1.7.1`; historical compiler evidence is `0.8.35`. Verify chosen settings rather than upgrading dependencies opportunistically.
- [x] Make default CI/local acceptance explicitly independent of RPC. Keep fork tests opt-in; pull requests should not require secrets.
- [x] Make the explicit fork command require a configured RPC and report **3 passed, 0 skipped** for the present suite. Missing `SEPOLIA_RPC_URL` currently causes revert; document/enforce a fail-fast prerequisite in the dedicated workflow.
- [x] After configuration changes, run and record:

  ```bash
  forge fmt --check
  forge build --sizes
  forge test --no-match-path 'test/fork/**'
  forge coverage --no-match-path 'test/fork/**' --report summary
  ```

  Fork validation remains separate:

  ```bash
  forge test --match-path test/fork/SepoliaForkTest.t.sol -vv
  ```

- [x] Record revision, settings, results, skip counts and reviewed warnings in `records.md`. Coverage is a dated diagnostic, not a percentage target.

**Done when:** a fresh checkout with initialized submodules reproduces local checks without RPC, and fork execution has explicit prerequisites/results. Explain why skipping differs from passing.

## T2 — Independent accounting verification

**Required before the planned live smoke test.** Use small test commits and preserve current cases.

- [x] Add a regression where the **same winner wins twice before withdrawing**: claims accumulate; one withdrawal pays the sum and reduces liabilities by that sum.
- [x] Add delayed settlement: retain an earlier claim, request the next round, withdraw the old claim while `CALCULATING`, then fulfill. Assert balance and old liabilities fall together and the new prize is unchanged. Entries and duplicate upkeep remain blocked while pending.
- [x] Extend the handler with bounded, deduplicated actors and independent accounting. Assert `sum(tracked individual claims) == totalOutstandingClaims` and `totalEntered == raffle.balance + totalSuccessfullyWithdrawn` in a closed model starting at zero and excluding forced ETH. Retain solvency.
- [ ] Track expected per-actor claims and the current round pot independently from successful entries, the chosen winner and successful withdrawals; compare expected claims to contract getters. Sum/conservation checks alone can miss simultaneous under-reporting of both claims and the aggregate. Exercise repeated actors/winners and record successful operation counts so early returns do not create misleading activity evidence.
- [ ] Add exact `WinningCredited` emitter/winner/amount assertions. Reuse the existing `WithdrawnWinnings` assertion.

**Done when:** focused regressions and stronger invariants pass with explicit model assumptions and successful enter/settle/withdraw activity. Explain a fault that the old inequality misses. Split request/fulfill handler actions later only if the delayed unit regression leaves a concrete gap.

> 中文：余额足够不等于账本正确。债权被少记时，旧 invariant 仍可能通过；独立金额记录和债权总和检查可以识别这类问题。

## T3 — Callback limits and privilege boundaries

**Required characterization/review before live deployment; fixes only where evidence warrants them.**

- [ ] Exercise fulfillment through the gas-limited coordinator mock at increasing player counts (e.g. 1, 20, 100, then expand if useful), with chosen build settings and configured `500000` callback gas. Assert callback success **and Raffle post-state**; outer transaction success is insufficient.
- [ ] Investigate the cost of clearing `s_players` during fulfillment. Record tested range/margin, not a universal capacity claim. If failure is reproduced, retain a regression and decide the smallest justified change before deployment. Intended small demo size is not an enforced cap: entry is permissionless and uncapped.
- [ ] Characterize request rejection rollback separately from callback failure: force a coordinator request revert and prove state/players/funds unchanged; simulate a failed callback and document the resulting state. Do not equate mock funding behavior with live billing.
- [ ] Test the application-relevant inherited `setCoordinator` boundary: unauthorized and zero-address changes rejected; permitted caller can change coordinator; old coordinator loses callback access. Document both owner and current coordinator authority. Do not migrate during a pending demo request; subscription ID is immutable.
- [ ] Record a scoped review of accounting, external calls, callbacks and privileges against the selected revision. Seek independent challenge for material implementation changes; otherwise label self-review honestly. Record unresolved findings.

**Done when:** callback limits/failure modes and privileged behavior have executable evidence, with no unexplained accounting failure or failure within the supported demo range. Request-ID storage is a design decision, not an automatic feature addition: the current model permits one pending request and trusts its coordinator.

## T4 — Refresh deployment readiness (historical Gates 2–3)

**Required immediately before public broadcast.** Preserve historical checks; refresh dynamic assumptions.

- [ ] Check current official [VRF parameters](https://docs.chain.link/vrf/v2-5/supported-networks), chain `11155111`, coordinator/LINK code, gas lane, confirmations, callback limit and LINK billing (`nativePayment: false`).
- [ ] Recheck subscription owner against signer, consumer list, LINK balance and pending requests. Record date/block and a justified funding buffer; historical 18 LINK is not a current sufficiency guarantee.
- [ ] Reconfirm the recorded subscription-reuse decision. Historical consumers and unresolved requests share funds/capacity. Reuse is acceptable for this controlled testnet exercise if understood; use a dedicated subscription if ownership/activity or budget cannot be bounded. Do not remove consumers or cancel merely to clear a checklist.
- [ ] State the demo operator, testnet spending limit, observation window and stalled-fulfillment response: stop further testing, inspect events/funding/callback success, preserve evidence. There is no pause or onchain recovery; stopping the operator does not prevent public entries.
- [ ] Run a fresh non-broadcast `DeployRaffle` simulation with final configuration and testnet signer. Inspect CREATE + `addConsumer`, owner, constructor arguments and subscription. A previous simulated address is not guaranteed to be reused.
- [ ] Prepare for partial broadcast: deployment and registration are separate transactions. If deployment succeeds but registration fails, record that address and diagnose/register it; do not blindly redeploy or enter before registration succeeds.

**Done when:** current assumptions and final simulation agree and the minimal incident procedure is written. Use synthetic keys in credential tests. Keep private keys/RPC credentials out of recorded logs and Git.

## Gate 4B — Optional bounded fork deployment

**Learning value:** persistent RPC state, signed transactions, receipts and actual coordinator permission checks. Gate 4A constructor tests do not exercise the script plus registration.

- [ ] Start local-only Anvil at block `11792671`; verify chain ID `11155111` so HelperConfig selects Sepolia. Confirm upstream block provenance using the recorded hash.
- [ ] Document signer and local-only funding/impersonation. Impersonation does not prove control of the real subscription owner's key.
- [ ] Broadcast only to the loopback fork endpoint. Read local receipts and verify deployed code, Raffle owner/coordinator/subscription and consumer membership after the script exits.
- [ ] Record sanitized commands, block, outcomes/postconditions and stop the fork. Simulated callbacks are not live VRF.

**Exit:** one successful rehearsal or an explicit decision to skip because local integration and simulation cover the immediate need. Avoid persistent fork infrastructure or another deployment framework. B2 does not establish live-service behavior.

## Gate 5A — Live Sepolia deployment and VRF round

**Required for C1; start after T1–T4.**

Chainlink's [Automation notice](https://docs.chain.link/chainlink-automation/introduction), checked 2026-09-28, lists v2.1 testnet sunset on June 24, 2026 and mainnet sunset on July 31, 2026. Legacy upkeep registration is therefore not a required milestone. The existing permissionless `performUpkeep` can be called manually once eligible; VRF fulfillment must still come from the real service.

- [ ] Deploy the reviewed revision with a dedicated testnet account. Record chain, compiler/Foundry/settings, constructor arguments, address, deployment receipt and block.
- [ ] Check deployed getters/owner/coordinator, consumer registration receipt and current subscription funding.
- [ ] Attempt explorer source verification with exact settings/constructor arguments; record its link or concrete blocker. Deployment and source verification are separate facts.
- [ ] Enter a controlled round, wait for eligibility, read `checkUpkeep`, then manually send `performUpkeep`; record request ID and transaction.
- [ ] Observe **real VRF fulfillment**, correlate request ID, inspect callback success, winner, credited amount, liabilities, cleared players and reopened state.
- [ ] Withdraw; verify event, zero claim and liability reduction. Include transaction fees when comparing winner wallet balances.
- [ ] Record hashes, blocks, addresses, revision and explorer links in `records.md`. Label trigger mode **manual** and upkeep ID **not applicable**.
- [ ] After integration-driven code/config changes, rerun affected tests and final local acceptance, refresh simulation, and record the revision actually deployed.

**Done when:** deployment → registration → entry → request → real fulfillment → claim → withdrawal is traceable. A stalled round remains unverified; do not fake the coordinator or re-request randomness to manufacture completion.

## Gate 5B — Optional external scheduling

- [ ] Pursue only if automated operation remains a concrete goal after C1. Assess current service support, credentials, cost and maintenance; record the decision before adding dependencies.
- [ ] If implemented, prove a separate scheduler-triggered live round and record service/execution identifiers and transaction. CRE is a possible future study, not a prerequisite for repository completion.

## T5 — Documentation closure and learner ownership (historical Gate 6)

Start concise security notes during T2–T3; finish after the selected validation milestone.

- [ ] Produce a compact testing guide and security note, as `TESTING.md` / `SECURITY_NOTES.md` or clearly linked existing sections. Cover commands/evidence limits, assets/actors/privileges, pull-payment remediation, residual risks and the T4 incident procedure. File count is not an acceptance criterion.
- [ ] Refresh README/roadmap status from one evidence ledger in `records.md`. Link detailed results instead of copying counters everywhere. Mark historical `TEST_CHECKLIST.md` as historical and reconcile inaccurate claims.
- [ ] Explain independently: callback-crediting liveness, liabilities/prizes, CEI boundaries, fork versus live VRF, owner/coordinator privileges and failed-callback consequences.
- [ ] Demonstrate one important new regression fails against an intentionally faulty local implementation and passes after restoration. Keep fault injection out of final production code; no mutation-testing framework required.
- [ ] Record final reviewed revision, local results, chosen B/C evidence and unresolved limitations; review tracked changes for secrets and establish a reviewable commit boundary.

**Exit rule:** educational closure requires T1–T3, relevant T5 evidence and either C1 or an explicit decision to finish at local/fork validation with the external blocker recorded. No C1 claim without live receipts. Optional B2/C2 must not indefinitely delay closure.

## Deferred unless justified by a concrete requirement

- Timeout/refund, alternate withdrawal recipient, request-ID/state redesign: separate decisions with fairness and late-callback analysis. [VRF security guidance](https://docs.chain.link/vrf/v2-5/security) warns against cancellation/re-request patterns and says failed callbacks are not retried. A naive retry is not safe recovery.
- Standalone subscription/funding scripts: test persistence/failure paths only if selected for real use. A nonzero Sepolia subscription skips funding; successful deployment simulation does not test the LINK funding branch.
- Forced ETH and broader adversarial receiver sequences: extend after required accounting work, explicitly revising the closed-model assumptions.
- Upgrades, governance, generalized schedulers, formal-verification infrastructure, frontend, mainnet, ZK/RWA features and compliance systems: outside this milestone.

Carry accounting, privilege, external-dependency and evidence skills into future projects; unrelated features here are not needed to demonstrate them.
