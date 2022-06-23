// SPDX-License-Identifier: MIT
pragma solidity ^0.8.6;

import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@chainlink/contracts/src/v0.8/VRFConsumerBaseV2.sol";
import "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";


contract Lottery is VRFConsumerBaseV2, Ownable {
    VRFCoordinatorV2Interface COORDINATOR;

    address payable[] public players;
    address payable public recentWinner;
    uint256 public randomness;
    uint256 public usdEntryFee;
    

    enum LOTTERY_STATE {
        OPEN,
        CLOSED,
        CALCULATING_WINNER
    }
    LOTTERY_STATE lottery_state;

    event RequestedRandomness(uint256 s_requestId);

    // 0
    // 1
    // 2
    
    AggregatorV3Interface internal priceFeed;
    address s_owner;
    uint64 s_subscriptionId;
    address vrfCoordinator = 0x6168499c0cFfCaCD319c818142124B7A15E857ab;
    bytes32 keyHash = 0xd89b2bf150e3b9e13446986e571fb9cab24b13cea0a43ea20a6049a85cc807cc;
    uint32 callbackGasLimit = 100000;
    uint16 requestConfirmations = 3;
    uint32 numWords =  2;
    uint256 public s_requestId;
    uint256[] public s_randomWords;

    constructor(uint64 subscriptionId) VRFConsumerBaseV2(vrfCoordinator) {
        priceFeed = AggregatorV3Interface(0x8A753747A1Fa494EC906cE90E9f37563A8AF630e);
        usdEntryFee = 50 * (10**18);
        COORDINATOR = VRFCoordinatorV2Interface(vrfCoordinator);
        s_owner = msg.sender;
        s_subscriptionId = subscriptionId;
        lottery_state = LOTTERY_STATE.CLOSED;
    }
    
    function get_lotterystate() external view returns(string memory){
        if(LOTTERY_STATE.OPEN == lottery_state) return 'OPEN';
        if(LOTTERY_STATE.CLOSED == lottery_state) return 'CLOSED';
        if(LOTTERY_STATE.CALCULATING_WINNER == lottery_state) return 'CALCULATING_WINNER';
        return "";
    }

    function enter() public payable {
        // $50 minimum
        require(lottery_state == LOTTERY_STATE.OPEN);
        require(msg.value >= getEntranceFee(), "Not enough ETH!");
        players.push(payable(msg.sender));
    }



    function getEntranceFee() public view returns (uint) {
        (
            /*uint80 roundID*/,
            int price,
            /*uint startedAt*/,
            /*uint timeStamp*/,
            /*uint80 answeredInRound*/
        ) = priceFeed.latestRoundData();
        uint256 adjustedPrice = uint256(price) * 10**10; // 18 decimals
        // $50, $2,000 / ETH
        // 50/2,000
        // 50 * 100000 / 2000
        uint256 costToEnter = (usdEntryFee * 10**18) / adjustedPrice;
        return costToEnter;
    }

    function startLottery() public onlyOwner {
        require(
            lottery_state == LOTTERY_STATE.CLOSED,
            "Can't start a new lottery yet!"
        );
        lottery_state = LOTTERY_STATE.OPEN;
    }

    function endLottery() public onlyOwner {
        // uint256(
        //     keccack256(
        //         abi.encodePacked(
        //             nonce, // nonce is preditable (aka, transaction number)
        //             msg.sender, // msg.sender is predictable
        //             block.difficulty, // can actually be manipulated by the miners!
        //             block.timestamp // timestamp is predictable
        //         )
        //     )
        // ) % players.length;
        lottery_state = LOTTERY_STATE.CALCULATING_WINNER;
        s_requestId = COORDINATOR.requestRandomWords(
            keyHash,
            s_subscriptionId,
            requestConfirmations,
            callbackGasLimit,
            numWords
        );
        emit RequestedRandomness(s_requestId);

    }

    function fulfillRandomWords(
        uint256, /* requestId */
        uint256[] memory randomWords) internal override {
    s_randomWords = randomWords;
    }


    function fulfillRandomness() public
    {
        randomness = s_randomWords[0];
        require(
            lottery_state == LOTTERY_STATE.CALCULATING_WINNER,
            "You aren't there yet!"
        );
        require(randomness > 0, "random-not-found");
        uint256 indexOfWinner = randomness % players.length;
        recentWinner = players[indexOfWinner];
        recentWinner.transfer(address(this).balance);
        // Reset
        players = new address payable[](0);
        lottery_state = LOTTERY_STATE.CLOSED;
    }
}