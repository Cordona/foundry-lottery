// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {Script} from "../lib/forge-std/src/Script.sol";
import {CreateSubscription, FundSubscription, AddConsumer} from "./Interactions.s.sol";
import {HelperConfig} from "./HelperConfig.s.sol";
import {DevOpsConstants} from "./DevOpsUtils.sol";
import {Commons} from "../src/Commons.sol";
import {Raffle} from "../src/Raffle.sol";

contract DeployRaffle is Script, DevOpsConstants {
    function deploy() public returns (Raffle, HelperConfig) {
        HelperConfig helperConfig = new HelperConfig();
        Commons.NetworkConfig memory networkConfig = helperConfig.getConfig();
        Commons.VRFConfig memory vrfConfig = networkConfig.vrfConfig;

        // TODO: Refactor and do not reinitialize vrfConfig.vrfCoordinator bellow because this value is eventually the same.
        if (vrfConfig.subscriptionId == NOT_INITIALIZED_SUBSCRIPTION_ID) {
            (vrfConfig.subscriptionId, vrfConfig.vrfCoordinator) =
                new CreateSubscription().newSubscription(vrfConfig.vrfCoordinator, networkConfig.account);

            new FundSubscription().fund(
                vrfConfig.vrfCoordinator,
                vrfConfig.subscriptionId,
                networkConfig.linkTokenAddress,
                networkConfig.account
            );
        }

        vm.startBroadcast(networkConfig.account);
        Raffle target = new Raffle(networkConfig.raffleConfig, networkConfig.vrfConfig);
        vm.stopBroadcast();

        AddConsumer addConsumer = new AddConsumer();
        addConsumer.addConsumer(
            address(target), vrfConfig.vrfCoordinator, vrfConfig.subscriptionId, networkConfig.account
        );

        return (target, helperConfig);
    }
}
