// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {ActionExecutor} from "../../../contracts/Governance/ActionExecutor.sol";
import {Treasury, SystemConfig} from "../../../contracts/Governance/Targets.sol";

contract AbiCallTest is Test {
    ActionExecutor executor;
    Treasury treasury;
    SystemConfig config;

    address alice = makeAddr("alice");
    address owner = makeAddr("owner");

    function setUp() public {
        vm.startPrank(owner);
        executor = new ActionExecutor();
        treasury = new Treasury();
        config = new SystemConfig();
        vm.deal(address(treasury), 10 ether);
        vm.deal(address(this), 10 ether);

        treasury.transferOwnership(address(executor));
        config.transferOwnership(address(executor));

        vm.stopPrank();
    }

    /**
     * @notice Scenario 1: Batch Execution & Return Data Decoding
     * Execute [Set Tax] + [Release Funds] in a single transaction.
     */
    function test_BatchExecutionAndDecoding() public {
        // Generate Payload (Encoding)

        // Action 1: SystemConfig.setTaxRate(10)
        // Calling a function that returns a value
        bytes memory data1 = abi.encodeCall(config.setTaxRate, (10));

        // Action 2: Treasury.release(alice, 1 ether)
        // Calling a payable function (sending 0 value here, triggering logic only)
        bytes memory data2 = abi.encodeCall(treasury.release, (alice, 1 ether));

        ActionExecutor.Action[] memory actions = new ActionExecutor.Action[](2);

        actions[0] = ActionExecutor.Action({
            target: address(config),
            value: 0,
            data: data1
        });

        actions[1] = ActionExecutor.Action({
            target: address(treasury),
            value: 0,
            data: data2
        });

        // Execution
        vm.recordLogs();
        executor.executeBatch(actions);

        // Verification & Decoding
        assertEq(config.taxRate(), 10);
        assertEq(address(treasury).balance, 9 ether);
        assertEq(alice.balance, 1 ether);



        // [Advanced] Decoding Return Data
        // The first action (setTaxRate) returned the 'oldRate' (uint256).
        // We can retrieve and decode it from the logs if needed.
        
        // Example logic (conceptual):
        // bytes memory returnData = ... (get from logs);
        // uint256 oldRate = abi.decode(returnData, (uint256));
    }

    /**
     * @notice Scenario 2: Error Bubbling
     * Verify that the error message from the target (SystemConfig) bubbles up through the Executor.
     */
    function test_RevertReasonBubbling() public {
        // Generate failing data (Value > 100 triggers "Rate too high")
        bytes memory failData = abi.encodeCall(SystemConfig.setTaxRate, (999));

        ActionExecutor.Action[] memory actions = new ActionExecutor.Action[](1);
        actions[0] = ActionExecutor.Action({
            target: address(config),
            value: 0,
            data: failData
        });

        // The Executor must not just say "Low-level call failed"
        // It must reveal the specific reason ("Rate too high") from SystemConfig.
        vm.expectRevert("Rate too high");
        
        executor.executeBatch(actions);
    }

    /**
     * @notice Scenario 3: Payable Call (Sending Value)
     * Sending ETH through the Executor to the target contract.
     */
    function test_PayableCall() public {
        // Scenario: Donating ETH to the Treasury (Triggering receive())
        // Data is empty ("") because we are just sending ETH.
        bytes memory emptyData = "";

        ActionExecutor.Action[] memory actions = new ActionExecutor.Action[](1);
        actions[0] = ActionExecutor.Action({
            target: address(treasury),
            value: 5 ether, // Sending 5 ETH along with the call
            data: emptyData
        });

        // Call executeBatch with 5 ETH attached
        executor.executeBatch{value: 5 ether}(actions);

        // Verify Treasury balance: 10 (initial) + 5 (received) = 15
        assertEq(address(treasury).balance, 15 ether);
    }
}