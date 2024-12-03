// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

abstract contract DevOpsConstants {
    //===========[ Raffle Values ]===========//
    uint256 internal constant ENTRANCE_FEE = 0.1 ether;
    uint256 internal constant LOTTERY_DURATION_SECONDS = 30;

    //===========[ VRF Values ]===========//
    address internal constant SEPOLIA_VRF_CONTRACT_ADDR = 0x9DdfaCa8183c41ad55329BdeeD9F6A8d53168B1B;
    address internal constant SEPOLIA_LINK_TOKEN_ADDR = 0x779877A7B0D9E8603169DdbD7836e478b4624789;
    bytes32 internal constant SEPOLIA_VRF_GAS_LINE = 0x787d74caea10b2b357790d5b5247c2f63d1d91572a9846f780606e4d953677ae;
    uint32 internal constant SEPOLIA_VRF_GAS_LIMIT = 500000;

    //===========[ VRF Mock Values ]===========//
    uint256 internal constant NOT_INITIALIZED_SUBSCRIPTION_ID = 0;
    uint96 internal constant MOCK_BASE_FEE = 0.25 ether;
    uint96 internal constant MOCK_GAS_PRICE_LINK = 1e9;
    int256 internal constant MOCK_WEI_UINT_LINK = 4e15;

    //===========[ Config Values ]===========//
    uint256 internal constant SEPOLIA_CHAIN_ID = 11155111;
    uint256 internal constant LOCAL_CHAIN_ID = 31337;

    //===========[ Config Values ]===========//
    address internal constant NULL_ADDRESS = address(0);

    //===========[ Accounts ]===========//
    address internal constant SEPOLIA_DEV_ACCOUNT = 0xbC7c091f89cd344D0575F3aA05b103bF748fEee1;
    address internal constant ANVIL_DEFAULT_SENDER = 0x1804c8AB1F12E6bbf3894d4083f33e07309d1f38;
}
