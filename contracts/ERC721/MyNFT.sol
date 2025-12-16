// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract MyNFT is ERC721URIStorage, Ownable {
    uint256 private _nextTokenId;

    constructor() ERC721("MyIPFSNFT", "MNFT") Ownable(msg.sender) {}

    /**
     * @dev Mint a new NFT and assign it to `recipient`.
     * @param recipient The address to receive the NFT
     * @param tokenURI The metadata URI (e.g., "ipfs://QmMeta...")
     * @return The ID of the newly minted token
     */
    function mintNFT(address recipient, string memory tokenURI)
        public
        onlyOwner
        returns(uint256)
    {
        // Get current ID and increment
        uint256 tokenId = _nextTokenId++;

        // 1. Mint the token to the recipient
        _safeMint(recipient, tokenId);

        // 2. Set the metadata URI for this specific token
        // This links Token ID <-> IPFS Hash
        _setTokenURI(tokenId, tokenURI);

        return tokenId;
    }
}