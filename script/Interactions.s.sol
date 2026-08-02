// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

import {Script, console} from "forge-std/Script.sol";
import {HelperConfig, CodeConstants} from "./HelperConfig.s.sol";
import {VRFCoordinatorV2_5Mock} from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";
import {LinkToken} from "../test/mocks/LinkToken.sol";
import {DevOpsTools} from "lib/foundry-devops/src/DevOpsTools.sol";

contract CreateSubscription is Script {
    function run() external returns (uint256, address) {
        return createSubscriptionUsingConfig();
    }

    function createSubscriptionUsingConfig() public returns (uint256, address) {
        HelperConfig helperConfig = new HelperConfig();

        HelperConfig.NetworkConfig memory config = helperConfig.getConfig();
        uint256 deployerPrivateKey = helperConfig.getDeployerKey();

        return createSubscription(config.vrfCoordinator, deployerPrivateKey);
    }

    function createSubscription(address vrfCoordinator, uint256 deployerPrivateKey) public returns (uint256, address) {
        console.log("Creating subscription on ChainID:", block.chainid);
        vm.startBroadcast(deployerPrivateKey);
        uint256 subId = VRFCoordinatorV2_5Mock(vrfCoordinator).createSubscription();
        vm.stopBroadcast();
        console.log("Your subscription Id is:", subId);
        console.log("Please update subscriptionId in HelperConfig!");

        return (subId, vrfCoordinator);
    }
}

contract FundSubscription is Script, CodeConstants {
    uint256 public constant LOCAL_FUND_AMOUNT = 100 ether; // 100 LINK
    uint256 public constant SEPOLIA_FUND_AMOUNT = 3 ether; // 3 LINK

    function fundSubscriptionUsingConfig() public {
        HelperConfig helperConfig = new HelperConfig();

        HelperConfig.NetworkConfig memory config = helperConfig.getConfig();
        uint256 deployerPrivateKey = helperConfig.getDeployerKey();

        fundSubscription(config.vrfCoordinator, config.subscriptionId, config.link, deployerPrivateKey);
    }

    function fundSubscription(
        address vrfCoordinator,
        uint256 subscriptionId,
        address linkToken,
        uint256 deployerPrivateKey
    ) public {
        console.log("Funding subscription: ", subscriptionId);
        console.log("Using vrfCoordinator: ", vrfCoordinator);
        console.log("On Chain Id: ", block.chainid);
        console.log("Link Token address: ", linkToken);

        vm.startBroadcast(deployerPrivateKey);

        if (block.chainid == LOCAL_CHAIN_ID) {
            VRFCoordinatorV2_5Mock(vrfCoordinator).fundSubscription(subscriptionId, LOCAL_FUND_AMOUNT);
        } else {
            LinkToken(linkToken).transferAndCall(vrfCoordinator, SEPOLIA_FUND_AMOUNT, abi.encode(subscriptionId));
        }

        vm.stopBroadcast();
    }

    function run() public {
        fundSubscriptionUsingConfig();
    }
}

contract AddConsumer is Script {
    function addConsumerUsingConfig(address mostRecentlyDeployed) public {
        HelperConfig helperConfig = new HelperConfig();
        HelperConfig.NetworkConfig memory config = helperConfig.getConfig();
        uint256 deployerPrivateKey = helperConfig.getDeployerKey();

        addConsumer(mostRecentlyDeployed, config.vrfCoordinator, config.subscriptionId, deployerPrivateKey);
    }

    function addConsumer(
        address contractToAddToVrf,
        address vrfCoordinator,
        uint256 subscriptionId,
        uint256 deployerPrivateKey
    ) public {
        console.log("Adding consumer contract: ", contractToAddToVrf);
        console.log("To vrfCoordinator: ", vrfCoordinator);
        console.log("On ChainId: ", block.chainid);
        vm.startBroadcast(deployerPrivateKey);
        VRFCoordinatorV2_5Mock(vrfCoordinator).addConsumer(subscriptionId, contractToAddToVrf);
        vm.stopBroadcast();
    }

    function run() public {
        address mostRecentlyDeployed = DevOpsTools.get_most_recent_deployment("Raffle", block.chainid);
        addConsumerUsingConfig(mostRecentlyDeployed);
    }
}
