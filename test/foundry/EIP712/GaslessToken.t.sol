// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../../../contracts/EIP712/GaslessToken.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";

/**
 * @title GaslessTokenTest
 * @notice Unit tests for GaslessToken EIP-712 functionality.
 */
contract GaslessTokenTest is Test {
    GaslessToken internal token;
    uint256 internal ownerPrivateKey;
    address internal owner;
    address internal receiver;
    address internal relayer;

    bytes32 private constant TRANSFER_REQUEST_TYPEHASH =
        keccak256("TransferRequest(address owner,address to,uint256 value,uint256 nonce,uint256 deadline)");

    function setUp() public {
        ownerPrivateKey = 0x123;
        owner = vm.addr(ownerPrivateKey);
        receiver = address(1);
        relayer = address(2);

        token = new GaslessToken();
        token.transfer(owner, 100 ether);
    }

    function testGaslessTransfer() public {
        uint256 nonce = token.nonces(owner);
        uint256 value = 10 ether;
        uint256 deadline = block.timestamp + 1 hours;

        // 1. Create Signature
        bytes memory signature = _signTransferRequest(ownerPrivateKey, owner, receiver, value, nonce, deadline);
        
        // 2. Relayer executes transaction
        vm.prank(relayer);
        token.executeTransfer(owner, receiver, value, deadline, signature);

        // 3. Assertions
        assertEq(token.balanceOf(owner), 90 ether);
        assertEq(token.balanceOf(receiver), 10 ether);
        assertEq(token.nonces(owner), nonce + 1);
    }

    function testRevertSignatureExpired() public {
        uint256 value = 10 ether;
        uint256 nonce = token.nonces(owner);
        // Set deadline in the past
        uint256 deadline = block.timestamp - 1;

        bytes memory signature = _signTransferRequest(ownerPrivateKey, owner, receiver, value, nonce, deadline);

        vm.expectRevert(
            abi.encodeWithSelector(GaslessToken.SignatureExpired.selector, deadline, block.timestamp)
        );
        vm.prank(relayer);
        token.executeTransfer(owner, receiver, value, deadline, signature);
    }

    function testRevertInvalidSignature() public {
        uint256 value = 10 ether;
        uint256 nonce = token.nonces(owner);
        uint256 deadline = block.timestamp + 1 hours;

        // Sign with WRONG private key (hacker)
        uint256 hackerPrivateKey = 0xBADC0DE;
        bytes memory signature = _signTransferRequest(hackerPrivateKey, owner, receiver, value, nonce, deadline);

        vm.expectRevert(GaslessToken.InvalidSignature.selector);
        vm.prank(relayer);
        token.executeTransfer(owner, receiver, value, deadline, signature);
    }

    function _signTransferRequest(
        uint256 pk,
        address _owner,
        address _to,
        uint256 _value,
        uint256 _nonce,
        uint256 _deadline
    ) internal view returns(bytes memory) {
        bytes32 structHash = keccak256(
            abi.encode(
                TRANSFER_REQUEST_TYPEHASH,
                _owner,
                _to,
                _value,
                _nonce,
                _deadline
            )
        );

        bytes32 domainSeparator = keccak256(
            abi.encode(
                keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"),
                keccak256(bytes("GaslessToken")),
                keccak256(bytes("1")),
                block.chainid,
                address(token)
            )
        );

        bytes32 digest = MessageHashUtils.toTypedDataHash(domainSeparator, structHash);

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(pk, digest);
        
        return abi.encodePacked(r, s, v);
    }
}

