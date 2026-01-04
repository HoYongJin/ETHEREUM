// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

contract TreasuryV1 is OwnableUpgradeable, UUPSUpgradeable {
    constructor() {
        _disableInitializers();
    }
    
    function initialize() public initializer {
        __Ownable_init(msg.sender);
        __UUPSUpgradeable_init();
    }

    function sendGrant(address to, uint256 amount) external onlyOwner {
        (bool success, ) = payable(to).call{value: amount}("");
        require(success, "Transfer failed");
    }

    function _authorizeUpgrade(address) internal override onlyOwner {}

    function version() public pure virtual returns (string memory) { 
        return "V1"; 
    }
}

contract TreasuryV2 is TreasuryV1 {
    event GrantSent(address indexed to, uint256 amount);

    function version() public pure override returns (string memory) { 
        return "V2"; 
    }
}