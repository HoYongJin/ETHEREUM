// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract ActionExecutor {
    // Structure for governance proposal actions
    struct Action {
        address target; // Target contract address
        uint256 value; // Amount of ETH to send (for payable functions)
        bytes data; // Encoded function call data (Payload)
    }

    event Executed(uint256 index, address target, bytes returnData);

    /**
     * @dev Executes multiple actions atomically. Reverts the entire transaction if any action fails.
     */
    function executeBatch(Action[] calldata actions) external payable {
        for (uint256 i = 0; i < actions.length; i++) {
            (address target, uint256 value, bytes memory data) = (
                actions[i].target,
                actions[i].value,
                actions[i].data
            );
            
            (bool success, bytes memory returnData) = target.call{value: value}(data);
            
            if(!success) {
                _revertWithReason(returnData);
            }

            emit Executed(i, target, returnData);
        }
    }

    /**
     * @dev Helper function to decode and bubble up low-level revert data.
     * (Logic similar to OpenZeppelin's Address.sol)
     */
    function _revertWithReason(bytes memory returnData) internal pure {
        if (returnData.length > 0) {
            assembly {
                let returnData_size := mload(returnData)
                revert(add(32, returnData), returnData_size)
            }   
        } else {
            revert("ActionExecutor: Low-level call failed without reason");
        }
    }
}
