// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {DeFiToken} from "../../../contracts/ERC20/DeFiToken.sol";

contract DeFiTokenTest is Test {
    DeFiToken public token;

    address public owner = makeAddr("owner");
    address public treasury = makeAddr("treasury");
    address public alice = makeAddr("alice");
    address public bob = makeAddr("bob");
    address public whale = makeAddr("whale");

    function setUp() public {
        vm.startPrank(owner);
        token = new DeFiToken(treasury);

        token.transfer(alice, 10_000 * 10 ** token.decimals());
        vm.stopPrank();
    }

    /**
     * @notice Test 1: Tax Mechanics
     * Alice sends 1000 tokens to Bob.
     * Expectation: 
     * - Alice loses 1000
     * - Bob receives 950 (95%)
     * - Treasury receives 25 (2.5%)
     * - Total Supply decreases by 25 (2.5% Burnt)
     */
    function test_TransferWithTax() public {
        uint256 amount = 1000 * 1e18;
        uint256 startSupply = token.totalSupply();
        uint256 startTreasuryBal = token.balanceOf(treasury);

        vm.prank(alice);
        token.transfer(bob, amount);

        // 1. Bob's Balance Check (95%)
        assertEq(token.balanceOf(bob), amount * 95 / 100);

        // 2. Treasury Check (+2.5%)
        uint256 taxShare = amount * 25 / 1000; // 2.5%
        assertEq(token.balanceOf(treasury), startTreasuryBal + taxShare);

        // 3. Burn Check (Total Supply decreased by 2.5%)
        assertEq(token.totalSupply(), startSupply - taxShare);
    }

    /**
     * @notice Test 2: Anti-Whale Mechanism
     * Max Wallet is 2% of Total Supply (1,000,000 * 0.02 = 20,000).
     * Whale tries to receive 21,000 tokens.
     */
    function test_MaxWalletLimit() public {
        vm.startPrank(owner);
        
        uint256 limit = token.totalSupply() * 2 / 100; // 20,000
        uint256 tooMuch = limit + 1 ether;

        // Expect Revert
        vm.expectRevert("Exceeds max wallet limit");
        token.transfer(whale, tooMuch);
        
        vm.stopPrank();
    }

    /**
     * @notice Test 3: Approval & TransferFrom(ERC20 Core Principle)
     * How tax interacts with allowance.
     * Alice approves Bob to spend 1000.
     * Bob transfers 1000 from Alice to himself.
     */
    function test_TransferFromWithTax() public {
        uint256 amount = 1000 * 1e18;

        // 1. Alice approves Bob
        vm.prank(alice);
        token.approve(bob, amount);
        assertEq(token.allowance(alice, bob), amount);

        // 2. Bob calls transferFrom
        vm.prank(bob);
        token.transferFrom(alice, bob, amount);

        // Check Logic:
        // - Alice balance: -1000
        // - Bob balance: +950
        // - Allowance: Should be 0 (Full amount used)
        assertEq(token.balanceOf(alice), 9000 * 1e18); // 10000 - 1000
        assertEq(token.balanceOf(bob), 950 * 1e18);
        assertEq(token.allowance(alice, bob), 0);
    }
}