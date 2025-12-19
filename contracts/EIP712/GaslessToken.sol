// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/utils/cryptography/EIP712.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

/**
 * @title GaslessToken
 * @notice ERC20 token supporting gasless transfers via EIP-712 meta-transactions.
 * @dev Implements a relay mechanism where a signer provides a signature and a relayer pays the gas.
 */
contract GaslessToken is ERC20, EIP712 {
    /// @dev EIP-712 TypeHash for the transfer request struct
    bytes32 private constant TRANSFER_REQUEST_TYPEHASH =
        keccak256("TransferRequest(address owner,address to,uint256 value,uint256 nonce,uint256 deadline)");

    /// @notice Tracks the nonce for each address to prevent replay attacks.
    mapping(address => uint256) public nonces;

    /**
     * @notice Emitted when a meta-transaction is successfully executed.
     * @param relayer The address that paid the gas for the transaction.
     * @param from The address that signed the message(token sender).
     * @param to The address receiving the tokens.
     * @param value The amount of tokens transferred.
     */
    event MetaTransactionExecuted(address indexed relayer, address indexed from, address indexed to, uint256 value);

    /// @notice Thrown when the signature deadline has passed.
    error SignatureExpired(uint256 deadline, uint256 currentTimestamp);

    /// @notice Thrown when the recovered signer does not match the owner.
    error InvalidSignature();

    /// @notice Thrown when the recovered signer is the zero address.
    error InvalidSigner();

    /// @notice Initializes the contract with metadata and mints initial supply to deployer.
    constructor() ERC20("GaslessToken", "GLT") EIP712("GaslessToken", "1") {
        _mint(msg.sender, 10000 * 10 ** decimals());
    }

    /**
     * @notice Executes a transfer on behalf of the `owner` using a valid EIP-712 signature.
     * @dev Increases the nonce of the owner to prevent replay attacks.
     * @param owner The address of the token holder(signer).
     * @param to The address of the recipient.
     * @param value The amount of tokens to transfer.
     * @param deadline The timestamp until which the signature is valid.
     * @param signature The raw signature bytes(r, s, v).
     * @return bool Returns true if the transfer succeeded.
     */
    function executeTransfer(
        address owner,
        address to,
        uint256 value,
        uint256 deadline,
        bytes calldata signature
    ) external returns(bool) {
        // 1. Check Deadline
        if(deadline < block.timestamp) {
            revert SignatureExpired(deadline, block.timestamp);
        }

        // 2. Verify Signature
        _verifySignature(owner, to, value, deadline, signature);

        // 3. Increment Nonce
        // This is critical to prevent the same signature from being used twice.
        // We use unchecked to save gas, as nonce overflow is practically impossible (2^256).
        unchecked {
            nonces[owner]++;
        }

        // 4. Execute Transfer
        _transfer(owner, to, value);

        emit MetaTransactionExecuted(msg.sender, owner, to, value);

        return true;
    }

    /**
     * @notice Returns the domain separator used for EIP-712 hashing.
     * @dev Exposes the internal _domainSeparatorV4 for frontend integration.
     * @return bytes32 The domain separator hash.
     */
    function getDomainSeparator() external view returns(bytes32) {
        return _domainSeparatorV4();
    }

    /**
     * @dev Reconstructs the hash and verifies the signer using ECDSA.
     * @param owner The expected signer.
     * @param to The recipient address.
     * @param value The amount to transfer.
     * @param deadline The validity deadline.
     * @param signature The signature bytes.
     */
    function _verifySignature(
        address owner,
        address to,
        uint256 value,
        uint256 deadline,
        bytes calldata signature
    ) internal view {
        uint256 currentNonce = nonces[owner];

        // Create the StructHash according to EIP-712
        bytes32 structHash = keccak256(
            abi.encode(
                TRANSFER_REQUEST_TYPEHASH,
                owner,
                to,
                value,
                currentNonce,
                deadline
            )
        );

        // Create the final digest (Prefix + DomainSeparator + StructHash)
        bytes32 digest = _hashTypedDataV4(structHash);

        // Recover the address from the signature
        address signer = ECDSA.recover(digest, signature);

        if (signer == address(0)) {
            revert InvalidSigner();
        }
        if (signer != owner) {
            revert InvalidSignature();
        }
    }
}