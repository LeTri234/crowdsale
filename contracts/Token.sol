// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract Token is ERC20, ERC20Burnable, Ownable {
    address crowdsale;
    address timelock;
    
    constructor() ERC20("MyToken", "MTK") {
        _mint(msg.sender, 10_000_000 * 10 ** decimals());
    }

    function mint(address to, uint256 amount) public onlyOwner {
        _mint(to, amount);
    }
    
    function setCrowdsaleTimelockAddress(address _crowdsale, address _timelock) public onlyOwner {
        crowdsale = _crowdsale;
        timelock = _timelock;
    }
    
    modifier onlyCrowsale() {
        require(msg.sender == crowdsale, "Only the crowdsale can modify the vault");
        _;
    }

    modifier onlyTimelock() {
        require(msg.sender == timelock, "Not timelock address");
        _;
    }
    
    
    function transferToTimeLock(address _owner, address _to,uint256 _amount) external onlyTimelock {
        _transfer(_owner, _to, _amount);
        _approve(_owner, _to, allowance(_owner, _to) + _amount);
        emit Transfer(_owner, _to, _amount);
    }

    function burnTimelockToken(address account, uint amount) external onlyTimelock {
        _burn(account, amount);
        } 
    
    function burnExcessTokenAfterSale(address _owner, uint256 _amount) external onlyCrowsale {
        _burn(_owner, _amount);
        _spendAllowance(_owner, _owner, _amount);
        emit Transfer(_owner, address(0), _amount);
    }
    
}