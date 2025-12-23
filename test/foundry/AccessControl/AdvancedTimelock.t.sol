// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {TimelockController} from "@openzeppelin/contracts/governance/TimelockController.sol";
import {ProtocolCore} from "../../../contracts/AccessControl/ProtocolCore.sol";

/**
 * @title AdvancedTimelockTest
 * @notice Comprehensive test suite for TimelockController features.
 * @dev Covers: Batch execution, Predecessor dependencies, Cancellation, Self-administration.
 */
contract AdvancedTimelockTest is Test {
    TimelockController public timelock;
    ProtocolCore public core;

    // Roles
    address public admin = makeAddr("admin");         // Proposer
    address public guardian = makeAddr("guardian");   // Canceller
    address public executor = makeAddr("executor");   // Executor (Anyone)

    // Constants
    uint256 constant MIN_DELAY = 1 days;

    function setUp() public {
        // 1. Setup Timelock Roles
        address[] memory proposers = new address[](1);
        proposers[0] = admin;

        address[] memory executors = new address[](1);
        executors[0] = executor;

        vm.startPrank(admin);

        // 2. Deploy Timelock
        // admin: address(0) means the Timelock itself is the admin (Self-Administered)
        timelock = new TimelockController(
            MIN_DELAY,
            proposers,      // Grants PROPOSER & CANCELLER
            executors,      // Grants EXECUTOR
            address(0)      // Admin defaults to Timelock contract
        );

        // 3. Deploy Core & Transfer Ownership
        core = new ProtocolCore();
        core.updateConfig(100, address(timelock));
        core.transferOwnership(address(timelock));

        vm.stopPrank();
    }

    /**
     * @notice SCENARIO 1: Batch Operation & Predecessor Dependency
     * Logic: We want to update config(Op A) AND upgrade version(Op B).
     * Constraint: Op B MUST happen after Op A is finished.
     */
    function test_BatchAndPredecessor() public {
        vm.startPrank(admin);

        // --- Step 1: Prepare Operation A (Batch Update) ---
        // We want to call updateConfig(500, admin)
        address[] memory targetsA = new address[](1);
        targetsA[0] = address(core);

        uint256[] memory valuesA = new uint256[](1);
        valuesA[0] = 0;

        bytes[] memory payloadsA = new bytes[](1);
        payloadsA[0] = abi.encodeCall(ProtocolCore.updateConfig, (500, admin));

        bytes32 saltA = keccak256("OperationA");

        // Schedule Batch A (No predecessor)
        timelock.scheduleBatch(
            targetsA, 
            valuesA, 
            payloadsA, 
            bytes32(0), 
            saltA, 
            MIN_DELAY
        );

        // Calculate ID for Op A to use as predecessor for Op B
        bytes32 idA = timelock.hashOperationBatch(targetsA, valuesA, payloadsA, bytes32(0), saltA);

        // --- Step 2: Prepare Operation B (Upgrade Version) ---
        // Constraint: This depends on idA
        bytes memory payloadB = abi.encodeCall(ProtocolCore.upgradeVersion, ());
        bytes32 saltB = keccak256("OperationB");

        timelock.schedule(
            address(core),
            0,
            payloadB,
            idA,
            saltB,
            MIN_DELAY
        );

        vm.stopPrank();

        // --- Step 3: Execution Attempt (Before Delay) ---
        vm.warp(block.timestamp + MIN_DELAY + 1 seconds);
        vm.startPrank(executor);

        // Try executing Op B first? -> Should FAIL
        // Reason: Predecessor(Op A) is not "Done" yet
        vm.expectRevert();
        timelock.execute(
            address(core),
            0,
            payloadB,
            idA,
            saltB
        );

        // Correct Order: Execute Op A first
        timelock.executeBatch(
            targetsA, 
            valuesA, 
            payloadsA, 
            bytes32(0), 
            saltA
        );

        // Verify Op A result
        (uint256 fee, address treasury) = core.config();
        assertEq(fee, 500);
        assertEq(treasury, admin);

        // Now Execute Op B -> Should SUCCESS
        timelock.execute(
            address(core), 
            0, 
            payloadB, 
            idA, 
            saltB
        );
        
        // Verify Op B result
        assertEq(core.version(), 2);

        vm.stopPrank();
    }

    /**
     * @notice SCENARIO 2: Emergency Cancellation
     * Logic: Admin proposes a malicious pause, Guardian cancels it.
     */
    function test_Cancellation() public {
        vm.startPrank(admin);

        // Malicious Payload: Pause the protocol
        bytes memory data = abi.encodeCall(ProtocolCore.pause, ());
        bytes32 salt = keccak256("Malicious");

        timelock.schedule(
            address(core), 
            0, 
            data, 
            bytes32(0), 
            salt, 
            MIN_DELAY
        );

        bytes32 id = timelock.hashOperation(
            address(core), 
            0, 
            data, 
            bytes32(0), 
            salt
        );

        // Guardian notices the malicious proposal!
        // Note: Admin in this setup also has Canceller role, but we use 'admin' account as proposer here.
        // Let's assume 'admin' realizes mistake or 'guardian' acts.
        // Since 'admin' is in the proposers array, they have CANCELLER_ROLE by default constructor logic.
        timelock.cancel(id);
        vm.stopPrank();
        
        // Time passes...
        vm.warp(block.timestamp + MIN_DELAY + 1 seconds);

        // Executor tries to run it -> Fail
        vm.startPrank(executor);
        vm.expectRevert(); // TimelockUnexpectedOperationState
        timelock.execute(
            address(core), 
            0, 
            data, 
            bytes32(0), 
            salt
        );
        vm.stopPrank();
    }

    /**
     * @notice SCENARIO 3: Self-Administration (Update Delay)
     * Logic: The Timelock updates its own 'minDelay' parameter.
     * This requires the Timelock to call 'updateDelay' on itself.
     */
    function test_UpdateMinDelay() public {
        vm.startPrank(admin);

        uint256 newDelay = 2 days;
        bytes memory data = abi.encodeCall(TimelockController.updateDelay, (newDelay));
        bytes32 salt = keccak256("UpdateDelay");

        // Target is the Timelock itself!
        timelock.schedule(
            address(timelock),
            0,
            data,
            bytes32(0),
            salt,
            MIN_DELAY
        );

        vm.stopPrank();

        // Wait
        vm.warp(block.timestamp + MIN_DELAY + 1 seconds);

        // Execute
        vm.startPrank(executor);
        timelock.execute(
            address(timelock),
            0,
            data,
            bytes32(0),
            salt
        );
        vm.stopPrank();

        // Verification
        assertEq(timelock.getMinDelay(), newDelay);
    }
}