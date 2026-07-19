// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

import {Test} from "forge-std/Test.sol";
import {Raffle} from "../../src/Raffle.sol";
import {DeployRaffle} from "../../script/DeployRaffle.s.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";

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

    function setUp() external {
        DeployRaffle deployer = new DeployRaffle();
        (raffle, helperConfig) = deployer.run();
        vm.deal(PLAYER, STARTING_USER_BALANCE);

        HelperConfig.NetworkConfig memory config = helperConfig.getConfig();
        (entranceFee, interval, vrfCoordinator, gasLane, subscriptionId, callbackGasLimit) =
        (
            config.entranceFee,
            config.interval,
            config.vrfCoordinator,
            config.gasLane,
            config.subscriptionId,
            config.callbackGasLimit
        );
    }

    function testRaffleInitializesInOpenState() public view {
        assert(raffle.getRaffleState() == Raffle.RaffleState.OPEN);
    }

    // ============================================================
    //                    Enter Raffle
    // ============================================================
    function testRaffleRevertsWhenNotEnoughEthSent() public {
        vm.prank(PLAYER);
        vm.expectRevert(Raffle.Raffle__NotEnoughEthSent.selector);
        raffle.enterRaffle();
    }

    function testRaffleRecordsPlayerWhenEnter() public {
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
        address playerRecorded = raffle.getPlayerByIndex(0);
        assert(playerRecorded == PLAYER);
    }

    function testRaffleEmitsWhenEnter() public {
        vm.expectEmit(true, false, false, false, address(raffle));
        emit EnteredRaffle(PLAYER);

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
    /*
    function test_CheckUpkeepReturnsFalse_WhenRaffleIsCalculating() public {
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
        vm.warp(block.timestamp + interval);

        raffle.performUpkeep("");

        assertEq(
            uint256(raffle.getRaffleState()),
            uint256(Raffle.RaffleState.CALCULATING)
        );

        (bool upkeepNeeded,) = raffle.checkUpkeep("");

        assertEq(upkeepNeeded, false);
    }
    */

    function test_CheckUpkeepReturnsFalse_WhenNoBalance() public {
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
        vm.warp(block.timestamp + interval);

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

    function test_CheckUpkeepReturnsTrue_WhenAllConditionsMet() public {
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
        vm.warp(block.timestamp + interval);

        (bool upkeepNeeded,) = raffle.checkUpkeep("");

        assertTrue(upkeepNeeded);
    }
}
