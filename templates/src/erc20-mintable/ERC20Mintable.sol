// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ERC20Permit} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import {ERC20Capped} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Capped.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";

/// @title ERC20Mintable
/// @notice A capped ERC20 token with permit support and role-based minting.
contract ERC20Mintable is ERC20, ERC20Permit, ERC20Capped, AccessControl {
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");

    error ZeroCap();

    /// @param name Token name
    /// @param symbol Token symbol
    /// @param cap Maximum supply (in wei)
    /// @param initialMinter Address granted the MINTER_ROLE
    constructor(
        string memory name,
        string memory symbol,
        uint256 cap,
        address initialMinter
    ) ERC20(name, symbol) ERC20Permit(name) ERC20Capped(cap) {
        if (cap == 0) revert ZeroCap();
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(MINTER_ROLE, initialMinter);
    }

    /// @notice Mint tokens to a recipient
    /// @param to Recipient address
    /// @param amount Amount to mint
    function mint(address to, uint256 amount) external onlyRole(MINTER_ROLE) {
        _mint(to, amount);
    }

    function _update(address from, address to, uint256 value) internal override(ERC20, ERC20Capped) {
        super._update(from, to, value);
    }
}
