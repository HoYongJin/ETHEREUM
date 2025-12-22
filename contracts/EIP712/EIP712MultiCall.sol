// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/utils/cryptography/EIP712.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

/**
 * @title EIP712MultiCall
 * @notice Allows atomic execution of multiple function calls via a single off-chain signature.
 * @dev This contract demonstrates advanced EIP-712 usage including nested structs and array hashing.
 */
contract EIP712MultiCall is EIP712 {
    /**
     * @notice Represents a single function call.
     * @param target The contract address to call.
     * @param data The calldata (encoded function signature and parameters).
     * @param value The amount of ETH (in wei) to send with the call.
     */
    struct Call {
        address target;
        bytes data;
        uint256 value;
    }

    /**
     * @notice Represents the main request payload to be signed by the user.
     * @param signer The address of the user initiating the calls.
     * @param calls An array of 'Call' structs to be executed atomically.
     * @param nonce A unique number to prevent replay attacks.
     * @param deadline The timestamp after which the signature is invalid.
     */
    struct BatchRequest {
        address signer;
        Call[] calls;
        uint256 nonce;
        uint256 deadline;
    }

    /// @notice Mapping to track used nonces for each user
    mapping(address => uint256) public nonces;

    /// @dev TypeHash for the inner 'Call' struct.
    /// Format: Call(address target,bytes data,uint256 value)
    bytes32 private constant CALL_TYPEHASH = keccak256(
        "Call(address target,bytes data,uint256 value)"
    );

    /// @dev TypeHash for the outer 'BatchRequest' struct.
    /// RULE: The main struct is defined first, followed by referenced structs in alphabetical order by name.
    /// Format: BatchRequest(...)Call(...)
    bytes32 private constant BATCH_REQUEST_TYPEHASH = keccak256(
        "BatchRequest(address signer,Call[] calls,uint256 nonce,uint256 deadline)Call(address target,bytes data,uint256 value)"
    );

    /// @notice Emitted when a batch of calls is successfully executed
    event BatchExecuted(address indexed signer, uint256 count);

    constructor() EIP712("EIP712MultiCall", "1") {}

    /**
     * @notice Executes a batch of calls if the provided signature is valid.
     * @param request The BatchRequest struct containing all details.
     * @param signature The EIP-712 signature from the 'signer'.
     */
    function executeBatch(
        BatchRequest calldata request,
        bytes calldata signature
    ) external payable {
        // 1. Validity Checks
        require(block.timestamp < request.deadline, "Signature expired");
        require(request.nonce == nonces[request.signer], "Invalid nonce");

        // 2. Signature Verification
        // Verify that the 'signer' actually signed this specific request
        _verifySignature(request, signature);

        // 3. Replay Protection
        // Increment the nonce BEFORE execution to prevent re-entrancy/replay
        unchecked{
            nonces[request.signer]++;
        }

        // 4. Atomic Execution Loop
        for(uint256 i=0; i<request.calls.length; i++) {
            Call memory _call = request.calls[i];

            // Execute the low-level call
            // Note: We forward the specified 'value' (ETH) with the call
            (bool success,) = _call.target.call{value: _call.value}(_call.data);

            // If any single call fails, the entire transaction reverts (Atomic)
            require(success, "Call failed");
        }

        emit BatchExecuted(request.signer, request.calls.length);
    }


    /**
     * @notice Internal function to reconstruct the digest and verify the signer.
     * @dev Implements complex array hashing logic required by EIP-712.
     */
    function _verifySignature(
        BatchRequest calldata request, 
        bytes calldata signature
    ) internal view {
        // ARRAY HASHING LOGIC
        // Step 1: Hash each individual 'Call' struct
        // We create a temporary array of bytes32 to store these hashes
        bytes32[] memory callHashes = new bytes32[](request.calls.length);

        for(uint256 i=0; i<callHashes.length; i++) {
            callHashes[i] = keccak256(abi.encode(
                CALL_TYPEHASH,
                request.calls[i].target,
                keccak256(request.calls[i].data),
                request.calls[i].value
            ));
        }

        // Step 2: Create the final StructHash for BatchRequest
        bytes32 structHash = keccak256(abi.encode(
            BATCH_REQUEST_TYPEHASH,
            request.signer,
            keccak256(abi.encodePacked(callHashes)),
            request.nonce,
            request.deadline
        ));

        // Step 3: Create the EIP-712 Digest (Domain Separator + StructHash)
        bytes32 digest = _hashTypedDataV4(structHash);

        // Step 4: Recover the signer address
        address recoveredSigner = ECDSA.recover(digest, signature);

        // Step 5: Final assertions
        require(recoveredSigner == request.signer, "Invalid signer");
        require(recoveredSigner != address(0), "Invalid signature");
    }
}