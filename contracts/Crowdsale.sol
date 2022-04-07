// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "./Token.sol";
import "./TimelockToken.sol";
import "./RefundVault.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
// 0
// 3.000.000  --> 1ETH = 50.000 

// 3000.0000  --> 1ETH = 43750 
// 5500.0000

// 5500.0000  --> 1ETH = 38.000 
// 8000.0000

// 800.0000  --> 1ETH = 35.000 
// 10.000.000

contract Crowdsale is Ownable {
    bool public isCompleted;
    bool public isRefunding;
    
    uint rate1 = 50_000;
    uint rate2 = 43_750;
    uint rate3 = 38_000;
    uint rate4 = 35_000;
    
    uint limitedTier1 = 3000000e18;
    uint limitedTier2 = 5500000e18;
    uint limitedTier3 = 8500000e18;
    uint limitedTier4 = 10000000e18;
    
    uint public start;
    uint public end;
    
    uint public fundingGoal;
    uint public tokenRised;
    uint public minimumValue = 0.1 ether;
    uint public maxEthPaid = 10 ether;
    uint private buyCoolDown = 1 minutes;
    mapping(address => uint) private lastBuy;
    
    uint private investorCount;
    mapping (uint=> address) investors;
    mapping (address => uint) public balances;    
    Token erc20Token;
    TimelockToken timelockToken;
    RefundVault refundVault;
    constructor(address _token, address _timelockToken, address _refundVault, uint _fundingGoal)  {
        erc20Token = Token(_token);
        isCompleted = false;
        isRefunding = false;      
        timelockToken = TimelockToken(_timelockToken);  
        refundVault = RefundVault(payable(_refundVault));
        fundingGoal = _fundingGoal;
    }
    
    function buyToken() external payable {
        validatePurchased();
        uint ethPaid = caculateExcessETH();
        uint tokens;
        if(tokenRised <= limitedTier1){
            tokens = caculateTokenPerTier(ethPaid, 1);
            if(tokens + tokenRised > limitedTier1){
                tokens = caculateExcessToken(ethPaid, limitedTier1, rate1, 1);
            }
        }else if(tokenRised > limitedTier1 && tokenRised <= limitedTier2){
            tokens = caculateTokenPerTier(ethPaid, 2);
            if(tokens + tokenRised > limitedTier2){
                tokens = caculateExcessToken(ethPaid, limitedTier2, rate2, 2);
            }
        }else if(tokenRised >= limitedTier2 && tokenRised <= limitedTier3){
            tokens = caculateTokenPerTier(ethPaid,3);
            if(tokens + tokenRised > limitedTier3){
                tokens = caculateExcessToken(ethPaid, limitedTier3, rate3, 3);
            }
        }else if(tokenRised >= limitedTier3 && tokenRised <= limitedTier4){
            tokens = caculateTokenPerTier(ethPaid,4);
            if(tokens + tokenRised > limitedTier4){
                tokens = caculateExcessToken(ethPaid, limitedTier4, rate4, 4);
            }
        }
        
        if(balances[msg.sender] > 0){
            balances[msg.sender] += tokens;
        }else{
            investors[investorCount] = msg.sender;
            balances[investors[investorCount]] += tokens;
            investorCount++;
        }
        
        tokenRised += tokens;
        lastBuy[msg.sender] = block.timestamp;
    
        refundVault.deposit{value: ethPaid}(msg.sender);
        timelockToken.deposit(erc20Token.owner(), msg.sender, tokens);
        
        checkCompletedCrowdsale();
    }
    
    function caculateExcessETH() internal returns(uint) {
        uint ethPaid = msg.value;
        uint differentWei;
        if(tokenRised >= limitedTier3){
            uint addedToken = tokenRised + (ethPaid * rate4);
            if(addedToken > limitedTier4){
                uint different = addedToken - limitedTier4;
                differentWei = different / rate4;
                ethPaid = ethPaid - differentWei;
            }
        }
        
        if(differentWei > 0){
            (bool success,) = msg.sender.call{value: differentWei}("");
            require(success);
        }
        
        return ethPaid;
    }
    
    function setStartToEnd(uint _start, uint _amountTime) public onlyOwner {
        require(_start > block.timestamp);
        require(_start + _amountTime > block.timestamp);
        start = _start;
        end = start + _amountTime;
    }
    
    function caculateExcessToken(uint _ethPaid, uint _limitTier, uint _rate,uint _tierSelected) internal returns(uint) {
        require( _ethPaid > 0 && _limitTier > 0 && _rate > 0);
        require(_tierSelected >= 1 && _tierSelected <= 4);
        
        uint ethThisTier = (_limitTier - tokenRised) / _rate;
        uint ethNextTier = _ethPaid - ethThisTier;
        uint tokenNextTier;
        bool refundToken;
        
        if(_tierSelected != 4){
            refundToken = false;
            tokenNextTier = caculateTokenPerTier(ethNextTier, uint(_tierSelected +1));
        }else{
            refundToken = true;
        }
        
        if(refundToken){
            (bool success,) = msg.sender.call{value: ethNextTier}("");
            require(success);
        }
        
        uint totalToken = _limitTier - tokenRised + tokenNextTier;
        
        return totalToken;
    }
    
    function caculateTokenPerTier(uint _ethPaid, uint tier) private view returns(uint) {
        require(tier >=1 && tier <= 4);
        require(_ethPaid >= minimumValue, "Minimum value is 0.1 ether");
        uint caculatedToken;
        
        if(tier == 1){
            caculatedToken = _ethPaid * rate1;
        }else if(tier == 2){
            caculatedToken = _ethPaid * rate2;
        }else if(tier == 3){
            caculatedToken = _ethPaid * rate3;
        }else if(tier == 4){
            caculatedToken = _ethPaid * rate4;
        }
        return caculatedToken;
    }
    
    function validatePurchased() private {
        bool hasNotEnd = !hasEnd();
        bool minimumPaid = msg.value >= minimumValue;
        bool maxPaid = msg.value <= maxEthPaid;
        bool timeOut = (block.timestamp - (buyCoolDown + lastBuy[msg.sender])) >= 0;
        require(hasNotEnd && minimumPaid && timeOut && maxPaid, "Cannot buy token");
    }
    
    function checkCompletedCrowdsale() public returns(bool) {
        if(!isCompleted){
            if(hasEnd() && !reachedGoal()){
                isRefunding = true;
                isCompleted = true;
                refundVault.enableRefund();
            }else if(hasEnd() && reachedGoal()){
                isCompleted = true;
                if(tokenRised < limitedTier4) {
                    uint tokenBurn = limitedTier4 - tokenRised;
                    erc20Token.burnExcessTokenAfterSale(erc20Token.owner() ,tokenBurn);
                }
            }
        }
        return isCompleted;
    }

    function crowdsaleCompleted() public onlyOwner returns(bool) {
        require(isCompleted, "Crowdsale is not completed");
        if(isCompleted && isRefunding){
            for(uint i = 0; i < investorCount; i++){
                address account = investors[i];
                balances[account] = 0;
                refundVault.refund(account);
                timelockToken.burnToken(account);
            }
            return true;
        }else if(isCompleted && reachedGoal()){
            refundVault.close();
             for(uint i = 0; i < investorCount; i++){
                address account = investors[i];
                balances[account] = 0;
                timelockToken.withdraw(account);
            }
            return true;
        }
        return false;
    }
    
    function getRemainingTime() external view returns(uint){
        return end - block.timestamp;
    }

    function hasEnd() public view returns(bool){
        return block.timestamp > end || tokenRised >= fundingGoal;
    }

    function reachedGoal() public view returns(bool){
        return tokenRised >= fundingGoal;
    }
    
    function getTotalInvestor() public view returns(uint){
        return investorCount;
    }
    
    function getEthVaultBalance() public view returns(uint){
        return refundVault.getVaultBalances();
    }
    
}


// 