// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

import {Test} from "forge-std/Test.sol";
import {Vm} from "forge-std/Vm.sol";
import {VRFCoordinatorV2_5Mock} from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";
import {Raffle} from "../../src/Raffle.sol";
import {DeployRaffle} from "../../script/DeployRaffle.s.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";

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
        uint256 requestId = _EntersSpecificAmountDistinctPlayers(N);
        bool success = _FulfillRequest(requestId);

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
     * players is equal to largest passing size (seventy-three).
     */
    function test_FulfillmentSuccess_WhenAmountEqualstoLargestPassingSize() public {
        uint256 N = 73;
        uint256 requestId = _EntersSpecificAmountDistinctPlayers(N);
        bool success = _FulfillRequest(requestId);

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
     * @dev Tests the fulfillment fails scenario when the number of
     * players is equal to first failing size (seventy-four).
     */
    function test_FulfillmentFailsWhenAmountEqualstoFirstFailingSize() public {
        uint256 N = 74;
        uint256 requestId = _EntersSpecificAmountDistinctPlayers(N);
        uint256 balanceBefore = address(raffle).balance;
        bool success = _FulfillRequest(requestId);

        // Assert: success (false), state (CALCULATING), player count (N),
        // recent winner (address(0)) -> no winner
        // totaloustanding equals to zero.
        assertFalse(success);
        assertEq(uint256(raffle.getRaffleState()), uint256(Raffle.RaffleState.CALCULATING));
        assertEq(raffle.getPlayersLength(), N);
        assertEq(raffle.getRecentWinner(), address(0));
        assertEq(raffle.getTotalOutstandingClaims(), 0);

        // Assert: fulfillment again fails (request id already consumed),
        // enter and performUpkeep rejected,
        // balance stays unchanged.
        vm.expectRevert(VRFCoordinatorV2_5Mock.InvalidRequest.selector);
        VRFCoordinatorV2_5Mock(vrfCoordinator).fulfillRandomWords(requestId, address(raffle));

        vm.expectRevert(Raffle.Raffle__RaffleNotOpen.selector);
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();

        assertEq(address(raffle).balance, balanceBefore);
        vm.expectRevert(
            abi.encodeWithSelector(
                Raffle.Raffle__UpkeepNotNeeded.selector,
                balanceBefore, // balance
                74, // players length
                Raffle.RaffleState.CALCULATING // state
            )
        );
        raffle.performUpkeep("");
    }

    function test_EalierClaimStillWithrawable_WhenSecondRoundFulfillmentFails() public {
        // Round 1: settle PLAYER's prize and leave it unclaimed.
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
        vm.warp(block.timestamp + interval);
        uint256 firstRoundRequestId = _performUpkeepAndGetRequestId();
        VRFCoordinatorV2_5Mock(vrfCoordinator).fulfillRandomWords(firstRoundRequestId, address(raffle));

        uint256 firstRoundExpectedPrize = entranceFee;
        assertEq(raffle.getRecentWinner(), PLAYER);
        assertEq(raffle.getClaimableWinnings(PLAYER), firstRoundExpectedPrize);

        // Round 2: enter 85 players and fulfill.
        // Round 1 left the prize unclaimed, `s_recentWinner` is already non-zero,
        // which makes the raffle non-fresh, reducing the gas cost.
        // Add extra mock subscription funding to prevent second round from insufficient balance.
        VRFCoordinatorV2_5Mock(vrfCoordinator).fundSubscription(subscriptionId, 100 ether);
        uint256 N = 85;
        uint256 secondRoundRequestId = _EntersSpecificAmountDistinctPlayers(N);
        uint256 balanceBefore = address(raffle).balance;
        bool success = _FulfillRequest(secondRoundRequestId);

        // Assert: Second round fulfillment fails.
        assertFalse(success);
        assertEq(uint256(raffle.getRaffleState()), uint256(Raffle.RaffleState.CALCULATING));

        // PLAYER withdraws the prize.
        uint256 balanceOfPlayerBefore = PLAYER.balance;
        uint256 outstandingClaimsBefore = raffle.getTotalOutstandingClaims();
        vm.prank(PLAYER);
        raffle.withdrawWinnings();
        uint256 balanceOfPlayerAfter = PLAYER.balance;
        uint256 outstandingClaimsAfter = raffle.getTotalOutstandingClaims();

        assertEq(balanceOfPlayerAfter - balanceOfPlayerBefore, firstRoundExpectedPrize);
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
     * and turn the slot cool.
     * @notice No raffle reads between this helper and the fulfillment,
     * it will turn the slot into warm.
     * @param amount - The amount of players to enter.
     * @return requestId - The request ID of the VRF request.
     */
    function _EntersSpecificAmountDistinctPlayers(uint256 amount) internal returns (uint256 requestId) {
        for (uint256 i = 0; i < amount; i++) {
            address player = makeAddr(string.concat("raffle actor", vm.toString(i)));
            hoax(player, STARTING_USER_BALANCE);
            raffle.enterRaffle{value: entranceFee}();
        }
        assertEq(raffle.getPlayersLength(), amount);

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
    function _FulfillRequest(uint256 requestId) internal returns (bool success) {
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
}
