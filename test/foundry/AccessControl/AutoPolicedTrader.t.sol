// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {AutoPolicedTrader} from "../../../contracts/AccessControl/AutoPolicedTrader.sol";
import {IAccessControl} from "@openzeppelin/contracts/access/IAccessControl.sol";

contract AutoPolicedTraderTest is Test {
    AutoPolicedTrader public system;

    address public rootAdmin;
    address public director;
    address public complianceBot;
    address public badTrader;

    bytes32 public constant TRADER_ROLE = keccak256("TRADER_ROLE");
    bytes32 public constant COMPLIANCE_ROLE = keccak256("COMPLIANCE_ROLE");
    bytes32 public constant DIRECTOR_ROLE = keccak256("DIRECTOR_ROLE");

    function setUp() public {
        rootAdmin = makeAddr("root");
        director = makeAddr("director");
        complianceBot = makeAddr("complianceBot");
        badTrader = makeAddr("badTrader");

        system = new AutoPolicedTrader(director, complianceBot);

        // Director hires the trader
        vm.prank(director);
        system.grantRole(TRADER_ROLE, badTrader);
    }

    /**
     * @notice Test the "Three Strikes Out" mechanism.
     * This verifies that internal logic can override role admin restrictions.
     */
    function test_AutomaticBanningSystem() public {
        // 1. Trader works fine initially
        vm.prank(badTrader);
        system.executeTrade(100);
        assertTrue(system.hasRole(TRADER_ROLE, badTrader));

        // 2. Compliance Bot reports 1st Strike
        vm.startPrank(complianceBot);
        system.reportViolation(badTrader);
        assertEq(system.strikes(badTrader), 1);
        assertTrue(system.hasRole(TRADER_ROLE, badTrader)); // Still has role

        // 3. Compliance Bot reports 2nd Strike
        system.reportViolation(badTrader);
        assertEq(system.strikes(badTrader), 2);
        assertTrue(system.hasRole(TRADER_ROLE, badTrader)); // Still has role

        // 4. Compliance Bot reports 3rd Strike -> BAN HAMMER
        system.reportViolation(badTrader);
        assertFalse(system.hasRole(TRADER_ROLE, badTrader), "Trader should be banned");
        assertEq(system.strikes(badTrader), 3);

        vm.stopPrank();

        // CHECK: Trader tries to trade -> Revert
        vm.prank(badTrader);
        vm.expectRevert();
        system.executeTrade(100);
    }

    /**
     * @notice Verify Separation of Powers(Admin Hierarchy)
     * Only Director can grant/revoke Trader role directly
     * Compliance Bot CANNOT revoke directly(only via strike system)
     */
    function test_SeparationOfPowers() public {
        // 1. Compliance Bot tries to call revokeRole directly -> Fail
        // Because ComplianceBot is NOT the admin of TRADER_ROLE
        vm.prank(complianceBot);
        vm.expectRevert();
        system.revokeRole(TRADER_ROLE, badTrader);

        // 2. RootAdmin also can`t revoke
        vm.prank(rootAdmin);
        vm.expectRevert();
        system.revokeRole(TRADER_ROLE, badTrader);

        // 3. Director can revoke directly
        vm.prank(director);
        system.revokeRole(TRADER_ROLE, badTrader);
        assertFalse(system.hasRole(TRADER_ROLE, badTrader));       
    }

    /**
     * @notice Verify Director cannot interfere with Compliance logic incorrectly
     * but can hire new people.
     */
    function test_DirectorCannotBePoliced() public {
        // Director tries to grant Trader role to himself
        vm.prank(director);
        system.grantRole(TRADER_ROLE, director);
        
        // Compliance reports Director
        vm.startPrank(complianceBot);
        system.reportViolation(director);
        system.reportViolation(director);
        system.reportViolation(director); // 3rd strike
        vm.stopPrank();

        // Director loses TRADER_ROLE, but keeps DIRECTOR_ROLE
        assertFalse(system.hasRole(TRADER_ROLE, director));     // Banned from trading
        assertTrue(system.hasRole(DIRECTOR_ROLE, director));    // Still a director!
    }
}