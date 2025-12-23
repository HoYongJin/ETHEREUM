// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";

/**
 * @title LendingPool
 * @notice Demonstrates advanced Role-Based Access Control (RBAC).
 */
contract LendingPool is AccessControl, Pausable {
    // 1. Define Roles using keccak256 hash
    bytes32 public constant RISK_MANAGER_ROLE = keccak256("RISK_MANAGER_ROLE");
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    bytes32 public constant GOVERNANCE_ROLE = keccak256("GOVERNANCE_ROLE");

    // Critical system parameters
    uint256 public interestRate;            // Basis Points(e.g., 500 = 5%)
    uint256 public MAX_RATE = 2000; // 20%

    event interestRateChanged(uint256 oldRate, uint256 newRate);

    constructor(address _admin, address _governance) {
        // 2. Grant initial roles
        // DEFAULT_ADMIN_ROLE is the root admin
        _grantRole(DEFAULT_ADMIN_ROLE, _admin);

        // Governance role can manage other roles later
        _grantRole(GOVERNANCE_ROLE, _governance);

        // Admin also holds pauser for deployment safety
        _grantRole(PAUSER_ROLE, _admin);

        // Initial setup
        interestRate = 500;
    }

    /**
     * @dev Sets the interest rate. Restricted to RISK_MANAGER_ROLE.
     * System must not be paused.
     */
    function setInterestRate(uint256 newRate) 
        external 
        onlyRole(RISK_MANAGER_ROLE) 
        whenNotPaused 
    {
        require(newRate <= MAX_RATE, "Rate too high");
        uint256 oldRate = interestRate;
        interestRate = newRate;
        emit interestRateChanged(oldRate, newRate);
    }

    /**
     * @dev Pauses the system. Restricted to PAUSER_ROLE.
     */
    function pause() external onlyRole(PAUSER_ROLE) {
        _pause();
    }

    /**
     * @dev Unpauses the system. Restricted to DEFAULT_ADMIN_ROLE (Higher security).
     * Even Pausers cannot unpause (Separation of duty).
     */
    function unpause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _unpause();
    }

    /**
     * @dev Advanced: Change the admin of a specific role.
     * We want 'GOVERNANCE_ROLE' to be the one who appoints 'RISK_MANAGERs'.
     * Only DEFAULT_ADMIN can execute this structural change.
     */
    function restructureRiskManagement() 
        external 
        onlyRole(DEFAULT_ADMIN_ROLE) 
    {
        // Current Admin of RISK_MANAGER_ROLE is DEFAULT_ADMIN_ROLE
        // We change it to GOVERNANCE_ROLE
        _setRoleAdmin(RISK_MANAGER_ROLE, GOVERNANCE_ROLE);
    }
}