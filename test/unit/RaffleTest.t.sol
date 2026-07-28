// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

import {Test} from "forge-std/Test.sol";
import {Vm} from "forge-std/Vm.sol";
import {Raffle} from "../../src/Raffle.sol";
import {DeployRaffle} from "../../script/DeployRaffle.s.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {VRFConsumerBaseV2Plus} from "@chainlink/contracts/src/v0.8/vrf/dev/VRFConsumerBaseV2Plus.sol";
import {VRFCoordinatorV2_5Mock} from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";
import {VRFV2PlusClient} from "@chainlink/contracts/src/v0.8/vrf/dev/libraries/VRFV2PlusClient.sol";

contract RejectingWinner {
    error RejectingWinner__RejectsEth();

    function enter(Raffle raffle) external payable {
        raffle.enterRaffle{value: msg.value}();
    }

    receive() external payable {
        revert RejectingWinner__RejectsEth();
    }
}

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
    event PickedWinner(address indexed winner);

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
    function testFuzz_enterRaffleReverts_WhenNotEnoughEthSent(uint256 amount) public {
        // entraceFee = 0.01 ether
        uint256 sentAmount = bound(amount, 0, entranceFee - 1); //1 wei
        hoax(PLAYER, sentAmount);

        vm.expectRevert(Raffle.Raffle__NotEnoughEthSent.selector);

        raffle.enterRaffle{value: sentAmount}();
    }

    function testFuzz_enterRaffleRecordsPlayer_WhenEnterWithEnoughEth(uint256 amount) public {
        uint256 maxSentAmount = 100 ether;
        uint256 sentAmount = bound(amount, entranceFee, maxSentAmount);
        uint256 previousBalance = address(raffle).balance;
        hoax(PLAYER, sentAmount);

        vm.expectEmit(true, false, false, false, address(raffle));

        emit EnteredRaffle(PLAYER);

        raffle.enterRaffle{value: sentAmount}();

        assertEq(address(raffle).balance, previousBalance + sentAmount);
        assertEq(raffle.getPlayerByIndex(0), PLAYER);
        assertEq(raffle.getPlayersLength(), 1);
    }

    function test_enterRaffleRecordsPlayerAndEmits_WhenEnter() public {
        vm.prank(PLAYER);
        vm.expectEmit(true, false, false, false, address(raffle));
        emit EnteredRaffle(PLAYER);

        raffle.enterRaffle{value: entranceFee}();

        address playerRecorded = raffle.getPlayerByIndex(0);
        assert(playerRecorded == PLAYER);
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

    /**
     * @dev Test if Raffle sends right network config parameters to Coordinator
     * `test_performUpkeepEmitsRequestId_WhenUpkeepNeeded` only proves:
     *    1. `performUpkeep` executed successfully
     *    2. `requestId` is greater than 0
     */
    function test_performUpkeepRequestsRandomWords_WithExpectedConfig() public raffleEnteredAndTimePassed {
        // -----------------
        // Arrange
        // -----------------
        vm.recordLogs();

        // -----------------
        // Act
        // -----------------
        raffle.performUpkeep("");

        Vm.Log[] memory logs = vm.getRecordedLogs();
        bytes32 expectedSignature =
            keccak256("RandomWordsRequested(bytes32,uint256,uint256,uint256,uint16,uint32,uint32,bytes,address)");

        bool eventFound;

        for (uint256 i = 0; i < logs.length; i++) {
            if (
                logs[i].emitter == vrfCoordinator && logs[i].topics.length == 4
                    && logs[i].topics[0] == expectedSignature
            ) {
                eventFound = true;
                // indexed topics
                bytes32 actualKeyHash = logs[i].topics[1];
                uint256 actualSubscriptionId = uint256(logs[i].topics[2]);
                address actualSender = address(uint160(uint256(logs[i].topics[3])));

                // non-indexed event data
                (
                    uint256 requestId,
                    uint256 preSeed,
                    uint16 actualRequestConfirmations,
                    uint32 actualCallbackGasLimit,
                    uint32 actualNumWords,
                    bytes memory actualExtraArgs
                ) = abi.decode(logs[i].data, (uint256, uint256, uint16, uint32, uint32, bytes));

                bytes memory expectedExtraArgs =
                    VRFV2PlusClient._argsToBytes(VRFV2PlusClient.ExtraArgsV1({nativePayment: false}));

                // -----------------
                // Assert
                // -----------------
                assertEq(actualKeyHash, gasLane);
                assertEq(actualSubscriptionId, subscriptionId);
                assertEq(actualRequestConfirmations, 3);
                assertEq(actualSender, address(raffle));
                assertEq(actualCallbackGasLimit, callbackGasLimit);
                assertEq(actualNumWords, 1);
                assertEq(actualExtraArgs, expectedExtraArgs);
                assertGt(requestId, 0);
                assertGt(preSeed, 0);

                break;
            }
        }

        assertTrue(eventFound, "RandomWordsRequested event not found");
    }

    /**
     * @dev Prevents duplicate VRF requests while the current round
     * is waiting for fulfillment.
     */
    function test_performUpkeepRevers_WhenCalledAgainWhileCalculating() public raffleEnteredAndTimePassed {
        // -----------------
        // Arrange
        // -----------------
        // Start the VRF request and move the raffle to CALCULATING.
        // Above tests already prove `performUpkeep` executed successfully.
        raffle.performUpkeep("");

        // -----------------
        // Act & Assert
        // -----------------
        // The same round can't create another request.
        // Use abi.encodeWithSelector to see details of the error.
        vm.expectRevert(
            abi.encodeWithSelector(
                Raffle.Raffle__UpkeepNotNeeded.selector,
                entranceFee, // balance
                1, // players length
                Raffle.RaffleState.CALCULATING // state
            )
        );

        raffle.performUpkeep("");
    }

    // ============================================================
    //                    fulfillRandomWords
    // ============================================================
    function test_fulfillRandomWordsReverts_WhenRequestDoesNotExist() public {
        vm.expectRevert(VRFCoordinatorV2_5Mock.InvalidRequest.selector);
        VRFCoordinatorV2_5Mock(vrfCoordinator).fulfillRandomWords(0, address(raffle));
    }

    function test_RawfulfillRandomWordsReverts_WhenCallerIsNotCoordinator() public {
        uint256[] memory randomWords = new uint256[](1);
        randomWords[0] = 1;

        vm.prank(PLAYER);
        vm.expectRevert(
            abi.encodeWithSelector(VRFConsumerBaseV2Plus.OnlyCoordinatorCanFulfill.selector, PLAYER, vrfCoordinator)
        );

        raffle.rawFulfillRandomWords(1, randomWords);
    }

    function test_fulfillRandomWordsSettlesRaffle_WhenRequestIsValid() public {
        // -----------------
        // Arrange
        // -----------------
        // Adds players & Sets expected winner
        address expectedWinner = makeAddr("expectedWinner");
        address thirdPlayer = makeAddr("thirdPlayer");

        address[] memory players = new address[](3);
        players[0] = PLAYER;
        players[1] = expectedWinner;
        players[2] = thirdPlayer;
        uint256 playersNumber = players.length;

        for (uint256 i = 0; i < playersNumber; i++) {
            hoax(players[i], STARTING_USER_BALANCE);
            raffle.enterRaffle{value: entranceFee}();
        }

        uint256 previousTimeStamp = raffle.getLastTimeStamp();

        // Sets time to pass
        vm.warp(block.timestamp + interval);

        uint256 requestId = _performUpkeepAndGetRequestId();

        uint256 prize = address(raffle).balance;
        uint256 winnerBalanceBefore = expectedWinner.balance;

        // Sets random words
        uint256[] memory randomWords = new uint256[](1);
        randomWords[0] = 1;

        uint256 expectedFulfillmentTimeStamp = block.timestamp;

        vm.expectEmit(true, false, false, false, address(raffle));
        emit PickedWinner(expectedWinner);

        // -----------------
        // Act
        // -----------------
        VRFCoordinatorV2_5Mock(vrfCoordinator).fulfillRandomWordsWithOverride(requestId, address(raffle), randomWords);

        // -----------------
        // Assert
        // -----------------
        // Assert: winner and payout
        assertEq(raffle.getRecentWinner(), expectedWinner);
        assertEq(expectedWinner.balance, winnerBalanceBefore + prize);

        // Assert: raffle reset
        assertEq(address(raffle).balance, 0);
        assertEq(uint256(raffle.getRaffleState()), uint256(Raffle.RaffleState.OPEN));
        assertEq(raffle.getPlayersLength(), 0);
        assertEq(raffle.getLastTimeStamp(), expectedFulfillmentTimeStamp);
        assertGt(raffle.getLastTimeStamp(), previousTimeStamp);
    }

    /**
     *    address[] memory players = new address[](3);
     *    uint256[] memory randomWords = new uint256[](1);
     *    uint256 playersLength = 3;
     *    players[0] = PLAYER;
     *    players[1] = makeAddr("player2");
     *    players[2] = makeAddr("player3");
     *    randomWords[0] = 1;
     *    address memory expectedWinner = players[randomWords[0] % playersLength];
     *    for (uint256 i = 0; i < playersLength; i++) {
     *        vm.prank(players[i]);
     *        raffle.enterRaffle{value: entranceFee}();
     *    }
     *
     *    uint256 requestId = _performUpkeepAndGetRequestId();
     *
     *    uint256 prize = address(raffle).balance;
     *    uint256 winnerBalanceBefore =  expectedWinner.balance;
     *
     *    raffle.fulfillRandomWordsWithOverride(requestId, randomWords);
     *    //raffle.rawFulfillRandomWords(requestId, randomWords);
     *
     *    assertEq(prize + winnerBalanceBefore, expectedWinner.balance);
     *    assertEq(0, address(raffle).balance);
     * }
     */

    function testFuzz_fulfillmentSelectsExpectedPlayerAndSettles_WhenRequestIsValid(
        uint256 playerCount,
        uint256 randomWord
    ) public {
        // -----------------
        // Arrange
        // -----------------
        // Adds players & Sets expected winner.
        uint256 boundedPlayerCount = bound(playerCount, 1, 20);
        address[] memory players = new address[](boundedPlayerCount);

        for (uint256 i = 0; i < boundedPlayerCount; i++) {
            address player = makeAddr(string.concat("fuzzPlayer", vm.toString(i)));

            players[i] = player;

            hoax(player, STARTING_USER_BALANCE);
            raffle.enterRaffle{value: entranceFee}();
        }

        // Derive the expected winner using the raffle specification.
        uint256 expectedWinnerIndex = randomWord % players.length;
        address expectedWinner = players[expectedWinnerIndex];

        // Sets time to pass.
        vm.warp(block.timestamp + interval);

        // Records prize and winner balance.
        uint256 prize = address(raffle).balance;
        uint256 winnerBalanceBefore = expectedWinner.balance;

        // Defensive check: prize = boundedPlayerCount * entranceFee.
        assertEq(prize, boundedPlayerCount * entranceFee);

        // -----------------
        // Act
        // -----------------
        uint256 requestId = _performUpkeepAndGetRequestId();
        uint256[] memory randomWords = new uint256[](1);
        randomWords[0] = randomWord;

        vm.expectEmit(true, false, false, false, address(raffle));
        emit PickedWinner(expectedWinner);

        VRFCoordinatorV2_5Mock(vrfCoordinator).fulfillRandomWordsWithOverride(requestId, address(raffle), randomWords);

        // -----------------
        // Assert
        // -----------------
        // Assert: winner selection and balance.
        assertEq(raffle.getRecentWinner(), expectedWinner);
        assertEq(expectedWinner.balance, winnerBalanceBefore + prize);

        // Assert: raffle reset.
        assertEq(address(raffle).balance, 0);
        assertEq(uint256(raffle.getRaffleState()), uint256(Raffle.RaffleState.OPEN));
        assertEq(raffle.getPlayersLength(), 0);
    }

    /**
     * @dev A security characterization test:
     * records exactly what will happen when push-payment design meet with winner that rejects payment.
     */
    function test_fulfillmentLeavesRoundUnsettled_WhenWinnerRejectesEth() public {
        // Arrange: make RejectingWinner the only player.
        RejectingWinner rejectingWinner = new RejectingWinner();

        vm.prank(PLAYER);
        rejectingWinner.enter{value: entranceFee}(raffle);

        assertEq(raffle.getPlayersLength(), 1);
        assertEq(raffle.getPlayerByIndex(0), address(rejectingWinner));

        uint256 prizeBefore = address(raffle).balance;
        uint256 timestampBefore = raffle.getLastTimeStamp();
        address recentWinnerBefore = raffle.getRecentWinner();

        vm.warp(block.timestamp + interval);
        uint256 requestId = _performUpkeepAndGetRequestId();

        assertEq(uint256(raffle.getRaffleState()), uint256(Raffle.RaffleState.CALCULATING));

        uint256[] memory randomWords = new uint256[](1);
        randomWords[0] = 0;

        // Act: the Mock catches the callback revert.
        VRFCoordinatorV2_5Mock(vrfCoordinator).fulfillRandomWordsWithOverride(requestId, address(raffle), randomWords);

        // Assert: settlement changes were rolled back.
        assertEq(uint256(raffle.getRaffleState()), uint256(Raffle.RaffleState.CALCULATING));
        assertEq(raffle.getPlayersLength(), 1);
        assertEq(raffle.getPlayerByIndex(0), address(rejectingWinner));
        assertEq(address(raffle).balance, prizeBefore);
        assertEq(address(rejectingWinner).balance, 0);
        assertEq(raffle.getRecentWinner(), recentWinnerBefore);
        assertEq(raffle.getLastTimeStamp(), timestampBefore);

        // No new upkeep can be started.
        (bool upkeepNeeded,) = raffle.checkUpkeep("");
        assertFalse(upkeepNeeded);

        // The failed VRF request cannot be retried.
        vm.expectRevert(VRFCoordinatorV2_5Mock.InvalidRequest.selector);
        VRFCoordinatorV2_5Mock(vrfCoordinator).fulfillRandomWords(requestId, address(raffle));
    }

    function test_StartsIndependentRound_AfterPreviousRoundSettles() public raffleEnteredAndTimePassed {
        // -----------------
        // First round
        // -----------------
        uint256 firstRequestId = _performUpkeepAndGetRequestId();

        uint256[] memory randomWords = new uint256[](1);
        randomWords[0] = 1;

        VRFCoordinatorV2_5Mock(vrfCoordinator)
            .fulfillRandomWordsWithOverride(firstRequestId, address(raffle), randomWords);

        uint256 firstRoundSettledAt = raffle.getLastTimeStamp();

        // -----------------
        // Second round
        // -----------------
        address secondRoundPlayer = makeAddr("secondRoundPlayer");
        vm.deal(secondRoundPlayer, STARTING_USER_BALANCE);
        vm.prank(secondRoundPlayer);
        raffle.enterRaffle{value: entranceFee}();

        assertEq(raffle.getPlayersLength(), 1, "Players length should be 1 after entering the second round");
        assertEq(raffle.getPlayerByIndex(0), secondRoundPlayer, "Player should be the second round player");

        // Time boundry: time passed interval - 1.
        vm.warp(firstRoundSettledAt + interval - 1);
        (bool upkeepNeededBeforeInterval,) = raffle.checkUpkeep("");
        assertFalse(upkeepNeededBeforeInterval);

        // Time boundry: time passed interval.
        vm.warp(firstRoundSettledAt + interval);
        (bool upkeepNeededAfterInterval,) = raffle.checkUpkeep("");
        assertTrue(upkeepNeededAfterInterval);

        // Tests if the second round can execute successfully.
        uint256 secondRequestId = _performUpkeepAndGetRequestId();

        assertNotEq(secondRequestId, firstRequestId);

        assertEq(uint256(raffle.getRaffleState()), uint256(Raffle.RaffleState.CALCULATING));
    }

    // ============================================================
    //                    helper functions
    // ============================================================
    /**
     * @dev Performs upkeep and returns requestId
     */
    function _performUpkeepAndGetRequestId() internal returns (uint256) {
        vm.recordLogs();

        raffle.performUpkeep("");

        Vm.Log[] memory logs = vm.getRecordedLogs();
        bytes32 expectedSignature = keccak256("RequestedRaffleWinner(uint256)");
        uint256 requestId;

        for (uint256 i = 0; i < logs.length; i++) {
            if (
                logs[i].emitter == address(raffle) && logs[i].topics.length == 2
                    && logs[i].topics[0] == expectedSignature
            ) {
                return uint256(logs[i].topics[1]);
            }
        }

        revert("RequestedRaffleWinner event not found");
    }
}
