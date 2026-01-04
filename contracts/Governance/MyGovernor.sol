// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

// 1. Token Imports
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Votes.sol";

// 2. Governor Imports
import "@openzeppelin/contracts/governance/Governor.sol";
import "@openzeppelin/contracts/governance/extensions/GovernorSettings.sol";
import "@openzeppelin/contracts/governance/extensions/GovernorCountingSimple.sol";
import "@openzeppelin/contracts/governance/extensions/GovernorVotes.sol";
import "@openzeppelin/contracts/governance/extensions/GovernorTimelockControl.sol";

// 3. Upgradeable Imports
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

// The Token(Voting Power)
contract MyToken is ERC20Votes, ERC20Permit {
    constructor() ERC20("MyToken", "MTK") ERC20Permit("MyToken") {
        _mint(msg.sender, 10_000 ether); // Mint 10,000 tokens to deployer
    }

    function _update(address from, address to, uint256 value)
        internal
        override(ERC20, ERC20Votes)
    {
        super._update(from, to, value);
    }

    function nonces(address owner)
        public
        view
        override(ERC20Permit, Nonces)
        returns(uint256)
    {
        return super.nonces(owner);
    }
}

// The Brain (Governor)
contract MyGovernor is 
    Governor, 
    GovernorSettings, 
    GovernorCountingSimple, 
    GovernorVotes, 
    GovernorTimelockControl 
{
    constructor(IVotes _token, TimelockController _timelock)
        Governor("MyDAO")
        GovernorSettings(1 days, 1 weeks, 1_000 ether)
        GovernorVotes(_token)
        GovernorTimelockControl(_timelock)
    {}

    // Quorum: 4% of total supply (Example logic)
    function quorum(uint256 blockNumber) 
        public 
        view 
        override 
        returns(uint256) 
    {
        return (token().getPastTotalSupply(blockNumber) * 4) / 100;
    }

    function votingDelay() 
        public 
        view 
        override(Governor, GovernorSettings) 
        returns(uint256) 
    {
        return super.votingDelay();
    }

    function votingPeriod() 
        public 
        view 
        override(Governor, GovernorSettings) 
        returns(uint256) 
    {
        return super.votingPeriod();
    }

    function proposalThreshold() 
        public 
        view 
        override(Governor, GovernorSettings) 
        returns(uint256) 
    {
        return super.proposalThreshold();
    }

    function state(uint256 proposalId) 
        public 
        view 
        override(Governor, GovernorTimelockControl) 
        returns(ProposalState) 
    {
        return super.state(proposalId);
    }

    function proposalNeedsQueuing(uint256 proposalId) 
        public 
        view 
        override(Governor, GovernorTimelockControl) 
        returns(bool) 
    {
        return super.proposalNeedsQueuing(proposalId);
    }

    function _executeOperations(
        uint256 proposalId, 
        address[] memory targets, 
        uint256[] memory values, 
        bytes[] memory calldatas, 
        bytes32 descriptionHash
    )
        internal
        override(Governor, GovernorTimelockControl)
    {
        super._executeOperations(proposalId, targets, values, calldatas, descriptionHash);
    }

    function _cancel(
        address[] memory targets, 
        uint256[] memory values, 
        bytes[] memory calldatas, 
        bytes32 descriptionHash
    )
        internal
        override(Governor, GovernorTimelockControl)
        returns(uint256)
    {
        return super._cancel(targets, values, calldatas, descriptionHash);
    }

    function _executor() 
        internal 
        view 
        override(Governor, GovernorTimelockControl) 
        returns(address) 
    {
        return super._executor();
    }

    function _queueOperations(
        uint256 proposalId, 
        address[] memory targets, 
        uint256[] memory values, 
        bytes[] memory calldatas, 
        bytes32 descriptionHash
    )
        internal
        override(Governor, GovernorTimelockControl)
        returns (uint48)
    {
        return super._queueOperations(proposalId, targets, values, calldatas, descriptionHash);
    }
}

// 3. The Target Logic (UUPS)
contract BoxV1 is OwnableUpgradeable, UUPSUpgradeable {
    uint256 public val;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize() public initializer {
        __Ownable_init(msg.sender);
        __UUPSUpgradeable_init();
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}    
    
    function version() public pure virtual returns(string memory) {
        return "V1";
    }
}

contract BoxV2 is BoxV1 {
    function version() public pure override returns(string memory) {
        return "V2";
    }
}