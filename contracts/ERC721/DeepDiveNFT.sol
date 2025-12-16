// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/**
 * @title DeepDiveNFT
 * @notice A comprehensive example of Standard ERC721 implementation.
 * @dev Implements ERC721Enumerable, AccessControl, and Pausable.
 * Uses standard `for` loops for batch minting (Gas heavy).
 */
contract DeepDiveNFT is ERC721Enumerable, AccessControl, Pausable, ReentrancyGuard {
    // =============================================================
    //                           ROLES
    // =============================================================

    /**
     * Role identifier for addresses allowed to pause/unpause the contract
     * Calculated as the keccak256 hash of the string "PAUSER_ROLE"
     */
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");

    /**
     * Role identifier for addresses allowed to withdraw funds
     */
    bytes32 public constant WITHDRAW_ROLE = keccak256("WITHDRAW_ROLE");

    // =============================================================
    //                           STATE VARIABLES
    // =============================================================

    // The maximum number of tokens that can be minted
    uint256 public constant MAX_SUPPLY = 1000;

    // The cost to mint one token
    uint256 public constant MINT_PRICE = 0.01 ether;

    // Internal variable to store the base URI for metadata
    string private _baseTokenURI;

    // =============================================================
    //                           CONSTRUCTOR
    // =============================================================

    /**
     * @notice Initializes the contract with metadata and sets up default roles.
     * @param name The name of the token collection.
     * @param symbol The symbol of the token collection.
     * @param baseURI The base URI for IPFS metadata (e.g., "ipfs://Qm.../").
     */
    constructor(
        string memory name, 
        string memory symbol, 
        string memory baseURI
    ) ERC721(name, symbol) 
    {
        _baseTokenURI = baseURI;

        // Grant the deployer the default admin role (can manage other roles).
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        
        // Grant the deployer specific roles for testing convenience.
        _grantRole(PAUSER_ROLE, msg.sender);
        _grantRole(WITHDRAW_ROLE, msg.sender);
    }

    // =============================================================
    //                        MINTING LOGIC
    // =============================================================

    /**
     * @notice Mints `quantity` tokens to the caller.
     * @dev Uses a `for` loop, which is standard but gas-intensive for large batches.
     * Checks for Paused state, Reentrancy, Supply, and Eth value.
     * @param quantity The number of tokens to mint.
     */
    function mint(uint256 quantity) external payable nonReentrant whenNotPaused {
        require(quantity > 0, "Quantity must be greater than 0");
        require(totalSupply() + quantity <= MAX_SUPPLY, "Exceeds max supply");
        require(msg.value >= MINT_PRICE * quantity, "Insufficient ETH sent");

        // Loop Minting: This writes to storage 'quantity' times
        for(uint256 i=0; i<quantity; i++) {
            uint256 tokenId = totalSupply();
            _safeMint(msg.sender, tokenId);
        }
    }

    // =============================================================
    //                        ADMIN FUNCTIONS
    // =============================================================

    /**
     * @notice Pauses all token transfers and minting actions.
     * @dev Can only be called by accounts with PAUSER_ROLE.
     */
    function pause() external onlyRole(PAUSER_ROLE) {
        _pause();
    }

    /**
     * @notice Unpauses the contract.
     * @dev Can only be called by accounts with PAUSER_ROLE.
     */
    function unpause() external onlyRole(PAUSER_ROLE) {
        _unpause();
    }

    /**
     * @notice Withdraws the entire ETH balance of the contract to the caller.
     * @dev Can only be called by accounts with WITHDRAW_ROLE.
     * Uses `call` for safe transfer.
     */
    function withdraw() external nonReentrant onlyRole(WITHDRAW_ROLE) {
        uint256 balance = address(this).balance;
        require(balance > 0, "No funds to withdraw");

        (bool success,) = payable(msg.sender).call{value: balance}("");
        require(success, "Withdraw failed");
    }

    /**
     * @notice Updates the base URI for computing {tokenURI}.
     * @dev Can only be called by the default admin.
     * @param baseURI The new base URI string.
     */
    function setBaseURI(string memory baseURI) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _baseTokenURI = baseURI;
    }

    // =============================================================
    //                        VIEW FUNCTIONS
    // =============================================================

    /**
     * @notice Returns all token IDs owned by a specific address.
     * @dev This function iterates over the user's balance. 
     * WARNING: O(n) complexity. Do not call this from another smart contract (Gas limit risk).
     * Intended for off-chain (frontend) use only.
     * @param owner The address to query.
     * @return An array of token IDs owned by `owner`.
     */
    function walletOfOwner(address owner) external view returns(uint256[] memory) {
        uint256 ownerBalance = balanceOf(owner);
        uint256[] memory tokenIds = new uint256[](ownerBalance);

        for(uint256 i=0; i<ownerBalance; i++) {
            // tokenOfOwnerByIndex is provided by ERC721Enumerable
            tokenIds[i] = tokenOfOwnerByIndex(owner, i);
        }
        
        return tokenIds;
    }

    /**
     * @dev Internal function to return the base URI string.
     * Overrides the empty implementation in ERC721.
     * @return The base URI string.
     */
    function _baseURI() internal view override returns(string memory) {
        return _baseTokenURI;
    }

    // =============================================================
    //                  OVERRIDES (REQUIRED)
    // =============================================================

    /**
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721Enumerable, AccessControl)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }


}