// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {VestingLinear} from "../src/vesting-linear/VestingLinear.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MockToken is ERC20 {
    constructor() ERC20("Mock", "MCK") {
        _mint(msg.sender, 1_000_000e18);
    }
}

contract VestingLinearTest is Test {
    VestingLinear public vesting;
    MockToken public token;
    address public beneficiary;

    function setUp() public {
        token = new MockToken();
        beneficiary = makeAddr("beneficiary");
        vesting = new VestingLinear(token, beneficiary, 365 days, 730 days, 1000e18);
        token.transfer(address(vesting), 1000e18);
    }

    function test_constructor_setsParams() public view {
        assertEq(vesting.beneficiary(), beneficiary);
        assertEq(vesting.cliffDuration(), 365 days);
        assertEq(vesting.vestingDuration(), 730 days);
        assertEq(vesting.totalAmount(), 1000e18);
    }

    function test_constructor_revertsOnZeroAddress() public {
        vm.expectRevert(VestingLinear.ZeroAddress.selector);
        new VestingLinear(token, address(0), 0, 100, 100);
    }

    function test_release_beforeCliff_reverts() public {
        // Before cliff, vestedAmount returns 0, so release reverts
        vm.expectRevert(VestingLinear.NothingToRelease.selector);
        vesting.release();
    }

    function test_release_afterCliff_succeeds() public {
        vm.warp(block.timestamp + 366 days);
        vesting.release();
        assertGt(token.balanceOf(beneficiary), 0);
    }

    function test_release_fullVesting() public {
        vm.warp(block.timestamp + 730 days);
        vesting.release();
        assertEq(token.balanceOf(beneficiary), 1000e18);
    }
}
