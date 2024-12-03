// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {Script, console} from "../lib/forge-std/src/Script.sol";
import {Commons} from "../src/Commons.sol";
import {DevOpsConstants} from "./DevOpsUtils.sol";
import {HelperConfig} from "./HelperConfig.s.sol";
import {VRFCoordinatorV2_5Mock} from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";
import {LinkToken} from "../test/mocks/LinkToken.sol";
import {DevOpsTools} from "lib/foundry-devops/src/DevOpsTools.sol";

contract CreateSubscription is Script {
    function run(address account) public {
        createSubscriptionUsingConfig(account);
    }

    function createSubscriptionUsingConfig(address account) public returns (uint256, address) {
        address vrfCoordinator = new HelperConfig().getConfig().vrfConfig.vrfCoordinator;
        return newSubscription(vrfCoordinator, account);
    }

    // TODO: Refactor and remove address as a return value
    function newSubscription(address vrfCoordinator, address account) public returns (uint256, address) {
        console.log(
            "Creating subscription on chain ID '%s' with VRF coordinator address '%s'", block.chainid, vrfCoordinator
        );

        vm.startBroadcast(account);
        uint256 subId = VRFCoordinatorV2_5Mock(vrfCoordinator).createSubscription();
        vm.stopBroadcast();

        console.log("Your subscription ID is '%s'", subId);
        console.log("Please update the subscription Id in your HelperConfig.s.sol");

        return (subId, vrfCoordinator);
    }
}

contract FundSubscription is Script, DevOpsConstants {
    uint256 private constant FUND_AMOUNT = 100 ether;

    function run(address account) public {
        fundUsingConfig(account);
    }

    function fundUsingConfig(address account) public {
        Commons.NetworkConfig memory networkConfig = new HelperConfig().getConfig();
        Commons.VRFConfig memory config = networkConfig.vrfConfig;

        address vrfCoordinator = config.vrfCoordinator;
        uint256 subscriptionId = config.subscriptionId;
        address linkToken = networkConfig.linkTokenAddress;

        fund(vrfCoordinator, subscriptionId, linkToken, account);
    }

    function fund(address vrfCoordinator, uint256 subscriptionId, address linkToken, address account) public {
        console.log("Funding Subscription with ID: '%s'", subscriptionId);
        console.log("Using VRF coordinator with ID: '%s'", vrfCoordinator);
        console.log("On ChainId: '%s'", block.chainid);

        if (block.chainid == LOCAL_CHAIN_ID) {
            vm.startBroadcast(account);
            VRFCoordinatorV2_5Mock(vrfCoordinator).fundSubscription(subscriptionId, FUND_AMOUNT);
            vm.stopBroadcast();
        } else {
            vm.startBroadcast(account);
            LinkToken(linkToken).transferAndCall(vrfCoordinator, FUND_AMOUNT, abi.encode(subscriptionId));
            vm.stopBroadcast();
        }
    }
}

contract AddConsumer is Script {
    function run(address account) external {
        address mostRecentlyDeployed = DevOpsTools.get_most_recent_deployment("Raffle", block.chainid);

        addConsumerUsingConfig(mostRecentlyDeployed, account);
    }

    function addConsumerUsingConfig(address mostRecentlyDeployed, address account) public {
        Commons.NetworkConfig memory networkConfig = new HelperConfig().getConfig();
        Commons.VRFConfig memory config = networkConfig.vrfConfig;

        uint256 subscriptionId = config.subscriptionId;
        address vrfCoordinator = config.vrfCoordinator;

        addConsumer(mostRecentlyDeployed, vrfCoordinator, subscriptionId, account);
    }

    function addConsumer(address consumer, address vrfCoordinator, uint256 subscriptionId, address account) public {
        console.log("Adding consumer contract: ", consumer);
        console.log("Using VRF coordinator with ID: '%s'", vrfCoordinator);
        console.log("On ChainId: '%s'", block.chainid);

        vm.startBroadcast(account);
        VRFCoordinatorV2_5Mock(vrfCoordinator).addConsumer(subscriptionId, consumer);
        vm.stopBroadcast();
    }
}
