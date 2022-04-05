// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "./Token.sol";
import "./TimelockToken.sol";
import "./RefundVault.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
// 0
// 3.000.000  --> 1ETH = 50.000 --> 60

// 3000.0000  --> 1ETH = 43750 --> 57.2
// 5500.0000

// 5500.0000  --> 1ETH = 38.000 --> 65,78
// 8000.0000

// 800.0000  --> 1ETH = 35.000 --> 57,14
// 10.000.000

contract Crowdsale is Ownable {
    bool public isCompleted;
    bool public isRefunding;
    
    uint rate1 = 50_000;
    uint rate2 = 43_750;
    uint rate3 = 38_000;
    uint rate4 = 35_000;
    
    uint limitedTier1 = 3_000_000;
    uint limitedTier2 = 5_500_000;
    uint limitedTier3 = 8_500_000;
    uint limitedTier4 = 10_000_000;
    
    uint public start;
    uint public end;
    
    uint public fundingGoal;
    uint public tokenRised;
    uint public ethRised;
    uint public minimumValue = 0.1 ether;
    uint private buyCoolDown = 1 minutes;
    mapping(address => uint) private lastBuy;
    
    uint private investorCount;
    mapping (uint=> address) investors;
    mapping (address => uint) public balances;    
    Token erc20Token;
    TimelockToken timelockToken;
    RefundVault refundVault;
    constructor(address _token, address _timelockToken, address _refundVault, uint _start, uint _end, uint _fundingGoal)  {
        start = _start;
        end = _end;
        erc20Token = Token(_token);
        isCompleted = false;
        isRefunding = false;      
        timelockToken = TimelockToken(_timelockToken);  
        refundVault = RefundVault(payable(_refundVault));
        fundingGoal = _fundingGoal;
    }
    
    function buyToke() external payable {
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
        
        tokenRised += tokens;
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
        require(hasNotEnd && minimumPaid, "The purchase has ended");
    }
    function hasEnd() public view returns(bool){
        return block.timestamp > end || tokenRised >= fundingGoal;
    }

}




