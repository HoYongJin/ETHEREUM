// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";


// 1. Vault: Can receive and send ETH (for testing payable calls)
contract Treasury is Ownable {
    uint256 public totalReleased;

    // Required to receive ETH
    receive() external payable {}

    constructor() Ownable(msg.sender) {}

    function release(address to, uint256 amount) external payable onlyOwner{
        require(address(this).balance >= amount, "Insufficient ETH");
        
        (bool sent, ) = to.call{value: amount}("");
        require(sent, "ETH Transfer failed");
        
        totalReleased += amount;
    }
}

// 2. Config: Changes state and throws errors (for testing logic & errors)
contract SystemConfig is Ownable{
    uint256 public taxRate;

    constructor() Ownable(msg.sender) {}

    function setTaxRate(uint256 newRate) external onlyOwner returns(uint256) {
        // Simulate an error condition
        require(newRate <= 100, "Rate too high");
        
        uint256 oldRate = taxRate;
        taxRate = newRate;
        
        return oldRate; // Return previous value (for testing return data decoding)
    }
}