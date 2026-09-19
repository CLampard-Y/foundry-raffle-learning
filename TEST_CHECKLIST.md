# Pending Test Checklist

This checklist records the highest-value test work identified after the pull-payment remediation.
It is intentionally risk-based: coverage percentage alone is not a sufficient reason to add a test.

> 中文：本清单按风险和工程价值排序，不为了单纯提高 coverage 百分比而增加重复测试。

## Current evidence

- [x] `src/Raffle.sol` runtime logic is fully covered by the current local suite.
- [x] Pull-payment P0 behavior is covered by unit, fuzz, and invariant tests.
- [x] Local deployment flow is covered by `test/integration/DeployRaffleTest.t.sol`.
- [x] Full local suite passes: unit, integration, and invariant tests.

## Add now: `HelperConfig` safety and configuration tests

Create a focused test file such as `test/unit/HelperConfigTest.t.sol`.

- [x] Unsupported chain ID reverts with `HelperConfig__InvalidChainId`.
  - Reason: prevents deployment from silently using an unintended network configuration.
  - Purpose: verifies fail-closed behavior for unknown chains.

- [x] Repeated local configuration lookup reuses the cached mock addresses.
  - Reason: `getOrCreateAnvilEthConfig()` should not deploy a second VRF coordinator or LINK token.
  - Purpose: verifies local configuration identity and prevents duplicate mock deployments.

- [x] Sepolia configuration returns the expected deployment parameters.
  - Verify the VRF coordinator, LINK token, gas lane, callback gas limit, and subscription ID.
  - Reason: these constants directly affect public-testnet deployment and VRF fulfillment.
  - Purpose: catches stale or accidentally changed network configuration before deployment.

- [x] Missing Sepolia deployer key reverts with `HelperConfig__InvalidDeployerKey`.
  - Reason: prevents a deployment attempt without a valid credential.
  - Purpose: verifies deployment credential validation.
  - Security note: use a test-only environment value; never expose a real private key.

## Already covered: do not duplicate these tests

- [x] Local mock deployment, subscription creation, subscription funding, raffle deployment, and consumer registration.
  - Evidence: `test/integration/DeployRaffleTest.t.sol`.

- [x] Direct local interaction behavior for raffle deployment setup.
  - Evidence: the existing integration test exercises the local `Interactions` path.

- [x] Raffle runtime behavior, including payout accounting and the invariant:
  - `total outstanding claims <= address(raffle).balance`.

## Verify later at deployment/fork level

- [ ] Sepolia funding path in `FundSubscription.fundSubscription()`.
  - Do not add a local unit test solely to increase branch coverage.
  - Verify with a Sepolia dry run, fork test, or testnet smoke test using the real LINK token and VRF coordinator.

- [ ] End-to-end Sepolia deployment and one live raffle round.
  - Verify configuration, subscription permissions, VRF fulfillment, and withdrawal behavior together.

## Do not add solely for coverage percentage

- [ ] `run()` and `...UsingConfig()` wrapper functions in `Interactions.s.sol`.
  - These mostly delegate to already-tested functions and add little independent confidence.

- [ ] `AddConsumer.run()` artifact lookup.
  - It depends on `broadcast/` deployment artifacts and is not a normal unit-test concern.
  - Validate it through the real deployment workflow instead.

- [ ] Internal behavior of test-only mocks such as `LinkToken`.
  - These are support utilities, not protocol production logic.

## Acceptance commands

After adding the `HelperConfig` tests, run:

```bash
/home/ZKdev/.foundry/bin/forge test
/home/ZKdev/.foundry/bin/forge coverage --no-match-coverage 'script/|test/'
```

Acceptance criteria:

- all existing unit, integration, and invariant tests still pass;
- each new `HelperConfig` test has one clear motivation;
- no real private key is committed or printed;
- protocol coverage remains the primary coverage signal;
- deployment scripts are verified at the appropriate integration or testnet level.

## Recommended order

1. Add the unsupported-chain test.
2. Add the local-cache/identity test.
3. Add the Sepolia-config value test.
4. Add the missing-deployer-key test.
5. Run the full suite and review the coverage report.
6. Schedule Sepolia/fork verification separately.
