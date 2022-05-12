// Forge Guess - Contract
//
// Forge Guess allows users to guess a number 1-97 and hope a random number 1-100 is lower.  
// Odds and bet maximums are calculated automatically at the contract level. Forge tokens using chainlink VRF.
// House edge of 0.5% - 7% depending on bet size.
//
// Forge Guess gives 100% of all profits to investors of the contract. 
// Invest Forge and become the house and make Forge when users use this contract!
// 2.5% Withdrawl fee goes 100% back to investors to promote longeviity!


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
    //Guess Storage
    uint256 public betid = 0;
    uint256 public betidIN = 0;
    mapping(uint256 => uint256) public betResults;
    mapping(uint256 => uint256) public blockNumForBetID;
    mapping(uint256 => uint256) public betAmt;
    mapping(uint256 => uint256) public betOdds;
    mapping(uint256 => uint256) public randomNumber;
    mapping(uint256 => address) public betee;
    mapping(uint256 => uint256) public winnings;
    mapping(address => int) public profitz;
    mapping(address => int) public profitzGuess;

    uint256 public randomResult;
    uint256 public unreleased = 0;
    uint256 public totalSupply = 1;
    
    mapping(address => uint256) private _balances;
    
    IERC20 public stakedToken = IERC20(0xbF4493415fD1E79DcDa8cD0cAd7E5Ed65DCe7074);
    
    event Staked(address indexed user, uint256 amount);
    event Withdrawn(address indexed user, uint256 amount);
    event GuessNote(uint256 UsersGuess, uint256 amount, address indexed user, uint256 betID);
    event ShowAnswer(uint256 UsersGuess, uint256 Result, uint256 amountWagered, uint256 betID, address indexed AddressOfGuesser, uint256 AmountWon, uint256 chainlinkRandom);
    
    
    
    function balanceOf(address account) public view returns (uint256) {
        return _balances[account];
    }
    
    string constant _transferErrorMessage = "staked token transfer failed";
    
    /**
     * Constructor inherits VRFConsumerBase
     * 
     * Network: Mumbai
     * Chainlink VRF Coordinator address: 0x8C7382F9D8f56b33781fE506E897a4F1e2d17255
     * LINK token address:                0x326C977E6efc84E512bB9C30f76E30c160eD06FB
     * Key Hash: 0x6e75b569a01ef56d18cab6a8e71e6600d6ce853834d4a5748b720d06f878b3a4
     */
    constructor() 
        VRFConsumerBase(
            0x8C7382F9D8f56b33781fE506E897a4F1e2d17255, // VRF Coordinator
            0x326C977E6efc84E512bB9C30f76E30c160eD06FB  // LINK Token
        )
    {
        
        keyHash = 0x6e75b569a01ef56d18cab6a8e71e6600d6ce853834d4a5748b720d06f878b3a4;
        fee = 1 * 10 ** 14; // 0.0001 LINK
    }
    
    /** 
     * Requests randomness 
     */
    function getRandomNumber(uint256 guess, uint256 amt, uint256 extraLINK) public returns (bytes32 requestId) {
        uint256 esT = estOUTPUT(amt, guess);
        require(amt < esT, "You will loose money everytime at these settings");
        require(amt >= 10**18, "Min bet 1 Forge");
        require(extraLINK >= 1, "Must send at least the minimum 0.0001"); //Allows increase in fees to be handled
        require(MaxINForGuess(guess) >= amt , "Bankroll too low for this bet, Please lower bet"); //MaxBet Amounts   
        require(guess<98 && guess > 0, "Must guess between 1-98");
        require(stakedToken.transferFrom(msg.sender, address(this), amt), "Transfer must work");
        
        uint256 lBal = LINK.balanceOf(address(this));
        //Free chainlink for player rolls
        if(extraLINK > 1){
        LINK.transferFrom(msg.sender, address(this), (fee * (extraLINK-1)));
        }
        if(amt < (10 * 10 ** 18)){
            LINK.transferFrom(msg.sender, address(this), fee * extraLINK);
        }else if(amt < 50 * 10 ** 18 ){
            if(betidIN > 100000 || lBal < fee * 21){  //Must seed with 10 link = 100,000 * 0.0001 = 10 LINK
                LINK.transferFrom(msg.sender, address(this), fee * extraLINK);
            }
        }else if(guess <= 93)
        {
            if(lBal < fee*21 ){
                LINK.transferFrom(msg.sender, address(this), fee * extraLINK);
            }
        }else
        {
            if(lBal < fee*21 ){
                LINK.transferFrom(msg.sender, address(this), fee * extraLINK);
            }
        }
        betOdds[betidIN] = guess;
        betAmt[betidIN] = amt;
        betee[betidIN] = msg.sender;
        winnings[betidIN] = esT;
        profitzGuess[msg.sender] -= int(amt);
        blockNumForBetID[betidIN] = block.number;
        emit GuessNote(guess, amt, msg.sender, betidIN);
        betidIN++;
        unreleased +=  amt;
        return requestRandomness(keyHash, fee * extraLINK);
    }

    function lastBlockFilled() public view returns (uint256){
        if(betid == betidIN){
            return block.number;
        }
        return blockNumForBetID[betid];
    }

    // Max AMT for a certien guess
     function MaxINForGuess(uint256 guess) public view returns (uint256){
         //AT 50% chance u get 1/23 of bankroll to bet
         uint256 ret = ((IERC20(address(stakedToken)).balanceOf(address(this)) - unreleased) * guess) / (50 * 21);
         return ret;
     }

function penalty () public view returns (uint num){

      uint tot = 0;
      for(uint x = betid; x<betidIN; x++){
          tot += winnings[x];
      }
      
      return tot;
 }
 
    //Incase of Chainlink failure
    function getBlank(uint256 extraLINK) public returns (bytes32 requestId) {
        LINK.transferFrom(msg.sender, address(this), fee * extraLINK);

        return requestRandomness(keyHash, fee * extraLINK);
    }

    /**
     * Callback function used by VRF Coordinator
     */
    function fulfillRandomness(bytes32 requestId, uint256 randomness) internal override {
        if(betid >= betidIN){
            return;
        }
        
        require(betid < betidIN, "Must have new bets");
        
        randomNumber[betid] = randomness;
        betResults[betid] = randomness % 100;
        address Guesser = betee[betid];
        uint256 odds = betOdds[betid];
        uint256 betAmount = betAmt[betid];
        uint256 esT = winnings[betid];
        if(randomness%100 < odds){
            profitzGuess[Guesser] += int(esT);
            stakedToken.transfer(Guesser, esT);
        }else{
            stakedToken.transfer(Guesser, 1);
            profitzGuess[Guesser] += int(1);
            winnings[betid] = 1;
        }
        unreleased -= betAmount;
        emit ShowAnswer(odds, randomness%100, betAmount,  betid, Guesser, winnings[betid], randomness);
        betid++;
    }

    //Stake and become the house
    function stakeFor(address forWhom, uint256 amount) public virtual {
        IERC20 st = stakedToken;
        require(amount > 0, "Cannot stake 0");

        unchecked { 
            uint toAdd = (amount * totalSupply) / (IERC20(address(stakedToken)).balanceOf(address(this)) - unreleased);
            _balances[forWhom] += toAdd;
            totalSupply += toAdd;
            profitz[forWhom] -= int(amount);
        }
        
        require(st.transferFrom(msg.sender, address(this), amount), _transferErrorMessage);
            
        emit Staked(forWhom, amount);
    }

    function maxGuessPerInput(uint guess, uint amt) public view returns(uint){
        uint x = 0;
    
        for(x =0; x<90; x++){
            if(MaxINForGuess(98-x) < amt){
                amt = MaxINForGuess(99-x);
            }
            if(estOUTPUT(amt, 99 - x) > amt){
                break;
            }
        }
        return 99 - x;
    }

    //Output Amount of payout based on odds and bet
    function estOUTPUT(uint256 betAmount, uint256 odds) public view returns (uint256){
        uint256 ratioz = (IERC20(address(stakedToken)).balanceOf(address(this)) - unreleased) * 50 / (betAmount * odds);
        uint256 estOutput = 0;
            if(ratioz < 30){

            estOutput = (100 * 90 * betAmount)/(odds*100);

            }else if(ratioz < 50){

            estOutput = (100 * 93 * betAmount)/(odds * 100);
                
            }else if(ratioz < 100){

            estOutput = (100 * 96 * betAmount)/(odds * 100);
                
            }else if(ratioz < 200){

            estOutput = (100 * 98 * betAmount)/(odds * 100);
            
            }else if(ratioz < 400){

            estOutput = (100 * 99 * betAmount)/(odds * 100);

            }else if (ratioz < 1000){
                
            estOutput = (100 * 995 * betAmount)/(odds * 1000);

            }else {
                
            estOutput = (100 * 99 * betAmount)/(odds * 100);

            }
            
            return estOutput;

     }

    //Withdrawl Estimator
    function withEstimator(uint256 amountOut) public view returns (uint256) {
        uint256 v = (975 * uOut(amountOut) / 1000);
        return v;
    }
    

        
    
    //Prevents you from withdrawing if large bets in play
    function perfectWithdraw(uint maxLoss) public {
    
         withdraw(balanceOf(msg.sender), maxLoss);
       
        
    }

    function uOut(uint amount)public view returns (uint tot){
    
        var stakeMinusUnreleased = (IERC20(address(stakedToken)).balanceOf(address(this) - unreleased);
        
        uint256 amt = amount * stakeMinusUnreleased / totalSupply ;
        
        uint maxPain = penalty() / stakeMinusUnreleased;
        
        uint tot = amt -  amt / stakeMinusUnreleased * maxPain;

    return tot;
    }
    
    
    //2.5% fee on withdrawls back to holders
    //Withdrawl function for house
    function withdraw(uint256 amount, uint256 maxLoss) public virtual {
          if(maxLoss<penalty()){
           return;
          }
        
        require(amount <= _balances[msg.sender], "withdraw: balance is lower");
        
        uint OutEst = uOut(amount);

        unchecked {
            _balances[msg.sender] -= OutEst;
            totalSupply = totalSupply - OutEst;
            profitz[msg.sender] += int(OutEst * 975 / 1000);
        }
        
        require(stakedToken.transfer(address(this), (OutEst * 25 / 1000)));
        require(stakedToken.transfer(msg.sender, ((OutEst * 975) / 1000)));
        
        emit Withdrawn(msg.sender, amount);
    }    

    function Profit(address user) public view returns(int) {
        uint256 withdrawable = withEstimator(balanceOf(user));
        int profit = profitz[user] + int(withdrawable);
        return profit;
    }

    function blockNumber() public view returns(uint) {
        return block.number;
    }
}

/*
*
* MIT License
* ===========
*
* Copyright (c) 2022 Forge
*
* Permission is hereby granted, free of charge, to any person obtaining a copy
* of this software and associated documentation files (the "Software"), to deal
* in the Software without restriction, including without limitation the rights
* to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
* copies of the Software, and to permit persons to whom the Software is
* furnished to do so, subject to the following conditions:
*
* The above copyright notice and this permission notice shall be included in all
* copies or substantial portions of the Software.   
*
* THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
* IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
* FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
* AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
* LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
* OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
*/
