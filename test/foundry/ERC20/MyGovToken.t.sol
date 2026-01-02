// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {MyGovToken} from "../../../contracts/ERC20/MyGovToken.sol";

contract MyGovTokenTest is Test {
    MyGovToken token;

    uint256 alicePrivateKey = 0xB16;
    address alice;                          // Token Holder
    address bob = makeAddr("bob");          // Alice's Delegatee
    address charlie = makeAddr("charlie");  // Token Receiver
    address david = makeAddr("david");      // Charlie's Delegatee

    // Delegation TypeHash for EIP-712 (Copied from OpenZeppelin Votes.sol)
    bytes32 private constant DELEGATION_TYPEHASH =
        keccak256("Delegation(address delegatee,uint256 nonce,uint256 expiry)");

    function setUp() public {
        alice = vm.addr(alicePrivateKey);
        token = new MyGovToken();

        // Distribute tokens to Alice
        token.transfer(alice, 1_000 * 1e18);
    }

    /**
     * @notice Scenario 1: The "Ghost Power" Phenomenon
     * Alice has tokens but hasn't delegated.
     * Proof: Token Balance != Voting Power
     */
    function test_UndelegatedTokensHaveNoPower() public {
        // Alice has 1000 tokens
        assertEq(token.balanceOf(alice), 1_000 * 1e18);
        // But 0 Voting Power because she didn't delegate yet
        assertEq(token.getVotes(alice), 0);

        // Even if she transfers to Bob, Bob gets 0 votes
        vm.prank(alice);
        token.transfer(bob, 500 ether);

        assertEq(token.balanceOf(bob), 500 ether);
        assertEq(token.getVotes(bob), 0);
    }

    /**
     * @notice Scenario 2: The Ripple Effect (Complex Transfer Chain)
     * Alice delegates to Bob
     * Charlie delegates to David.
     * Action: Alice sends tokens to Charlie
     * Result: Bob loses power, David gains power
     */
    function test_ComplexPowerShift() public {
        // Setup Delegations
        vm.prank(alice);
        token.delegate(bob);    // Alice -> Bob

        // Check initial state
        assertEq(token.balanceOf(bob), 0);
        assertEq(token.getVotes(bob), 1000 ether);  // Bob has Alice's power

        // Setup Delegations
        vm.prank(charlie);
        token.delegate(david);  // Charlie -> David (Charlie has 0 tokens now)

        // Check initial state
        assertEq(token.balanceOf(david), 0);
        assertEq(token.getVotes(david), 0);     // David has nothing

        // Alice transfers to Charlie
        vm.prank(alice);
        token.transfer(charlie, 400 ether);

        // Verify The Ripple Effect
        
        // Alice's balance decreased -> Her delegatee (Bob) loses power
        assertEq(token.getVotes(bob), 600 ether);       

        // Charlie's balance increased -> His delegatee (David) gains power
        // David gained power even though David was not involved in the transfer
        assertEq(token.getVotes(david), 400 ether);
    }

    /**
     * @notice Scenario 3: Time Travel & Checkpoints
     * Simulating block progression to verify 'getPastVotes'.
     * This is crucial for preventing Flash Loan Governance attacks.
     */
    function test_CheckpointsAndHistory() public {
        // Start at Block 100
        vm.roll(100);
        vm.prank(alice);
        token.delegate(alice); // Self-delegation (Alice has 1000)

        // Move to Block 110: Alice burns 500 tokens
        vm.roll(110);
        vm.prank(alice);
        token.transfer(bob, 500 ether);

        // Move to Block 120: Alice receives 200 tokens
        vm.roll(120);
        token.transfer(alice, 200 ether);

        // Current Block: 120
        // Current Votes: 700
        assertEq(token.getVotes(alice), 700 * 1e18);

        // At Block 105 (Between 100 and 110): Should be 1000
        uint256 votesAt105 = token.getPastVotes(alice, 105);
        assertEq(votesAt105, 1_000 ether);

        // At Block 115 (Between 110 and 120): Should be 500
        uint256 votesAt115 = token.getPastVotes(alice, 115);
        assertEq(votesAt115, 500 ether);

        // At Block 125 (Between 120 and 130): Should be 700
        vm.roll(130);
        uint256 votesAt125 = token.getPastVotes(alice, 125);
        assertEq(votesAt125, 700 ether);
    }

    /**
     * @notice Scenario 4: Gasless Delegation (delegateBySig)
     * Manually constructing EIP-712 Signature for delegation.
     */
    function test_DelegateBySig() public {
        // Alice wants to delegate to Bob using signature
        uint256 nonce = token.nonces(alice);
        uint256 expiry = block.timestamp + 1 days;

        // 1. Build StructHash
        bytes32 structHash = keccak256(abi.encode(
            DELEGATION_TYPEHASH,
            bob,
            nonce,
            expiry
        ));

        // 2. Build Digest
        bytes32 digest = keccak256(abi.encodePacked(
            "\x19\x01",
            token.DOMAIN_SEPARATOR(),
            structHash
        ));

        // 3. Sign
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(alicePrivateKey, digest);

        // 4. Execution (Anyone can relay this)
        // Before: Bob has 0
        assertEq(token.getVotes(bob), 0);
        token.delegateBySig(bob, nonce, expiry, v, r, s);

        // After: Bob has 100 (from signer)
        assertEq(token.getVotes(bob), 1_000 ether);
        assertEq(token.delegates(alice), bob);

    }
}