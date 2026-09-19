// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

import {Test} from "forge-std/Test.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";

contract HelperConfigTest is Test {
    address private constant SEPOLIA_VRF_COORDINATOR = 0x9DdfaCa8183c41ad55329BdeeD9F6A8d53168B1B;
    bytes32 private constant SEPOLIA_GAS_LANE = 0x787d74caea10b2b357790d5b5247c2f63d1d91572a9846f780606e4d953677ae;
    uint256 private constant SEPOLIA_SUBSCRIPTION_ID =
        38935307025656909513953714257720199287951776187933259851240202794364574788117;
    uint32 private constant CALLBACK_GAS_LIMIT = 500000;
    address private constant SEPOLIA_LINK_TOKEN = 0x779877A7B0D9E8603169DdbD7836e478b4624789;

    function test_GetConfigByChainIdReverts_WhenChainIdUnsupported() public {
        uint256 unsupportedChainId = 627;
        HelperConfig helperConfig = new HelperConfig();

        vm.expectRevert(HelperConfig.HelperConfig__InvalidChainId.selector);
        helperConfig.getConfigByChainId(unsupportedChainId);
    }

    function test_ReusesCachedMockAddresses_WhenLocalConfigExists() public {
        // Arrange
        HelperConfig helperConfig = new HelperConfig();

        // Act
        HelperConfig.NetworkConfig memory firstConfig = helperConfig.getConfigByChainId(helperConfig.LOCAL_CHAIN_ID());
        HelperConfig.NetworkConfig memory secondConfig = helperConfig.getConfigByChainId(helperConfig.LOCAL_CHAIN_ID());

        // Assert
        assertEq(firstConfig.vrfCoordinator, secondConfig.vrfCoordinator);
        assertEq(firstConfig.link, secondConfig.link);
    }

    function test_SepoliaConfigReturnsExpectedDeploymentParameters() public {
        // Arrange & Act
        HelperConfig helperConfig = new HelperConfig();

        HelperConfig.NetworkConfig memory actualConfig =
            helperConfig.getConfigByChainId(helperConfig.ETH_SEPOLIA_CHAIN_ID());

        // Assert
        assertEq(actualConfig.vrfCoordinator, SEPOLIA_VRF_COORDINATOR);
        assertEq(actualConfig.gasLane, SEPOLIA_GAS_LANE);
        assertEq(actualConfig.subscriptionId, SEPOLIA_SUBSCRIPTION_ID);
        assertEq(actualConfig.callbackGasLimit, CALLBACK_GAS_LIMIT);
        assertEq(actualConfig.link, SEPOLIA_LINK_TOKEN);
    }

    function test_getDeployerKeyReverts_WhenDeployerKeyInvalid() public {
        // Arrange
        uint256 invalidDeployerKey = 0;

        HelperConfig helperConfig = new HelperConfig();

        // Act & Assert
        vm.chainId(helperConfig.ETH_SEPOLIA_CHAIN_ID());
        vm.setEnv("SEPOLIA_PRIVATE_KEY", vm.toString(invalidDeployerKey));
        vm.expectRevert(HelperConfig.HelperConfig__InvalidDeployerKey.selector);
        helperConfig.getDeployerKey();
    }
}
