// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../../../contracts/ERC721/MyNFT.sol";

contract MyNFTTest is Test {
    MyNFT myNFT;

    address owner = address(1);
    address recipient = address(2);

    function setUp() public {
        vm.prank(owner);
        myNFT = new MyNFT();
    }

    // [Test] Verify Minting and Metadata URI storage
    function testMintAndTokenURI() public {
        string memory ipfsURI = "ipfs://bafkreiaok2xuspb5cnjajjaqa3n7qvr3maudvaryrj6fx72p5hqa5ybhzi";

        // 1. Mint NFT as owner
        vm.prank(owner);
        uint256 tokenId = myNFT.mintNFT(recipient, ipfsURI);

        // 2. Check Ownership
        assertEq(myNFT.ownerOf(tokenId), recipient);

        // 3. Check Balance
        assertEq(myNFT.balanceOf(recipient), 1);

        // 4. Verify Token URI
        // It must return the exact IPFS string we passed.
        string memory storedURI = myNFT.tokenURI(tokenId);
        assertEq(storedURI, ipfsURI);

        // Log for visual check
        console.log("Minted Token ID:", tokenId);
        console.log("Stored URI:", storedURI);
    }
}