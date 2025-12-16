// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../../../contracts/ERC20/AdvancedDeFiToken.sol";

contract AdvancedDeFiTokenTest is Test {
    AdvancedDeFiToken token;
    
    // Private key for testing signature generation
    uint256 ownerPrivateKey = 0xA11CE; 
    address owner;
    address spender = address(2);

    function setUp() public {
        // Derive address from private key
        owner = vm.addr(ownerPrivateKey);
        
        // Deploy token with a cap of 1000 tokens
        token = new AdvancedDeFiToken(1000);
        
        // Transfer initial tokens to owner
        token.transfer(owner, 100 ether);
    }

    // [Test] Verify EIP-2612 Permit functionality (Gasless Approval)
    function testPermit() public {
        uint256 deadline = block.timestamp + 1 days;
        uint256 nonce = token.nonces(owner);
        uint256 value = 50 ether;

        // 1. Get the Domain Separator
        // This ensures the signature is only valid for this specific contract and chain
        bytes32 domainSeparator = token.DOMAIN_SEPARATOR();
        
        // 2. Create the Permit Struct Hash (Follows EIP-2612 standard)
        // keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)")
        bytes32 structHash = keccak256(abi.encode(
            keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)"),
            owner,
            spender,
            value,
            nonce,
            deadline
        ));

        // 3. Create the final Digest to sign
        // Format: \x19\x01 || DomainSeparator || StructHash
        bytes32 digest = keccak256(abi.encodePacked(
            "\x19\x01",
            domainSeparator,
            structHash
        ));

        // 4. Generate Signature using Foundry's vm.sign
        // v, r, s are the components of the ECDSA signature
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(ownerPrivateKey, digest);

        // 5. Execute Permit
        // Note: No vm.prank needed! Anyone can submit this signature to approve tokens.
        token.permit(owner, spender, value, deadline, v, r, s);

        // 6. Assertions
        // Check if allowance is updated correctly
        assertEq(token.allowance(owner, spender), value);
        // Check if nonce is incremented (to prevent replay attacks)
        assertEq(token.nonces(owner), nonce + 1); 
    }

    // [Test] Verify Tax Logic (Deflationary Mechanism)
    function testTransferWithTax() public {
        uint256 initialBalance = token.balanceOf(owner);
        uint256 sendAmount = 10 ether;
        address recipient = address(3);

        vm.startPrank(owner);
        token.transfer(recipient, sendAmount);
        vm.stopPrank();

        // Tax Calculation: 2% of 10 ether = 0.2 ether
        uint256 tax = (sendAmount * 200) / 10000; 
        uint256 amountReceived = sendAmount - tax;

        // Verify recipient received amount minus tax
        assertEq(token.balanceOf(recipient), amountReceived);
        
        // Verify owner balance decreased by full send amount
        assertEq(token.balanceOf(owner), initialBalance - sendAmount);
    }
}