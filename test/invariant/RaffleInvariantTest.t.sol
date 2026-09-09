// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

import {Test} from "forge-std/Test.sol";
import {StdInvariant} from "forge-std/StdInvariant.sol";
import {Vm} from "forge-std/Vm.sol";

import {Raffle} from "../../src/Raffle.sol";
import {DeployRaffle} from "../../script/DeployRaffle.s.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {VRFCoordinatorV2_5Mock} from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";

contract RaffleHandler is Test {
    Raffle public immutable raffle;

    VRFCoordinatorV2_5Mock private immutable i_coordinator;
    uint256 private immutable i_subscriptionId;
    uint256 private immutable i_entranceFee;
    uint256 private immutable i_interval;

    address[] private s_actors;

    uint256 public enterCalls;
    uint256 public settleCalls;
    uint256 public withdrawCalls;

    constructor(Raffle _raffle, address coordinator, uint256 subscriptionId, uint256 entranceFee, uint256 interval) {
        raffle = _raffle;
        i_coordinator = VRFCoordinatorV2_5Mock(coordinator);
        i_subscriptionId = subscriptionId;
        i_entranceFee = entranceFee;
        i_interval = interval;
    }

    /**
     * @dev Creates deterministic actor from fuzz input (actorSeed)
     * and enters with valid entrance fee.
     * @param actorSeed - The fuzz input to generate actor.
     */
    function enter(uint256 actorSeed) external {
        if (raffle.getRaffleState() != Raffle.RaffleState.OPEN) {
            return;
        }

        address actor = address(uint160(uint256(keccak256(abi.encode("raffle actor", actorSeed)))));

        hoax(actor, i_entranceFee);
        raffle.enterRaffle{value: i_entranceFee}();

        s_actors.push(actor);
        enterCalls++;
    }

    function settle(uint256 randomWord) external {
        if (raffle.getRaffleState() != Raffle.RaffleState.OPEN) {
            return;
        }

        if (raffle.getPlayersLength() == 0) {
            return;
        }

        uint256 eligibleTime = raffle.getLastTimeStamp() + i_interval;

        if (block.timestamp < eligibleTime) {
            vm.warp(eligibleTime);
        }

        (bool upkeepNeeded,) = raffle.checkUpkeep("");

        if (!upkeepNeeded) {
            return;
        }

        // Each stateful run may perform many settlements.
        i_coordinator.fundSubscription(i_subscriptionId, 100 ether);

        uint256 requestId = _performUpkeepAndGetRequestId();

        uint256[] memory randomWords = new uint256[](1);
        randomWords[0] = randomWord;

        i_coordinator.fulfillRandomWordsWithOverride(requestId, address(raffle), randomWords);

        settleCalls++;
    }

    function withdraw(uint256 actorSeed) external {
        uint256 actorsLength = s_actors.length;

        if (actorsLength == 0) {
            return;
        }

        address actor = s_actors[actorSeed % actorsLength];

        if (raffle.getClaimableWinnings(actor) == 0) {
            return;
        }

        vm.prank(actor);
        raffle.withdrawWinnings();

        withdrawCalls++;
    }

    function actorsLength() external view returns (uint256) {
        return s_actors.length;
    }

    function _performUpkeepAndGetRequestId() internal returns (uint256) {
        vm.recordLogs();

        raffle.performUpkeep("");

        Vm.Log[] memory logs = vm.getRecordedLogs();
        bytes32 expectedSignature = keccak256("RequestedRaffleWinner(uint256)");

        for (uint256 i = 0; i < logs.length; i++) {
            if (
                logs[i].emitter == address(raffle) && logs[i].topics.length == 2
                    && logs[i].topics[0] == expectedSignature
            ) {
                return uint256(logs[i].topics[1]);
            }
        }

        revert("request ID not found");
    }
}

contract RaffleInvariantTest is StdInvariant, Test {
    Raffle public raffle;
    HelperConfig public helperConfig;
    RaffleHandler public handler;

    function setUp() external {
        DeployRaffle deployer = new DeployRaffle();
        HelperConfig.NetworkConfig memory config;

        (raffle, helperConfig, config) = deployer.run();

        handler = new RaffleHandler(
            raffle, config.vrfCoordinator, config.subscriptionId, config.entranceFee, config.interval
        );

        bytes4[] memory selectors = new bytes4[](3);

        selectors[0] = RaffleHandler.enter.selector;
        selectors[1] = RaffleHandler.settle.selector;
        selectors[2] = RaffleHandler.withdraw.selector;

        targetContract(address(handler));
        targetSelector(FuzzSelector({addr: address(handler), selectors: selectors}));
    }

    function invariant_TotalOutstandingClaimsNeverExceedBalance() public view {
        uint256 outstanding = raffle.getTotalOutstandingClaims();
        uint256 balance = address(raffle).balance;

        assertLe(outstanding, balance);
    }
}
