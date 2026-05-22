// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {ERC4626Vault} from "../src/erc4626-vault/ERC4626Vault.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MockERC20 is ERC20 {
    constructor() ERC20("Mock", "MCK") {
        _mint(msg.sender, 1_000_000e18);
    }
}

contract ERC4626VaultTest is Test {
    ERC4626Vault public vault;
    MockERC20 public asset;
    address public user;

    function setUp() public {
        asset = new MockERC20();
        vault = new ERC4626Vault(asset, "Vault Shares", "vMCK", 100_000e18, 100);
        user = makeAddr("user");
    }

    function test_constructor_setsCap() public view {
        assertEq(vault.cap(), 100_000e18);
    }

    function test_constructor_revertsOnZeroCap() public {
        vm.expectRevert(ERC4626Vault.ZeroCap.selector);
        new ERC4626Vault(asset, "Vault", "VLT", 0, 0);
    }

    function test_constructor_revertsOnHighFee() public {
        vm.expectRevert(ERC4626Vault.FeeTooHigh.selector);
        new ERC4626Vault(asset, "Vault", "VLT", 100e18, 1001);
    }

    function test_deposit_mintsShares() public {
        asset.transfer(user, 1000e18);
        vm.startPrank(user);
        asset.approve(address(vault), 1000e18);
        vault.deposit(1000e18, user);
        vm.stopPrank();
        assertGt(vault.balanceOf(user), 0);
    }

    function test_deposit_exceedsCap_reverts() public {
        asset.transfer(user, 200_000e18);
        vm.startPrank(user);
        asset.approve(address(vault), 200_000e18);
        vm.expectRevert();
        vault.deposit(200_000e18, user);
        vm.stopPrank();
    }

    function test_setCap_byOwner() public {
        vault.setCap(200_000e18);
        assertEq(vault.cap(), 200_000e18);
    }
}
