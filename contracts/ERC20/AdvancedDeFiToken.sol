// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Capped.sol";    // 1. Cap on supply
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";    // 2. Gasless approval
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Votes.sol";     // 3. Voting rights (DAO)
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20FlashMint.sol"; // 4. Flash Loan
import "@openzeppelin/contracts/access/Ownable.sol";

contract AdvancedDeFiToken is 
    ERC20, 
    ERC20Capped, 
    ERC20Permit, 
    ERC20Votes, 
    ERC20FlashMint, 
    Ownable 
{
    // Burn tax rate for transfers (2%) (Unit: Basis Points, 10000 = 100%)
    uint256 private constant BURN_TAX_RATE = 200;

    // Whitelist for tax exemption
    mapping(address => bool) private isExcludedFromTax;

    constructor(uint256 cap) 
        ERC20("Advanced DeFi Token", "ADT")
        ERC20Capped(cap * 10**18)   // Set max supply cap
        ERC20Permit("Advanced DeFi Token")
        Ownable(msg.sender)
    {
        // Exclude deployer from tax
        isExcludedFromTax[msg.sender] = true;

        // Initial mint (Mint only 50% of the Cap to the deployer)
        ERC20._mint(msg.sender, (cap * 10**18) / 2);
    }

    // Getter Function
    function getTaxRate() external pure returns(uint256) {
        return BURN_TAX_RATE;
    }

    // Getter Function
    function getIsExcludedFromTax(address account) external view returns(bool) {
        return isExcludedFromTax[account];
    }

    /**
     * @dev Sets the tax exemption status for an account (Only admin)
     * @param account The address to update
     * @param tf Whether the address is excluded from tax
     */
    function setExcludedFromTax(address account, bool tf) external onlyOwner {
        isExcludedFromTax[account] = tf;
    }

    /**
     * @dev Core logic: Hook executed on every token state change (transfer, mint, burn).
     * In OpenZeppelin 5.0, `_update` replaces `_beforeTokenTransfer`.
     */
    function _update(address from, address to, uint256 value) internal override(ERC20, ERC20Capped, ERC20Votes) {
        // 1. Do not apply tax for Minting (from == 0) or Burning (to == 0)
        if(from == address(0) || to == address(0)) {
            super._update(from, to, value);
            return;
        }

        // 2. Apply tax logic 
        uint256 burnAmount = 0;
        uint256 sendAmount = value;

        // Apply tax if the sender is not excluded
        if(!isExcludedFromTax[from]) {
            burnAmount = (value * BURN_TAX_RATE) / 10000;   // Calculate 2% tax
            sendAmount -= burnAmount;                       // Subtract tax from total value
        }

        // 3. Call parent contracts' _update
        // Note: Logic is required here to handle the balance updates correctly.
        // Since `super._update` handles the balance transfer, we call it twice if tax applies:
        // once for the burn, and once for the actual transfer.

        // [Advanced Pattern] Handling tax within _update
        if(burnAmount > 0) {
            // Burn the tax amount from the sender (from -> address(0))
            // This also updates voting checkpoints automatically.
            super._update(from, address(0), burnAmount);
        }
        
        // Send the remaining amount to the recipient (from -> to)
        super._update(from, to, sendAmount);
    }

    /**
     * @dev Solve multiple inheritance conflict (Override Hell)
     * Both ERC20Votes and ERC20Permit have a `nonces` function.
     * We explicitly override to use the logic from ERC20Permit (and Nonces).
     */
    function nonces(address owner) public view override(ERC20Permit, Nonces) returns (uint256) {
        return super.nonces(owner);
    }
}