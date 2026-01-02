// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {LogicV1, LogicV2} from "../../../contracts/Governance/UUPS.sol"; 

contract UUPSTest is Test {
    LogicV1 logicV1;
    LogicV2 logicV2;
    ERC1967Proxy proxy;
    address owner = makeAddr("owner");

    // EIP-1967 Implementation Slot Constant
    // bytes32(uint256(keccak256('eip1967.proxy.implementation')) - 1)
    bytes32 constant IMPLEMENTATION_SLOT = 
        0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;

    function setUp() public {
        vm.startPrank(owner);

        // 1. Deploy Logic V1
        logicV1 = new LogicV1();

        // 2. Deploy Proxy and Initialize val = 100
        bytes memory initData = abi.encodeCall(LogicV1.initialize, (100));
        proxy = new ERC1967Proxy(address(logicV1), initData);

        vm.stopPrank();
    }

    /**
     * @notice Inspect Storage Slots for OZ v5.x Compatibility
     */
    function test_V5StorageLayoutInspection() public {
        // 1. Verify standard access via getter
        LogicV1 proxyAsV1 = LogicV1(address(proxy));
        assertEq(proxyAsV1.val(), 100);

        // 2. Read raw Storage Slot 0
        // In OZ v5, Parent contracts (Ownable) use Namespaced Storage.
        // So, Slot 0 MUST be free for the child contract's variables.
        // 'val' (100) should be at Slot 0.
        bytes32 slot0Val = vm.load(address(proxy), bytes32(uint256(0)));
        // Explicit Assertion: Slot 0 MUST equal 100 (0x64)
        assertEq(uint256(slot0Val), 100);

        // 3. Verify EIP-1967 Implementation Slot
        bytes32 implSlotValue = vm.load(address(proxy), IMPLEMENTATION_SLOT);
        assertEq(address(logicV1), address(uint160(uint256(implSlotValue))));
    }

    /**
     * @notice Test Upgrade V1 -> V2 and New Storage (Slot 1)
     */
    function test_UpgradeAndNewStorage() public {
        vm.startPrank(owner);
        LogicV1 proxyAsV1 = LogicV1(address(proxy));

        // 1. Deploy V2 & Upgrade
        logicV2 = new LogicV2();
        proxyAsV1.upgradeToAndCall(address(logicV2), "");

        // 2. Cast to V2 interface
        LogicV2 proxyAsV2 = LogicV2(address(proxy));

        // 3. Verify Persistence (Slot 0)
        assertEq(proxyAsV2.val(), 100);

        // 4. Set new variable (Slot 1)
        proxyAsV2.setMultiplier(10);

        // 5. Verify Logic
        assertEq(proxyAsV2.getMultipliedVal(), 1_000);

        // 6. Check Slot 1
        bytes32 slot1Val = vm.load(address(proxy), bytes32(uint256(1)));
        assertEq(uint256(slot1Val), 10);

        vm.stopPrank();
    }
}