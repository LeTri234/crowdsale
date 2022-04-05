//SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract RefundVault is Ownable, ReentrancyGuard {
    enum VaultState {Active, Refunding, Closed}
    mapping(address => uint) public deposited;
    
    VaultState public state;
    address public wallet;
    address public crowdsale;
    
    event Closed();
    event RefundEnabled();
    event Refunded(address indexed beneficiary, uint amount);
    
    constructor(address _wallet, address _crowdsale) {
        require(_wallet != address(0), "Wallet cannot be the zero address");
        require(_crowdsale != address(0), "Crowdsale cannot be the zero address");
        wallet = _wallet;
        state = VaultState.Active;
    }
    
    receive() external payable{}
    
    modifier onlyCrowsale() {
        require(msg.sender == crowdsale, "Only the crowdsale can modify the vault");
        _;
    }
    
    function setCrowdsale(address _crowdsale) onlyOwner external {
        crowdsale = _crowdsale;
    }
    
    function deposit(address beneficiary) external payable onlyCrowsale {
        require(beneficiary != address(0), "Beneficiary cannot be the zero address");
        require(msg.value > 0, "Amount must be greater than zero");
        require(state == VaultState.Active, "Vault is not active");
        deposited[beneficiary] += msg.value;
    }
        
    function close() external onlyCrowsale {
        require(state == VaultState.Active, "Vault is not active");
        state = VaultState.Closed;
        (bool success,) = wallet.call{value: address(this).balance}("");
        require(success, "Cannot tranfer ETH from the vault");
        emit Closed();
    }
    
    function enableRefund() external onlyCrowsale {
        require(state == VaultState.Active, "Vault is not active");
        state = VaultState.Refunding;
        emit RefundEnabled();
    }
    
    function refund(address beneficiary) external onlyCrowsale nonReentrant() {
        require(state == VaultState.Refunding, "Vault is not refunding");
        uint ethRefund = deposited[beneficiary];
        deposited[beneficiary] = 0;
        (bool success,) = beneficiary.call{value: ethRefund}("");
        require(success, "Cannot tranfer ETH from the vault");
        emit Refunded(beneficiary, ethRefund);
    }
    
     function getVaultBalances() external view returns(uint){
        return address(this).balance;
    }
        
}
    
