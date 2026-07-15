# HelperConfig and VRF Mock Notes

## 1. Deployment Problem
- Raffle constructor needs parameters (entrancefee, interval, vrfcoordinator, gaslane, subscriptionid, callbackgaslimit), which are different in Sepolia and local Anvil.
- Hard-coded in `DeployRaffle` script making contract less robust
- Therefore, we need `HelperConfig` to selecte separately network config while deployment logic reamining the same.
## 2. NetworkConfig
**Service Parameters**: Defines the raffle's business behavior rather than the Chainlink integration itselt
- entranceFee
- interval

**VRF Service Parameters**
- vrfCoordinator: Raffle should send randomness requests to which onchain coordinator contract
- gasLane: Which VRF key/job configuration should process this request
- subscriptionId: Which billing account should pay for the randomness request
- callbackGasLimit: Unlike the `vrfCoordinator` or `subscriptionId`, `callbackGasLimit` also depends on how much work the consumer callback performs

**Q&A**
- Why return parameters with `struct` instead of multiple variables: 
## 3. Sepolia vs Local Anvil

| Event              | Sepolia         | Local Anvil       |
| --------------- | --------------- | ----------------- |
| VRF Coordinator | Official deploy address | Local mock address |
| subscriptionId  | Real subscription | Local created/temporary configuration         |
| gasLane         | Sepolia config | mock 中通常不代表真实 job |
| Outside VRF node     | Yes | No|
| Test spped      | Slow with gas | Fast, deterministic, repeatable |

## 4. `getConfigByChainId` / `getOrCreateAnvilEthConfig`
`getConfigByChainId`:
- is `networkConfig[chainId]`'s vrfCoordinator not default value?
- (No) return `networkConfig[chainId]`
- (Yes && chainId == LOCAL_CHAIN_ID) return `getOrCreateAnvilEthConfig()`
- (Else) revert `HelperConfig__InvalidChainId()`

`getOrCreateAnvilEthConfig`
- if localNetworkConfig.vrfCoordinator already exists -> reuse it
- otherwise -> deploy mock and save config

## 5. Why VRFCoordinatorV2_5Mock Is Needed
**Real environment**
```
Raffle
-> Real Coordinator get the randomness request
-> Chainlink node monitors and generates randomness + proof
-> Coordinator verifies proof
-> Raffle.rawFulfillRandomWords()
-> Raffle.fulfillRandomWords()
```

**Mock environment**
```
Raffle
-> VRFCoordinatorV2_5Mock.requestRandomWords()
-> Mock stores request and emits event
-> Test manually calls Mock.fulfillRandomWords()
-> Mock generates deterministic test words
-> Raffle.rawFulfillRandomWords()
-> Raffle.fulfillRandomWords()
```
Mock 替代了 Chainlink node、等待 confirmations 和 cryptographic proof verification，但保留了 request、subscription、consumer authorization、callback gas、payment accounting 和 trusted callback。

Why Anvil cannot wait real Chainlink VRF?
> Local Anvil has no real Chainlink Coordinator, no off-chain VRF node monitoring request, no real subscription billing; Unit test must be quick, deterministic, repeatable. Therefore we need Mock to stimulates request / fulfillment interface and major state transitions.

## 6. DeployRaffle Flow
```
DeployRaffle.s.sol
        ↓
DeployRaffle.run()
        ↓
DeployRaffle.deployContract()
        ↓
new HelperConfig()
        ↓
getConfig()
        ↓
Sepolia config OR deploy / reuse local mock
        ↓
startBroadcast(account)
        ↓
new Raffle(config)
        ↓
stopBroadcast()
```

## 7. What the Mock Proves and Does Not Prove
Can proves
- If Raffle call the correct VRF interface
- If request parameters input correctly
- If state convers correctly after callback
- If winnner selection / reset suit expectations
- If local test repeatable

Can not proves
- If real Chainlink node will respond promptly
- If Sepolia coordinator address setting is correct
- If subscription has funds
- If consumer is authorized correctly
- The real fee of gas / LINK
- Real network latency and service usability

## 8. Code Mapping

| Concept                   | Code                                        |
| ------------------------- | ------------------------------------------- |
| Configuration container   | `NetworkConfig`                             |
| Live-network config       | `getSepoliaEthConfig()`                     |
| Local setup               | `getOrCreateAnvilEthConfig()`               |
| Network selection         | `getConfigByChainId()` / constructor branch |
| Local external dependency | `VRFCoordinatorV2_5Mock`                    |
| Deployment consumer       | `DeployRaffle.deployContract()`             |

## 9. Remaining Gaps