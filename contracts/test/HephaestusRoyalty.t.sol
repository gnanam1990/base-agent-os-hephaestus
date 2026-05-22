// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test, console} from "forge-std/Test.sol";
import {HephaestusRoyalty} from "../src/HephaestusRegistry.sol";

contract HephaestusRoyaltyTest is Test {
    HephaestusRoyalty public royalty;

    address public treasury;
    address public agent;
    address public nonAgent;
    address public originator;
    address public contractAddr;

    function setUp() public {
        treasury = makeAddr("treasury");
        agent = makeAddr("agent");
        nonAgent = makeAddr("nonAgent");
        originator = makeAddr("originator");
        contractAddr = makeAddr("contract");

        royalty = new HephaestusRoyalty(treasury, agent);
    }

    // ─────────────────────────────────────────────────────────────
    // Constructor tests
    // ─────────────────────────────────────────────────────────────

    function test_constructor_setsTreasury() public view {
        assertEq(royalty.treasury(), treasury);
    }

    function test_constructor_setsAgent() public view {
        assertEq(royalty.agent(), agent);
    }

    function test_constructor_revertsOnZeroTreasury() public {
        vm.expectRevert(HephaestusRoyalty.ZeroAddress.selector);
        new HephaestusRoyalty(address(0), agent);
    }

    function test_constructor_revertsOnZeroAgent() public {
        vm.expectRevert(HephaestusRoyalty.ZeroAddress.selector);
        new HephaestusRoyalty(treasury, address(0));
    }

    // ─────────────────────────────────────────────────────────────
    // registerContract tests
    // ─────────────────────────────────────────────────────────────

    function test_registerContract_byAgent_succeeds() public {
        vm.prank(agent);
        royalty.registerContract(contractAddr, originator);

        assertTrue(royalty.registered(contractAddr));
        assertEq(royalty.feeOriginatorOf(contractAddr), originator);
    }

    function test_registerContract_byNonAgent_reverts() public {
        vm.prank(nonAgent);
        vm.expectRevert(HephaestusRoyalty.NotAgent.selector);
        royalty.registerContract(contractAddr, originator);
    }

    function test_registerContract_revertsOnZeroAddress() public {
        vm.prank(agent);
        vm.expectRevert(HephaestusRoyalty.ZeroAddress.selector);
        royalty.registerContract(address(0), originator);
    }

    function test_registerContract_emitsEvent() public {
        vm.expectEmit(true, true, false, false);
        emit HephaestusRoyalty.ContractRegistered(contractAddr, originator);

        vm.prank(agent);
        royalty.registerContract(contractAddr, originator);
    }

    // ─────────────────────────────────────────────────────────────
    // forwardFee tests
    // ─────────────────────────────────────────────────────────────

    function test_forwardFee_registered_splitsFee() public {
        vm.prank(agent);
        royalty.registerContract(contractAddr, originator);

        uint256 feeAmount = 1 ether;
        uint256 treasuryBefore = treasury.balance;
        uint256 originatorBefore = originator.balance;

        royalty.forwardFee{value: feeAmount}(contractAddr);

        uint256 expectedOriginator = (feeAmount * 9500) / 10000;
        uint256 expectedTreasury = feeAmount - expectedOriginator;

        assertEq(originator.balance - originatorBefore, expectedOriginator);
        assertEq(treasury.balance - treasuryBefore, expectedTreasury);
    }

    function test_forwardFee_unregistered_allToTreasury() public {
        uint256 feeAmount = 1 ether;
        uint256 treasuryBefore = treasury.balance;

        royalty.forwardFee{value: feeAmount}(contractAddr);

        assertEq(treasury.balance - treasuryBefore, feeAmount);
    }

    function test_forwardFee_zeroValue_noTransfer() public {
        uint256 treasuryBefore = treasury.balance;
        royalty.forwardFee{value: 0}(contractAddr);
        assertEq(treasury.balance, treasuryBefore);
    }

    function test_forwardFee_emitsEvent() public {
        vm.prank(agent);
        royalty.registerContract(contractAddr, originator);

        uint256 feeAmount = 1 ether;
        uint256 expectedOriginator = (feeAmount * 9500) / 10000;
        uint256 expectedTreasury = feeAmount - expectedOriginator;

        vm.expectEmit(false, true, false, true);
        emit HephaestusRoyalty.FeeForwarded(contractAddr, expectedTreasury, expectedOriginator);

        royalty.forwardFee{value: feeAmount}(contractAddr);
    }
}
