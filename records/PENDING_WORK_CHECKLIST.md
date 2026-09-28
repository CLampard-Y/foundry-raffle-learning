# Pending Work Checklist

> **Purpose:** ordered work remaining before and during Sepolia validation. This is a gate-based checklist, not a claim that the project is production-ready.
>
> 中文：这是部署前后的待完成清单。每项只有在对应证据存在后才能标记完成。

## Current baseline

- [x] Pull-payment remediation implemented and locally tested.
- [x] Rejecting winners cannot block round finalization.
- [x] Withdrawal success, failure preservation, duplicate withdrawal, and reentrancy behavior tested.
- [x] Cross-round reserved-claim accounting tested.
- [x] Stateful invariant tested: `totalOutstandingClaims <= address(raffle).balance`.
- [x] Local deployment, subscription setup, funding, and consumer registration tested.
- [x] Local acceptance run passes: 38 tests, build, and formatting.
- [ ] Sepolia deployment and a live VRF/Automation round are **not yet verified**.

## Evidence levels

Use these labels consistently when describing completion:

| Level                      | Meaning                                                                                                       | What it does **not** prove                                                           |
| -------------------------- | ------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------ |
| A — Local project verified | Local unit/fuzz/invariant/integration tests, build, formatting, and documentation pass                        | Real RPC, VRF nodes, Automation nodes, or public-chain deployment                    |
| B — Fork validated         | A pinned Sepolia state snapshot supports read-only checks and/or an ephemeral fork deployment                 | Live VRF fulfillment, billing, Automation scheduling, or public transaction receipts |
| C — Sepolia validated      | A real deployment completes consumer setup and one live round, including withdrawal                           | Production readiness, audit status, or mainnet safety                                |
| D — Production-ready       | **Not a target of this repository**; would require a new threat model, operations, review, and scope decision | —                                                                                    |

Gate 1 plus the relevant read-only parts of Gate 2 are sufficient for a fork **test**. Gate 3 and the account/owner prerequisites in Gate 4B are required for an ephemeral fork **deployment**. Gate 4 is optional but recommended before a first public-testnet deployment. A fork is not a substitute for Gate 5.

## Gate 1 — Repository and evidence cleanup

Complete this gate before using a public network.

- [x] Update [`PROJECT_STATUS_AND_ROADMAP.md`](../PROJECT_STATUS_AND_ROADMAP.md) to match the current repository state.
  - Replace the stale `c640ed7` baseline with the current commit.
  - Remove obsolete claims that the invariant is staged, formatting fails, or only 31 tests pass.
  - Record the current 38-test local evidence.
- [x] Review the current worktree and decide which documentation changes belong in the next commit.
- [x] Re-run and record the local acceptance commands:

  ```bash
  forge fmt --check
  forge build --sizes
  forge test -vv
  forge coverage --report summary
  ```

- [x] Review, but do not silently ignore, remaining compiler/lint warnings.
- [x] Record residual security findings and assumptions in the README or roadmap:
  - no timeout/recovery if VRF fulfillment never arrives;
  - coordinator migration is an owner/coordinator trust assumption;
  - a permanently rejecting winner cannot withdraw its individual claim;
  - callback behavior relies on the configured coordinator and does not locally validate `requestId`.
- [x] Establish a clean, reviewable commit boundary.

**Gate 1 evidence:** current commit reference, passing local commands, updated status document, and documented residual risks.

## Gate 2 — Sepolia read-only preflight

Do not broadcast transactions until every applicable item below passes.

- [x] Configure `SEPOLIA_RPC_URL` locally for read-only checks.
- [x] Configure a disposable `SEPOLIA_PRIVATE_KEY` before signer-dependent checks or deployment simulation.
  - A fork read-only test does not require a private key; fork deployment and Gate 3 do.
  - Never commit `.env`, print the key, or use a production key.
- [x] Confirm the RPC network:

  ```bash
  cast chain-id --rpc-url "$SEPOLIA_RPC_URL"
  ```

  Expected chain ID: `11155111`.

- [x] Verify deployed bytecode exists at the configured Sepolia VRF coordinator.
- [x] Verify deployed bytecode exists at the configured Sepolia LINK token.
- [x] Recheck the coordinator, LINK token, key hash/gas lane, billing mode, and callback-gas limits against current official Chainlink documentation.
- [x] Query the configured VRF subscription through the coordinator:
  - subscription exists;
  - when deployment is planned with the configured key, subscription owner equals the address derived from `SEPOLIA_PRIVATE_KEY`;
  - LINK balance is sufficient because `nativePayment: false` is configured;
  - the subscription is not cancelled or otherwise unusable;
  - current consumers are understood.
- [x] Decide whether to reuse the hard-coded subscription or create a dedicated project subscription.

**Stop condition:** if subscription ownership, funding, coordinator, or LINK address is uncertain, stop and resolve it before deployment.

**Gate 2 evidence:** [dated RPC results and subscription reuse decision](records.md#step5minimum-acceptable-stage-verify-existing-consumer-of-the-subscription). Historical requests were pending at the recorded block; recheck subscription state before live deployment.

## Gate 3 — Non-broadcast deployment simulation

- [x] Run the deployment script without `--broadcast`:

  ```bash
  forge script script/DeployRaffle.s.sol:DeployRaffle \
    --rpc-url "$SEPOLIA_RPC_URL" \
    -vvvv
  ```

- [x] Inspect and record:
  - intended sender;
  - resolved chain ID and configuration;
  - coordinator and subscription ID;
  - Raffle constructor arguments;
  - consumer-registration target;
  - whether any unexpected subscription creation or funding path is attempted.
- [x] Resolve any simulation revert before broadcasting.

**Gate 3 evidence:** successful simulation and reviewable sender/call trace.

## Gate 4 — Optional Sepolia fork validation

This gate is useful but not mandatory. It is not a replacement for live Sepolia testing.

### 4A — Fork test

- [x] Pin a Sepolia fork block for reproducibility.
- [x] Use a dedicated fork test or `createSelectFork` setup to validate:
  - copied coordinator and LINK bytecode/configuration;
  - copied subscription existence, owner, balances, and consumers;
  - constructor/configuration compatibility against the snapshot.
- [x] Do not describe manually simulated coordinator callbacks as live VRF fulfillment.

**Gate 4A evidence:** [pinned Sepolia fork test record](records.md#step-3-sepolia-fork-test-gate-4a), block `11792671`; 3 passed, 0 failed, 0 skipped (2026-09-28 UTC). Gate 4B remains open.

### 4B — Ephemeral fork deployment

- [ ] Start an Anvil fork at the same pinned block and confirm its `block.chainid`.
  - It must resolve the intended Sepolia configuration; if it reports `31337`, `HelperConfig` will select local mocks instead.
- [ ] Ensure the deployment account has fork ETH for gas.
- [ ] Ensure the signer is the subscription owner, or explicitly document any owner impersonation used only inside the fork.
  - `AddConsumer` is owner-restricted by the real coordinator.
- [ ] Broadcast only to the local fork and confirm that no public transaction is being sent.
- [ ] Record the fork block, chain ID, account setup, command, and result.

- [ ] Record the limitation: a fork cannot prove live VRF node fulfillment, billing latency, Automation monitoring, Automation consensus, or live receipts.

**Gate 4 evidence:** fork block, RPC endpoint provenance, reproducible command, and documented limitations.

## Gate 5 — Live Sepolia smoke test

Only begin after Gates 1–3 pass.

- [ ] Confirm the current Chainlink Automation registration/execution path for Sepolia. Do not assume legacy Automation availability.
- [ ] Deploy with a disposable, funded testnet account.
- [ ] Record chain ID, source commit, toolchain versions, deployment address, transaction hash, and block number.
- [ ] Confirm the deployed Raffle is registered as a consumer under the intended subscription.
- [ ] Confirm the subscription remains sufficiently funded.
- [ ] Register Automation through the currently supported Sepolia workflow, if required.
- [ ] Record the upkeep ID and registration transaction.
- [ ] Enter the raffle once.
- [ ] Observe successful upkeep execution.
- [ ] Observe VRF request and fulfillment.
- [ ] Confirm the winner claim is credited.
- [ ] Withdraw the claim and confirm the claim becomes zero.
- [ ] Record all relevant transaction hashes, blocks, addresses, and explorer links.
- [ ] Re-run local regression tests after any live-integration-driven code change.

**Gate 5 evidence:** a completed live round with deployment, consumer, upkeep, VRF fulfillment, and withdrawal evidence.

## Gate 6 — Testing and security documentation

These documents close the project as a well-documented educational/testnet repository. They do not create security assurance that the code or tests have not established.

### `TESTING.md`

- [ ] Document the test taxonomy: unit, negative-path, fuzz, integration, invariant, fork, and live smoke tests.
- [ ] Record the exact local commands, toolchain versions, test counts, coverage snapshot, and invariant configuration.
- [ ] Explain what each high-value test proves and its boundary.
- [ ] Document the fork procedure and explicitly distinguish fork evidence from live Chainlink evidence.
- [ ] Add a reproducible evidence table with dates, commits, commands, and results.

### `SECURITY_NOTES.md`

- [ ] Document assets, actors, trust boundaries, and state transitions.
- [ ] Describe the rejecting-winner payout-liveness defect and pull-payment remediation.
- [ ] Link each important security property to its regression or invariant test.
- [ ] Record residual risks:
  - missing VRF fulfillment has no timeout/recovery;
  - coordinator migration is a privileged trust assumption;
  - a permanently rejecting winner cannot withdraw its individual claim;
  - callback/request-ID assumptions rely on coordinator behavior;
  - Sepolia subscription and Automation availability are external assumptions.
- [ ] State explicitly that this is not a formal audit, formal verification, or production-readiness claim.

### Documentation closure

- [ ] Link `TESTING.md` and `SECURITY_NOTES.md` from `README.md`.
- [ ] Update [`PROJECT_STATUS_AND_ROADMAP.md`](../PROJECT_STATUS_AND_ROADMAP.md) and the deployment record with the final evidence level (A, B, or C).
- [ ] Ensure no secret, private key, or sensitive RPC material is committed.

**Gate 6 evidence:** both documents are internally consistent with the code, tests, README, and recorded deployment/fork evidence.

## After the smoke test

- [ ] Update the README deployment record and project roadmap.
- [ ] Separate verified facts from assumptions and unresolved risks.
- [ ] Preserve no private keys or sensitive RPC data in Git.
- [ ] Decide whether the project remains testnet-only or requires additional recovery/security design.

## Explicitly out of scope for this milestone

- VRF timeout/retry/recovery redesign — valuable future hardening, but a separate architectural decision.
- Alternate withdrawal recipient for permanently rejecting winners — a documented design limitation for now.
- Upgradeability, governance, mainnet operation, ZK, RWA, or compliance features.

These items must not be silently added to the current deployment scope.

## Final completion rule

The project may be described as **Level A / locally verified** after Gates 1 and 6 are complete. It may be described as **Level B / fork validated** only after Gate 4 evidence exists. It may be described as **Level C / Sepolia validated** only after Gates 5 and 6 evidence exists. A successful testnet round still does not establish production readiness or security-audit status.
