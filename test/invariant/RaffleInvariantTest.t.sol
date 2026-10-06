// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

import {Test} from "forge-std/Test.sol";
import {StdInvariant} from "forge-std/StdInvariant.sol";
import {Vm} from "forge-std/Vm.sol";
import {console} from "forge-std/console.sol";

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
    uint256 private constant ACTOR_COUNT = 8;

    uint256 public enterCalls;
    uint256 public totalEntered;
    uint256 public totalSuccessfullyWithdrawn;
    uint256 public currentRoundPot;
    uint256 public settleCalls;
    uint256 public withdrawCalls;

    constructor(Raffle _raffle, address coordinator, uint256 subscriptionId, uint256 entranceFee, uint256 interval) {
        raffle = _raffle;
        i_coordinator = VRFCoordinatorV2_5Mock(coordinator);
        i_subscriptionId = subscriptionId;
        i_entranceFee = entranceFee;
        i_interval = interval;

        for (uint256 i = 0; i < ACTOR_COUNT; i++) {
            address actor = makeAddr(string.concat("raffle actor", vm.toString(i)));
            s_actors.push(actor);
        }
    }

    /**
     * @dev Selects an actor from the fixed pool
     * and enters with valid entrance fee.
     * @param actorSeed - The fuzz input to generate actor.
     */
    function enter(uint256 actorSeed) external {
        if (raffle.getRaffleState() != Raffle.RaffleState.OPEN) {
            return;
        }

        uint256 actorCount = s_actors.length;
        uint256 actorIndex = actorSeed % actorCount;
        address actor = s_actors[actorIndex];
        hoax(actor, i_entranceFee);
        raffle.enterRaffle{value: i_entranceFee}();

        currentRoundPot += i_entranceFee;
        totalEntered += i_entranceFee;
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

        if (vm.getBlockTimestamp() < eligibleTime) {
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

        assertTrue(raffle.getRaffleState() == Raffle.RaffleState.OPEN, "Raffle should not be in calculating state");
        assertEq(raffle.getPlayersLength(), 0);
        currentRoundPot = 0;
        settleCalls++;
    }

    function withdraw(uint256 actorSeed) external {
        uint256 actorCount = s_actors.length;

        if (actorCount == 0) {
            return;
        }

        // Ensure there is at least one actor to attempt withdrawal.
        address actor = s_actors[actorSeed % actorCount];
        for (uint256 i = 1; i < ACTOR_COUNT; i++) {
            if (raffle.getClaimableWinnings(actor) > 0) {
                break;
            }

            actor = s_actors[((actorSeed % actorCount) + i) % actorCount];
        }

        if (raffle.getClaimableWinnings(actor) == 0) {
            return;
        }

        uint256 balanceBeforeWithdrawal = address(actor).balance;
        vm.prank(actor);
        raffle.withdrawWinnings();
        uint256 balanceAfterWithdrawal = address(actor).balance;
        totalSuccessfullyWithdrawn += balanceAfterWithdrawal - balanceBeforeWithdrawal;

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

    function getActorsByIndex(uint256 index) external view returns (address) {
        return s_actors[index];
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
        assertEq(address(raffle).balance, 0);

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

    function test_AllEightPlayersInPoolAreDistinct() public view {
        uint256 actorCount = handler.actorsLength();
        assertEq(actorCount, 8);

        for (uint256 i = 0; i < actorCount; i++) {
            address actor_i = handler.getActorsByIndex(i);
            for (uint256 j = i + 1; j < actorCount; j++) {
                address actor_j = handler.getActorsByIndex(j);
                assertTrue(actor_i != actor_j);
            }
        }
    }

    function test_HandlerReusesActor_WithoutGrowingPool() public {
        assertEq(handler.actorsLength(), 8);

        address actor = handler.getActorsByIndex(0);
        address expectedActor = makeAddr(string.concat("raffle actor", "0"));
        assertEq(actor, expectedActor);

        // Different seeds, but should select the same actor
        uint256 E = raffle.getEntranceFee();
        assertEq(handler.totalEntered(), 0);
        handler.enter(0);
        assertEq(handler.totalEntered(), E);
        handler.enter(8);
        assertEq(handler.totalEntered(), 2 * E);

        // Assert
        // Entering does not expand the pool.
        assertEq(handler.actorsLength(), 8);
        // Two and only two entries were made.
        assertEq(handler.enterCalls(), 2);
        assertEq(raffle.getPlayersLength(), 2);
        //Both seeds select the same actor.
        assertEq(raffle.getPlayerByIndex(0), actor);
        assertEq(raffle.getPlayerByIndex(1), actor);
    }

    function test_HandlerTracksCumulativeWithdrawals_AcrossRounds() public {
        uint256 E = raffle.getEntranceFee();
        address actor = handler.getActorsByIndex(0);

        // First withdrawal.
        handler.enter(0);
        handler.settle(0);
        uint256 balanceBeforeFirstWithdrawal = address(actor).balance;
        handler.withdraw(0);

        assertEq(address(actor).balance, balanceBeforeFirstWithdrawal + E);
        assertEq(handler.totalSuccessfullyWithdrawn(), E);
        assertEq(handler.withdrawCalls(), 1);
        assertEq(address(raffle).balance, 0);

        // Second withdrawal: no-claim path.
        uint256 balanceBeforeSecondWithdrawal = address(actor).balance;
        handler.withdraw(0);

        assertEq(address(actor).balance, balanceBeforeSecondWithdrawal);
        assertEq(handler.totalSuccessfullyWithdrawn(), E);
        assertEq(handler.withdrawCalls(), 1);
        assertEq(address(raffle).balance, 0);

        // Second enter.
        handler.enter(0);
        assertEq(handler.totalSuccessfullyWithdrawn(), E);

        handler.settle(0);
        uint256 balanceBeforeThirdWithdrawal = address(actor).balance;
        handler.withdraw(0);
        uint256 balanceAfterThirdWithdrawal = address(actor).balance;

        assertEq(balanceAfterThirdWithdrawal - balanceBeforeThirdWithdrawal, E);
        assertEq(handler.withdrawCalls(), 2);
        assertEq(address(raffle).balance, 0);
        assertEq(handler.totalEntered(), 2 * E);
        assertEq(handler.totalSuccessfullyWithdrawn(), 2 * E);
    }

    /**
     * @dev Validate handler's independent pot bookkeeping.
     */
    function test_HandlerPreservesCurrentRoundPot_WhenOldClaimWithdrawn() public {
        assertEq(handler.currentRoundPot(), 0);
        uint256 E = raffle.getEntranceFee();

        // Round 1: actor0 enters, settles but does not withdraw.
        handler.enter(0);
        assertEq(handler.currentRoundPot(), E);
        handler.settle(0);
        assertEq(raffle.getClaimableWinnings(address(handler.getActorsByIndex(0))), E);
        assertEq(handler.currentRoundPot(), 0);
        assertEq(address(raffle).balance, E);

        // Round 2: actor1 enters twice and actor0 withdraws.
        handler.enter(1);
        handler.enter(1);

        uint256 potBeforeFirstOldClaimWithdrawal = handler.currentRoundPot();
        assertEq(potBeforeFirstOldClaimWithdrawal, 2 * E);
        assertEq(address(raffle).balance, 3 * E);

        handler.withdraw(0); // actor0 withdraws
        assertEq(handler.withdrawCalls(), 1);
        assertEq(handler.totalSuccessfullyWithdrawn(), E);
        uint256 potAfterFirstOldClaimWithdrawal = handler.currentRoundPot();
        assertEq(potBeforeFirstOldClaimWithdrawal, potAfterFirstOldClaimWithdrawal);

        // actor0 withdraws again without influencing the current round pot.
        handler.withdraw(0); // actor0 withdraws again
        assertEq(handler.totalSuccessfullyWithdrawn(), E);
        assertEq(handler.withdrawCalls(), 1);
        uint256 potAfterSecondOldClaimWithdrawal = handler.currentRoundPot();
        assertEq(potAfterSecondOldClaimWithdrawal, potAfterFirstOldClaimWithdrawal);

        // actor1 can settles as expected.
        handler.settle(1);
        assertEq(handler.currentRoundPot(), 0);
        assertTrue(raffle.getRecentWinner() == address(handler.getActorsByIndex(1)));
    }

    // ===============================================================
    // Invariant tests require following assumptions:
    //  1. Zero starting balance; tracked entries/withdrawals only.
    //  2. Forced ETH excluded.
    // ===============================================================

    function afterInvariant() public view {
        assertGt(handler.withdrawCalls(), 0, "No withdraw calls have been made");

        console.log("=== After Invariant Test ===");
        console.log("Enter Calls", handler.enterCalls());
        console.log("Settle Calls", handler.settleCalls());
        console.log("Withdraw Calls", handler.withdrawCalls());
    }

    function invariant_TotalOutstandingClaimsNeverExceedBalance() public view {
        uint256 outstanding = raffle.getTotalOutstandingClaims();
        uint256 balance = address(raffle).balance;

        assertLe(outstanding, balance);
    }

    /**
     * @dev Verify the reported aggregate claims aggress with the individual actor claims sum.
     */
    function invariant_SumOfActorClaimsEqualsTotalOutstandingClaims() public view {
        uint256 sumOfClaims = 0;
        uint256 actorsLength = handler.actorsLength();

        for (uint256 i = 0; i < actorsLength; i++) {
            address actor = handler.getActorsByIndex(i);
            sumOfClaims += raffle.getClaimableWinnings(actor);
        }

        assertEq(sumOfClaims, raffle.getTotalOutstandingClaims());
    }

    function invariant_TotalEnteredEqualsWithdrawnPlusBalance() public view {
        assertEq(handler.totalEntered(), handler.totalSuccessfullyWithdrawn() + address(raffle).balance);
    }

    function invariant_BalanceEqualsOutstandingClaimsPlusCurrentRoundPot() public view {
        uint256 balance = address(raffle).balance;
        uint256 outstandingClaims = raffle.getTotalOutstandingClaims();
        uint256 currentRoundPot = handler.currentRoundPot();

        assertEq(balance, outstandingClaims + currentRoundPot);
    }
}
