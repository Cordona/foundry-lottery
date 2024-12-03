// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {Test, console} from "../../lib/forge-std/src/Test.sol";
import {Vm} from "../../lib/forge-std/src/Vm.sol";
import {DeployRaffle} from "../../script/DeployRaffle.s.sol";
import {DevOpsConstants} from "../../script/DevOpsUtils.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {Raffle} from "../../src/Raffle.sol";
import {Commons} from "../../src/Commons.sol";
import {VRFCoordinatorV2_5Mock} from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";

contract TestRaffle is Test, DevOpsConstants {
    //===========[ Constant ]===========//
    uint256 private constant STARTING_PLAYER_BALANCE = 1 ether;

    //===========[ Immutable ]===========//
    address private immutable i_firstPlayer;
    address private immutable i_secondPlayer;
    address private immutable i_thirdPlayer;
    address private immutable i_forthPlayer;

    //===========[ Storage ]===========//
    Raffle private s_subject;
    Commons.RaffleConfig s_raffleConfig;
    Commons.VRFConfig s_vrfConfig;
    HelperConfig private s_helperConfig;

    //===========[ Modifiers ]===========//
    modifier withStartedRaffle() {
        vm.startPrank(i_firstPlayer);
        s_subject.enterRaffle{value: s_raffleConfig.entranceFee}();
        vm.stopPrank();
        _;
    }

    modifier skipFork() {
        if (block.chainid != LOCAL_CHAIN_ID) {
            return;
        }
        _;
    }

    //===========[ Events ]===========//
    event RaffleEntered(address indexed player);
    event WinnerPicked(address indexed winner);

    constructor() {
        i_firstPlayer = makeAddr("Krokodil");
        i_secondPlayer = makeAddr("Krokodilka");
        i_thirdPlayer = makeAddr("Gushter");
        i_forthPlayer = makeAddr("Kartoff");
    }

    function setUp() external {
        (s_subject, s_helperConfig) = new DeployRaffle().deploy();
        Commons.NetworkConfig memory config = s_helperConfig.getConfig();

        s_raffleConfig = config.raffleConfig;
        s_vrfConfig = config.vrfConfig;

        deal(i_firstPlayer, STARTING_PLAYER_BALANCE);
        deal(i_secondPlayer, STARTING_PLAYER_BALANCE);
        deal(i_thirdPlayer, STARTING_PLAYER_BALANCE);
        deal(i_forthPlayer, STARTING_PLAYER_BALANCE);
    }

    function testRaffleInitsInOpenState() public view {
        assert(s_subject.getState() == Commons.RaffleState.OPEN);
    }

    function testRaffleRevertsWithInsufficientEntranceFee() public {
        // Given
        uint256 insufficient = 0.0001 ether;
        // When
        vm.prank(i_firstPlayer);
        // Then
        vm.expectRevert(Raffle.Raffle__SendMoreToEnterRaffle.selector);
        s_subject.enterRaffle{value: insufficient}();
    }

    function testRaffleStateUpdatesWithSufficientEntranceFee() public withStartedRaffle {
        // Then
        assertEq(s_subject.getPlayers()[0], i_firstPlayer);
    }

    function testEnteringRaffleEmitsEvent() public {
        // Given
        vm.prank(i_firstPlayer);
        vm.expectEmit(true, false, false, false, address(s_subject));
        emit RaffleEntered(i_firstPlayer);
        // When
        s_subject.enterRaffle{value: s_raffleConfig.entranceFee}();
    }

    function testPlayerCanNotEnterWhileRaffleIsCalculating() public withStartedRaffle {
        // When
        vm.warp(block.timestamp + s_raffleConfig.lotteryDurationSeconds + 1);
        vm.roll(block.number + 1);

        s_subject.performUpkeep("");

        // Then
        vm.startPrank(i_secondPlayer);
        vm.expectRevert(Raffle.Raffle__RaffleNotOpen.selector);
        s_subject.enterRaffle{value: s_raffleConfig.entranceFee}();
        vm.stopPrank();
    }

    function testUpkeepReturnsFalseIfNoBalance() public {
        // When
        vm.warp(block.timestamp + s_raffleConfig.lotteryDurationSeconds + 1);
        vm.roll(block.number + 1);

        (bool result,) = s_subject.checkUpkeep("");

        // Then
        assert(result == false);
    }

    function testUpkeepReturnsFalseIfRaffleIsNotOpen() public withStartedRaffle {
        // When
        vm.warp(block.timestamp + s_raffleConfig.lotteryDurationSeconds + 1);
        vm.roll(block.number + 1);

        s_subject.performUpkeep("");

        (bool result,) = s_subject.checkUpkeep("");

        // Then
        assert(result == false);
    }

    function testWillRevertIfShouldNotUpkeep() public withStartedRaffle {
        // Then
        vm.expectRevert(
            abi.encodeWithSelector(
                Raffle.Raffle__ShouldNotUpkeep.selector,
                address(s_subject).balance,
                s_subject.getPlayers().length,
                s_subject.getState()
            )
        );

        s_subject.performUpkeep("");
    }

    function testShouldUpKeepIfConditionsAreMet() public withStartedRaffle {
        // When
        vm.warp(block.timestamp + s_raffleConfig.lotteryDurationSeconds + 1);
        vm.roll(block.number + 1);

        // Then
        s_subject.performUpkeep("");
    }

    function testExecutesUpkeepAndUpdatesStateAndEmitsRequestId() public withStartedRaffle skipFork {
        // When
        vm.warp(block.timestamp + s_raffleConfig.lotteryDurationSeconds + 1);
        vm.roll(block.number + 1);

        vm.recordLogs();

        s_subject.performUpkeep("");

        // Then
        Vm.Log[] memory entries = vm.getRecordedLogs();
        bytes32 requestId = entries[1].topics[1];

        assert(uint256(requestId) > 0);
    }

    function testShouldFulfillRandomWordsOnlyAfterPerformedUpkeep(uint256 randomRequestId)
        public
        withStartedRaffle
        skipFork
    {
        vm.expectRevert(VRFCoordinatorV2_5Mock.InvalidRequest.selector);

        VRFCoordinatorV2_5Mock(s_vrfConfig.vrfCoordinator).fulfillRandomWords(randomRequestId, address(s_subject));
    }

    function testFulfillRandomWordsPicksWinnerAndSendsMoney() public skipFork {
        // Given
        address[] memory players = new address[](3);

        players[0] = i_firstPlayer;
        players[1] = i_secondPlayer;
        players[2] = i_thirdPlayer;

        // When
        for (uint256 index; index < players.length; index++) {
            vm.startPrank(players[index]);
            s_subject.enterRaffle{value: s_raffleConfig.entranceFee}();
            vm.stopPrank();
        }

        vm.warp(block.timestamp + s_raffleConfig.lotteryDurationSeconds + 1);
        vm.roll(block.number + 3);

        vm.recordLogs();
        s_subject.performUpkeep("");
        Vm.Log[] memory entries = vm.getRecordedLogs();
        bytes32 requestId = entries[1].topics[1];

        VRFCoordinatorV2_5Mock(s_vrfConfig.vrfCoordinator).fulfillRandomWords(uint256(requestId), address(s_subject));

        // Then
        address expectedWinner = players[2];
        address recentWinner = s_subject.getRecentWinner();
        uint256 winnerBalance = recentWinner.balance;
        uint256 expectedWinnerBalance = 1.2 ether;
        Commons.RaffleState raffleState = s_subject.getState();

        assert(expectedWinner == recentWinner);
        assert(raffleState == Commons.RaffleState.OPEN);
        console.log("[DEBUG]: Winner balance: %s", winnerBalance);
        assert(winnerBalance == expectedWinnerBalance);
    }
}
