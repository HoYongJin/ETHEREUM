// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {EIP712MultiCall} from "../../../contracts/EIP712/EIP712MultiCall.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";

/**
 * @title EIP712MultiCallTest
 * @notice Unit tests for verifying EIP-712 MultiCall functionality
 * @dev Focuses on validating nested struct hashing and atomic execution logic
 */
contract EIP712MultiCallTest is Test {
    EIP712MultiCall public multiCall;

    uint256 internal userPrivateKey;
    address internal user;
    address internal relayer;
    address internal receiver1;
    address internal receiver2;

    // Inner struct TypeHash
    bytes32 private constant CALL_TYPEHASH = keccak256(
        "Call(address target,bytes data,uint256 value)"
    );

    // Outer struct TypeHash (Nested)
    // Rule: Main struct first, then referenced structs in alphabetical order
    bytes32 private constant BATCH_REQUEST_TYPEHASH = keccak256(
        "BatchRequest(address signer,Call[] calls,uint256 nonce,uint256 deadline)Call(address target,bytes data,uint256 value)"
    );

    function setUp() public {
        // 1. Setup User & Relayer
        userPrivateKey = 0xA11CE;
        user = vm.addr(userPrivateKey);
        relayer = address(0x9999);
        receiver1 = address(0x1111);
        receiver2 = address(0x2222);

        // 2. Deploy Contract
        multiCall = new EIP712MultiCall();

        // 3. Fund the Contract
        // Since the contract acts as a proxy sending ETH on behalf of the user,
        // it must hold funds. We fund it with 100 ETH for testing purposes
        vm.deal(address(multiCall), 100 ether);
    }

    /**
     * @notice Verifies that a valid batch request executes all calls successfully.
     */
    function testExecuteBatch_Success() public {
        // Scenario: Send 1 ETH to receiver1 and 2 ETH to receiver2.
        
        // 1. Prepare Call Array
        EIP712MultiCall.Call[] memory _calls = new EIP712MultiCall.Call[](2);

        _calls[0] = EIP712MultiCall.Call({
            target: receiver1,
            data: "",
            value: 1 ether
        });

        _calls[1] = EIP712MultiCall.Call({
            target: receiver2,
            data: "",
            value: 2 ether
        });

        // 2. Prepare BatchRequest
        uint256 nonce = multiCall.nonces(user);

        EIP712MultiCall.BatchRequest memory request = EIP712MultiCall.BatchRequest({
            signer: user,
            calls: _calls,
            nonce: nonce,
            deadline: block.timestamp + 1 hours
        });

        // 3. Generate Signature (Off-chain simulation)
        bytes memory signature = _signBatchRequest(userPrivateKey, request);

        // 4. Execute Transaction (Relayer submits)
        vm.prank(relayer);
        multiCall.executeBatch(request, signature);

        // 5. Assertions
        assertEq(receiver1.balance, 1 ether, "Receiver1 should have 1 ETH");
        assertEq(receiver2.balance, 2 ether, "Receiver2 should have 2 ETH");
        assertEq(multiCall.nonces(user), nonce + 1, "Nonce should increment");
    }

    /**
     * @notice Verifies the 'Atomic' property.
     * If the second call fails, the first call must also be rolled back.
     */
    function testExecuteBatch_Revert_Atomic() public {
        // 1. Prepare Call Array (Success + Fail combination)
        EIP712MultiCall.Call[] memory _calls = new EIP712MultiCall.Call[](2);

        // Call 1: Valid (1 ETH transfer)
        _calls[0] = EIP712MultiCall.Call({
            target: receiver1,
            data: "",
            value: 1 ether
        });

        // Call 2: Invalid (Try to send 1000 ETH, exceeding contract balance)
        _calls[1] = EIP712MultiCall.Call({
            target: receiver2,
            data: "",
            value: 1000 ether 
        });

        // 2. Prepare BatchRequest
        uint256 nonce = multiCall.nonces(user);

        EIP712MultiCall.BatchRequest memory request = EIP712MultiCall.BatchRequest({
            signer: user,
            calls: _calls,
            nonce: nonce,
            deadline: block.timestamp + 1 hours
        });

        // 3. Generate Signature (Off-chain simulation)
        bytes memory signature = _signBatchRequest(userPrivateKey, request);

        // 4. Execute and Expect Revert
        vm.prank(relayer);
        vm.expectRevert("Call failed");
        multiCall.executeBatch(request, signature);

        // 5. Assertion: Verify Rollback
        // Even though Call 1 was valid, it should be reverted because Call 2 failed.
        assertEq(receiver1.balance, 0, "Atomic rollback failed: Receiver1 received funds!");
    }

    /**
     * @notice Verifies that the contract rejects signatures from unauthorized signers.
     */
    function testExecuteBatch_Revert_InvalidSignature() public {
        // Data Prep
        EIP712MultiCall.Call[] memory calls = new EIP712MultiCall.Call[](1);
        calls[0] = EIP712MultiCall.Call({
            target: receiver1, 
            data: "",
            value: 1 ether
        });
        
        EIP712MultiCall.BatchRequest memory request = EIP712MultiCall.BatchRequest({
            signer: user,
            calls: calls,
            nonce: 0,
            deadline: block.timestamp + 1 hours
        });

        // Sign with a Hacker's key (Not the user's key)
        uint256 hackerKey = 0xBADC0DE;
        bytes memory signature = _signBatchRequest(hackerKey, request);

        // Execution
        vm.prank(relayer);
        vm.expectRevert("Invalid signer"); 
        multiCall.executeBatch(request, signature);
    }

    /**
     * @dev Simulates the off-chain EIP-712 signing process.
     * This function manually implements the array hashing logic.
     * * @param pk Private key of the signer
     * @param request The BatchRequest struct to sign
     * @return The 65-byte ECDSA signature
     */
    function _signBatchRequest(
        uint256 pk,
        EIP712MultiCall.BatchRequest memory request
    ) internal view returns(bytes memory) {
        // ARRAY HASHING LOGIC
        // In EIP-712, arrays are hashed by:
        // 1. Hashing each element individually (hashStruct)
        // 2. Concatenating these hashes
        // 3. Hashing the result with keccak256
        bytes32[] memory callHashes = new bytes32[](request.calls.length);

        for(uint256 i=0; i<callHashes.length; i++) {
            callHashes[i] = keccak256(abi.encode(
                CALL_TYPEHASH,
                request.calls[i].target,
                keccak256(request.calls[i].data),
                request.calls[i].value
            ));
        }

        // STRUCT HASHING
        bytes32 structHash = keccak256(abi.encode(
            BATCH_REQUEST_TYPEHASH,
            request.signer,
            keccak256(abi.encodePacked(callHashes)),
            request.nonce,
            request.deadline
        ));

        // DOMAIN SEPARATOR
        bytes32 domainSeparator = keccak256(abi.encode(
            keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"),
            keccak256(bytes("EIP712MultiCall")), // Contract Name
            keccak256(bytes("1")),               // Version
            block.chainid,
            address(multiCall)
        ));

        // SIGNING
        // Combine: \x19\x01 + DomainSeparator + StructHash
        bytes32 digest = MessageHashUtils.toTypedDataHash(domainSeparator, structHash);

        // Sign with Foundry's cheatcode
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(pk, digest);

        // Return packed signature
        return abi.encodePacked(r, s, v);
    }

}

