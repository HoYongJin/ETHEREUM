// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

contract LogicV1 is Initializable, OwnableUpgradeable, UUPSUpgradeable {
    // OZ v5 uses "Namespaced Storage" (ERC-7201).
    // Parent contracts like OwnableUpgradeable store their state in
    // hashed slots (random-looking locations)

    // [Storage Slot 0] - The first state variable
    uint256 public val;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(uint256 _val) public initializer {
        __Ownable_init(msg.sender); 
        __UUPSUpgradeable_init();
        val = _val;
    }

    // Only the owner can authorize a upgrade
    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}

    function version() public pure virtual returns (string memory) {
        return "V1";
    }
}

contract LogicV2 is LogicV1 {
    // [Storage Hierarchy]
    // LogicV2 inherits LogicV1.
    // LogicV1 takes Slot 0 ('val').
    
    // New variables MUST be appended to avoid collision with V1 layout.
    // [Storage Slot 1]
    uint256 public multiplier; 

    function version() public pure override returns (string memory) {
        return "V2";
    }

    function setMultiplier(uint256 _multiplier) public {
        multiplier = _multiplier;
    }

    // Logic using both Slot 0 and Slot 1
    function getMultipliedVal() public view returns (uint256) {
        return val * multiplier;
    }
}