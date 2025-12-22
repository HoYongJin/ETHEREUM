// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {SecureVault} from "../../../contracts/AccessControl/SecureVault.sol";
import {SmartDAO} from "../../../contracts/AccessControl/SmartDAO.sol";

contract Ownable2StepAdvancedTest is Test {
    SecureVault public vault;
    SmartDAO public dao;

    address public alice;   // Current Owner
    address public bob;     // Accidental Wrong Address
    address public hacker;

    function setUp() public {
        alice = makeAddr("alice");
        bob = makeAddr("bob");
        hacker = makeAddr("hacker");

        // 1. Deploy Vault with Alice as owner
        vm.prank(alice);
        vault = new SecureVault(alice);

        // 2. Deploy DAO
        dao = new SmartDAO();

        // 3. Fund the vault
        vm.deal(address(vault), 10 ether);
    }

    /**
     * @notice Scenario 1: The "Fat Finger" Mistake (Recovery)
     * Alice accidentally transfers ownership to Bob (who lost his keys).
     * In Ownable(Basic), Alice would have lost the contract forever.
     * In Ownable2Step, Alice remains the owner and can fix it.
     */
    function test_RecoverFromAccidentalTransfer() public {
        // --- Step 1: Alice makes a mistake ---
        vm.prank(alice);

        // Alice intends to send to DAO, but types Bob's address
        vault.transferOwnership(bob);

        // CHECK: Is Bob the owner now? NO.
        assertEq(vault.owner(), alice, "Alice should STILL be the owner");
        assertEq(vault.pendingOwner(), bob, "Bob should be pending");

        // --- Step 2: Bob cannot accept (simulating lost keys) ---
        // Or even if Hacker tries to accept
        vm.prank(hacker);
        vm.expectRevert();
        vault.acceptOwnership();

        // --- Step 3: Alice realizes mistake and fixes it ---
        // Alice effectively "Cancels" the transfer to Bob by overwriting it
        // She transfers to the correct address (DAO)
        vm.prank(alice);
        vault.transferOwnership(address(dao));

        // CHECK: Bob is kicked out, DAO is new pending
        assertEq(vault.owner(), alice, "Alice is STILL owner until acceptance");
        assertEq(vault.pendingOwner(), address(dao), "DAO should be new pending");
    }

    /**
     * @notice Scenario 2: Smart Contract Handover
     * Transferring ownership to a contract (DAO).
     * The contract MUST explicitly call acceptOwnership.
     */
    function test_HandoverToContract() public {
        // 1. Alice initiates transfer to DAO
        vm.prank(alice);
        vault.transferOwnership(address(dao));

        // 2. Verify state
        assertEq(vault.owner(), alice);
        assertEq(vault.pendingOwner(), address(dao));

        // 3. DAO accepts ownership
        // Note: We call a function on DAO that triggers `vault.acceptOwnership()`
        dao.claimVaultOwnership(address(vault));

        // 4. Final Verification
        assertEq(vault.owner(), address(dao), "DAO should be the new owner");
        assertEq(vault.pendingOwner(), address(0), "Pending owner should be cleared");

        // 5. Proof of Power
        // Alice tries to withdraw -> Fail
        vm.prank(alice);
        vm.expectRevert(); 
        vault.emergencyWithdraw(alice);

        // DAO tries to withdraw -> Success
        dao.executeWithdraw(address(vault), address(dao));
        assertEq(address(dao).balance, 10 ether);
    }

    /**
     * @notice Scenario 3: Cancel Transfer (Reset)
     * Alice starts transfer, decides not to do it, and cancels it.
     */
    function test_CancelTransfer() public {
        vm.startPrank(alice);
        
        // Start transfer to Bob
        vault.transferOwnership(bob);
        assertEq(vault.pendingOwner(), bob);

        // Cancel it by transferring to address(0) or self
        // Note: Ownable2Step allows setting pending to address(0) via internal logic,
        // but publicly we usually overwrite. 
        // If we want to strictly 'cancel', we can transfer ownership to 'self' (Alice)
        // OR transfer to address(0) is actually allowed in start logic to clear it!
        
        vault.transferOwnership(address(0)); // This sets pendingOwner to 0x0
        
        assertEq(vault.pendingOwner(), address(0));
        assertEq(vault.owner(), alice);
        
        vm.stopPrank();
    }
}