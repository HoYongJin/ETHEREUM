// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract MyPermitToken is ERC20, ERC20Permit {
    constructor() ERC20("MyToken", "MTK") ERC20Permit("MyToken") {
        _mint(msg.sender, 10_000 * 1e18);
    }
}

// 2. Gasless Deposit Vault (Core)
contract GaslessVault {
    using SafeERC20 for IERC20;

    IERC20Permit public immutable token;
    mapping(address => uint256) public balances;

    event Deposited(address indexed owner, uint256 amount, address relayer, uint256 fee);

    constructor(address _token) {
        token = IERC20Permit(_token);
    }

    /**
     * @notice Executes approval and deposit in a single transaction using Permit signature.
     * @dev This function is called by a Relayer (Bob), not the User.
     * @param owner The signer (Alice)
     * @param amount Total approved amount (Deposit + Fee)
     * @param deadline Signature deadline
     * @param v Signature parameter v
     * @param r Signature parameter r
     * @param s Signature parameter s
     * @param relayerFee Fee paid to the relayer (Bob)
     */
    function depositWithPermit(
        address owner,
        uint256 amount,
        uint256 deadline,
        uint8 v, bytes32 r, bytes32 s,
        uint256 relayerFee
    ) external {
        // 1. Execute Permit (Gasless Approve)
        // Here, Alice's signature is verified, and this contract (Vault) gains permission 
        // to spend the 'amount'.
        // Reverts if verification fails.
        token.permit(owner, address(this), amount, deadline, v, r, s);

        // 2. Transfer Funds (TransferFrom)
        // Now the Vault has allowance, so it can move funds.
        IERC20 erc20 = IERC20(address(token));
        uint256 depositAmount = amount - relayerFee;
        
        // 2-1. Pay fee to Relayer (msg.sender)
        if (relayerFee > 0) {
            erc20.safeTransferFrom(owner, msg.sender, relayerFee);
        }

        // 2-2. Deposit the rest into the Vault
        erc20.safeTransferFrom(owner, address(this), depositAmount);

        // 3. Update State
        balances[owner] += depositAmount;

        emit Deposited(owner, depositAmount, msg.sender, relayerFee);
    }
}