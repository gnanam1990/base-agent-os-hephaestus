// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {DutchAuction} from "../src/dutch-auction/DutchAuction.sol";
import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";

contract MockNFT is ERC721 {
    constructor() ERC721("MockNFT", "MNFT") {
        _mint(msg.sender, 0);
    }
}

contract DutchAuctionTest is Test {
    DutchAuction public auction;
    MockNFT public nft;
    address public buyer;
    address public seller;

    function setUp() public {
        seller = makeAddr("seller");
        nft = new MockNFT();
        // Transfer NFT to seller
        nft.transferFrom(address(this), seller, 0);
        
        buyer = makeAddr("buyer");
        
        // Create auction from seller
        vm.prank(seller);
        nft.approve(address(auction), 0);
        
        vm.prank(seller);
        auction = new DutchAuction(ERC721(address(nft)), 10 ether, 1 ether, 1 hours, 0);
        
        vm.prank(seller);
        nft.approve(address(auction), 0);
    }

    function test_currentPrice_atStart() public view {
        assertEq(auction.currentPrice(), 10 ether);
    }

    function test_currentPrice_atEnd() public {
        vm.warp(block.timestamp + 1 hours);
        assertEq(auction.currentPrice(), 1 ether);
    }

    function test_buy_insufficientPayment_reverts() public {
        vm.deal(buyer, 0.5 ether);
        vm.prank(buyer);
        vm.expectRevert(DutchAuction.InsufficientPayment.selector);
        auction.buy{value: 0.5 ether}();
    }
}
