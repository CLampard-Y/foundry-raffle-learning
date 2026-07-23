// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

import {Script} from "forge-std/Script.sol";
import {Raffle} from "../src/Raffle.sol";
import {HelperConfig} from "./HelperConfig.s.sol";
import {CreateSubscription, FundSubscription, AddConsumer} from "./Interactions.s.sol";

contract DeployRaffle is Script {
    function run()
        external
        returns (Raffle raffle, HelperConfig helperConfig, HelperConfig.NetworkConfig memory resolvedConfig)
    {
        return deployContract();
    }

    /**
     * @dev Deploys Raffle contract and helperConfig contract
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

        if (resolvedConfig.subscriptionId == 0) {
            CreateSubscription createSubscription = new CreateSubscription();
            (resolvedConfig.subscriptionId, resolvedConfig.vrfCoordinator) =
                createSubscription.createSubscription(resolvedConfig.vrfCoordinator);
        }

        // Fund it
        FundSubscription fundSubscription = new FundSubscription();
        fundSubscription.fundSubscription(
            resolvedConfig.vrfCoordinator, resolvedConfig.subscriptionId, resolvedConfig.link
        );

        vm.startBroadcast();
        Raffle raffle = new Raffle(
            resolvedConfig.entranceFee,
            resolvedConfig.interval,
            resolvedConfig.vrfCoordinator,
            resolvedConfig.gasLane,
            resolvedConfig.subscriptionId,
            resolvedConfig.callbackGasLimit
        );
        vm.stopBroadcast();

        AddConsumer addConsumer = new AddConsumer();
        //addConsumer.run();
        addConsumer.addConsumer(address(raffle), resolvedConfig.vrfCoordinator, resolvedConfig.subscriptionId);

        return (raffle, helperConfig, resolvedConfig);
    }
}
