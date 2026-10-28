// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

import {Script} from "forge-std/Script.sol";
import {Raffle} from "../src/Raffle.sol";
import {HelperConfig} from "./HelperConfig.s.sol";
import {CreateSubscription, FundSubscription, AddConsumer} from "./Interactions.s.sol";
import {IVRFSubscriptionV2Plus} from "@chainlink/contracts/src/v0.8/vrf/dev/interfaces/IVRFSubscriptionV2Plus.sol";

contract DeployRaffle is Script {
    error DeployRaffle__OwnerOfSubscriptionIsNotExpected();
    error DeployRaffle__VrfCoordinatorIsNotExpected();
    error DeployRaffle__SubscriptionIsNotExpected();
    error DeployRaffle__CallbackGasLimitNotEqual();
    error DeployRaffle__OwnerOfRaffleIsNotExpected();
    error DeployRaffle__ConsumerNotRegistered();

    // D1 measurement: cap 60, 425,607 gas, pinned build.
    uint256 constant MEASURED_CALLBACK_GAS_LIMIT = 500000;

    function run()
        external
        returns (Raffle raffle, HelperConfig helperConfig, HelperConfig.NetworkConfig memory resolvedConfig)
    {
        return deployContract();
    }

    /**
     * @dev Deploys Raffle contract and helperConfig contract
     * @dev Deploy script with self-check:
     *  1. The owner of subscription and Raffle is deployerKey's matching address.
     *  2. The Raffle is added in consumers[] successfully.
     *  3. The gas limit is same with measured limit.
     *  4. The vrfCoordinator, subscriptionId is same with config.
     * @param raffle - Raffle contract
     * @param helperConfig - Initial config for helperConfig contract
     * @param resolvedConfig - Resolved config for NetworkConfig in helperConfig contract
     */
    function deployContract()
        internal
        returns (Raffle raffle, HelperConfig helperConfig, HelperConfig.NetworkConfig memory resolvedConfig)
    {
        helperConfig = new HelperConfig();

        resolvedConfig = helperConfig.getConfig();
        uint256 deployerPrivateKey = helperConfig.getDeployerKey();
        address expectedOwner = vm.addr(deployerPrivateKey);

        if (resolvedConfig.subscriptionId == 0) {
            CreateSubscription createSubscription = new CreateSubscription();
            (resolvedConfig.subscriptionId, resolvedConfig.vrfCoordinator) =
                createSubscription.createSubscription(resolvedConfig.vrfCoordinator, deployerPrivateKey);

            FundSubscription fundSubscription = new FundSubscription();
            fundSubscription.fundSubscription(
                resolvedConfig.vrfCoordinator, resolvedConfig.subscriptionId, resolvedConfig.link, deployerPrivateKey
            );
        }

        (,,, address ownerOfSubscription,) =
            IVRFSubscriptionV2Plus(resolvedConfig.vrfCoordinator).getSubscription(resolvedConfig.subscriptionId);
        if (ownerOfSubscription != expectedOwner) {
            revert DeployRaffle__OwnerOfSubscriptionIsNotExpected();
        }

        vm.startBroadcast(deployerPrivateKey);
        raffle = new Raffle(
            resolvedConfig.entranceFee,
            resolvedConfig.interval,
            resolvedConfig.vrfCoordinator,
            resolvedConfig.gasLane,
            resolvedConfig.subscriptionId,
            resolvedConfig.callbackGasLimit
        );
        vm.stopBroadcast();

        if (address(raffle.s_vrfCoordinator()) != resolvedConfig.vrfCoordinator) {
            revert DeployRaffle__VrfCoordinatorIsNotExpected();
        }

        if (raffle.getSubscriptionId() != resolvedConfig.subscriptionId) {
            revert DeployRaffle__SubscriptionIsNotExpected();
        }

        if (raffle.getCallbackGasLimit() != MEASURED_CALLBACK_GAS_LIMIT) {
            revert DeployRaffle__CallbackGasLimitNotEqual();
        }

        // The owner of Raffle is deployerKey's matching address.
        if (raffle.owner() != expectedOwner) {
            revert DeployRaffle__OwnerOfRaffleIsNotExpected();
        }

        AddConsumer addConsumer = new AddConsumer();

        addConsumer.addConsumer(
            address(raffle), resolvedConfig.vrfCoordinator, resolvedConfig.subscriptionId, deployerPrivateKey
        );
        (,,,, address[] memory consumers) =
            IVRFSubscriptionV2Plus(resolvedConfig.vrfCoordinator).getSubscription(resolvedConfig.subscriptionId);
        uint256 amountOfConsumers = consumers.length;
        bool foundedFlag;
        for (uint256 i = 0; i < amountOfConsumers; i++) {
            if (consumers[i] == address(raffle)) {
                foundedFlag = true;
                break;
            }
        }
        if (!foundedFlag) {
            revert DeployRaffle__ConsumerNotRegistered();
        }

        return (raffle, helperConfig, resolvedConfig);
    }
}
