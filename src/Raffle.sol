// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {Commons} from "./Commons.sol";
import {VRFConsumerBaseV2Plus} from "@chainlink/contracts/src/v0.8/vrf/dev/VRFConsumerBaseV2Plus.sol";
import {VRFV2PlusClient} from "@chainlink/contracts/src/v0.8/vrf/dev/libraries/VRFV2PlusClient.sol";

/**
 * @title A sample Raffle contract
 * @author Cordona.Tech
 * @notice This contract is for creating a sample raffle
 * @dev Implements Chainlink VRFv2.5
 */
contract Raffle is VRFConsumerBaseV2Plus {
    using Commons for Commons.UpkeepConditions;

    //===========[ Errors ]===========//
    error Raffle__SendMoreToEnterRaffle();
    error Raffle__WinnerPrizeTransferFailed();
    error Raffle__RaffleNotOpen();
    error Raffle__ShouldNotUpkeep(uint256 balance, uint256 playersCount, Commons.RaffleState raffleState);

    //===========[ Constant ]===========//
    uint16 private constant REQUEST_CONFIRMATIONS = 3;
    uint32 private constant RANDOM_WORDS_NUMBER = 1;

    //===========[ Immutable ]===========//
    address private immutable i_owner;
    uint256 private immutable i_entranceFee;
    uint256 private immutable i_lotteryDurationInSeconds;
    uint256 private immutable i_subscriptionId;
    bytes32 private immutable i_gasLane;
    uint32 private immutable i_gasLimit;

    //===========[ Storage ]===========//
    address payable[] private s_players;
    uint256 private s_lastTimeStamp;
    address private s_recentWinner;
    Commons.RaffleState private s_raffleState;

    //===========[ Events ]===========//
    event RaffleEntered(address indexed player);
    event WinnerPicked(address indexed winner);
    event RequestedRaffleWinner(uint256 indexed requestId);

    constructor(Commons.RaffleConfig memory raffleConfig, Commons.VRFConfig memory vrfConfig)
        VRFConsumerBaseV2Plus(vrfConfig.vrfCoordinator)
    {
        i_owner = msg.sender;
        i_entranceFee = raffleConfig.entranceFee;
        i_lotteryDurationInSeconds = raffleConfig.lotteryDurationSeconds;
        i_gasLane = vrfConfig.gasLane;
        i_gasLimit = vrfConfig.gasLimit;
        i_subscriptionId = vrfConfig.subscriptionId;
        s_lastTimeStamp = block.timestamp;
        s_raffleState = Commons.RaffleState.OPEN;
    }

    function enterRaffle() external payable {
        if (s_raffleState != Commons.RaffleState.OPEN) {
            revert Raffle__RaffleNotOpen();
        }

        if (msg.value < i_entranceFee) {
            revert Raffle__SendMoreToEnterRaffle();
        }

        s_players.push(payable(msg.sender));

        emit RaffleEntered(msg.sender);
    }

    /**
     *
     * @dev This is a function the Chainlink nodes will call to see if the lottery is ready to have a winner picked
     * The following should be true in order for upkeepNeeded to be true:
     * 1. The time interval has passed between raffle runs
     * 2. The lottery is open
     * 3. The contract has ETH
     * 4. The contract has players
     * 5. Implicitly, your subscription has a LINK
     * @param - ignored
     * @return upkeepNeeded - true if it's time to restart the lottery
     * @return - ignored
     */
    function checkUpkeep(bytes memory /* checkData */ ) public view returns (bool, bytes memory /* performData */ ) {
        Commons.UpkeepConditions memory upkeepConditions = Commons.UpkeepConditions({
            timeHasPassed: ((block.timestamp - s_lastTimeStamp) >= i_lotteryDurationInSeconds),
            isOpen: s_raffleState == Commons.RaffleState.OPEN,
            hasBalance: address(this).balance > 0 ether,
            hasPlayers: s_players.length > 0
        });

        return (upkeepConditions.shouldUpkeep(), "");
    }

    function performUpkeep(bytes calldata /* performData */ ) external {
        (bool shouldUpkeep,) = checkUpkeep("");

        // TODO: Write test
        if (!shouldUpkeep) {
            revert Raffle__ShouldNotUpkeep(address(this).balance, s_players.length, s_raffleState);
        }

        s_raffleState = Commons.RaffleState.CALCULATING;

        VRFV2PlusClient.RandomWordsRequest memory request = VRFV2PlusClient.RandomWordsRequest({
            keyHash: i_gasLane,
            subId: i_subscriptionId,
            requestConfirmations: REQUEST_CONFIRMATIONS,
            callbackGasLimit: i_gasLimit,
            numWords: RANDOM_WORDS_NUMBER,
            extraArgs: VRFV2PlusClient._argsToBytes(VRFV2PlusClient.ExtraArgsV1({nativePayment: false}))
        });

        uint256 requestId = s_vrfCoordinator.requestRandomWords(request);

        emit RequestedRaffleWinner(requestId);
    }

    function fulfillRandomWords(uint256 requestId, uint256[] calldata randomWords) internal override {
        uint256 winnerIndex = randomWords[0] % s_players.length;
        address payable recentWinner = s_players[winnerIndex];

        s_recentWinner = recentWinner;
        s_raffleState = Commons.RaffleState.OPEN;
        s_players = new address payable[](0);
        s_lastTimeStamp = block.timestamp;

        emit WinnerPicked(recentWinner);

        (bool success,) = recentWinner.call{value: address(this).balance}("");
        if (!success) revert Raffle__WinnerPrizeTransferFailed();
    }

    function getState() external view returns (Commons.RaffleState) {
        return s_raffleState;
    }

    /* Getters */
    function getEntranceFee() external view returns (uint256) {
        return i_entranceFee;
    }

    function getPlayers() external view returns (address payable[] memory) {
        return s_players;
    }

    function getRecentWinner() external view returns (address) {
        return s_recentWinner;
    }

    function getLastTimestamp() external view returns (uint256) {
        return s_lastTimeStamp;
    }
}
