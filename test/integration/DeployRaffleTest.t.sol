// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

import {Test} from "forge-std/Test.sol";
import {Raffle} from "../../src/Raffle.sol";
import {DeployRaffle} from "../../script/DeployRaffle.s.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {IVRFSubscriptionV2Plus} from "@chainlink/contracts/src/v0.8/vrf/dev/interfaces/IVRFSubscriptionV2Plus.sol";

contract DeployRaffleTest is Test {
    uint256 private constant LOCAL_CHAIN_ID = 31337;
    address private constant EXPECTED_ANVIL_DEPLOYER = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266;

    function test_UsesConsistentDeployerIdentity_WhenDeployingLocally() public {
        // -------------
        // Arrange
        // -------------
        vm.skip(block.chainid != LOCAL_CHAIN_ID, "local-only integration test");

        DeployRaffle deployer = new DeployRaffle();

        // -------------
        // Act
        // -------------
        (Raffle deployedRaffle, HelperConfig deploymentHelperConfig, HelperConfig.NetworkConfig memory resolvedConfig) =
            deployer.run();

        uint256 resolvedDeployerPrivateKey = deploymentHelperConfig.getDeployerKey();
        address resolvedDeployer = vm.addr(resolvedDeployerPrivateKey);

        uint256 subscriptionId = resolvedConfig.subscriptionId;
        // Type casting.
        IVRFSubscriptionV2Plus coordinator = IVRFSubscriptionV2Plus(resolvedConfig.vrfCoordinator);
        (,,, address subscriptionOwner,) = coordinator.getSubscription(subscriptionId);

        // -------------
        // Assert
        // -------------
        assertEq(resolvedDeployer, EXPECTED_ANVIL_DEPLOYER);

        //assertEq(subscriptionOwner,EXPECTED_ANVIL_DEPLOYER);
        assertEq(subscriptionOwner, resolvedDeployer);

        assertTrue(address(deployedRaffle) != address(0));
    }
}
