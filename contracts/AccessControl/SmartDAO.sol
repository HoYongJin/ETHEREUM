// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./SecureVault.sol";

contract SmartDAO {
    // Allows this contract to accept ownership of a target vault
    function claimVaultOwnership(address _vault) external {
        // This call will fail if this contract is not the 'pendingOwner' of _vault
        SecureVault(payable(_vault)).acceptOwnership();
    }

    // Function to prove DAO is the new owner
    function executeWithdraw(address _vault, address _to) external {
        SecureVault(payable(_vault)).emergencyWithdraw(_to);
    }

    receive() external payable {}
}