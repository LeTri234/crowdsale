// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "./Token.sol";

contract TimelockToken {
    
    uint public start;
    uint public end;
    
    Token erc20Token;
    
    mapping(address => uint) public deposits;
    
    constructor(address _token) {
        erc20Token = Token(_token);
    }
    
    function setStarttoEnd(uint _start, uint _amountTime) external {
        start = _start;
        end = start + _amountTime;
    }
    
    function deposit(address _from, address _beneficiary, uint _amount) external {
        require(block.timestamp >= start && block.timestamp < end, "Time is out of range");
        deposits[_beneficiary] += _amount;
        erc20Token.transferToTimeLock(_from, address(this) ,_amount);
    }   
    
    function withdraw(address _beneficiary) external {
        require(block.timestamp >= end, "Not ended yet");
        require(deposits[_beneficiary] > 0, "No deposit");
        uint amountToken = deposits[_beneficiary];
        deposits[_beneficiary] = 0;
        erc20Token.transfer(_beneficiary, amountToken);
        erc20Token.approve(_beneficiary, amountToken);
    }
    
}