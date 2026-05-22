// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IERC2981} from "@openzeppelin/contracts/interfaces/IERC2981.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/// @title NFTRoyaltySplitter
/// @notice EIP-2981 compatible royalty splitter that distributes fees to multiple recipients.
contract NFTRoyaltySplitter is IERC2981, ReentrancyGuard {
    function supportsInterface(bytes4 interfaceId) external pure returns (bool) {
        return interfaceId == type(IERC2981).interfaceId;
    }
    address[] public payees;
    uint256[] public shares;
    uint256 public totalShares;
    mapping(address => uint256) public released;

    error ZeroAddress();
    error ZeroShares();
    error NothingToRelease();

    event RoyaltyReceived(address indexed payer, uint256 amount);
    event RoyaltyReleased(address indexed payee, uint256 amount);

    constructor(address[] memory payees_, uint256[] memory shares_) {
        if (payees_.length != shares_.length) revert ZeroShares();
        for (uint256 i; i < payees_.length; i++) {
            if (payees_[i] == address(0)) revert ZeroAddress();
            if (shares_[i] == 0) revert ZeroShares();
            payees.push(payees_[i]);
            shares.push(shares_[i]);
            totalShares += shares_[i];
        }
    }

    /// @notice EIP-2981 royalty info
    function royaltyInfo(uint256, uint256 salePrice)
        external
        view
        returns (address receiver, uint256 royaltyAmount)
    {
        receiver = address(this);
        royaltyAmount = salePrice * 500 / 10000; // 5% default
    }

    /// @notice Claim accumulated royalties
    function claim() external nonReentrant {
        uint256 amount = releasable(msg.sender);
        if (amount == 0) revert NothingToRelease();
        released[msg.sender] += amount;
        (bool success, ) = payable(msg.sender).call{value: amount}("");
        require(success, "Transfer failed");
        emit RoyaltyReleased(msg.sender, amount);
    }

    function releasable(address payee) public view returns (uint256) {
        uint256 index = _indexOf(payee);
        if (index == type(uint256).max) return 0;
        uint256 currentAllocation = (address(this).balance + _totalReleased()) * shares[index] / totalShares;
        return currentAllocation - released[payee];
    }

    function _indexOf(address payee) internal view returns (uint256) {
        for (uint256 i; i < payees.length; i++) {
            if (payees[i] == payee) return i;
        }
        return type(uint256).max;
    }

    function _totalReleased() internal view returns (uint256) {
        uint256 total;
        for (uint256 i; i < payees.length; i++) {
            total += released[payees[i]];
        }
        return total;
    }

    receive() external payable {
        emit RoyaltyReceived(msg.sender, msg.value);
    }
}
