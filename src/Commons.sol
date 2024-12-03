// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

library Commons {
    struct RaffleConfig {
        uint256 entranceFee;
        uint256 lotteryDurationSeconds;
    }

    struct VRFConfig {
        bytes32 gasLane;
        uint256 subscriptionId;
        address vrfCoordinator;
        uint32 gasLimit;
    }

     struct NetworkConfig {
        Commons.RaffleConfig raffleConfig;
        Commons.VRFConfig vrfConfig;
        address linkTokenAddress;
        address account;
    }

    struct UpkeepConditions {
        bool timeHasPassed;
        bool isOpen;
        bool hasBalance;
        bool hasPlayers;
    }

    enum RaffleState {
        OPEN,
        CALCULATING
    }

    function shouldUpkeep(UpkeepConditions memory self) internal pure returns (bool) {
        return self.timeHasPassed && self.isOpen && self.hasBalance && self.hasPlayers;
    }
}
