// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {Multisig3of5} from "../src/multisig-3of5/Multisig3of5.sol";

contract Multisig3of5Test is Test {
    Multisig3of5 public multisig;
    address[5] public owners;

    function setUp() public {
        for (uint256 i; i < 5; i++) {
            owners[i] = makeAddr(string(abi.encodePacked("owner", i)));
        }
        multisig = new Multisig3of5(owners);
    }

    function test_submit_createsTransaction() public {
        vm.prank(owners[0]);
        multisig.submit(address(0x1), 0, "");
        // Transaction exists (no revert)
    }

    function test_submit_byNonOwner_reverts() public {
        vm.prank(makeAddr("outsider"));
        vm.expectRevert(Multisig3of5.NotOwner.selector);
        multisig.submit(address(0x1), 0, "");
    }

    function test_approve_incrementsCount() public {
        vm.prank(owners[0]);
        multisig.submit(address(0x1), 0, "");
        vm.prank(owners[1]);
        multisig.approve(0);
        // Approval recorded
    }

    function test_execute_insufficientApprovals_reverts() public {
        vm.prank(owners[0]);
        multisig.submit(address(0x1), 0, "");
        vm.prank(owners[0]);
        vm.expectRevert(Multisig3of5.InsufficientApprovals.selector);
        multisig.execute(0);
    }
}
