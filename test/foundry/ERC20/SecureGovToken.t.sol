// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {SecureGovToken} from "../../../contracts/ERC20/SecureGovToken.sol";

contract SecureGovTokenTest is Test {
    SecureGovToken public token;

    address whale = makeAddr("whale"); // Honest token holder
    address attacker = makeAddr("attacker"); // Malicious actor
    address governor = makeAddr("governor"); // The Governance Contract

    function setUp() public {
        token = new SecureGovToken();

        // Whale holds 100,000 tokens
        token.transfer(whale, 100_000 * 1e18);

        // Whale delegates to themselves to activate checkpoints
        vm.prank(whale);
        token.delegate(whale);
    }

    /**
     * @notice Scenario: Flash Loan Attack Simulation
     * 1. Proposal is created at Block 100.
     * 2. Attacker borrows tokens at Block 105 (Flash Loan).
     * 3. Attacker tries to vote for the proposal created at Block 100.
     * * Expectation: Attacker must have 0 votes for Block 100.
     */
    function test_FlashLoanDefense() public {
        vm.roll(100);

        // Let's say a proposal is created NOW.
        // The snapshot block for this proposal is 100.
        uint256 proposalSnapshotBlock = block.number;

        // At this point, Attacker has 0 tokens and 0 votes.
        assertEq(token.balanceOf(attacker), 0);
        assertEq(token.getVotes(attacker), 0);

        // The Attack (Flash Loan)
        // Attacker borrows 100,000 tokens from Whale (Simulating Flash Loan)
        vm.roll(105);
        vm.prank(whale);
        token.transfer(attacker, 100_000 * 1e18);

        // Attacker MUST delegate to self to get voting power
        vm.prank(attacker);
        token.delegate(attacker);

        // Check current power (Block 105)
        // Attacker successfully gained power in the current block
        assertEq(token.balanceOf(attacker), 100_000 * 1e18);
        assertEq(token.getVotes(attacker), 100_000 * 1e18);

        // The Governor contract checks voting power at 'proposalSnapshotBlock' (Block 100)
        uint256 attackerHistoricalVotes = token.getPastVotes(
            attacker,
            proposalSnapshotBlock
        );

        // VERIFICATION:
        // Even though Attacker holds tokens NOW, they had 0 at the snapshot block.
        // Therefore, their vote weight is ZERO.
        assertEq(attackerHistoricalVotes, 0);

        // Whale gets tokens back
        vm.prank(attacker);
        token.transfer(whale, 100_000 * 1e18);

        assertEq(token.balanceOf(whale), 100_000 * 1e18);
    }

    /**
     * @notice Scenario: Supply Shock (Burning)
     * Testing if burning tokens correctly reduces voting power in history.
     */
    function test_BurnAffectsVotingPower() public {
        vm.roll(200);

        // Whale has 100k votes
        assertEq(token.getVotes(whale), 100_000 * 1e18);

        // Whale burns 50k tokens
        vm.prank(whale);
        token.burn(50_000 * 1e18); // Using ERC20Burnable function

        // Check 1: Balance reduced?
        assertEq(token.balanceOf(whale), 50_000 * 1e18);

        // Check 2: Voting Power reduced? (Current)
        assertEq(token.getVotes(whale), 50_000 * 1e18);

        vm.roll(201);

        // At Block 200 (When burn happened), the checkpoint recorded the DROP.
        // So at end of Block 200, votes are 50k.
        assertEq(token.getPastVotes(whale, 200), 50_000 * 1e18);

        // At Block 199 (Before burn), votes were 100k.
        assertEq(token.getPastVotes(whale, 199), 100_000 * 1e18);
    }
}
