// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";

/**
 * @title ProtocolCore
 * @notice The core logic contract for the DeFi protocol, managed by a TimelockController.
 * @dev This contract implements Ownable for access control and Pausable for emergency stops.
 * Ideally, ownership should be transferred to a TimelockController after deployment.
 */
contract ProtocolCore is Ownable, Pausable {
    /**
     * @dev Structure to hold protocol configuration parameters.
     * @param feeBasisPoints The transaction fee in basis points(e.g., 100 = 1%).
     * @param treasury The address where collected fees are sent.
     */
    struct Config {
        uint256 feeBasisPoints;
        address treasury;
    }

    uint256 public version;
    Config public config;

    /**
     * @dev Emitted when the protocol configuration is updated.
     * @param newFee The new fee value in basis points.
     * @param newTreasury The address of the new treasury.
     */
    event ConfigUpdated(uint256 newFee, address newTreasury);

    /**
     * @dev Emitted when the protocol version is incremented.
     * @param newVersion The updated version number.
     */
    event Upgraded(uint256 newVersion);

    /**
     * @notice Initializes the contract with default values.
     * @dev Sets the initial owner to the deployer. Ownership should be transferred later.
     */
    constructor() Ownable(msg.sender) {
        version = 1;
        // Default config: 1% fee (100 bps), treasury is the deployer initially
        config = Config(100, msg.sender);
    }

    /**
     * @notice Updates the protocol configuration.
     * @dev Can only be called by the owner(Timelock).
     * This function is allowed even when the contract is paused to enable fixes during emergencies.
     * @param _newFee The new fee in basis points.
     * @param _newTreasury The new treasury address.
     */
    function updateConfig(uint256 _newFee, address _newTreasury) external onlyOwner {
        config = Config(_newFee, _newTreasury);
        emit ConfigUpdated(_newFee, _newTreasury);
    }

    /**
     * @notice Bumps the protocol version number.
     * @dev Can only be called by the owner(Timelock).
     * Typically called after a batch of configuration updates is complete.
     */
    function upgradeVersion() external onlyOwner {
        version++;
        emit Upgraded(version);
    }

    /**
     * @notice Triggers an emergency pause of the protocol.
     * @dev Can only be called by the owner(Timelock).
     * Calls the internal `_pause` function from OpenZeppelin's Pausable.
     * While paused, functions with the `whenNotPaused` modifier will revert.
     */
    function pause() external onlyOwner {
        _pause();
    }

    /**
     * @notice Unpauses the protocol, resuming normal operations.
     * @dev Can only be called by the owner(Timelock).
     * Calls the internal `_unpause` function from OpenZeppelin's Pausable.
     */
    function unpause() external onlyOwner {
        _unpause();
    }

    /**
     * @notice Simulates a user deposit action.
     * @dev This function demonstrates the usage of the `whenNotPaused` modifier.
     * If the protocol is paused, users cannot call this function.
     */
    function deposit() external payable whenNotPaused {
        // ... Critical business logic for deposit ...
    }
}