// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

import {Script} from "forge-std/Script.sol";
import {VRFCoordinatorV2_5Mock} from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";
import {LinkToken} from "../test/mocks/LinkToken.sol";

abstract contract CodeConstants {
    /* VRF Mock Values */
    uint96 public constant MOCK_BASE_FEE = 0.25 ether;
    uint96 public constant MOCK_GAS_PRICE_LINK = 1e9;
    // LINK / ETH price
    int256 public constant MOCK_WEI_PER_UNIT_LINK = 4e15;

    uint256 public constant ETH_SEPOLIA_CHAIN_ID = 11155111;
    uint256 public constant LOCAL_CHAIN_ID = 31337;

    uint256 public constant DEFAULT_ANVIL_PRIVATE_KEY =
        0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;
}

contract HelperConfig is Script, CodeConstants {
    error HelperConfig__InvalidChainId();
    error HelperConfig__InvalidDeployerKey();

    struct NetworkConfig {
        uint256 entranceFee;
        uint256 interval;
        address vrfCoordinator;
        bytes32 gasLane;
        uint256 subscriptionId;
        uint32 callbackGasLimit;
        address link;
    }

    uint256 private constant ENTRANCE_FEE = 0.01 ether;
    uint256 private constant INTERVAL = 30;
    uint32 private constant CALLBACK_GAS_LIMIT = 500000;
    uint256 private constant SEPOLIA_SUBSCRIPTION_ID =
        38935307025656909513953714257720199287951776187933259851240202794364574788117;
    address private constant SEPOLIA_VRF_COORDINATOR = 0x9DdfaCa8183c41ad55329BdeeD9F6A8d53168B1B;
    bytes32 private constant SEPOLIA_GAS_LANE = 0x787d74caea10b2b357790d5b5247c2f63d1d91572a9846f780606e4d953677ae;
    address private constant SEPOLIA_LINK_TOKEN = 0x779877A7B0D9E8603169DdbD7836e478b4624789;

    NetworkConfig public localNetworkConfig;
    mapping(uint256 chainId => NetworkConfig) public networkConfigs;

    constructor() {
        networkConfigs[ETH_SEPOLIA_CHAIN_ID] = getSepoliaEthConfig();
    }

    function getConfig() public returns (NetworkConfig memory) {
        return getConfigByChainId(block.chainid);
    }

    function getDeployerKey() public view returns (uint256) {
        if (block.chainid == LOCAL_CHAIN_ID) {
            return DEFAULT_ANVIL_PRIVATE_KEY;
        }

        if (block.chainid == ETH_SEPOLIA_CHAIN_ID) {
            uint256 deployerPrivateKey = vm.envUint("SEPOLIA_PRIVATE_KEY");

            if (deployerPrivateKey == 0) {
                revert HelperConfig__InvalidDeployerKey();
            }

            return deployerPrivateKey;
        }

        revert HelperConfig__InvalidChainId();
    }

    function getConfigByChainId(uint256 chainId) public returns (NetworkConfig memory) {
        if (networkConfigs[chainId].vrfCoordinator != address(0)) {
            return networkConfigs[chainId];
        } else if (chainId == LOCAL_CHAIN_ID) {
            return getOrCreateAnvilEthConfig();
        } else {
            revert HelperConfig__InvalidChainId();
        }
    }

    function getSepoliaEthConfig() public pure returns (NetworkConfig memory) {
        return NetworkConfig({
            entranceFee: ENTRANCE_FEE,
            interval: INTERVAL,
            vrfCoordinator: SEPOLIA_VRF_COORDINATOR,
            gasLane: SEPOLIA_GAS_LANE,
            callbackGasLimit: CALLBACK_GAS_LIMIT,
            subscriptionId: SEPOLIA_SUBSCRIPTION_ID,
            link: SEPOLIA_LINK_TOKEN
        });
    }

    function getOrCreateAnvilEthConfig() public returns (NetworkConfig memory) {
        // Check to see if we set an active network localNetworkConfig
        if (localNetworkConfig.vrfCoordinator != address(0)) {
            return localNetworkConfig;
        }

        // Deploy mocks
        vm.startBroadcast(getDeployerKey());
        VRFCoordinatorV2_5Mock vrfCoordinatorMock =
            new VRFCoordinatorV2_5Mock(MOCK_BASE_FEE, MOCK_GAS_PRICE_LINK, MOCK_WEI_PER_UNIT_LINK);
        LinkToken linkToken = new LinkToken();
        vm.stopBroadcast();

        localNetworkConfig = NetworkConfig({
            entranceFee: ENTRANCE_FEE,
            interval: INTERVAL,
            vrfCoordinator: address(vrfCoordinatorMock),
            // Doesn't matter
            gasLane: SEPOLIA_GAS_LANE,
            callbackGasLimit: CALLBACK_GAS_LIMIT,
            subscriptionId: 0,
            link: address(linkToken)
        });

        return localNetworkConfig;
    }
}
