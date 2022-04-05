// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract TimelockToken {
    
    uint public start;
    uint public end;
    
    IERC20 Token;
    
    mapping(address => uint) public deposits;
    
    constructor(uint _start, uint _end, IERC20 _token) {
        start = _start;
        end = _end;
        Token = _token;
    }
    
    
    function deposit(address _from, uint _amount) external {
        require(block.timestamp >= start && block.timestamp < end, "Time is out of range");
        deposits[_from] += _amount;
        Token.transferFrom(_from, address(this), _amount);
        Token.approve(address(this), _amount);
    }
    
    function withdraw(address _beneficiary) external {
        require(block.timestamp >= end, "Not ended yet");
        require(deposits[_beneficiary] > 0, "No deposit");
        uint token = deposits[_beneficiary];
        deposits[_beneficiary] = 0;
        Token.transfer(_beneficiary, token);
        Token.approve(_beneficiary, token);
    }
    
}