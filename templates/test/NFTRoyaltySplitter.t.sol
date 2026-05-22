// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {NFTRoyaltySplitter} from "../src/nft-royalty-splitter/NFTRoyaltySplitter.sol";

contract NFTRoyaltySplitterTest is Test {
    NFTRoyaltySplitter public splitter;
    address public alice;
    address public bob;

    function setUp() public {
        alice = makeAddr("alice");
        bob = makeAddr("bob");
        address[] memory payees = new address[](2);
        payees[0] = alice;
        payees[1] = bob;
        uint256[] memory shares = new uint256[](2);
        shares[0] = 60;
        shares[1] = 40;
        splitter = new NFTRoyaltySplitter(payees, shares);
    }

    function test_royaltyInfo_returnsReceiver() public view {
        (address receiver, uint256 amount) = splitter.royaltyInfo(0, 1000e18);
        assertEq(receiver, address(splitter));
        assertEq(amount, 50e18); // 5%
    }

    function test_claim_distributesCorrectly() public {
        // Send ETH to splitter
        vm.deal(address(this), 10 ether);
        (bool success, ) = address(splitter).call{value: 10 ether}("");
        assertTrue(success);

        // Alice claims her share
        vm.prank(alice);
        splitter.claim();
        assertEq(alice.balance, 6 ether);
    }

    function test_claim_nothing_reverts() public {
        vm.prank(alice);
        vm.expectRevert(NFTRoyaltySplitter.NothingToRelease.selector);
        splitter.claim();
    }
}
