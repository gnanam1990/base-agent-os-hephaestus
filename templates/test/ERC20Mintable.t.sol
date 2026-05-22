// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {ERC20Mintable} from "../src/erc20-mintable/ERC20Mintable.sol";

contract ERC20MintableTest is Test {
    ERC20Mintable public token;
    address public minter;
    address public user;

    function setUp() public {
        minter = makeAddr("minter");
        user = makeAddr("user");
        token = new ERC20Mintable("TestToken", "TT", 1_000_000e18, minter);
    }

    function test_constructor_setsName() public view {
        assertEq(token.name(), "TestToken");
    }

    function test_constructor_setsSymbol() public view {
        assertEq(token.symbol(), "TT");
    }

    function test_constructor_grantsMinterRole() public view {
        assertTrue(token.hasRole(token.MINTER_ROLE(), minter));
    }

    function test_constructor_revertsOnZeroCap() public {
        vm.expectRevert();
        new ERC20Mintable("Test", "TT", 0, minter);
    }

    function test_mint_byMinter_succeeds() public {
        vm.prank(minter);
        token.mint(user, 100e18);
        assertEq(token.balanceOf(user), 100e18);
    }

    function test_mint_byNonMinter_reverts() public {
        vm.prank(user);
        vm.expectRevert();
        token.mint(user, 100e18);
    }

    function test_mint_exceedsCap_reverts() public {
        vm.prank(minter);
        vm.expectRevert();
        token.mint(user, 1_000_001e18);
    }
}
