// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/utils/cryptography/EIP712.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

/**
 * @title EIP712Profile
 * @notice Allows users to update their profile nickname via gasless signatures.
 */
contract EIP712Profile is EIP712 {
    // Stores user nicknames.
    mapping(address => string) public profies;
    
    // Stores nonces for each user to prevent replay attacks
    mapping(address => uint256) public nonces;

    // The EIP-712 TypeHash defining the structure of the signed data
    // Structure: ProfileRequest(address user, string nickname, uint256 nonce)
    bytes32 private constant PROFILE_TYPEHASH = keccak256(
        "ProfileRequest(address user,string nickname,uint256 nonce)"
    );

    // Event emitted when a profile is successfully updated
    event ProfileUpdated(address indexed user, string newNickname);

    constructor() EIP712("EIP712Profile", "1") {}

    /**
     * @notice Updates the user's nickname using a valid EIP-712 signature.
     * @dev This function can be called by a Relayer (paying gas) on behalf of the user.
     * @param user The address of the user who signed the message.
     * @param nickname The new nickname to set.
     * @param signature The EIP-712 signature provided by the user.
     */
    function updateProfileWithSignature(
        address user,
        string calldata nickname,
        bytes calldata signature
    ) external {
        // 1. Retrieve the current nonce for the user.
        uint256 currentNonce = getNonce(user);

        // 2. Build the StructHash
        bytes32 structHash = keccak256(abi.encode(
            PROFILE_TYPEHASH,
            user,
            keccak256(bytes(nickname)),
            currentNonce
        ));

        // 3. Create the final Digest (DomainSeparator + StructHash)
        bytes32 digest = _hashTypedDataV4(structHash);

        // 4. Recover the signer address from the digest and signature
        address signer = ECDSA.recover(digest, signature);

        // 5. Verification: Check if the recovered signer matches the user
        require(signer == user, "Invalid signature");
        require(signer != address(0), "Invalid signer");

        // 6. Update State
        updateNonce(user);
        profies[user] = nickname;

        // 7. Emit event
        emit ProfileUpdated(user, nickname);
    }

    function getNonce(address user) internal view returns(uint256) {
        return nonces[user];
    }

    function updateNonce(address user) internal {
        nonces[user]++;
    }
}