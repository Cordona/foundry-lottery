// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {Script} from "../lib/forge-std/src/Script.sol";
import {VRFCoordinatorV2_5Mock} from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";
import {Commons} from "../src/Commons.sol";
import {DevOpsConstants} from "./DevOpsUtils.sol";
import {LinkToken} from "../test/mocks/LinkToken.sol";

contract HelperConfig is Script, DevOpsConstants {
    //===========[ Errors ]===========//
    error HelperConfig__NotSupportedChainId(uint256 chainId);

    //===========[ Storage ]===========//
    mapping(uint256 chainId => Commons.NetworkConfig) private s_networkConfigs;
    Commons.NetworkConfig private s_anvilConfig;

    constructor() {
        s_networkConfigs[SEPOLIA_CHAIN_ID] = getSepoliaConfig();
    }

    function getSepoliaConfig() private pure returns (Commons.NetworkConfig memory) {
        return Commons.NetworkConfig({
            raffleConfig: Commons.RaffleConfig({entranceFee: ENTRANCE_FEE, lotteryDurationSeconds: LOTTERY_DURATION_SECONDS}),
            vrfConfig: Commons.VRFConfig({
                gasLane: SEPOLIA_VRF_GAS_LINE,
                subscriptionId: NOT_INITIALIZED_SUBSCRIPTION_ID,
                vrfCoordinator: SEPOLIA_VRF_CONTRACT_ADDR,
                gasLimit: SEPOLIA_VRF_GAS_LIMIT
            }),
            linkTokenAddress: SEPOLIA_LINK_TOKEN_ADDR,
            account: SEPOLIA_DEV_ACCOUNT
        });
    }

    function getConfig() public returns (Commons.NetworkConfig memory) {
        return getConfigByChainId(block.chainid);
    }

    function getConfigByChainId(uint256 chainId) public returns (Commons.NetworkConfig memory) {
        if (s_networkConfigs[chainId].vrfConfig.vrfCoordinator != NULL_ADDRESS) {
            return s_networkConfigs[chainId];
        } else if (chainId == LOCAL_CHAIN_ID) {
            return getOrCreateAnvilConfig();
        } else {
            revert HelperConfig__NotSupportedChainId(chainId);
        }
    }

    function getOrCreateAnvilConfig() private returns (Commons.NetworkConfig memory) {
        if (s_anvilConfig.vrfConfig.vrfCoordinator != NULL_ADDRESS) {
            return s_anvilConfig;
        }

        vm.startBroadcast();
        VRFCoordinatorV2_5Mock mockCoordinator =
            new VRFCoordinatorV2_5Mock(MOCK_BASE_FEE, MOCK_GAS_PRICE_LINK, MOCK_WEI_UINT_LINK);
        LinkToken mockToken = new LinkToken();
        vm.stopBroadcast();

        s_anvilConfig = Commons.NetworkConfig({
            raffleConfig: Commons.RaffleConfig({entranceFee: ENTRANCE_FEE, lotteryDurationSeconds: LOTTERY_DURATION_SECONDS}),
            vrfConfig: Commons.VRFConfig({
                gasLane: SEPOLIA_VRF_GAS_LINE,
                subscriptionId: NOT_INITIALIZED_SUBSCRIPTION_ID,
                vrfCoordinator: address(mockCoordinator),
                gasLimit: SEPOLIA_VRF_GAS_LIMIT
            }),
            linkTokenAddress: address(mockToken),
            account: ANVIL_DEFAULT_SENDER
        });

        return s_anvilConfig;
    }
}
