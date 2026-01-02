// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title DeFiToken
 * @notice An advanced ERC20 token with auto-tax, burn, and anti-whale mechanisms.
 * @dev Demonstrates how to override the `_update` function to intercept and modify transfers.
 */
contract DeFiToken is ERC20, Ownable {
    // Fee: 5% total (2.5% Burn + 2.5% Treasury)
    uint256 public constant TOTAL_FEE = 500;    // 500 basis points = 5%
    uint256 public constant DENOMINATOR = 10000;

    // Limits: Max wallet holds 2% of supply
    uint256 public constant MAX_WALLET_PERCENT = 2;

    address public treasury;

    // Accounts excluded from fees and limits (e.g., Owner, DEX Pair)
    mapping(address => bool) public isExcluded;

    // === Events ===
    event TreasuryUpdated(address oldTreasury, address newTreasury);
    event ExclusionChanged(address account, bool isExcluded);

    constructor(address _treasury) ERC20("SmartDeFiToken", "SDT") Ownable(msg.sender) {
        require(_treasury != address(0), "Invalid treasury");
        treasury = _treasury;

        // 1. Initial Supply Minting
        // 1 million tokens
        _mint(msg.sender, 1_000_000 * 10 ** decimals());

        // 2. Setup Exclusions
        // Owner and Treasury should bypass limits and fees
        isExcluded[treasury] = true;
        isExcluded[msg.sender] = true;
        isExcluded[address(this)] = true;
    }

    /**
     * @dev Updates the treasury address.
     */
    function setTreasury(address _newTreasury) external onlyOwner {
        require(_newTreasury != address(0), "Invalid treasury");
        emit TreasuryUpdated(treasury, _newTreasury);

        // Revoke old treasury privilege
        isExcluded[treasury] = false;

        // Grant new treasury privilege
        treasury = _newTreasury;
        isExcluded[treasury] = true;
    }

    /**
     * @dev Add or remove an address from exclusion list.
     */
    function setExclusion(address _account, bool _status) external onlyOwner {
        emit ExclusionChanged(_account, _status);
        isExcluded[_account] = _status;
    }

    /**
     * @dev The CORE logic of ERC20 v5.
     * All mints, burns, and transfers go through this function.
     * We override it to inject our Tax and Anti-Whale logic.
     * * @param from The sender address (address(0) for mints)
     * @param to The recipient address (address(0) for burns)
     * @param value The amount being transferred
     */
    function _update(address from, address to, uint256 value) internal override {
        // 1. Skip logic for Minting and Burning (optional, but cleaner)
        if(from == address(0) || to == address(0)) {
            super._update(from, to, value);
            return;
        }

        // 2. Check if the transfer involves an excluded account
        bool takeFee = true;
        if(isExcluded[from] || isExcluded[to]) {
            takeFee = false;
        }

        uint256 transferAmount = value;

        if(takeFee) {
            // --- Logic A: Calculate Fees ---
            uint256 taxAmount = (value * TOTAL_FEE) / DENOMINATOR;
            uint256 burnAmount = taxAmount / 2;
            uint256 treasuryAmount = taxAmount - burnAmount;

            transferAmount = value - taxAmount;

            // --- Logic B: Execute Fee Transfers ---
            // Send to Treasury
            super._update(from, treasury, treasuryAmount);

            // Burn (Send to address(0))
            super._update(from, address(0), burnAmount);
        }

        // --- Logic C: Anti-Whale Check ---
        // If the recipient is not excluded, check their new balance limit
        if(!isExcluded[to]) {
            require(
                balanceOf(to) + transferAmount <= ((totalSupply() * MAX_WALLET_PERCENT) / 100),
                "Exceeds max wallet limit"
            );
        }

        // 3. Final Transfer to Recipient
        // Perform the actual move of the remaining tokens
        super._update(from, to, transferAmount);
    }
}