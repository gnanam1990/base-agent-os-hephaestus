// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {PaymentSplitter} from "../src/payment-splitter/PaymentSplitter.sol";

contract PaymentSplitterTest is Test {
    PaymentSplitter public splitter;
    address public alice;
    address public bob;

    function setUp() public {
        alice = makeAddr("alice");
        bob = makeAddr("bob");
        address[] memory payees = new address[](2);
        payees[0] = alice;
        payees[1] = bob;
        uint256[] memory shares = new uint256[](2);
        shares[0] = 70;
        shares[1] = 30;
        splitter = new PaymentSplitter(payees, shares);
    }

    function test_constructor_setsPayees() public view {
        assertEq(splitter.payeeCount(), 2);
    }

    function test_constructor_setsShares() public view {
        assertEq(splitter.shares(alice), 70);
        assertEq(splitter.shares(bob), 30);
    }

    function test_claim_distributesCorrectly() public {
        // Send ETH to splitter
        vm.deal(address(this), 10 ether);
        (bool success, ) = address(splitter).call{value: 10 ether}("");
        assertTrue(success);

        // Alice claims her share
        vm.prank(alice);
        splitter.claim();
        assertEq(alice.balance, 7 ether);
    }

    function test_claim_revertsWithNothing() public {
        vm.prank(alice);
        vm.expectRevert(PaymentSplitter.NothingToRelease.selector);
        splitter.claim();
    }

    function test_receive_emitsEvent() public {
        vm.deal(address(this), 1 ether);
        vm.expectEmit(false, false, false, true);
        emit PaymentSplitter.PaymentReceived(address(this), 1 ether);
        (bool success, ) = address(splitter).call{value: 1 ether}("");
        assertTrue(success);
    }
}
