// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

import {Test} from "forge-std/Test.sol";
import {Raffle} from "../../src/Raffle.sol";
import {DeployRaffle} from "../../script/DeployRaffle.s.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {VRFConsumerBaseV2Plus} from "@chainlink/contracts/src/v0.8/vrf/dev/VRFConsumerBaseV2Plus.sol";

contract RaffleOwnerPowersTest is Test {
    Raffle public raffle;
    HelperConfig public helperConfig;

    uint256 entranceFee;
    uint256 interval;
    address vrfCoordinator;
    bytes32 gasLane;
    uint256 subscriptionId;
    uint32 callbackGasLimit;

    address public PLAYER = makeAddr("player");
    uint256 public constant STARTING_USER_BALANCE = 10 ether;

    event CoordinatorSet(address newCoordinator);

    function setUp() external {
        DeployRaffle deployer = new DeployRaffle();
        HelperConfig.NetworkConfig memory resolvedConfig;

        (raffle, helperConfig, resolvedConfig) = deployer.run();
        vm.deal(PLAYER, STARTING_USER_BALANCE);

        (entranceFee, interval, vrfCoordinator, gasLane, subscriptionId, callbackGasLimit) =
        (
            resolvedConfig.entranceFee,
            resolvedConfig.interval,
            resolvedConfig.vrfCoordinator,
            resolvedConfig.gasLane,
            resolvedConfig.subscriptionId,
            resolvedConfig.callbackGasLimit
        );
    }

    function test_CoordinatorRemainUnchanged_WhenStrangerCalls() public {
        address ownerOfRaffle = raffle.owner();
        address initialCoordinator = address(raffle.s_vrfCoordinator());
        address newCoordinator = makeAddr("newCoordinator");

        vm.prank(PLAYER);
        vm.expectRevert(
            abi.encodeWithSelector(
                VRFConsumerBaseV2Plus.OnlyOwnerOrCoordinator.selector, PLAYER, ownerOfRaffle, initialCoordinator
            )
        );
        raffle.setCoordinator(newCoordinator);

        assertEq(address(raffle.s_vrfCoordinator()), initialCoordinator);
    }

    function test_SetCoordinatorReverts_WhenOwnerPassZeroAddress() public {
        address ownerOfRaffle = raffle.owner();
        address initialCoordinator = address(raffle.s_vrfCoordinator());

        vm.prank(ownerOfRaffle);
        vm.expectRevert(VRFConsumerBaseV2Plus.ZeroAddress.selector);
        raffle.setCoordinator(address(0));

        assertEq(address(raffle.s_vrfCoordinator()), initialCoordinator);
    }

    function test_OwnerRepointsCoordinator_OldCoordinatorRejected() public {
        address ownerOfRaffle = raffle.owner();
        address oldCoordinator = address(raffle.s_vrfCoordinator());
        address newCoordinator = makeAddr("newCoordinator");

        // `vm.expectEmit` and `vm.prank` each cover only the next call
        // any getter placed between them and the real call consumes them.
        vm.prank(ownerOfRaffle);
        vm.expectEmit(false, false, false, true, address(raffle));
        emit CoordinatorSet(newCoordinator);
        raffle.setCoordinator(newCoordinator);

        assertEq(address(raffle.s_vrfCoordinator()), newCoordinator);

        // The old coordinator calling rawFulfillRandomWords should revert.
        uint256 requestId = 0;
        vm.prank(oldCoordinator);
        vm.expectRevert(
            abi.encodeWithSelector(
                VRFConsumerBaseV2Plus.OnlyCoordinatorCanFulfill.selector, oldCoordinator, newCoordinator
            )
        );
        raffle.rawFulfillRandomWords(requestId, new uint256[](1));
    }
}

