// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

import {Script} from "forge-std/Script.sol";
import {Raffle} from "../src/Raffle.sol";
import {HelperConfig} from "./HelperConfig.s.sol";

contract DeployRaffle is Script {
    

    function run() external returns (Raffle, HelperConfig) {
        return deployContract();
    }

    function deployContract() internal returns (Raffle, HelperConfig) {
        uint256 entranceFee;
        uint256 interval;
        address vrfCoordinator;
        bytes32 gasLane;
        uint256 subscriptionId;
        uint32 callbackGasLimit;

        HelperConfig helperConfig = new HelperConfig();
        /*
        (
            entranceFee,
            interval,
            vrfCoordinator,
            gasLane,
            subscriptionId,
            callbackGasLimit
        ) = helperConfig.getConfig();
        */

        vm.startBroadcast();
        Raffle raffle = new Raffle(
            entranceFee, 
            interval, 
            vrfCoordinator, 
            gasLane, 
            subscriptionId, 
            callbackGasLimit
        );
        vm.stopBroadcast();

        return (raffle, helperConfig);
    }
}
