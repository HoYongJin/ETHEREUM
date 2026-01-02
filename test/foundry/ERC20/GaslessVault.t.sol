// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {GaslessVault, MyPermitToken} from "../../../contracts/ERC20/GaslessVault.sol";

contract GaslessVaultTest is Test {
    MyPermitToken token;
    GaslessVault vault;

    uint256 alicePrivateKey = 0xA11CE;  // Private key for Alice (for signing)
    address alice;
    address owner = makeAddr("owner");
    address bob = makeAddr("bob");      // Relayer

    bytes32 private constant PERMIT_TYPEHASH =
        keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)");

    function setUp() public {
        alice = vm.addr(alicePrivateKey);

        vm.startPrank(owner);

        token = new MyPermitToken();
        vault = new GaslessVault(address(token));

        token.transfer(alice, 1_000 * 1e18);
    }

    function test_DepositWithPermit() public {
        uint256 totalAmount = 1_000 * 1e18; // Total amount to approve
        uint256 fee = 10 * 1e18;            // Tip for Bob
        uint256 depositAmount = totalAmount - fee;
        uint256 deadline = block.timestamp + 1 days;

        // 1. Get current Nonce of Alice
        uint256 nonce = token.nonces(alice);

        // 2. Generate StructHash (Content Hash)
        bytes32 structHash = keccak256(abi.encode(
            PERMIT_TYPEHASH,
            alice,
            address(vault),
            totalAmount,
            nonce,
            deadline
        ));

        // 3. Get Domain Separator (Query from Token Contract)
        bytes32 domainSeparator = token.DOMAIN_SEPARATOR();

        // 4. Generate Final Digest (EIP-712 Standard)
        bytes32 digest = keccak256(abi.encodePacked(
            "\x19\x01",
            domainSeparator,
            structHash
        ));

        // 5. Sign (Generate v, r, s)
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(alicePrivateKey, digest);

        // Bob (Relayer) pays gas and calls the function.
        vm.startPrank(bob);
        vault.depositWithPermit(
            alice,
            totalAmount,
            deadline,
            v, r, s,
            fee
        );
        vm.stopPrank();

        // 1. Check Alice's Vault balance (Received 990 after fee?)
        assertEq(vault.balances(alice), depositAmount);
        
        // 2. Did Bob receive the fee (10)?
        assertEq(token.balanceOf(bob), fee);

        // 3. Did the Vault contract receive tokens?
        assertEq(token.balanceOf(address(vault)), depositAmount);

        // 4. Did Alice's Nonce increase? (Check Replay Protection)
        assertEq(token.nonces(alice), nonce + 1);
    }
}