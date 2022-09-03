// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@chainlink/contracts/src/v0.8/VRFConsumerBase.sol";

contract CoinToss is VRFConsumerBase {
    bytes32 internal keyHash;
    uint256 internal fee;

    // uint256 can store up to 115792089237316195423570985008687907853269984665640564039457584007913129639935
    // 49.9% probability = (0.499 * (uint256+1))
    uint256 constant probOne =
        57780252529458097711785492504343953926634992332820282019728792003956564819968;
    // 50.1% probability = (0.501 * (uint256+1))
    uint256 constant probTwo =
        58011836707958097711785492504343953926634992332820282019728792003956564819968;

    struct status {
        uint256 side; // 1 = heads, 2 = tails
        bool isWinner;
        uint256 betAmount;
    }

    address public CoinTossCreator;
    mapping(address => status) public playerStatus;
    uint256 public random;
    uint256 private constant NOT_STARTED = 41;
    uint256 private constant ROLL_IN_PROGRESS = 42;
    uint256 private constant COMPLETED = 43;
    uint256 public CoinTossStatus = NOT_STARTED;

    event SidePickStarted(bytes32 indexed requestId);
    event SidePicked(bytes32 indexed requestId);

    constructor(address creator)
        VRFConsumerBase(
            0xb3dCcb4Cf7a26f6cf6B120Cf5A73875B7BBc655B, // VRF Coordinator
            0x01BE23585060835E02B77ef475b0Cc51aA1e0709 // LINK Token
        )
    {
        keyHash = 0x2ed0feb3e7fd2022120aa84fab1945545a9f2ffc9076fd6156fa96eaff4c1311;
        fee = 0.1 * 10**18; // 0.1 LINK
        CoinTossCreator = creator;
    }

    function flipCoin() public returns (bytes32 requestId) {
        require(CoinTossStatus == NOT_STARTED, "CoinFlip already started");
        require(address(this).balance >= 1, "Start conditions not met");
        require(LINK.balanceOf(address(this)) >= fee, "Not enough LINK");

        // If the amount sent by the user is larger than the contract's current balance, return the amount to the user.
        if (playerStatus[msg.sender].betAmount > address(this).balance) {
            payable(address(this)).transfer(playerStatus[msg.sender].betAmount);
        } else {
            requestId = requestRandomness(keyHash, fee);
            CoinTossStatus = ROLL_IN_PROGRESS;
            emit SidePickStarted(requestId);
        }
    }

    function fulfillRandomness(bytes32 requestId, uint256 randomness)
        internal
        override
    {
        random = (randomness % 2) + 1;
        emit SidePicked(requestId);
        CoinTossStatus = COMPLETED;
    }

    function enterHeads() public payable {
        require(msg.value > 0, "Invalid entry betAmount");
        require(CoinTossStatus == NOT_STARTED, "CoinFlip already started");
        require(playerStatus[msg.sender].side == 0, "Player already entered");
        playerStatus[msg.sender].side = 1;
    }

    function enterTails() public payable {
        require(msg.value > 0, "Invalid entry betAmount");
        require(CoinTossStatus == NOT_STARTED, "CoinFlip already started");
        require(playerStatus[msg.sender].side == 0, "Player already entered");
        playerStatus[msg.sender].side = 2;
    }

    function calculateWinnings() public {
        uint256 winAmount = 0;

        // With 49.9% probability, send back twice the amount of the bet to the user.
        // With 50.1% probability, send nothing back to the user.
        if (
            (random <= probOne && playerStatus[msg.sender].side == 1) ||
            (random <= probOne && playerStatus[msg.sender].side == 2)
        ) {
            winAmount = playerStatus[msg.sender].betAmount * 2;
        } else if (
            (random >= probTwo && playerStatus[msg.sender].side == 1) ||
            (random >= probTwo && playerStatus[msg.sender].side == 2)
        ) {
            winAmount = playerStatus[msg.sender].betAmount = 0;
        }
    }

    function getWinnings(uint256 winAmount) public {
        require(playerStatus[msg.sender].isWinner == false);
        require(CoinTossStatus == COMPLETED);
        require(playerStatus[msg.sender].side == random);
        require(playerStatus[msg.sender].betAmount == winAmount);
        playerStatus[msg.sender].isWinner = true;
        payable(msg.sender).transfer(winAmount);
    }
}
