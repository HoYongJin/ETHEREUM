// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../../../contracts/ERC721/DeepDiveNFT.sol";

contract DeepDiveNFTTest is Test {
    DeepDiveNFT nft;
    address admin = address(1);
    address user = address(2);

    function setUp() public {
        vm.prank(admin);
        nft = new DeepDiveNFT("DeepDive", "DD", "ipfs://QmBaseMetadata/");

        vm.deal(user, 10 ether);
    }

    /**
     * @notice Verifies that standard minting works and token URIs are correct.
     */
    function testMint() public {
        vm.startPrank(user);

        uint256 quantity = 3;
        uint256 cost = nft.MINT_PRICE() * quantity;

        nft.mint{value: cost}(quantity);

        assertEq(nft.balanceOf(user), 3);
        assertEq(nft.tokenURI(0), "ipfs://QmBaseMetadata/0");
        assertEq(nft.tokenURI(1), "ipfs://QmBaseMetadata/1");
        assertEq(nft.tokenURI(2), "ipfs://QmBaseMetadata/2");

        vm.stopPrank();
    }

    /**
     * @notice Tests AccessControl: Only admin/pauser can pause.
     */
    function testPauseRole() public {
        // 1. User tries to pause -> Should Revert
        vm.prank(user);
        vm.expectRevert(); // Expect AccessControl error
        nft.pause();

        // 2. Admin tries to pause -> Should Succeed
        vm.prank(admin);
        nft.pause();

        // 3. Verify Paused state: Minting should fail
        vm.prank(user);
        vm.expectRevert(); // "Pausable: paused"
        nft.mint{value: 0.01 ether}(1);
    }

    /**
     * @notice Measures gas usage for loop-based minting.
     * Check the console output to see how expensive it is.
     */
    function testGasUsageLoop() public {
        vm.startPrank(user);
        uint256 quantity = 5;
        uint256 cost = nft.MINT_PRICE() * quantity;

        uint256 gasStart = gasleft();
        nft.mint{value: cost}(quantity);
        uint256 gasUsed = gasStart - gasleft();

        console.log("Gas used for minting 5 tokens (Standard Loop):", gasUsed);
    }
}