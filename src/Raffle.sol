// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

import {VRFConsumerBaseV2Plus} from "@chainlink/contracts/src/v0.8/vrf/dev/VRFConsumerBaseV2Plus.sol";
import {VRFV2PlusClient} from "@chainlink/contracts/src/v0.8/vrf/dev/libraries/VRFV2PlusClient.sol";

/**
 * @title A sample Raffle Contract
 * @author CLampard-Y
 * @notice This contract is for creating a sample raffle
 * @dev It implements Chainlink VRFv2.5 and Chainlink Automation
 */
contract Raffle is VRFConsumerBaseV2Plus {
    /* Errors */
    error Raffle__NotEnoughEthSent();
    error Raffle__TransferFailed();
    error Raffle__RaffleNotOpen();
    error Raffle__UpkeepNotNeeded(uint256 balance, uint256 playersLength, uint256 raffleState);
    error Raffle_NoWinningsToWithdraw();
    error Raffle_TransferFailed();

    /* Structs Declaration */
    enum RaffleState {
        OPEN, // 0
        CALCULATING // 1
    }

    /* State Variables */
    uint16 private constant REQUEST_CONFIRMATIONS = 3;
    uint32 private constant NUM_WORDS = 1;

    uint256 private immutable i_entranceFee;
    // @dev Duration of the lottery in seconds
    uint256 private immutable i_interval;
    uint256 private immutable i_subscriptionId;
    uint32 private immutable i_callbackGasLimit;
    bytes32 private immutable i_keyHash;

    address payable[] private s_players;
    uint256 private s_lastTimeStamp;
    address private s_recentWinner;
    mapping(address winner => uint256 amount) private s_claimableWinnings;
    uint256 private s_totalOutstandingClaims;
    RaffleState private s_raffleState;

    event EnteredRaffle(address indexed player);
    event RequestedRaffleWinner(uint256 indexed requestId);
    event PickedWinner(address indexed winner);
    event WinningCredited(address indexed winner, uint256 amount);
    event WithdrawnWinnings(address indexed winner, uint256 amount);

    constructor(
        uint256 entranceFee,
        uint256 interval,
        address vrfCoordinator,
        bytes32 gasLane,
        uint256 subscriptionId,
        uint32 callbackGasLimit
    ) VRFConsumerBaseV2Plus(vrfCoordinator) {
        s_raffleState = RaffleState.OPEN;

        i_entranceFee = entranceFee;
        i_interval = interval;
        i_keyHash = gasLane;
        i_subscriptionId = subscriptionId;
        i_callbackGasLimit = callbackGasLimit;

        s_lastTimeStamp = block.timestamp;

        // Initialize the total outstanding claims to zero.
        s_totalOutstandingClaims = 0;
    }

    function enterRaffle() external payable {
        if (msg.value < i_entranceFee) revert Raffle__NotEnoughEthSent();
        if (s_raffleState != RaffleState.OPEN) {
            revert Raffle__RaffleNotOpen();
        }

        s_players.push(payable(msg.sender));
        emit EnteredRaffle(msg.sender);
    }

    /**
     * @dev This is the function that the Chainlink nodes will call to see
     * if the lottery is ready to have a winner picked.
     * The following should be true in order for upkeepNeeded to be true:
     * 1. The time interval has passed between raffle runs
     * 2. The lottery is open
     * 3. The contract has ETH and players
     * 4. Implicitly, your subscription has LINK
     * @param -ignored
     * @return upkeepNeeded - true if it's time to restart the lottery
     * @return - ignored
     */
    function checkUpkeep(
        bytes memory /* checkData */
    )
        public
        view
        returns (
            bool,
            bytes memory /* performData */
        )
    {
        bool timeHasPassed = ((block.timestamp - s_lastTimeStamp) >= i_interval);
        bool raffleIsOpen = (s_raffleState == RaffleState.OPEN);
        bool hasBalance = (address(this).balance > 0);
        bool hasPlayers = (s_players.length > 0);
        bool upkeepNeeded = timeHasPassed && raffleIsOpen && hasBalance && hasPlayers;
        return (upkeepNeeded, hex"");
    }

    function performUpkeep(
        bytes memory /* performData */
    )
        external
    {
        // check to see if enough time has passed
        (bool upkeepNeeded,) = checkUpkeep("");
        if (!upkeepNeeded) {
            revert Raffle__UpkeepNotNeeded(address(this).balance, s_players.length, uint256(s_raffleState));
        }

        s_raffleState = RaffleState.CALCULATING;
        uint256 requestId = s_vrfCoordinator.requestRandomWords(
            VRFV2PlusClient.RandomWordsRequest({
                keyHash: i_keyHash,
                subId: i_subscriptionId,
                requestConfirmations: REQUEST_CONFIRMATIONS,
                callbackGasLimit: i_callbackGasLimit,
                numWords: NUM_WORDS,
                extraArgs: VRFV2PlusClient._argsToBytes(
                    // Set nativePayment to true to pay for VRF requests with Sepolia ETH instead of LINK
                    VRFV2PlusClient.ExtraArgsV1({nativePayment: false})
                )
            })
        );

        emit RequestedRaffleWinner(requestId);
    }

    /**
     * @dev Only calculates and records winner and prize.
     * @dev Don't call transfer() in this function
     * to prevent reentrancy attacks (e.g. rejecting winner).
     */
    function fulfillRandomWords(
        uint256,
        /*requestId*/
        uint256[] calldata randomWords
    )
        internal
        override
    {
        // Effects
        uint256 indexOfWinner = randomWords[0] % s_players.length;
        address payable Winner = s_players[indexOfWinner];
        uint256 prize = address(this).balance - s_totalOutstandingClaims;

        s_claimableWinnings[Winner] += prize;
        s_totalOutstandingClaims += prize;

        s_recentWinner = Winner;
        s_raffleState = RaffleState.OPEN;
        s_players = new address payable[](0);
        s_lastTimeStamp = block.timestamp;

        emit PickedWinner(Winner);
        emit WinningCredited(Winner, prize);
    }

    function withdrawWinnings() external {
        uint256 amount = s_claimableWinnings[msg.sender];

        if (amount == 0) {
            revert Raffle_NoWinningsToWithdraw();
        }

        // Effects before interactions
        s_claimableWinnings[msg.sender] = 0;
        s_totalOutstandingClaims -= amount;

        // Interactions
        (bool success, ) = payable(msg.sender).call{value: amount}("");

        if (!success) {
            revert Raffle_TransferFailed();
        }

        emit WithdrawnWinnings(msg.sender, amount);
    }

    /**
     * Getter Functions
     */
    function getEntranceFee() public view returns (uint256) {
        return i_entranceFee;
    }

    function getRaffleState() public view returns (RaffleState) {
        return s_raffleState;
    }

    function getPlayerByIndex(uint256 index) public view returns (address) {
        return s_players[index];
    }

    function getRecentWinner() external view returns (address) {
        return s_recentWinner;
    }

    function getPlayersLength() external view returns (uint256) {
        return s_players.length;
    }

    function getLastTimeStamp() external view returns (uint256) {
        return s_lastTimeStamp;
    }

    function getClaimableWinnings(address winner) external view returns (uint256) {
        return s_claimableWinnings[winner];
    }

    function getTotalOutstandingClaims() external view returns (uint256) {
        return s_totalOutstandingClaims;
    }
}
