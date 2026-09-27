# Project Status and Improvement Roadmap

## 1. Document control

| Field                                | Current value                                                                          |
| ------------------------------------ | -------------------------------------------------------------------------------------- |
| Repository state at evidence capture | `3d9c19e` — `docs: record Sepolia read-only preflight evidence`                        |
| Source/test evidence baseline        | `7063450` — `chore: configure linting and fix invariant time handling`                 |
| Latest local verification date       | 2026-09-22                                                                             |
| Latest Sepolia read-only check       | 2026-09-26 17:21 UTC; block `11787627`                                                 |
| Latest deployment simulation         | 2026-09-27 05:06 UTC; no broadcast                                                      |
| Current phase                        | Gates 1–3 complete; optional Gate 4 fork validation next                                |
| Next highest-value work              | Pin a Sepolia block and begin Gate 4 fork validation                                    |
| Intended scope                       | Educational and portfolio-oriented testnet project; not a production lottery           |

This document uses the following evidence states:

- **VERIFIED** — supported by current repository contents or an executed command.
- **LOCALLY TESTED** — verified in Foundry’s local EVM with mocks or local deployment.
- **FORK VALIDATED** — verified against a pinned public-chain snapshot; not live-network evidence.
- **SEPOLIA VALIDATED** — supported by real public-testnet transactions and a completed live round.
- **PROPOSED** — recommended future work.
- **UNVERIFIED** — requires new RPC, fork, deployment, or review evidence.

Passing tests do not automatically establish security, live-service availability, or production readiness.

## 2. Executive status

The project is a locally verified Foundry raffle implementation with pull-payment settlement, stateful accounting tests, and local deployment integration. Sepolia read-only preflight and a non-broadcast deployment simulation are complete. It has not yet been fork-tested, fork-deployed, deployed to Sepolia, or exercised through live VRF and Automation services.

| Area                                   | Evidence state                            | Status             | Current boundary                                                                                                                                  |
| -------------------------------------- | ----------------------------------------- | ------------------ | ------------------------------------------------------------------------------------------------------------------------------------------------- |
| Raffle state machine                   | VERIFIED / LOCALLY TESTED                 | COMPLETE           | `OPEN -> CALCULATING -> OPEN`, entry, upkeep, callback settlement, reset, and multi-round behavior are tested.                                    |
| Pull-payment remediation               | VERIFIED / LOCALLY TESTED                 | COMPLETE           | Fulfillment credits a claim instead of pushing ETH; a rejecting winner cannot block round finalization.                                           |
| Withdrawal behavior                    | VERIFIED / LOCALLY TESTED                 | COMPLETE           | Successful withdrawal, failed transfer preservation, double withdrawal, and reentrancy behavior are covered.                                      |
| Cross-round accounting                 | VERIFIED / LOCALLY TESTED                 | COMPLETE           | Reserved previous claims are excluded from the next prize.                                                                                        |
| Stateful invariant                     | VERIFIED / LOCALLY TESTED                 | COMPLETE           | `totalOutstandingClaims <= address(raffle).balance` passes across handler-generated actions.                                                      |
| HelperConfig tests                     | VERIFIED / LOCALLY TESTED                 | COMPLETE           | Four tests cover unsupported lookup, local cache reuse, stored Sepolia values, and a zero deployer key.                                           |
| Local deployment integration           | VERIFIED / LOCALLY TESTED                 | COMPLETE           | Local mocks, subscription creation/funding, Raffle deployment, ownership, and consumer registration are tested.                                   |
| Local acceptance suite                 | VERIFIED                                  | COMPLETE           | 38 tests pass; build and formatting pass in the recorded verification run.                                                                        |
| Sepolia configuration                  | LOCALLY TESTED; RPC CHECKED               | PREFLIGHT COMPLETE | Coordinator/LINK code and subscription state were checked at Sepolia block `11787627`; live VRF/Automation remain unverified.                    |
| Deployment script simulation          | VERIFIED / NON-BROADCAST SIMULATION       | COMPLETE           | At commit `3d9c19e`, Raffle creation and consumer registration simulated successfully; no public transaction or receipt exists.                  |
| Fork test/deployment                   | UNVERIFIED                                | OPTIONAL NEXT      | A pinned fork can validate snapshot compatibility and deployment orchestration, but not live VRF or Automation.                                   |
| Sepolia deployment                     | UNVERIFIED                                | PLANNED            | No public deployment receipt, address, or transaction evidence is recorded.                                                                       |
| Automation registration/live execution | UNVERIFIED                                | PLANNED            | No upkeep ID or live execution evidence is recorded.                                                                                              |
| Testing documentation                  | UNVERIFIED                                | PENDING            | `TESTING.md` has not yet been created.                                                                                                            |
| Security notes                         | UNVERIFIED                                | PENDING            | `SECURITY_NOTES.md` has not yet been created; no formal audit is claimed.                                                                         |
| Production readiness                   | NOT CLAIMED                               | OUT OF SCOPE       | This repository is not approved for real funds or production lottery operation.                                                                   |

## 3. What is complete

### Contract and test work

- Pull-payment settlement is implemented in `src/Raffle.sol`.
- Winner claims are credited during fulfillment and withdrawn separately.
- Checks-effects-interactions ordering is used in `withdrawWinnings()`.
- Reserved claims are deducted before calculating a later round’s prize.
- Unit, negative-path, fuzz, integration, and stateful invariant tests are present.
- The local invariant runs with 128 runs and depth 64, producing 8,192 handler calls with zero reverts in the recorded run.

### Deployment configuration and local integration

- `HelperConfig` resolves local Anvil and Sepolia configuration paths.
- The network-specific deployer key is passed consistently through local subscription setup, Raffle deployment, and consumer registration.
- The local integration test verifies deployer identity, subscription ownership, Raffle ownership, and consumer registration.
- The Sepolia configuration tests verify stored values only; they do not query Sepolia.
- Separate read-only RPC checks confirmed the configured coordinator/LINK code, subscription owner, 18 LINK balance, and two historical consumers. [Gate 2 evidence and reuse decision](records/records.md#step5minimum-acceptable-stage-verify-existing-consumer-of-the-subscription) record the pending-request caveat.

### Current local evidence

The recorded 2026-09-22 verification used Foundry `1.7.1` and Solc `0.8.35`:

| Command                           | Result                                                                                                                  |
| --------------------------------- | ----------------------------------------------------------------------------------------------------------------------- |
| `forge fmt --check`               | Passed                                                                                                                  |
| `forge build --sizes`             | Passed; the `block.timestamp` lint is intentionally excluded because the raffle uses timestamp-based elapsed-time logic |
| `forge test -vv`                  | 38 passed, 0 failed, 0 skipped                                                                                          |
| `forge coverage --report summary` | Passed; aggregate 81.75% lines, 80.95% statements, 89.29% branches, 75.00% functions                                    |

Coverage is diagnostic evidence, not a correctness or security certificate. Reported `Raffle.sol` execution coverage is 100% in the recorded run.

The normal build excludes the intentional `block-timestamp` lint. A forced recompilation still reports the dependency `EnumerableSet.at` identifier warning and the invariant handler's `actorsLength` naming collision; these are reviewed compiler warnings, not test failures.

## 4. Historical development stages

This table summarizes repository history; it does not claim anything that was only present on an unavailable server.

| Stage                                              | Result                                                                                    | Status                                  |
| -------------------------------------------------- | ----------------------------------------------------------------------------------------- | --------------------------------------- |
| Project foundation and CI                          | Foundry project, dependencies, and CI workflow                                            | COMPLETE                                |
| Core Raffle, VRF, and Automation-compatible upkeep | State machine, request/callback flow, and upkeep checks                                   | COMPLETE                                |
| Portable configuration                             | `HelperConfig`, local mocks, and Sepolia constants                                        | COMPLETE locally; Sepolia read-only checked |
| Subscription/deployment flow                       | Creation, funding, deployment, and consumer registration                                  | COMPLETE locally                        |
| Failure characterization                           | Rejecting-winner callback failure identified and reproduced                               | COMPLETE                                |
| Pull-payment remediation                           | Callback no longer pushes ETH to the winner                                               | COMPLETE and locally tested             |
| Withdrawal and accounting verification             | Withdrawal failure, duplicate withdrawal, reentrancy, multi-round reserves, and invariant | COMPLETE and locally tested             |
| HelperConfig safety coverage                       | Four focused configuration tests                                                          | COMPLETE and locally tested             |
| Public-network validation                          | Sepolia read-only preflight; fork and live deployment still pending                       | PREFLIGHT COMPLETE; DEPLOYMENT PENDING  |
| Final testing/security documentation               | `TESTING.md` and `SECURITY_NOTES.md`                                                      | PENDING                                 |

## 5. Immediate roadmap

### Gate 1 — Repository and evidence closure

Before using a public network:

- [x] Update all status documents to the current repository/evidence baseline.
- [x] Re-run and record `forge fmt --check`, `forge build --sizes`, `forge test -vv`, and `forge coverage --report summary`.
- [x] Review remaining compiler/lint warnings and explicitly accept or resolve them.
- [x] Record the residual security findings listed in Section 7.
- [x] Review documentation changes and establish a clean, reviewable commit boundary.

Primary checklist: [`PENDING_WORK_CHECKLIST.md`](records/PENDING_WORK_CHECKLIST.md).

### Gate 2 — Sepolia read-only preflight

- [x] Configure `SEPOLIA_RPC_URL`; do not commit `.env` or secrets.
- [x] Confirm RPC chain ID `11155111`.
- [x] Confirm deployed bytecode at the configured VRF coordinator and LINK token.
- [x] Recheck coordinator, LINK token, gas lane/key hash, billing mode, callback limit, and supported APIs against current official Chainlink documentation.
- [x] Query the configured subscription:
  - it exists;
  - owner matches the planned deployer;
  - LINK balance is sufficient because `nativePayment: false` is configured;
  - consumers and subscription status are understood.
- [x] Decide whether to reuse the hard-coded subscription or create a dedicated project subscription.

**Gate 2 evidence:** [dated Sepolia RPC results and reuse decision](records/records.md#step5minimum-acceptable-stage-verify-existing-consumer-of-the-subscription). Historical requests were pending at the recorded block; recheck the subscription before a live transaction.

Do not broadcast if coordinator, subscription ownership, funding, or LINK billing assumptions remain uncertain.

### Gate 3 — Non-broadcast deployment simulation

- [x] Configure a disposable `SEPOLIA_PRIVATE_KEY` only for signer-dependent checks.
- [x] Run `DeployRaffle` without `--broadcast`.
- [x] Inspect the sender, constructor parameters, subscription ID, coordinator, and consumer-registration call.
- [x] Confirm no simulation revert occurred; resolve any failure before a future broadcast.

**Gate 3 evidence:** [2026-09-27 simulation record](records/records.md) at commit `3d9c19e`: two successful simulated transactions (Raffle creation and `addConsumer`), no unexpected subscription creation or funding, and no public receipts. The Raffle address in the record is simulated only.

### Gate 4 — Optional Sepolia fork validation

Fork validation is recommended but not mandatory.

#### Fork test

- [ ] Pin a Sepolia fork block.
- [ ] Validate copied coordinator/LINK code and subscription state.
- [ ] Validate configuration and constructor compatibility.
- [ ] Do not call manually simulated callbacks “live VRF fulfillment.”

#### Ephemeral fork deployment

- [ ] Start an Anvil fork and confirm its chain ID. If it reports `31337`, `HelperConfig` selects local mocks instead of Sepolia configuration.
- [ ] Fund the fork deployment account with fork ETH.
- [ ] Use the subscription owner, or explicitly document owner impersonation used only inside the fork.
- [ ] Broadcast only to the local fork and record the fork block, chain ID, command, and result.

A fork cannot prove live VRF nodes, billing latency, Automation monitoring, Automation consensus, or public transaction receipts.

### Gate 5 — Live Sepolia smoke test

- [ ] Confirm the currently supported Chainlink Automation registration path; do not assume legacy Automation availability.
- [ ] Deploy with a disposable funded testnet account.
- [ ] Confirm Raffle consumer registration and subscription funding.
- [ ] Register Automation if required and record the upkeep ID.
- [ ] Enter the raffle.
- [ ] Observe upkeep execution and real VRF fulfillment.
- [ ] Confirm claim crediting and successful withdrawal.
- [ ] Record chain ID, commit, toolchain, addresses, blocks, transaction hashes, subscription/upkeep IDs, and explorer links.
- [ ] Re-run local regression tests after any code change caused by live integration.

## 6. Final documentation closure

### `TESTING.md`

- [ ] Document unit, negative-path, fuzz, integration, invariant, fork, and live smoke tests.
- [ ] Record commands, toolchain versions, test counts, coverage, invariant configuration, dates, and commits.
- [ ] Explain what each important test proves and its boundary.
- [ ] Distinguish local mock, fork, and live Chainlink evidence.
- [ ] Include a reproducible evidence table.

### `SECURITY_NOTES.md`

- [ ] Document assets, actors, trust boundaries, state transitions, and privileged roles.
- [ ] Describe the rejecting-winner defect and pull-payment remediation.
- [ ] Link security properties to regression and invariant tests.
- [ ] Record residual risks and operational assumptions.
- [ ] State clearly that the document is not a formal audit, formal verification, or production-readiness approval.

### Documentation closure criteria

- [ ] Link both documents from `README.md`.
- [ ] Update this roadmap, the README deployment record, and [`PENDING_WORK_CHECKLIST.md`](records/PENDING_WORK_CHECKLIST.md).
- [ ] Preserve no private key, `.env`, or sensitive RPC/broadcast material.

## 7. Risk and unknown register

| ID   | Risk / unknown                                                              | Status                        | Handling                                                                                                        |
| ---- | --------------------------------------------------------------------------- | ----------------------------- | --------------------------------------------------------------------------------------------------------------- |
| R-01 | A rejecting winner previously blocked settlement                            | MITIGATED LOCALLY             | Pull payment and regression tests prevent callback payout failure from blocking a round.                        |
| R-02 | Missing VRF fulfillment can leave the raffle in `CALCULATING`               | OPEN                          | No timeout, retry, cancellation, or recovery path exists; future hardening requires a separate design decision. |
| R-03 | Coordinator can be changed through inherited privileged behavior            | ACCEPTED TRUST ASSUMPTION     | Owner/coordinator custody must be documented and controlled.                                                    |
| R-04 | Callback ignores local request-ID validation and assumes valid random words | ACCEPTED WITHIN CURRENT MODEL | Current design relies on the configured coordinator and one-request-at-a-time state machine.                    |
| R-05 | A permanently rejecting winner cannot withdraw its own claim                | DESIGN LIMITATION             | Later rounds remain live, but no alternate recipient/claim-transfer path exists.                                |
| R-06 | Sepolia constants and hard-coded subscription may become stale or unusable  | OPEN; PREFLIGHT CHECKED       | Read-only checks passed at block `11787627`; recheck before broadcast. Historical requests remain pending.       |
| R-07 | Automation registration and live execution are unverified                   | OPEN                          | Confirm the current supported Sepolia path and complete a live round.                                           |
| R-08 | Toolchain/compiler settings are not intentionally pinned                    | OPEN                          | Document or pin the intended toolchain before relying on bytecode/gas comparisons.                              |
| R-09 | Historical notes or unavailable-server changes may be incomplete            | UNKNOWN                       | Treat current repository evidence as authoritative; do not infer lost changes.                                  |

## 8. Completion model

| Level                 | Completion claim                                                              | Evidence required                                                                               |
| --------------------- | ----------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------- |
| A — Locally verified  | Educational contract and local verification are complete                      | Gates 1 and 6; 38-test local evidence and accurate documentation                                |
| B — Fork validated    | Public-chain snapshot compatibility and ephemeral deployment are demonstrated | Gate 4 evidence, including pinned block and limitations                                         |
| C — Sepolia validated | Real testnet integration is demonstrated                                      | Gate 5 plus Gate 6 evidence: deployment, consumer, Automation, VRF fulfillment, and withdrawal  |
| D — Production-ready  | Not a target of this repository                                               | Would require new scope, threat model, operations, independent review, and additional hardening |

A successful fork or testnet run does not establish production readiness or security-audit status.

## 9. Evidence index

- Core contract: [`src/Raffle.sol`](src/Raffle.sol)
- Deployment orchestration: [`script/DeployRaffle.s.sol`](script/DeployRaffle.s.sol)
- Network configuration: [`script/HelperConfig.s.sol`](script/HelperConfig.s.sol)
- Interaction scripts: [`script/Interactions.s.sol`](script/Interactions.s.sol)
- Raffle tests: [`test/unit/RaffleTest.t.sol`](test/unit/RaffleTest.t.sol)
- HelperConfig tests: [`test/unit/HelperConfigTest.t.sol`](test/unit/HelperConfigTest.t.sol)
- Deployment integration test: [`test/integration/DeployRaffleTest.t.sol`](test/integration/DeployRaffleTest.t.sol)
- Stateful invariant: [`test/invariant/RaffleInvariantTest.t.sol`](test/invariant/RaffleInvariantTest.t.sol)
- Test checklist: [`TEST_CHECKLIST.md`](TEST_CHECKLIST.md)
- Pending work checklist: [`PENDING_WORK_CHECKLIST.md`](records/PENDING_WORK_CHECKLIST.md)
- Main documentation: [`README.md`](README.md)
- CI workflow: [`.github/workflows/test.yml`](.github/workflows/test.yml)

`TESTING.md` and `SECURITY_NOTES.md` are not yet present and remain final documentation tasks.

## 10. Tracking log

| Date                     | Item                                     | Previous state        | New state                    | Evidence                                                         |
| ------------------------ | ---------------------------------------- | --------------------- | ---------------------------- | ---------------------------------------------------------------- |
| 2026-08-02               | Network-specific broadcaster refactor    | In progress           | COMPLETE                     | `d10503d`; local deployment identity integration test            |
| 2026-08-16               | Repository recovery                      | Context incomplete    | COMPLETE                     | Git/history review and local verification                        |
| 2026-08-19 to 2026-09-01 | Pull-payment and accounting work         | Failure characterized | IMPLEMENTED / LOCALLY TESTED | Pull payment, withdrawal tests, multi-round tests, and invariant |
| 2026-09-16 to 2026-09-19 | HelperConfig safety coverage             | Proposed              | COMPLETE / LOCALLY TESTED    | `a2655d9`; four tests pass                                       |
| 2026-09-19               | README and verification evidence refresh | Stale documentation   | UPDATED                      | `bcbbe3b`; current local evidence recorded                       |
| 2026-09-20               | Roadmap rename and status correction     | Stale roadmap         | IN PROGRESS                  | This document; fork and Sepolia evidence remained pending        |
| 2026-09-26 UTC           | Sepolia read-only preflight              | Unverified external state | PREFLIGHT COMPLETE       | [RPC evidence at block `11787627`](records/records.md#step5minimum-acceptable-stage-verify-existing-consumer-of-the-subscription); Gate 3 pending |
| 2026-09-27 UTC           | Non-broadcast deployment simulation      | Gate 3 pending        | SIMULATION COMPLETE          | [Sender, configuration, and two-call trace](records/records.md); commit `3d9c19e`; zero receipts |

When updating this roadmap, link each status change to a commit, command output, test result, fork block, transaction, or review record. Never promote `IMPLEMENTED` directly to `SECURITY-REVIEWED`, `FORK VALIDATED`, or `DEPLOYED` without the corresponding evidence.
