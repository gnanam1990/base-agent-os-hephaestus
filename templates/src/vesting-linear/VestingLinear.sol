// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

/// @title VestingLinear
/// @notice Linear vesting with cliff for a single beneficiary.
contract VestingLinear is Ownable {
    using SafeERC20 for IERC20;

    IERC20 public immutable token;
    address public beneficiary;
    uint256 public startTime;
    uint256 public cliffDuration;
    uint256 public vestingDuration;
    uint256 public totalAmount;
    uint256 public released;

    error ZeroAddress();
    error ZeroDuration();
    error ZeroAmount();
    error NothingToRelease();
    error CliffNotReached();

    event TokensReleased(address indexed beneficiary, uint256 amount);

    /// @param token_ ERC20 token to vest
    /// @param beneficiary_ Vesting beneficiary
    /// @param cliffDuration_ Cliff period in seconds
    /// @param vestingDuration_ Total vesting duration in seconds
    /// @param totalAmount_ Total tokens to vest
    constructor(
        IERC20 token_,
        address beneficiary_,
        uint256 cliffDuration_,
        uint256 vestingDuration_,
        uint256 totalAmount_
    ) Ownable(msg.sender) {
        if (beneficiary_ == address(0)) revert ZeroAddress();
        if (vestingDuration_ == 0) revert ZeroDuration();
        if (totalAmount_ == 0) revert ZeroAmount();
        token = token_;
        beneficiary = beneficiary_;
        cliffDuration = cliffDuration_;
        vestingDuration = vestingDuration_;
        totalAmount = totalAmount_;
        startTime = block.timestamp;
    }

    /// @notice Release vested tokens
    function release() external {
        uint256 amount = _vestedAmount() - released;
        if (amount == 0) revert NothingToRelease();
        if (block.timestamp < startTime + cliffDuration) revert CliffNotReached();
        released += amount;
        token.safeTransfer(beneficiary, amount);
        emit TokensReleased(beneficiary, amount);
    }

    /// @notice Amount currently vested
    function vestedAmount() external view returns (uint256) {
        return _vestedAmount();
    }

    function _vestedAmount() internal view returns (uint256) {
        if (block.timestamp < startTime + cliffDuration) return 0;
        uint256 elapsed = block.timestamp - startTime;
        if (elapsed >= vestingDuration) return totalAmount;
        return (totalAmount * elapsed) / vestingDuration;
    }
}
