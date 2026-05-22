// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {TimeLock} from "../src/timelock/TimeLock.sol";

contract TimeLockTest is Test {
    TimeLock public timelock;
    address public beneficiary;

    function setUp() public {
        beneficiary = makeAddr("beneficiary");
        timelock = new TimeLock(beneficiary, block.timestamp + 365 days);
    }

    function test_release_beforeTime_reverts() public {
        vm.expectRevert(TimeLock.TimeNotReached.selector);
        timelock.release();
    }

    function test_release_afterTime_succeeds() public {
        vm.deal(address(timelock), 1 ether);
        vm.warp(block.timestamp + 366 days);
        timelock.release();
        assertEq(beneficiary.balance, 1 ether);
    }

    function test_release_alreadyReleased_reverts() public {
        vm.deal(address(timelock), 1 ether);
        vm.warp(block.timestamp + 366 days);
        timelock.release();
        vm.expectRevert(TimeLock.AlreadyReleased.selector);
        timelock.release();
    }
}
