// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/// @title PaymentSplitter
/// @notice Splits incoming ETH among multiple recipients with claim-based distribution.
contract PaymentSplitter is ReentrancyGuard {
    address[] public payees;
    mapping(address => uint256) public shares;
    mapping(address => uint256) public released;
    uint256 public totalShares;

    error ZeroAddress();
    error DuplicatePayee();
    error ZeroShares();
    error NothingToRelease();

    event PaymentReceived(address indexed from, uint256 amount);
    event PaymentReleased(address indexed payee, uint256 amount);

    /// @param payees_ Array of payee addresses
    /// @param shares_ Array of share amounts
    constructor(address[] memory payees_, uint256[] memory shares_) {
        if (payees_.length != shares_.length) revert ZeroShares();
        for (uint256 i; i < payees_.length; i++) {
            if (payees_[i] == address(0)) revert ZeroAddress();
            if (shares_[i] == 0) revert ZeroShares();
            if (shares[payees_[i]] != 0) revert DuplicatePayee();
            payees.push(payees_[i]);
            shares[payees_[i]] = shares_[i];
            totalShares += shares_[i];
        }
    }

    receive() external payable {
        emit PaymentReceived(msg.sender, msg.value);
    }

    /// @notice Release owed ETH to caller
    function claim() external nonReentrant {
        uint256 amount = releasable(msg.sender);
        if (amount == 0) revert NothingToRelease();
        released[msg.sender] += amount;
        (bool success, ) = payable(msg.sender).call{value: amount}("");
        require(success, "Transfer failed");
        emit PaymentReleased(msg.sender, amount);
    }

    /// @notice Amount releasable to a payee
    function releasable(address payee) public view returns (uint256) {
        return _currentAllocation(payee) - released[payee];
    }

    function _currentAllocation(address payee) internal view returns (uint256) {
        if (totalShares == 0) return 0;
        return (address(this).balance + _totalReleased()) * shares[payee] / totalShares;
    }

    function _totalReleased() internal view returns (uint256) {
        uint256 total;
        for (uint256 i; i < payees.length; i++) {
            total += released[payees[i]];
        }
        return total;
    }

    function payeeCount() external view returns (uint256) {
        return payees.length;
    }
}
