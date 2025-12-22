// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable2Step.sol";

/**
 * @title SecureVault
 * @notice A critical contract holding funds. 
 * Ownership transfer MUST be safe to prevent locking out the admin.
 */
contract SecureVault is Ownable2Step {
    uint256 public constant CRITICAL_FEE = 500; // 5%

    event EmergencyWithdraw(address indexed to, uint256 amount);

    constructor(address initialOwner) Ownable(initialOwner) {}

    /**
     * @dev Critical function only the owner can call.
     * If ownership is lost, these funds are stuck forever.
     */
    function emergencyWithdraw(address to) external onlyOwner {
        uint256 balance = address(this).balance;

        (bool success,) = payable(to).call{value: balance}("");
        require(success, "Withdraw Fail");

        emit EmergencyWithdraw(to, balance);
    }

    // Allow contract to receive ETH
    receive() external payable {}
}