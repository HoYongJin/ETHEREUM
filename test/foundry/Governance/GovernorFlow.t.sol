// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {TimelockController} from "@openzeppelin/contracts/governance/TimelockController.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {MyToken, MyGovernor, BoxV1, BoxV2} from "../../../contracts/Governance/MyGovernor.sol";

contract GovernorFlowTest is Test {
    MyToken token;
    MyGovernor governor;
    TimelockController timelock;
    ERC1967Proxy boxProxy;
    BoxV1 boxV1;
    BoxV2 boxV2;

    address admin = makeAddr("admin");
    address voter = makeAddr("voter");

    uint256 constant MIN_DELAY = 1 days;

    function setUp() public {
        vm.startPrank(admin);

        // Deploy ERC20Votes token. 10,000 tokens are minted to the admin
        token = new MyToken();

        // Transfer 10% of supply (1,000 tokens) to the voter.
        token.transfer(voter, 1_000 ether);
        vm.stopPrank();

        // In ERC20Votes, holding tokens does NOT automatically grant voting power.
        // Users must 'delegate' to themselves (or others) to create a checkpoint
        vm.startPrank(voter);
        token.delegate(voter);
        vm.stopPrank();

        vm.startPrank(admin);

        // Deploy TimelockController with a minimum delay.
        // Proposers and Executors arrays are empty for now(will set them up later)
        address[] memory proposers = new address[](0);
        address[] memory executors = new address[](0);
        timelock = new TimelockController(MIN_DELAY, proposers, executors, admin);

        // Connect the Governor to the Token (Voting Power) and Timelock (Execution).
        governor = new MyGovernor(token, timelock);

        // Role Setup (Wiring the Governance)
        // Fetch the role identifiers from the Timelock contract.
        bytes32 PROPOSER_ROLE = timelock.PROPOSER_ROLE();
        bytes32 EXECUTOR_ROLE = timelock.EXECUTOR_ROLE();
        bytes32 DEFAULT_ADMIN_ROLE = timelock.DEFAULT_ADMIN_ROLE();

        // 1. Grant 'Proposer' role to the Governor.
        // This ensures that ONLY successful proposals from the Governor can be queued in the Timelock.
        timelock.grantRole(PROPOSER_ROLE, address(governor));

        // 2. Grant 'Executor' role to address(0) (Anyone).
        // This allows ANYONE to execute a proposal once the timelock delay has passed.
        timelock.grantRole(EXECUTOR_ROLE, address(0));


        // 3. Revoke 'Admin' role from the deployer.
        // This removes the centralized control. Now, the system is fully decentralized,
        // and the Timelock is self-governed by its own rules.
        timelock.revokeRole(DEFAULT_ADMIN_ROLE, admin);

        // Deploy the logic contract.
        boxV1 = new BoxV1();
        
        // Prepare initialization data (abi.encodeCall avoids typo errors).
        bytes memory initData = abi.encodeCall(BoxV1.initialize, ());
        
        // Deploy the ERC1967 Proxy pointing to BoxV1 logic.
        boxProxy = new ERC1967Proxy(address(boxV1), initData);

        // Transfer Ownership to Timelock
        // In UUPS, the '_authorizeUpgrade' function is protected by 'onlyOwner'.
        // To allow the DAO to upgrade this contract, the Timelock must be the owner.
        // The upgrade flow will be: Governor -> Timelock -> Proxy.upgradeTo(newLogic).
        BoxV1(address(boxProxy)).transferOwnership(address(timelock));

        vm.stopPrank();
    }

    function test_FullGovernanceLifecycle() public {
        vm.roll(block.number + 1);

        // Prepare the new implementation logic (V2)
        boxV2 = new BoxV2();

        // 1. Create Proposal (Propose)

        // Define the action: Call 'upgradeTo(boxV2)' on the UUPS Proxy
        // abi.encodeCall is safer than abi.encodeWithSignature as it checks types
        bytes memory payload = abi.encodeCall(
            BoxV1(address(boxProxy)).upgradeToAndCall,
            (address(boxV2), "")
        );

        address[] memory targets = new address[](1);
        targets[0] = address(boxProxy);     // The contract to call

        uint256[] memory values = new uint256[](1);
        values[0] = 0;                      // No ETH sending required

        bytes[] memory calldatas = new bytes[](1);
        calldatas[0] = payload;             // The encoded function call

        string memory description = "Proposal #1: Upgrade Box to V2";
        bytes32 descriptionHash = keccak256(bytes(description));

        vm.startPrank(voter);

        // Submit the proposal to the Governor
        uint256 proposalId = governor.propose(
            targets, 
            values, 
            calldatas, 
            description
        );

        vm.stopPrank();

        // Check State: Pending (Enum index 0)
        // Proposal exists but voting hasn't started yet (Voting Delay).
        assertEq(uint(governor.state(proposalId)), 0);

        // 2. Voting Delay -> Transition to Active

        // Time Travel: Warp time and roll blocks forward to pass the delay.
        // GovernorVotes checks past block snapshots, so vm.roll is crucial.
        vm.warp(block.timestamp + governor.votingDelay() + 1);
        vm.roll(block.number + governor.votingDelay() + 1);

        // Check State: Active (Enum index 1)
        // Voting is now open.
        assertEq(uint(governor.state(proposalId)), 1);

        // 3. Cast Vote

        vm.startPrank(voter);
        // Vote Type: 0 = Against, 1 = For, 2 = Abstain
        // Voter supports the upgrade.
        governor.castVote(proposalId, 1); 
        vm.stopPrank();

        // 4. Voting Period End -> Transition to Succeeded

        // Time Travel: Warp forward to end the voting duration.
        vm.warp(block.timestamp + governor.votingPeriod() + 1);
        vm.roll(block.number + governor.votingPeriod() + 1);

        // Check State: Succeeded (Enum index 4)
        // Quorum reached and For > Against.
        assertEq(uint(governor.state(proposalId)), 4);

        // 5. Queue in Timelock -> Transition to Queued

        // Schedule the transaction in the Timelock.
        // This starts the countdown for the execution delay.   
        governor.queue(targets, values, calldatas, descriptionHash);

        // Check State: Queued (Enum index 5)
        assertEq(uint(governor.state(proposalId)), 5);

        // 6. Timelock Delay -> Ready for Execution

        // Time Travel: Wait for the Timelock's minimum delay
        // Before this time passes, execution will revert.
        vm.warp(block.timestamp + MIN_DELAY + 1);
        vm.roll(block.number + 100);

        // 7. Execute -> Transition to Executed

        // Execute the proposal.
        // Flow: Governor -> Timelock -> BoxProxy (upgradeTo)
        governor.execute(targets, values, calldatas, descriptionHash);

        // Check State: Executed (Enum index 7)
        assertEq(uint(governor.state(proposalId)), 7);

        // 8. Verification

        // Verify that the proxy now points to the V2 logic.
        BoxV2 upgradedBox = BoxV2(address(boxProxy));
        assertEq(upgradedBox.version(), "V2");
    }
}