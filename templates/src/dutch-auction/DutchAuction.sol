// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/// @title DutchAuction
/// @notice Dutch auction for NFTs with linear price decay.
contract DutchAuction is ReentrancyGuard {
    IERC721 public immutable nft;
    address public immutable seller;
    uint256 public immutable startPrice;
    uint256 public immutable endPrice;
    uint256 public immutable startTime;
    uint256 public immutable duration;
    uint256 public immutable tokenId;

    bool public ended;

    error AuctionEnded();
    error AuctionNotStarted();
    error InsufficientPayment();
    error NotSeller();

    event Purchased(address indexed buyer, uint256 price);

    /// @param nft_ NFT contract
    /// @param startPrice_ Starting price (high)
    /// @param endPrice_ Ending price (low)
    /// @param duration_ Auction duration in seconds
    /// @param tokenId_ Token ID to auction
    constructor(
        IERC721 nft_,
        uint256 startPrice_,
        uint256 endPrice_,
        uint256 duration_,
        uint256 tokenId_
    ) {
        nft = nft_;
        seller = msg.sender;
        startPrice = startPrice_;
        endPrice = endPrice_;
        startTime = block.timestamp;
        duration = duration_;
        tokenId = tokenId_;
    }

    /// @notice Current auction price
    function currentPrice() public view returns (uint256) {
        if (block.timestamp >= startTime + duration) return endPrice;
        uint256 elapsed = block.timestamp - startTime;
        return startPrice - ((startPrice - endPrice) * elapsed / duration);
    }

    /// @notice Purchase the NFT at current price
    function buy() external payable nonReentrant {
        if (ended) revert AuctionEnded();
        if (block.timestamp < startTime) revert AuctionNotStarted();
        uint256 price = currentPrice();
        if (msg.value < price) revert InsufficientPayment();

        ended = true;
        nft.transferFrom(seller, msg.sender, tokenId);

        uint256 refund = msg.value - price;
        if (refund > 0) {
            (bool refundSuccess, ) = payable(msg.sender).call{value: refund}("");
            require(refundSuccess, "Refund failed");
        }

        (bool paySuccess, ) = payable(seller).call{value: price}("");
        require(paySuccess, "Payment failed");

        emit Purchased(msg.sender, price);
    }
}
