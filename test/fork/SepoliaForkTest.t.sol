// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

// Import `Test` already provides `vm`.
import {Test} from "forge-std/Test.sol";
import {IVRFSubscriptionV2Plus} from "@chainlink/contracts/src/v0.8/vrf/dev/interfaces/IVRFSubscriptionV2Plus.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {Raffle} from "../../src/Raffle.sol";

contract SepoliaForkTest is Test {
    uint256 public constant ETH_SEPOLIA_CHAIN_ID = 11155111;

    address public constant FIXED_SEPOLIA_COORDINATOR = 0x9DdfaCa8183c41ad55329BdeeD9F6A8d53168B1B;
    address public constant FIXED_SEPOLIA_LINK = 0x779877A7B0D9E8603169DdbD7836e478b4624789;

    uint256 public constant FIXED_SEPOLIA_SUBSCRIPTION_ID =
        38935307025656909513953714257720199287951776187933259851240202794364574788117;
    address public constant FIXED_SEPOLIA_SUBSCRIPTION_OWNER = 0x1B2bBE13FFd0c4f2654D401d102C1CdC749Dea41;
    uint256 public constant FIXED_SEPOLIA_BALANCE = 18000000000000000000;
    uint256 public constant FIXED_SEPOLIA_NATIVE_BALANCE = 0;

    function setUp() public {
        // Set up and verify RPC URL.
        string memory rpcUrl = vm.envOr("SEPOLIA_RPC_URL", string(""));
        vm.skip(bytes(rpcUrl).length == 0, "Sepolia RPC URL not set");
        vm.createSelectFork(rpcUrl, 11792671);
        assertEq(vm.getChainId(), ETH_SEPOLIA_CHAIN_ID);
        assertEq(vm.getBlockNumber(), 11792671);
    }

    function test_PinnedForkHasExpectedAndNonEmptyCoordinatorAndLink() public {
        // ================================
        // Verify Coordinator & LINK
        // ================================
        HelperConfig helperConfig = new HelperConfig();
        HelperConfig.NetworkConfig memory resolvedConfig = helperConfig.getConfig();

        assertEq(resolvedConfig.vrfCoordinator, FIXED_SEPOLIA_COORDINATOR);
        assertEq(resolvedConfig.link, FIXED_SEPOLIA_LINK);
        assertGt(resolvedConfig.vrfCoordinator.code.length, 0);
        assertGt(resolvedConfig.link.code.length, 0);
    }

    function test_PinnedForkHasExpectedSubscription() public {
        // ================================
        // Verify Subscription
        // ================================
        address[] memory FIXED_SEPOLIA_SUBSCRIPTION_CONSUMERS = new address[](2);
        FIXED_SEPOLIA_SUBSCRIPTION_CONSUMERS[0] = address(0x8a23ca647D6EDCbf28b335Aa2E564E2165DFf410);
        FIXED_SEPOLIA_SUBSCRIPTION_CONSUMERS[1] = address(0x014eC4E62841ccdCD65658aa4f479f6AfD3b00d6);

        HelperConfig helperConfig = new HelperConfig();
        HelperConfig.NetworkConfig memory resolvedConfig = helperConfig.getConfig();
        uint256 actualSubscription = resolvedConfig.subscriptionId;
        assertEq(actualSubscription, FIXED_SEPOLIA_SUBSCRIPTION_ID);

        (uint96 actualBalance, uint96 actualNativeBalance,, address actualOwner, address[] memory actualConsumers) =
            IVRFSubscriptionV2Plus(resolvedConfig.vrfCoordinator).getSubscription(actualSubscription);

        assertEq(actualBalance, FIXED_SEPOLIA_BALANCE);
        assertEq(actualNativeBalance, FIXED_SEPOLIA_NATIVE_BALANCE);
        assertEq(actualOwner, FIXED_SEPOLIA_SUBSCRIPTION_OWNER);
        assertEq(actualConsumers, FIXED_SEPOLIA_SUBSCRIPTION_CONSUMERS);
    }

    function test_RaffleConstructorCompatibility() public {
        // ================================
        // Verify Raffle constructor
        // ================================
        HelperConfig helperConfig = new HelperConfig();
        HelperConfig.NetworkConfig memory resolvedConfig = helperConfig.getConfig();
        Raffle deployedraffle = new Raffle(
            resolvedConfig.entranceFee,
            resolvedConfig.interval,
            resolvedConfig.vrfCoordinator,
            resolvedConfig.gasLane,
            resolvedConfig.subscriptionId,
            resolvedConfig.callbackGasLimit
        );

        assertEq(uint256(deployedraffle.getRaffleState()), uint256(Raffle.RaffleState.OPEN));
        assertEq(deployedraffle.getLastTimeStamp(), block.timestamp);
        assertEq(deployedraffle.getTotalOutstandingClaims(), 0);

        assertEq(deployedraffle.getEntranceFee(), resolvedConfig.entranceFee);
        assertEq(deployedraffle.getInterval(), resolvedConfig.interval);
        assertEq(deployedraffle.getGasLane(), resolvedConfig.gasLane);
        assertEq(deployedraffle.getSubscriptionId(), resolvedConfig.subscriptionId);
        assertEq(deployedraffle.getCallbackGasLimit(), resolvedConfig.callbackGasLimit);
    }
}
