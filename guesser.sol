// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "@chainlink/contracts/src/v0.8/VRFConsumerBase.sol";

/**
 * Request testnet LINK and ETH here: https://faucets.chain.link/
 * Find information on LINK Token Contracts and get the latest ETH and LINK faucets here: https://docs.chain.link/docs/link-token-contracts/
 */
 interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address recipient, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
    
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
}

contract ForgeGuess is VRFConsumerBase {
    
    bytes32 internal keyHash;
    uint256 internal fee;
    uint256 public betid = 0;
    uint256 public betidIN = 0;
    //Guess Storage
    mapping(uint256 => uint256) public betResults;
    mapping(uint256 => uint256) public betAmt;
    mapping(uint256 => uint256) public betOdds;
    mapping(uint256 => uint256) public randomNumber;
    mapping(uint256 => address) public betee;
    mapping(uint256 => uint256) public winnings;
    uint256 public randomResult;
    uint256 public unreleased=0;
    uint256 public totalSupply = 1;
    uint256 public wagered = 0;
    bool initeds = false;
    mapping(address => uint256) private _balances;
    IERC20 public stakedToken = IERC20(0xbF4493415fD1E79DcDa8cD0cAd7E5Ed65DCe7074);
    
    event Staked(address indexed user, uint256 amount);
    event Withdrawn(address indexed user, uint256 amount);
    event GuessNote(uint256 UsersGuess, uint256 amount, address indexed user, uint256 betID);
    event ShowAnswer(uint256 UsersGuess, uint256 Result, uint256 amountWagered, uint256 betID, address indexed AddressOfGuesser, uint256 AmountWon);
    function balanceOf(address account) public view returns (uint256) {
        return _balances[account];
    }
    

    string constant _transferErrorMessage = "staked token transfer failed";
    
    /**
     * Constructor inherits VRFConsumerBase
     * 
     * Network: Kovan
     * Chainlink VRF Coordinator address: 0xdD3782915140c8f3b190B5D67eAc6dc5760C46E9
     * LINK token address:                0xa36085F69e2889c224210F603D836748e7dC0088
     * Key Hash: 0x6c3699283bda56ad74f6b855546325b68d482e983852a7a82979cc4807b641f4
     */
    constructor() 
        VRFConsumerBase(
            0x8C7382F9D8f56b33781fE506E897a4F1e2d17255, // VRF Coordinator
            0x326C977E6efc84E512bB9C30f76E30c160eD06FB  // LINK Token
        )
    {
        
        keyHash = 0x6e75b569a01ef56d18cab6a8e71e6600d6ce853834d4a5748b720d06f878b3a4;
        fee = 0.0001 * 10 ** 18; // 0.0001 LINK
    }
    
    /** 
     * Requests randomness 
     */
    function getRandomNumber(uint256 guess, uint256 amt) public returns (bytes32 requestId) {
        require(MaxINForGuess(guess) >= amt , "Bankroll too low for this bet, Please lower bet"); //Plays off 1/11th of the bankroll
        require(guess<98, "Must guess lower than 98");
        require(stakedToken.transferFrom(msg.sender, address(this), amt), "Transfer must work");
        uint256 lBal = LINK.balanceOf(address(this));
        if(amt < 1 * 10 ** 18){
            LINK.transferFrom(msg.sender, address(this), fee);
        }else if(amt < 50 * 10 ** 18 ){
            if(betidIN > 100000 || lBal < fee * 9){  //Must seed with 10 link = 100,000 * 0.0001 = 10 LINK
                LINK.transferFrom(msg.sender, address(this), fee);
            }
        }else if(guess <= 93)
        {
            if(lBal < fee*9 ){
                LINK.transferFrom(msg.sender, address(this), fee);
            }
        }else
        {
            if(lBal < fee*9 ){
                LINK.transferFrom(msg.sender, address(this), fee);
            }
        }
        betOdds[betidIN] = guess;
        betAmt[betidIN] = amt;
        betee[betidIN] = msg.sender;
        emit GuessNote(guess, amt, msg.sender, betidIN);
        betidIN++;
        unreleased +=  amt;
        wagered += amt;
        return requestRandomness(keyHash, fee);
    }


    // Max AMT for a certien guess
     function MaxINForGuess(uint256 guess) public view returns (uint256){
         uint256 ret = ((stakedToken.balanceOf(address(this)) - unreleased) * guess) / (50 * 20);
         return ret;
     }


    //Incase of Chainlink failure
    function getBlank() public returns (bytes32 requestId) {
        LINK.transferFrom(msg.sender, address(this), fee);

        return requestRandomness(keyHash, fee);
    }


    /**
     * Callback function used by VRF Coordinator
     */
    function fulfillRandomness(bytes32 requestId, uint256 randomness) internal override {
        if(betid >= betidIN){
            return;
        }
        require(betid < betidIN, "Must have new bets");
        randomResult = randomness;
        randomNumber[betid] = randomness;
        betResults[betid] = randomness % 100;
        address Guesser = betee[betid];
        uint256 odds = betOdds[betid];
        uint256 betAmount = betAmt[betid];
        if(randomness%100 < odds){
            winnings[betid]=estOUTPUT(betAmount, odds);
            stakedToken.transfer(Guesser, winnings[betid]);
        }else{
            stakedToken.transfer(Guesser, 1);
            winnings[betid] = 1;
        }
        unreleased -= betAmount;
        emit ShowAnswer(odds, randomness%100, betAmount,  betid, Guesser, winnings[betid]);
        betid++;
    }


    //Stake and become the house
    function stakeFor(address forWhom, uint256 amount) public payable virtual {
        IERC20 st = stakedToken;
        require(msg.value == 0, "non-zero eth");
        require(amount > 0, "Cannot stake 0");
        unchecked { 
            _balances[forWhom] += (amount * totalSupply) / (stakedToken.balanceOf(address(this)) - unreleased);
            totalSupply += (amount * totalSupply ) / (stakedToken.balanceOf(address(this)) - unreleased);
        }
        
        require(st.transferFrom(msg.sender, address(this), amount), _transferErrorMessage);
            
        emit Staked(forWhom, amount);
    }

    //Output Amount of payout based on odds and bet
    function estOUTPUT(uint256 betAmount, uint256 odds) public view returns (uint256){
        uint256 ratioz = (stakedToken.balanceOf(address(this)) - unreleased) / betAmount;
        uint256 estOutput = 0;
            if(ratioz < 20){  

            estOutput = (100 * 93 *  betAmount)/(odds * 100);
            }else if(ratioz < 50){

            estOutput = (100 * 95 * betAmount)/(odds*100);

            }else if(ratioz < 100){

            estOutput = (100 * 98 * betAmount)/(odds * 100);
                
            }else if(ratioz < 150){

            estOutput = (100 * 985 * betAmount)/(odds * 1000);
                
            }else if(ratioz < 300){

            estOutput = (100 * 990 * betAmount)/(odds * 1000);
            }else{

            estOutput = (100 * 995 * betAmount)/(odds * 1000);
                
            }
            return estOutput;

     }

    //Withdrawl Estimator
    function withEstimator(uint256 amountOut) public view returns (uint256) {
        uint256 v = (98 * amountOut * (stakedToken.balanceOf(address(this)) - (unreleased * 5 / 3)) / 100 / totalSupply);
        return v;
    }

    //Prevents you from withdrawing if large bets in play
    function perfectWithdraw(uint256 thres)public {
        if(betidIN - betid < thres ){
            withdraw(balanceOf(msg.sender));
        }
    }

    //2% fee on withdrawls back to holders
    //Withdrawl function for house
    function withdraw(uint256 amount) public virtual {
        require(amount <= _balances[msg.sender], "withdraw: balance is lower");
        uint256 amt = amount * (stakedToken.balanceOf(address(this)) - (unreleased * 5 / 3)) / totalSupply ;
        require(stakedToken.transfer(address(this), (amt / 50)));
        require(stakedToken.transfer(msg.sender, amt * 49 / 50));
        unchecked {
            _balances[msg.sender] -= amount;
            totalSupply = totalSupply - amount;
        }
           
        emit Withdrawn(msg.sender, amount);
    }
}
