// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

/// @title TimeLock
/// @notice Time-locked release of tokens after a specified timestamp.
contract TimeLock is Ownable {
    address public beneficiary;
    uint256 public releaseTime;
    bool public released;

    error ZeroAddress();
    error TimeNotReached();
    error AlreadyReleased();

    event Released(address indexed beneficiary, uint256 amount);

    /// @param beneficiary_ Address that can claim
    /// @param releaseTime_ Unix timestamp when tokens become available
    constructor(address beneficiary_, uint256 releaseTime_) Ownable(msg.sender) {
        if (beneficiary_ == address(0)) revert ZeroAddress();
        beneficiary = beneficiary_;
        releaseTime = releaseTime_;
    }

    /// @notice Release locked ETH to beneficiary
    function release() external onlyOwner {
        if (block.timestamp < releaseTime) revert TimeNotReached();
        if (released) revert AlreadyReleased();
        released = true;
        uint256 amount = address(this).balance;
        (bool success, ) = payable(beneficiary).call{value: amount}("");
        require(success, "Transfer failed");
        emit Released(beneficiary, amount);
    }

    receive() external payable {}
}
