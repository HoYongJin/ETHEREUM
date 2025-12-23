// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {LendingPool} from "../../../contracts/AccessControl/LendingPool.sol";
import {IAccessControl} from "@openzeppelin/contracts/access/IAccessControl.sol";

contract LendingPoolTest is Test {
    LendingPool public pool;

    address public superAdmin;
    address public governance; // DAO
    address public riskGuy;    // A quantitative analyst
    address public pauserGuy;  // A monitoring bot
    address public hacker;

    bytes32 public constant DEFAULT_ADMIN_ROLE = 0x00;
    bytes32 public constant RISK_MANAGER_ROLE = keccak256("RISK_MANAGER_ROLE");
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    bytes32 public constant GOVERNANCE_ROLE = keccak256("GOVERNANCE_ROLE");

    function setUp() public {
        superAdmin = makeAddr("superAdmin");
        governance = makeAddr("governance");
        riskGuy = makeAddr("riskGuy");
        pauserGuy = makeAddr("pauserGuy");
        hacker = makeAddr("hacker");

        // Deploy Contract
        pool = new LendingPool(superAdmin, governance);
    }

    /**
     * @notice 1. Basic Role Verification
     * Verifies that roles act as expected (Allowed vs Restricted).
     */
    function test_BasicRoleAccess() public {
        // Setup: Admin grants Risk Role to riskGuy
        vm.prank(superAdmin);
        pool.grantRole(RISK_MANAGER_ROLE, riskGuy);

        // 1. RiskGuy tries to set rate -> Success
        vm.prank(riskGuy);
        pool.setInterestRate(1000);
        assertEq(pool.interestRate(), 1000);

        // 2. Hacker tries to set rate -> Fail
        vm.prank(hacker);
        vm.expectRevert();
        pool.setInterestRate(2000);

        assertEq(pool.interestRate(), 1000);
    }

    /**
     * @notice 2. Advanced: Role Hierarchy Restructuring
     * This is the MOST IMPORTANT part to understand AccessControl.
     * Scenario: Admin transfers the power to manage RiskManagers to the Governance.
     */
    function test_RoleHierarchyChange() public {
        // --- Phase 1: Default State ---
        // By default, DEFAULT_ADMIN_ROLE manages all roles
        assertEq(pool.getRoleAdmin(RISK_MANAGER_ROLE), DEFAULT_ADMIN_ROLE);

        // So Governance CANNOT grant Risk Role yet.
        vm.prank(governance);
        vm.expectRevert();
        pool.grantRole(RISK_MANAGER_ROLE, riskGuy);

        // --- Phase 2: Restructuring ---
        // SuperAdmin executes the architecture change
        vm.prank(superAdmin);
        pool.restructureRiskManagement();

        // CHECK: Who is the admin of RISK_MANAGER_ROLE now?
        assertEq(pool.getRoleAdmin(RISK_MANAGER_ROLE), GOVERNANCE_ROLE);

        // --- Phase 3: Governance takes over ---
        // Now Governance CAN grant the role
        vm.prank(governance);
        pool.grantRole(RISK_MANAGER_ROLE, riskGuy);
        assertTrue(pool.hasRole(RISK_MANAGER_ROLE, riskGuy));

        // Note: SuperAdmin can NO LONGER grant this role directly!
        // Because SuperAdmin does not have GOVERNANCE_ROLE
        vm.prank(superAdmin);
        vm.expectRevert();
        pool.grantRole(RISK_MANAGER_ROLE, hacker);
    }

    /**
     * @notice 3. Renounce Role (Self-Revocation)
     * Scenario: RiskGuy resigns and removes his own access for security.
     */
    function test_RenounceRole() public {
        // Setup
        vm.prank(superAdmin);
        pool.grantRole(RISK_MANAGER_ROLE, riskGuy);

        assertTrue(pool.hasRole(RISK_MANAGER_ROLE, riskGuy));

        vm.startPrank(riskGuy);
        pool.setInterestRate(1500);
        assertEq(pool.interestRate(), 1500);

        // RiskGuy wants to quit.
        // renounceRole(role, account) -> account must be msg.sender
        pool.renounceRole(RISK_MANAGER_ROLE, riskGuy);

        // Check: Access lost
        assertFalse(pool.hasRole(RISK_MANAGER_ROLE, riskGuy));

        // Verify cannot call function anymore
        vm.expectRevert();
        pool.setInterestRate(1500);

        vm.stopPrank();
    }
}