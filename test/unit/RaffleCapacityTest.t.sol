// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

import {Test} from "forge-std/Test.sol";
import {Vm} from "forge-std/Vm.sol";
import {VRFCoordinatorV2_5Mock} from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";
import {Raffle} from "../../src/Raffle.sol";
import {DeployRaffle} from "../../script/DeployRaffle.s.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {AddConsumer} from "../../script/Interactions.s.sol";

/**
 * @dev This contract test the raffle capacity.
 */
contract RaffleCapacityTest is Test {
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

    event RandomWordsFulfilled(
        uint256 indexed requestId,
        uint256 outputSeed,
        uint256 indexed subId,
        uint96 payment,
        bool nativePayment,
        bool success,
        bool onlyPremium
    );

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

    /**
     * @dev Tests the fulfillment success scenario
     * when the number of players is equal to twenty.
     */
    function test_FulfillmentSuccess_WhenAmountEqualstoTwenty() public {
        uint256 N = 20;
        _entersSpecificAmountDistinctPlayers(N);
        uint256 requestId = _performUpkeepAndGetRequestIdInCool();
        bool success = _fulfillRequest(requestId);

        // Assert: success (true), state (OPEN), player count (0),
        // recent winner and his claim (N * entranceFee),
        // totaloustanding equals to balance,
        assertTrue(success);
        assertEq(uint256(raffle.getRaffleState()), uint256(Raffle.RaffleState.OPEN));
        assertEq(raffle.getPlayersLength(), 0);
        assertEq(raffle.getClaimableWinnings(raffle.getRecentWinner()), N * entranceFee);
        assertEq(raffle.getTotalOutstandingClaims(), address(raffle).balance);
    }

    /**
     * @dev Tests the fulfillment still success scenario when the number of
     * players is equal to cap (sixty).
     */
    function test_FulfillmentSuccess_WhenPlayersAmountEqualstoCap() public {
        // Arrange
        uint256 N = raffle.getMaxAmountOfPlayers();

        // Act
        _entersSpecificAmountDistinctPlayers(N);
        uint256 requestId = _performUpkeepAndGetRequestIdInCool();
        bool success = _fulfillRequest(requestId);

        // Assert: success (true), state (OPEN), player count (0),
        // recent winner and his claim (N * entranceFee),
        // totaloustanding equals to balance.
        assertTrue(success);
        assertEq(uint256(raffle.getRaffleState()), uint256(Raffle.RaffleState.OPEN));
        assertEq(raffle.getPlayersLength(), 0);
        assertEq(raffle.getClaimableWinnings(raffle.getRecentWinner()), N * entranceFee);
        assertEq(raffle.getTotalOutstandingClaims(), address(raffle).balance);
    }

    /**
     * @dev Tests having entered the cap (60) players, the contract rejects
     * one more player and remains unchanged.
     */
    function test_MoreEnterFails_WhenPlayersAmountEqualsCap() public {
        // Arrange: N equals to the cap (maximum amount of players) plus one.
        uint256 N = raffle.getMaxAmountOfPlayers() + 1;

        // Act
        // First round: Enter Cap players (success).
        _entersSpecificAmountDistinctPlayers(N - 1);
        uint256 playersLengthBeforeSecondRound = raffle.getPlayersLength();
        uint256 balanceBeforeSecondRound = address(raffle).balance;
        assertEq(playersLengthBeforeSecondRound, N - 1);
        assertEq(balanceBeforeSecondRound, (N - 1) * entranceFee);

        // Second round: Enter one more player (revert: TheAmountOfPlayersExceedLimit).
        vm.expectRevert(Raffle.Raffle__TheAmountOfPlayersExceedLimit.selector);
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
        uint256 playersLengthAfterSecondRound = raffle.getPlayersLength();
        uint256 balanceAfterSecondRound = address(raffle).balance;

        // Assert: Enter one more player fails and
        // contract remains unchanged (players length, balance).
        assertEq(uint256(raffle.getRaffleState()), uint256(Raffle.RaffleState.OPEN));
        assertEq(playersLengthAfterSecondRound, playersLengthBeforeSecondRound);
        assertEq(balanceAfterSecondRound, balanceBeforeSecondRound);
    }

    /**
     * @dev Failed-callback test: Fulfillment fails when the gas limit is
     * exceeded (using custom small limit raffle):
     * 1. Custom raffle uses a gas limit of 300000 (< measured 425,607).
     * 2. Enter 60 players (the cap).
     */
    function test_FulfillmentFails_WhenGasLimitExceeded() public {
        _useSmallLimitRaffle(300000);
        uint256 N = raffle.getMaxAmountOfPlayers();
        _entersSpecificAmountDistinctPlayers(N);

        uint256 requestId = _performUpkeepAndGetRequestIdInCool();
        uint256 balanceBeforeFulfillment = address(raffle).balance;
        bool success = _fulfillRequest(requestId);
        uint256 balanceAfterFulfillment = address(raffle).balance;

        // Assert
        assertFalse(success);
        assertEq(balanceAfterFulfillment, balanceBeforeFulfillment);
        assertEq(raffle.getTotalOutstandingClaims(), 0);

        // The same request can't be fulfilled again
        vm.expectRevert(VRFCoordinatorV2_5Mock.InvalidRequest.selector);
        VRFCoordinatorV2_5Mock(vrfCoordinator).fulfillRandomWords(requestId, address(raffle));

        assertEq(raffle.getPlayersLength(), N);
        assertEq(uint256(raffle.getRaffleState()), uint256(Raffle.RaffleState.CALCULATING));
        assertEq(raffle.getRecentWinner(), address(0));

        // No more players can enter
        vm.expectRevert(Raffle.Raffle__RaffleNotOpen.selector);
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();

        // No more peformUpkeep can be called
        vm.expectRevert(
            abi.encodeWithSelector(
                Raffle.Raffle__UpkeepNotNeeded.selector,
                balanceAfterFulfillment, // balance
                N, // players length
                Raffle.RaffleState.CALCULATING // state
            )
        );
        raffle.performUpkeep("");
    }

    /**
     * @dev Tests that the earlier round winner can still withdraw their winnings as expected
     *  while the second round fulfillment fails due to gas limit exceeded.
     */
    function test_EarlierClaimStillWithdrawable_WhenSecondRoundFulfillmentFails() public {
        // Add extra mock subscription funding to prevent second round from insufficient balance.
        VRFCoordinatorV2_5Mock(vrfCoordinator).fundSubscription(subscriptionId, 100 ether);

        _useSmallLimitRaffle(300000);

        // Round 1: Enter N = 20 players and fulfill.
        uint256 N = 20;
        _entersSpecificAmountDistinctPlayers(N);
        uint256 requestId = _performUpkeepAndGetRequestIdInCool();
        bool success = _fulfillRequest(requestId);

        // Assert: Round 1 fulfillment success and raffle resets.
        assertTrue(success);
        assertEq(uint256(raffle.getRaffleState()), uint256(Raffle.RaffleState.OPEN));
        assertEq(raffle.getPlayersLength(), 0);
        assertEq(raffle.getTotalOutstandingClaims(), address(raffle).balance);

        // Record round 1 winner and assert.
        address firstRoundWinner = raffle.getRecentWinner();
        uint256 firstRoundExpectedPrize = N * entranceFee;
        assertEq(raffle.getTotalOutstandingClaims(), firstRoundExpectedPrize);
        assertEq(raffle.getClaimableWinnings(firstRoundWinner), firstRoundExpectedPrize);

        // Round 2: Enter N = cap players and fulfill (fails due to gas limit).
        N = raffle.getMaxAmountOfPlayers();
        _entersSpecificAmountDistinctPlayers(N);
        uint256 firstRoundWinnerBalanceBeforeWithdrawal = firstRoundWinner.balance;
        requestId = _performUpkeepAndGetRequestIdInCool();
        success = _fulfillRequest(requestId);

        // Assert: Second round fulfillment fails and raffle remains unchanged.
        assertFalse(success);
        assertEq(uint256(raffle.getRaffleState()), uint256(Raffle.RaffleState.CALCULATING));
        assertEq(raffle.getPlayersLength(), N);
        assertEq(raffle.getRecentWinner(), firstRoundWinner);
        assertEq(address(raffle).balance, firstRoundExpectedPrize + (N * entranceFee));

        // First round winner withdraws the prize.
        uint256 outstandingClaimsBefore = raffle.getTotalOutstandingClaims();
        vm.prank(firstRoundWinner);
        raffle.withdrawWinnings();
        uint256 firstRoundWinnerBalanceAfterWithdrawal = firstRoundWinner.balance;
        uint256 outstandingClaimsAfter = raffle.getTotalOutstandingClaims();

        assertEq(
            firstRoundWinnerBalanceAfterWithdrawal - firstRoundWinnerBalanceBeforeWithdrawal, firstRoundExpectedPrize
        );
        assertEq(outstandingClaimsBefore - outstandingClaimsAfter, firstRoundExpectedPrize);
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

    /**
     * @dev Enters specific amount of distinct players into the raffle
     * @param amount - The amount of players to enter.
     */
    function _entersSpecificAmountDistinctPlayers(uint256 amount) internal {
        for (uint256 i = 0; i < amount; i++) {
            address player = makeAddr(string.concat("raffle actor", vm.toString(i)));
            hoax(player, STARTING_USER_BALANCE);
            raffle.enterRaffle{value: entranceFee}();
        }
        assertEq(raffle.getPlayersLength(), amount);
    }

    /**
     * @dev Performs upkeep and returns requestId in cool state.
     * @notice No raffle reads between this helper and the fulfillment,
     * it will turn the slot into warm.
     * @return requestId - The request ID of the VRF request.
     */
    function _performUpkeepAndGetRequestIdInCool() internal returns (uint256 requestId) {
        vm.warp(block.timestamp + interval);
        requestId = _performUpkeepAndGetRequestId();
        vm.cool(address(raffle));
        vm.recordLogs();

        return requestId;
    }

    /**
     * @dev Fulfills the VRF request.
     * @param requestId - The request ID of the VRF request.
     * @return success - Whether the fulfillment was successful.
     */
    function _fulfillRequest(uint256 requestId) internal returns (bool success) {
        VRFCoordinatorV2_5Mock(vrfCoordinator).fulfillRandomWords(requestId, address(raffle));

        Vm.Log[] memory logs = vm.getRecordedLogs();
        bytes32 expectedSignature = keccak256("RandomWordsFulfilled(uint256,uint256,uint256,uint96,bool,bool,bool)");

        for (uint256 i = 0; i < logs.length; i++) {
            if (
                logs[i].emitter == address(vrfCoordinator) && logs[i].topics.length == 3
                    && logs[i].topics[0] == expectedSignature
            ) {
                (,,, success,) = abi.decode(logs[i].data, (uint256, uint96, bool, bool, bool));
                return success;
            }
        }

        revert("RandomWordsFulfilled event not found");
    }

    /**
     * @dev
     */
    function _useSmallLimitRaffle(uint32 limit) internal {
        Raffle small = new Raffle(entranceFee, interval, vrfCoordinator, gasLane, subscriptionId, limit);
        new AddConsumer().addConsumer(address(small), vrfCoordinator, subscriptionId, helperConfig.getDeployerKey());
        raffle = small;
    }
}
