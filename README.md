<h1 align="center">Foundry Raffle</h1>

<p align="center">A Solidity learning project with VRF-based settlement, pull-payment winnings, and Foundry accounting tests.</p>

<p align="center">
  <a href="https://github.com/CLampard-Y/foundry-raffle-learning/actions/workflows/test.yml"><img src="https://github.com/CLampard-Y/foundry-raffle-learning/actions/workflows/test.yml/badge.svg" alt="CI workflow"></a>
  <a href="https://book.getfoundry.sh/"><img src="https://img.shields.io/badge/Built%20with-Foundry-FFDB1F.svg" alt="Built with Foundry"></a>
</p>

An educational and portfolio-oriented Solidity + Foundry raffle based on the Cyfrin Updraft Smart Contract Lottery learning path. The project demonstrates a stateful raffle integrated with Chainlink VRF v2.5-compatible requests and Automation-compatible upkeep logic.

## Scope and Project Status

This repository is intentionally a learning and testnet-oriented project. It is not a production lottery, fundraising protocol, or audited financial application.

Status snapshot: **2026-09-19 (Asia/Shanghai)**. Local verification used source/test baseline `a2655d9` (`test(deploy): add HelperConfig safety coverage`). Documentation edits are separate from that baseline.

| Area | Status | Evidence / boundary |
| --- | --- | --- |
| Core Raffle state machine | `IMPLEMENTED / LOCALLY TESTED` | `OPEN -> CALCULATING -> OPEN`, entry, upkeep, VRF request, settlement, and pull-payment withdrawal are implemented. |
| Payout liveness remediation | `IMPLEMENTED / LOCALLY TESTED` | VRF fulfillment credits winnings instead of pushing ETH to the winner; rejecting receivers cannot block round finalization. |
| HelperConfig safety tests | `LOCALLY TESTED` | Four tests cover unsupported configuration lookup, cached local mock addresses, exact stored Sepolia parameters, and rejection of a zero Sepolia deployer key. |
| Stateful invariant | `LOCALLY TESTED` | `totalOutstandingClaims <= address(raffle).balance` across handler-generated operations; 128 runs, depth 64, 8,192 calls, zero reverts in the observed run. |
| Local test suite | `PASS` | 38 tests: 32 Raffle unit/fuzz tests, 4 HelperConfig tests, 1 local deployment integration test, and 1 invariant. |
| Formatting and build | `PASS WITH BUILD WARNINGS` | `forge fmt --check` and `forge build --sizes` pass; compiler/lint warnings are noted below. |
| Public Sepolia deployment | `NOT VERIFIED` | No deployment receipt, transaction hash, deployed address, or successful live round is recorded in this repository. |
| Chainlink Automation registration | `NOT VERIFIED` | Contract-level `checkUpkeep`/`performUpkeep` logic exists, but no upkeep ID or live execution evidence is recorded. |
| Security audit / production readiness | `NOT CLAIMED` | No formal audit or production deployment is claimed. |

The [test checklist](TEST_CHECKLIST.md) records the earlier test plan; the implementation and verification results below describe the current evidence. Historical notes and checklist wording do not establish live deployment or security-review status.

## What This Project Demonstrates

| Area | Demonstrated capability |
| --- | --- |
| Solidity state-machine design | Explicit `OPEN` and `CALCULATING` states with guarded transitions |
| Chainlink VRF integration | VRF v2.5-compatible request configuration, subscription setup, and coordinator-only callback path |
| Automation integration | Automation-compatible `checkUpkeep` and `performUpkeep` functions with on-chain revalidation |
| Payout isolation | Pull-payment claims, reserved-prize accounting, checks-effects-interactions withdrawal, and failure-safe claims |
| Foundry verification | Unit tests, revert assertions, event/log inspection, fuzz tests, integration testing, and stateful invariant testing |
| Deployment engineering | Configuration regression tests, network-specific broadcaster identity, local subscription setup, and consumer registration |
| Reproducibility foundations | Git submodules, `foundry.lock`, environment template, and deterministic local Anvil configuration; compiler/toolchain pinning remains pending |

## Architecture and Lifecycle

```text
Player ──enterRaffle{value}──▶ Raffle (OPEN)
                                  │
                     performUpkeep() rechecks eligibility
                                  │
                                  ↓
                         Raffle (CALCULATING)
                                  │
                         requestRandomWords()
                                  ↓
                         VRF Coordinator
                                  │
                       rawFulfillRandomWords()
                                  ↓
                 Credit claim, clear players, reopen round
                                  │
                                  ↓
                         Raffle (OPEN)

Winner ──withdrawWinnings()──▶ Clear claim, then transfer ETH
```

### Round behavior

1. `enterRaffle()` accepts at least the configured entrance fee and records the caller while the raffle is `OPEN`. Overpayment is currently accepted.
2. `checkUpkeep()` returns true only when the interval has elapsed, the raffle is open, players exist, and the contract has ETH. It does not query VRF subscription funding or service availability. `performUpkeep()` is permissionless; callers must satisfy these same conditions.
3. `performUpkeep()` rechecks those conditions, moves the raffle to `CALCULATING`, requests one VRF word, and emits `RequestedRaffleWinner`.
4. The inherited VRF consumer verifies that the callback caller is the configured coordinator. `fulfillRandomWords()` selects `randomWords[0] % players.length`.
5. Settlement computes the current prize as:

   `prize = address(this).balance - s_totalOutstandingClaims`

   The prize is credited to `s_claimableWinnings[winner]`, players are cleared, and the raffle returns to `OPEN` without making an external payment call.
6. The winner withdraws separately through `withdrawWinnings()`. State is cleared before the external call, and a failed call reverts without losing the claim.

The main accounting property tested by the invariant suite is:

`totalOutstandingClaims <= address(raffle).balance`

This compares the aggregate liability counter with the contract balance. It does not independently sum every winner's claim or prove eventual VRF fulfillment. Previous winners can leave claims unwithdrawn while new rounds proceed. A winner that cannot receive ETH retains its claim, but there is currently no alternative withdrawal-recipient function.

## Contracts and Scripts

| File | Purpose |
| --- | --- |
| [`src/Raffle.sol`](src/Raffle.sol) | Core raffle state machine, VRF request/callback handling, claim accounting, and withdrawals |
| [`script/DeployRaffle.s.sol`](script/DeployRaffle.s.sol) | Resolves network configuration, creates/funds a local subscription when needed, deploys `Raffle`, and registers it as a VRF consumer |
| [`script/HelperConfig.s.sol`](script/HelperConfig.s.sol) | Provides Anvil mock configuration and static Sepolia configuration; resolves the network-specific deployer key |
| [`script/Interactions.s.sol`](script/Interactions.s.sol) | Standalone subscription creation, funding, and consumer-registration scripts |
| [`test/unit/RaffleTest.t.sol`](test/unit/RaffleTest.t.sol) | Contract unit, negative-path, fuzz, payout, accounting, and reentrancy tests |
| [`test/unit/HelperConfigTest.t.sol`](test/unit/HelperConfigTest.t.sol) | Configuration lookup, local mock reuse, stored Sepolia parameters, and zero-key rejection tests |
| [`test/invariant/RaffleInvariantTest.t.sol`](test/invariant/RaffleInvariantTest.t.sol) | Handler-based stateful invariant for outstanding claim liabilities |
| [`test/integration/DeployRaffleTest.t.sol`](test/integration/DeployRaffleTest.t.sol) | Local deployment ownership, subscription ownership, and consumer-registration integration test |
| [`test/mocks/LinkToken.sol`](test/mocks/LinkToken.sol) | Local LINK-like token used by the mock setup |
| [`notes/`](notes/) | Learning and recovery notes; some notes are historical and may contain stale terminology |

## Repository Layout

```text
.
├── src/
│   └── Raffle.sol
├── script/
│   ├── DeployRaffle.s.sol
│   ├── HelperConfig.s.sol
│   └── Interactions.s.sol
├── test/
│   ├── unit/
│   │   ├── RaffleTest.t.sol
│   │   └── HelperConfigTest.t.sol
│   ├── invariant/RaffleInvariantTest.t.sol
│   ├── integration/DeployRaffleTest.t.sol
│   └── mocks/LinkToken.sol
├── notes/
├── foundry.toml
├── foundry.lock
├── .env.example
├── TEST_CHECKLIST.md
└── .github/workflows/test.yml
```

## Tech Stack and Dependencies

| Component | Version / source |
| --- | --- |
| Solidity | Pragma `^0.8.19` |
| Foundry | `1.7.1` observed on the development server; toolchain is not pinned in-repository |
| Compiler | Solc `0.8.35` selected in the latest local run; compiler version is not pinned in `foundry.toml` |
| Chainlink contracts | `contracts-v1.5.0` submodule, pinned by `foundry.lock` |
| forge-std | `v1.16.2` submodule, pinned by `foundry.lock` |
| foundry-devops | `0.4.0` submodule, pinned by `foundry.lock` |
| OpenZeppelin Contracts | `v4.9.6` submodule, pinned by `foundry.lock` |
| Solmate | Pinned git revision in `foundry.lock` |

The observed compiler/tool versions are evidence for the latest local run, not a reproducibility guarantee. Pin or document the intended toolchain before relying on bytecode or gas comparisons.

## Quick Start

### Prerequisites

- Git with submodule support
- Foundry (`forge`, `cast`, and `anvil`)
- A shell environment capable of loading `.env` for testnet work

### Clone and initialize dependencies

```bash
git clone --recurse-submodules https://github.com/CLampard-Y/foundry-raffle-learning.git
cd foundry-raffle-learning
git submodule update --init --recursive
```

If Foundry is not installed, follow the [official Foundry installation guide](https://book.getfoundry.sh/getting-started/installation).

### Build and test locally

```bash
forge build --sizes
forge test
```

The local suite runs in Forge's test EVM; no running Anvil node, RPC URL, funded wallet, or real private key is required. The expected result at the recorded baseline is **38 passed, 0 failed, 0 skipped**. `forge test` includes the invariant suite automatically.

For a focused review or coverage report:

```bash
forge test --match-path test/unit/HelperConfigTest.t.sol -vv
forge test --match-path test/invariant/RaffleInvariantTest.t.sol -vv
forge coverage --report summary
```

## Local Anvil Deployment

Start Anvil in one terminal:

```bash
anvil
```

In a second terminal, deploy the integrated local flow:

```bash
forge script script/DeployRaffle.s.sol:DeployRaffle \
  --rpc-url http://127.0.0.1:8545 \
  --broadcast \
  -vvvv
```

On chain ID `31337`, `HelperConfig` uses Foundry’s deterministic Anvil deployer key. The integrated script then deploys local VRF/LINK mocks, creates and funds a VRF subscription, deploys `Raffle`, and registers it as a consumer using the same broadcaster identity. Local addresses and broadcast artifacts are ephemeral and are ignored by Git.

The standalone interaction scripts depend on their own configuration resolution and, for `AddConsumer.run()`, a most-recent deployment lookup. The repository does not yet establish a durable multi-command standalone workflow; prefer the integrated `DeployRaffle` path for local setup.

## Sepolia Deployment — Planned / Not Verified

The Sepolia configuration resolver is locally tested, but no live deployment or successful live VRF/Automation round is currently evidenced. Exact-value assertions protect a recorded configuration from accidental changes; they do not establish that those values are currently valid on Sepolia. The commands below remain deployment templates until preflight and live verification are completed.

### Environment

```bash
cp .env.example .env
```

Set values in `.env` or the shell environment:

```dotenv
SEPOLIA_RPC_URL=<sepolia-rpc-url>
SEPOLIA_PRIVATE_KEY=<dedicated-testnet-private-key>
```

Never commit `.env`, private keys, RPC credentials, or sensitive broadcast data. Use a disposable testnet account and fund it only with the required testnet assets.

### Preflight checklist

- [ ] Verify the current Chainlink VRF v2.5 Sepolia coordinator, gas lane/key hash, LINK token, billing mode, and supported API from current official documentation.
- [ ] Confirm that the configured subscription exists, is funded, and is owned by the account corresponding to `SEPOLIA_PRIVATE_KEY`.
- [ ] Decide whether the configured subscription should be reused or replaced with a project-specific subscription.
- [ ] Inspect a non-broadcast simulation before sending transactions.
- [ ] Plan Chainlink Automation registration separately; `DeployRaffle` does not register an upkeep.
- [ ] Record the source commit, compiler/Foundry versions, constructor arguments, and deployed-bytecode verification result.
- [ ] Complete a live entry, upkeep, VRF fulfillment, and withdrawal; record receipts and confirm accounting after withdrawal.

`HelperConfig.s.sol` currently contains a nonzero Sepolia subscription ID, so `DeployRaffle` skips subscription creation and funding on Sepolia. That is an assumption about external onchain state, not proof that the subscription is usable.

### Simulation and broadcast templates

```bash
set -a
source .env
set +a

# Simulation: no transactions are broadcast
forge script script/DeployRaffle.s.sol:DeployRaffle \
  --rpc-url "$SEPOLIA_RPC_URL" \
  -vvvv

# Broadcast only after the preflight checklist passes
forge script script/DeployRaffle.s.sol:DeployRaffle \
  --rpc-url "$SEPOLIA_RPC_URL" \
  --broadcast \
  --slow \
  -vvvv
```

The script reads `SEPOLIA_PRIVATE_KEY` through `vm.envUint` and passes the resolved key through subscription setup, deployment, and consumer registration. Do not add a second, conflicting signer mechanism without reviewing ownership assumptions.

### Deployment record template

Fill this only after a confirmed testnet run:

```text
Status: NOT VERIFIED
Verification date:
Source commit:
Foundry / solc version and compiler settings:
Chain ID: 11155111
Raffle address:
Deployment transaction / block:
Constructor arguments / bytecode verification:
Raffle owner:
VRF Coordinator:
VRF subscription ID:
Subscription owner:
Subscription billing mode / funded balance:
Consumer-registration transaction:
Automation upkeep ID:
Entry transaction:
First upkeep transaction:
First VRF request / fulfillment transaction:
Winner / credited amount:
Withdrawal transaction / remaining claim:
Outstanding claims / contract balance after withdrawal:
Explorer links:
Notes / configuration version:
```

## Testing and Verification

### Current local snapshot

The latest local verification was run on **2026-09-19**, using source/test baseline `a2655d9`, Foundry `1.7.1`, and Solc `0.8.35`:

| Command | Result |
| --- | --- |
| `forge fmt --check` | Passed |
| `forge build --sizes` | Passed; timestamp-comparison lint warnings remain |
| `forge test -vv` | **38 passed, 0 failed, 0 skipped** |
| `forge coverage --report summary` | Passed; aggregate 81.75% lines, 80.88% statements, 89.29% branches, 75.00% functions |

Compilation during verification also reported dependency identifier warnings (`EnumerableSet.at`) and the invariant handler's `actorsLength` naming collision. These are not test failures; passing tests do not resolve or replace warning review.

Current test breakdown:

- 32 Raffle unit tests, including 3 fuzz tests with 256 runs each;
- 4 HelperConfig unit tests;
- 1 local deployment integration test;
- 1 stateful invariant with 128 runs, depth 64, and 8,192 handler calls;
- invariant handler selectors: `enter`, `settle`, and `withdraw`.

Coverage details:

| Target | Lines | Branches | Boundary |
| --- | ---: | ---: | --- |
| `src/Raffle.sol` | 100% | 100% | Execution coverage only; not a security guarantee |
| `script/DeployRaffle.s.sol` | 100% | 100% | Local integrated path |
| `script/HelperConfig.s.sol` | 90.32% | 100% | Four configuration tests; no live Sepolia verification |
| `script/Interactions.s.sol` | 51.06% | 50.00% | Standalone paths are not fully exercised |
| `test/invariant/RaffleInvariantTest.t.sol` | 92.59% | 87.50% | Handler itself is test code |

The aggregate includes scripts and test-support contracts. A reported 100% branch metric does not establish exhaustive semantic coverage: for example, HelperConfig's nonzero Sepolia-key return and unsupported-chain key resolution have no dedicated tests. Use the behavior matrix below to interpret the numbers.

### HelperConfig behavior matrix

Evidence: [`test/unit/HelperConfigTest.t.sol`](test/unit/HelperConfigTest.t.sol).

| Test | Verified behavior | Boundary |
| --- | --- | --- |
| `test_GetConfigByChainIdReverts_WhenChainIdUnsupported` | An unsupported lookup reverts with `HelperConfig__InvalidChainId` | Exercises `getConfigByChainId`, not every network-dependent function |
| `test_ReusesCachedMockAddresses_WhenLocalConfigExists` | Two local lookups on the same instance return identical VRF and LINK addresses | Checks returned identity; does not independently count deployments or validate mock bytecode |
| `test_SepoliaConfigReturnsExpectedDeploymentParameters` | Constructor-populated mapping resolves the expected coordinator, LINK token, gas lane, callback gas limit, and subscription ID | Expected values are separate test literals; no RPC access or live subscription validation |
| `test_getDeployerKeyReverts_WhenDeployerKeyInvalid` | On the Sepolia chain ID, an environment value of `"0"` triggers `HelperConfig__InvalidDeployerKey` | Covers zero specifically, not all invalid, absent, or malformed credentials |

The last test writes a synthetic environment value using `vm.setEnv`. It does not edit `.env` or require a real credential. An absent or malformed value reaches `vm.envUint` before the explicit zero check; the test does not establish the custom error for those cases. The earlier checklist's wording “missing deployer key” is therefore broader than the implemented test.

The Sepolia lookup selects the chain ID using the production constant getter. It checks the returned parameter values but does not independently guard against an accidental change to that chain-ID constant. Neither the Sepolia entrance fee nor the interval has an exact-value assertion in this configuration test.

> 中文：新增四个测试验证的是本地配置行为；Sepolia 参数与期望值一致，不代表链上配置已验证。密钥测试只覆盖值为零，不能写成已覆盖“缺失或所有非法密钥”。

### Behaviors exercised by the suite

- Entry fee lower bound, overpayment acceptance, player recording, and events;
- all `checkUpkeep` conditions and interval boundaries;
- `performUpkeep` revalidation, state lock, duplicate prevention, request event, and request configuration;
- coordinator-only callback access and mock rejection of nonexistent or already-consumed request IDs;
- winner selection, round reset, request isolation, and fuzzed player counts from 1 to 20;
- pull-payment crediting, rejecting-winner liveness, claim preservation after failed withdrawal, duplicate-withdrawal rejection, and reentrancy resistance;
- reserved winnings excluded from subsequent round prizes;
- local deployer/subscription/Raffle ownership and VRF consumer registration;
- the four HelperConfig behaviors and boundaries described above;
- the bounded outstanding-claims invariant across handler-generated `enter`, `settle`, and `withdraw` sequences.

### Remaining verification gaps

These are proposed follow-ups, not claims of completed work:

1. **Public-network integration:** verify actual subscription ownership/funding, consumer registration, LINK billing, callback gas, Automation execution, and a complete live round. Local mocks cannot establish node availability, fees, or latency.
2. **Credential behavior:** decide the intended error behavior for absent/malformed values; test nonzero Sepolia-key resolution with a synthetic key and unsupported-chain `getDeployerKey` rejection. Keep each test's environment setup explicit.
3. **Configuration assertions:** consider an independent Sepolia chain-ID expectation, entry-fee/interval checks, and nonzero deployed mock-code checks. Address equality alone would also pass if both returned addresses were zero.
4. **Accounting depth:** independently reconcile tracked claim balances against the aggregate counter and test conservation across operations. The current handler immediately settles mock requests and re-funds the subscription before settlement; it does not model delayed callbacks or billing depletion.
5. **Event observability:** add an exact `WinningCredited` event assertion. `WithdrawnWinnings` already has an emitter/winner/amount assertion in `test_WithdrawWinningsClearsClaim_WhenCallerHasClaim`.
6. **Conditional script support:** if standalone interaction scripts become a supported workflow, test their persistence and failure paths on a persistent local chain. Do not duplicate wrapper tests solely for coverage.

Coverage percentage should remain a diagnostic signal, not the primary completion criterion.

## CI

The workflow at [`.github/workflows/test.yml`](.github/workflows/test.yml) currently runs:

```text
forge fmt --check
forge build --sizes
forge test -vvv
```

It does not explicitly run a separate `forge coverage` or invariant command, although `forge test` discovers invariant tests present in the checked-out tree. No private key or RPC secret is required for the local CI workflow.

These commands passed locally in the snapshot above. This is not evidence of a particular remote GitHub Actions run. CI currently installs Foundry without a fixed version, and `foundry.toml` does not pin Solc; reproducible release artifacts require explicit toolchain settings.

## Security Assumptions and Known Limitations

### Trust boundaries and protections

- VRF callback entry is protected by the inherited `VRFConsumerBaseV2Plus` coordinator check.
- The inherited consumer also exposes `setCoordinator`: the owner or current coordinator can change the trusted coordinator. Deployer/owner custody and coordinator migration are therefore part of the trust model; the coordinator address is not immutable.
- The callback no longer performs an external ETH transfer; it records a claim and reopens the raffle.
- `withdrawWinnings()` applies checks-effects-interactions ordering and zeroes the claim before the external call.
- A failed withdrawal reverts the transaction, preserving the claimant’s credit.
- `s_totalOutstandingClaims` prevents previously reserved winnings from being counted as a later round’s prize.

### Known limitations

- The contract does not store or validate an active VRF `requestId`; it relies on the coordinator callback boundary and the `CALCULATING` one-request-at-a-time state machine.
- There is no contract-level timeout, retry, cancellation, refund, or recovery path if a VRF fulfillment never arrives.
- Rejecting-winner payout denial of service is mitigated locally; this does not solve missing or failed VRF fulfillment. The callback has no explicit state/request-ID validation of its own and trusts the configured coordinator's delivery semantics.
- `fulfillRandomWords()` assumes the coordinator supplies at least one random word.
- `checkUpkeep`/`performUpkeep` are compatible with Automation usage but the contract does not explicitly inherit an Automation interface.
- Sepolia configuration values are static and require fresh official/onchain verification.
- The configured nonzero Sepolia subscription causes deployment to skip creation/funding and assumes the subscription is already valid, funded, and owned by the deployer.
- Standalone interaction scripts rely on fresh configuration instances and, for `AddConsumer.run()`, most-recent deployment artifacts; this workflow is not fully integration-tested.
- The project has no pause mechanism, governance/multisig, upgradeability, audit, mainnet deployment, or compliance workflow.
- The project accepts overpayment and does not expose a refund path for excess entry ETH.
- Funds received outside normal entries, including forced ETH, are included in the next settled prize after reserved claims are deducted. There is no separate donation or surplus-recovery mechanism.

This repository must not be used to custody real funds without a new threat model, independent security review, operational controls, and a deployment-specific validation process.

## Roadmap

Use this table as a completion framework. Change a status only when the listed evidence exists; empty deployment-record fields above are intentional.

| Work item | Current status | Evidence needed to close |
| --- | --- | --- |
| Pull-payment and cross-round regression tests | Locally tested | Current Raffle suite and bounded invariant pass; security review remains separate |
| Initial HelperConfig test set | Locally tested | Four tests pass, within the behavior matrix's stated limits |
| Reproducible toolchain | Pending | Explicit Foundry/Solc/settings baseline used in both local verification and CI |
| Additional verification | Proposed | Risk-selected tests from the gaps above, with assertions and reproducible results |
| Sepolia preflight | Pending | Dated official configuration checks and onchain subscription/owner/funding checks |
| Sepolia deployment and Automation round | Not verified | Completed deployment record, including fulfillment and withdrawal receipts |
| Independent security review | Not performed in this documentation update | Reviewed commit, threat model, findings, remediation tests, and residual-risk record |
| Operational procedure | Pending before public operation | Owner/coordinator policy, funding and stalled-request monitoring, response contacts, and incident procedure reflecting the lack of onchain recovery |

Recommended next milestone: complete Sepolia preflight and record a non-broadcast simulation before any public-network deployment. Keep testnet validation separate from authorization to operate with real funds.

ZK, RWA, upgradeability, governance, and mainnet operations are intentionally outside this repository’s current scope.

## Non-Claims

This project does not claim:

- a completed security audit or formal verification;
- production readiness or suitability for real lotteries/fund management;
- a completed Sepolia or mainnet deployment;
- current validity of every static Sepolia integration value;
- Chainlink Automation registration or successful live execution;
- protection against every oracle, coordinator, economic, or operational failure mode.

## Acknowledgements

Source files currently declare `SPDX-License-Identifier: MIT`; add a repository-level `LICENSE` file before claiming a repository-wide license. The implementation is based on the Cyfrin Updraft Smart Contract Lottery learning material and uses Chainlink contracts, Foundry, OpenZeppelin Contracts, Solmate, and foundry-devops as pinned dependencies.
