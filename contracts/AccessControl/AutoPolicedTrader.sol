// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/AccessControl.sol";

/**
 * @title AutoPolicedTrader
 * @notice Demonstrates 'Self-Revocation' logic based on behavior.
 */
contract AutoPolicedTrader is AccessControl {
    bytes32 public constant TRADER_ROLE = keccak256("TRADER_ROLE");
    bytes32 public constant COMPLIANCE_ROLE = keccak256("COMPLIANCE_ROLE");
    bytes32 public constant DIRECTOR_ROLE = keccak256("DIRECTOR_ROLE");

    // Strike count for each trader
    mapping(address => uint256) public strikes;
    uint256 public constant MAX_STRIKE = 3;

    event TradeExecuted(address indexed trader, uint256 amount);
    event ViolationReported(address indexed trader, address indexed reporter, uint256 currentStrikes);
    event TraderBanned(address indexed trader);

    constructor(address _director, address _complianceBot) {
        // 1. Setup Hierarchy
        _grantRole(DEFAULT_ADMIN_ROLE, _msgSender());

        _grantRole(DIRECTOR_ROLE, _director);
        _grantRole(COMPLIANCE_ROLE, _complianceBot);

        // 2. Advanced: Define who manages whom
        // TRADER_ROLE is managed by DIRECTOR_ROLE
        _setRoleAdmin(TRADER_ROLE, DIRECTOR_ROLE);
    }

    // --- Trader Action ---
    function executeTrade(uint256 amount) external onlyRole(TRADER_ROLE) {
        // Business logic...
        emit TradeExecuted(_msgSender(), amount);
    }

    // --- Compliance Action (The Self-Policing Logic) ---
    /**
     * @dev Compliance role reports a violation.
     * If strikes reach limit, the CONTRACT ITSELF revokes the role.
     */
    function reportViolation(address trader) external onlyRole(COMPLIANCE_ROLE) {
        // Ensure target is actually a trader
        require(hasRole(TRADER_ROLE, trader), "Target is not a trader");

        strikes[trader]++;
        uint256 currentStrikes = strikes[trader];

        emit ViolationReported(trader, _msgSender(), currentStrikes);

        // Programmatic Access Control
        // If 3 strikes, perform "internal revocation"
        if(currentStrikes >= MAX_STRIKE) {
            _banTrader(trader);
        }
    }

    // --- Director Action ---
    function resetStrikes(address trader) external onlyRole(DIRECTOR_ROLE) {
        strikes[trader] = 0;
    }

    // --- Internal Helpers ---
    function _banTrader(address trader) internal {
        // Note: We use '_revokeRole' because 'revokeRole' requires msg.sender to be the Admin. 
        // Here, the CALLER is 'ComplianceBot', but 'ComplianceBot' is NOT the admin of 'Trader'.
        // So we must bypass the admin check by using the internal function.
        _revokeRole(TRADER_ROLE, trader);
        emit TraderBanned(trader);
    }
}