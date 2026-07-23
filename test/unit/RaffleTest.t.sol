// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

import {Test} from "forge-std/Test.sol";
import {Vm} from "forge-std/Vm.sol";
import {Raffle} from "../../src/Raffle.sol";
import {DeployRaffle} from "../../script/DeployRaffle.s.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {VRFConsumerBaseV2Plus} from "@chainlink/contracts/src/v0.8/vrf/dev/VRFConsumerBaseV2Plus.sol";

contract RaffleTest is Test {
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

    event EnteredRaffle(address indexed player);

    modifier raffleEnteredAndTimePassed() {
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();

        vm.warp(block.timestamp + interval);
        _;
    }

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

    // ============================================================
    //                    Constructor
    // ============================================================
    function test_RaffleInOpenState_WhenInitialized() public view {
        assertEq(uint256(raffle.getRaffleState()), uint256(Raffle.RaffleState.OPEN));
    }

    /**
     * @dev Test if entranceFee is set correctly when initialized
     * expected = `entranceFee` from `HelperConfig`
     * actual = `entranceFee` from `Raffle constructor`
     */
    function test_ConstructorSetsEntranceFee_WhenInitialized() public view {
        assertEq(raffle.getEntranceFee(), entranceFee);
    }

    function test_ConstructorSetsVrfCoordinator_WhenInitialized() public view {
        assertEq(address(raffle.s_vrfCoordinator()), vrfCoordinator);
    }

    function test_ConstructorReverts_WhenVrfCoordinatorIsZeroAddress() public {
        vm.expectRevert(VRFConsumerBaseV2Plus.ZeroAddress.selector);

        new Raffle(entranceFee, interval, address(0), gasLane, subscriptionId, callbackGasLimit);
    }

    // ============================================================
    //                    Enter Raffle
    // ============================================================
    function test_enterRaffleReverts_WhenNotEnoughEthSent() public {
        vm.prank(PLAYER);
        vm.expectRevert(Raffle.Raffle__NotEnoughEthSent.selector);
        raffle.enterRaffle();
    }

    function test_enterRaffleRecordsPlayer_WhenEnter() public {
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
        address playerRecorded = raffle.getPlayerByIndex(0);
        assert(playerRecorded == PLAYER);
    }

    function test_enterRaffleEmits_WhenEnter() public {
        vm.expectEmit(true, false, false, false, address(raffle));
        emit EnteredRaffle(PLAYER);

        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
    }

    function test_enterRaffleReverts_WhenRaffleIsCalculating() public raffleEnteredAndTimePassed {
        raffle.performUpkeep("");

        vm.expectRevert(Raffle.Raffle__RaffleNotOpen.selector);
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
    }

    // ============================================================
    //                    CheckUpkeep
    // ============================================================
    function test_CheckUpkeepReturnsFalse_WhenNotEnoughTimePassed() public {
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();

        (bool upkeepNeeded,) = raffle.checkUpkeep("");

        assertFalse(upkeepNeeded);
    }

    /**
     * @dev Tests CheckUpkeep returns false when raffle is not open
     * can't test by setting `s.raffleState` to `CALCULATING` because:
     *  1. `s.raffleState` is private
     *  2. even it's public, solidity only generate getter for `s_raffleState`, which still can't change outside of contract
     *  3. should not add such setter for test, which will break contract state and security boundary
     * real productive way to test: change state by calling `performUpkeep`
     */
    function test_CheckUpkeepReturnsFalse_WhenRaffleIsCalculating() public raffleEnteredAndTimePassed {
        raffle.performUpkeep("");
        (bool upkeepNeeded,) = raffle.checkUpkeep("");

        assertFalse(upkeepNeeded);
    }

    function test_CheckUpkeepReturnsFalse_WhenNoBalance() public raffleEnteredAndTimePassed {
        vm.deal(address(raffle), 0);
        (bool upkeepNeeded,) = raffle.checkUpkeep("");

        assertFalse(upkeepNeeded);
    }

    /**
     * @dev Tests CheckUpkeep returns false when no players
     * can't test a new null raffle contract, because that lacks players and balance
     * can't sure which causes the revert
     * Send ETH to raffle contract to isolate `hasPlayers` condition
     */
    function test_CheckUpkeepReturnsFalse_WhenNoPlayer() public {
        vm.deal(address(raffle), entranceFee);
        vm.warp(block.timestamp + interval);

        (bool upkeepNeeded,) = raffle.checkUpkeep("");

        assertFalse(upkeepNeeded);
    }

    function test_CheckUpkeepReturnsFalse_WhenOneSecondBeforeInterval() public {
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
        vm.warp(block.timestamp + interval - 1);

        (bool upkeepNeeded,) = raffle.checkUpkeep("");

        assertFalse(upkeepNeeded);
    }

    function test_CheckUpkeepReturnsTrue_WhenAllConditionsMet() public raffleEnteredAndTimePassed {
        (bool upkeepNeeded,) = raffle.checkUpkeep("");

        assertTrue(upkeepNeeded);
    }

    // ============================================================
    //                    PerformUpkeep
    // ============================================================
    function test_performUpkeepSetsStateToCalculating_WhenUpkeepNeeded() public raffleEnteredAndTimePassed {
        raffle.performUpkeep("");

        assertEq(uint256(raffle.getRaffleState()), uint256(Raffle.RaffleState.CALCULATING));
    }

    /**
     * @dev Test if performUpkeep reverts when `upkeepNeeded` is false
     * @dev By setting `timePassed` not satified to make `upkeepNeeded` false
     */
    function test_performUpkeepReverts_WhenUpkeepNotNeeded_IntervalHasNotPassed() public {
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();

        vm.warp(block.timestamp + interval - 1);

        vm.expectRevert(
            abi.encodeWithSelector(
                Raffle.Raffle__UpkeepNotNeeded.selector,
                entranceFee, // balance
                1, // players length
                uint256(Raffle.RaffleState.OPEN)
            )
        );

        raffle.performUpkeep("");
    }

    /**
     * @dev Test if performUpkeep emits RequestedRaffleWinner event
     * @dev Not test "how randomness generated, how to secure the randomness", which is tested by Chainlink
     */
    function test_performUpkeepEmitsRequestId_WhenUpkeepNeeded() public raffleEnteredAndTimePassed {
        vm.recordLogs();

        raffle.performUpkeep("");

        Vm.Log[] memory logs = vm.getRecordedLogs();
        bytes32 expectedSignature = keccak256("RequestedRaffleWinner(uint256)");

        bool eventFound;
        uint256 requestId;

        for (uint256 i = 0; i < logs.length; i++) {
            if (
                logs[i].emitter == address(raffle) && logs[i].topics.length == 2
                    && logs[i].topics[0] == expectedSignature
            ) {
                requestId = uint256(logs[i].topics[1]);
                eventFound = true;
                break;
            }
        }

        assertTrue(eventFound, "RequestedRaffleWinner event not found");
        assertGt(requestId, 0);
    }
}
