// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ERC4626} from "@openzeppelin/contracts/token/ERC20/extensions/ERC4626.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

/// @title ERC4626Vault
/// @notice A capped ERC4626 vault with configurable withdrawal fee.
contract ERC4626Vault is ERC4626, Ownable {
    uint256 public cap;
    uint256 public withdrawalFeeBps;

    error ZeroCap();
    error ExceedsCap();
    error FeeTooHigh();

    uint256 public constant MAX_FEE_BPS = 1000; // 10% max

    /// @param asset_ The underlying ERC20 asset
    /// @param name_ Vault share token name
    /// @param symbol_ Vault share token symbol
    /// @param cap_ Maximum total assets
    /// @param withdrawalFeeBps_ Fee in basis points on withdrawals
    constructor(
        ERC20 asset_,
        string memory name_,
        string memory symbol_,
        uint256 cap_,
        uint256 withdrawalFeeBps_
    ) ERC4626(asset_) ERC20(name_, symbol_) Ownable(msg.sender) {
        if (cap_ == 0) revert ZeroCap();
        if (withdrawalFeeBps_ > MAX_FEE_BPS) revert FeeTooHigh();
        cap = cap_;
        withdrawalFeeBps = withdrawalFeeBps_;
    }

    /// @notice Set a new cap (only owner)
    function setCap(uint256 newCap) external onlyOwner {
        if (newCap == 0) revert ZeroCap();
        cap = newCap;
    }

    function maxDeposit(address) public view override returns (uint256) {
        return cap - totalAssets();
    }

    function maxMint(address) public view override returns (uint256) {
        uint256 remaining = cap - totalAssets();
        return remaining == 0 ? 0 : remaining * (10 ** decimals());
    }

    function _deposit(address caller, address receiver, uint256 assets, uint256 shares) internal override {
        if (totalAssets() + assets > cap) revert ExceedsCap();
        super._deposit(caller, receiver, assets, shares);
    }

    function _withdraw(address caller, address receiver, address owner, uint256 assets, uint256 shares) internal override {
        if (withdrawalFeeBps > 0) {
            uint256 fee = (assets * withdrawalFeeBps) / 10000;
            super._withdraw(caller, receiver, owner, assets + fee, shares);
        } else {
            super._withdraw(caller, receiver, owner, assets, shares);
        }
    }
}
