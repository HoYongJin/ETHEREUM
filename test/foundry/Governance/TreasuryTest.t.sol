// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "@openzeppelin/contracts/governance/TimelockController.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";

import {MyToken, MyGovernor} from "../../../contracts/Governance/MyGovernor.sol";
import {TreasuryV1, TreasuryV2} from "../../../contracts/Governance/Treasury.sol";

contract TreasuryTest is Test {
    MyToken token;
    MyGovernor governor;
    TimelockController timelock;
    ERC1967Proxy treasuryProxy;
    TreasuryV1 treasuryV1;
    TreasuryV2 treasuryV2;

    address admin = makeAddr("admin");

    // Voter needs a Private Key to sign messages off-chain (EIP-712)
    uint256 voterPrivateKey = 0xA11CE;
    address voter = vm.addr(voterPrivateKey);
    
    // Relayer submits the vote on behalf of the voter (pays gas)
    address relayer = makeAddr("relayer");
    
    // Developer receives the grant funding
    address developer = makeAddr("developer");

    function setUp() public {
        vm.startPrank(admin);

        // 1. Deploy Token & Distribute
        token = new MyToken();
        token.transfer(voter, 10_000 ether);

        // 2. Deploy Infrastructure (Timelock & Governor)
        address[] memory empty;
        timelock = new TimelockController(1 days, empty, empty, admin);
        governor = new MyGovernor(token, timelock);

        // 3. Role Setup
        // Only the Governor can propose to the Timelock
        timelock.grantRole(timelock.PROPOSER_ROLE(), address(governor));
        // Anyone can execute after the delay
        timelock.grantRole(timelock.EXECUTOR_ROLE(), address(0));
        // Revoke admin rights to ensure decentralization
        timelock.revokeRole(timelock.DEFAULT_ADMIN_ROLE(), admin);

        // 4. Deploy Treasury (Target Contract)
        treasuryV1 = new TreasuryV1();
        bytes memory initData = abi.encodeCall(TreasuryV1.initialize, ());
        treasuryProxy = new ERC1967Proxy(address(treasuryV1), initData);

        // Transfer Ownership to Timelock
        // This allows the DAO (via Timelock) to call 'upgradeTo' and 'sendGrant'.
        TreasuryV1(address(treasuryProxy)).transferOwnership(address(timelock));

        // Fund the Treasury with 1000 ETH for the grant test
        vm.deal(address(treasuryProxy), 1_000 ether);

        vm.stopPrank();

        // 5. Delegate Voting Power
        // Voter must delegate to activate checkpoints
        vm.startPrank(voter);
        token.delegate(voter);
        vm.stopPrank();
        
        // Advance block to finalize the delegation checkpoint
        vm.roll(block.number + 1);
    }

    function test_GrandDAOProposal() public {
        // Prepare the V2 implementation logic
        treasuryV2 = new TreasuryV2();

        // 1. Construct Batch Proposal (3 Actions in 1 Proposal)
        address[] memory targets = new address[](3);
        uint256[] memory values = new uint256[](3);
        bytes[] memory calldatas = new bytes[](3);

        // Action 1: Upgrade Treasury to V2
        // Target: Treasury Proxy
        // Logic: Call 'upgradeToAndCall'
        targets[0] = address(treasuryProxy);
        values[0] = 0;
        calldatas[0] = abi.encodeCall(
            UUPSUpgradeable.upgradeToAndCall,
            (address(treasuryV2), "")
        );

        // Action 2: Send Grant (500 ETH)
        // Target: Treasury Proxy
        // Logic: Call 'sendGrant' defined in TreasuryV1
        // Note: The Timelock (Owner) will be the caller, satisfying 'onlyOwner'.
        targets[1] = address(treasuryProxy);
        values[1] = 0;
        calldatas[1] = abi.encodeCall(
            treasuryV1.sendGrant,
            (developer, 500 ether)
        );

        // --- Action 3: Change Governance Config ---
        // Target: Governor itself
        // Logic: Change voting period from 1 week to 2 weeks
        // Note: Governor allows this via 'onlyGovernance' (Timelock calls Governor).
        targets[2] = address(governor);
        values[2] = 0;
        calldatas[2] = abi.encodeCall(
            governor.setVotingPeriod,
            (2 days)
        );

        string memory description = "Grand Proposal: Upgrade, Pay, and Config";
        bytes32 descriptionHash = keccak256(bytes(description));

        // Submit the Batch Proposal
        vm.startPrank(voter);
        uint256 proposalId = governor.propose(targets, values, calldatas, description);
        vm.stopPrank();

        // Pass Voting Delay to start voting
        vm.warp(block.timestamp + governor.votingDelay() + 1);
        vm.roll(block.number + governor.votingDelay() + 1);

        // 2. Gasless Voting (EIP-712 Signature)
        // The voter signs a message off-chain, and a Relayer submits it on-chain.

        // A. Get the Domain Separator (Unique ID for this contract & chain)
        bytes32 domainSeparator = keccak256(abi.encode(
            keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"),
            keccak256(bytes(governor.name())), // Contract Name
            keccak256(bytes("1")),               // Version
            block.chainid,
            address(governor)
        ));

        // B. Define the TypeHash (Schema of the data being signed)
        // This must match the definition in the Governor contract.
        bytes32 BALLOT_TYPEHASH = keccak256(
            "Ballot(uint256 proposalId,uint8 support,address voter,uint256 nonce)"
        );

        // C. Create the Struct Hash (The actual data)
        bytes32 structHash = keccak256(abi.encode(
            BALLOT_TYPEHASH,
            proposalId,
            1,  // 1 = for
            voter,
            governor.nonces(voter)
        ));

        // D. Create the Final Digest (Domain + Struct)
        bytes32 digest = MessageHashUtils.toTypedDataHash(domainSeparator, structHash);

        // E. Sign the digest using Voter's Private Key
        // This generates v, r, s (ECDSA signature components)
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(voterPrivateKey, digest);

        // Combine into a single bytes array
        bytes memory signature = abi.encodePacked(r, s, v);

        // 3. Relayer Submits the Vote
        
        // Switch context to Relayer(someone else paying for gas)
        vm.startPrank(relayer);

        // Verify signature and count the vote for the Voter
        governor.castVoteBySig(proposalId, 1, voter, signature);

        vm.stopPrank();

        vm.warp(block.timestamp + governor.votingPeriod() + 1);
        vm.roll(block.number + governor.votingPeriod() + 1);

        governor.queue(targets, values, calldatas, descriptionHash);

        vm.warp(block.timestamp + 1 days + 1);

        // 4. Execute & Verify Batch Operations

        // Execute all 3 actions atomically
        governor.execute(targets, values, calldatas, descriptionHash);

        // Verification 1: Did the upgrade happen?
        // Check if the proxy now returns "V2"
        assertEq(TreasuryV2(address(treasuryProxy)).version(), "V2");

        // Verification 2: Did the grant transfer happen?
        // Developer balance should be 500, Treasury should decrease by 500
        assertEq(developer.balance, 500 ether);
        assertEq(address(treasuryProxy).balance, 500 ether);

        // Verification 3: Did the Governor config change?
        // Voting period should now be 2 weeks
        assertEq(governor.votingPeriod(), 2 days);
    }
}