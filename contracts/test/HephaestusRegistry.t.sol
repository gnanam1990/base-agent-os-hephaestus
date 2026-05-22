// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test, console} from "forge-std/Test.sol";
import {HephaestusRegistry} from "../src/HephaestusRegistry.sol";

contract HephaestusRegistryTest is Test {
    HephaestusRegistry public registry;

    address public owner;
    address public agent;
    address public nonOwner;
    address public nonAgent;

    function setUp() public {
        owner = address(this);
        agent = makeAddr("agent");
        nonOwner = makeAddr("nonOwner");
        nonAgent = makeAddr("nonAgent");

        registry = new HephaestusRegistry(agent);
    }

    // ─────────────────────────────────────────────────────────────
    // Constructor tests
    // ─────────────────────────────────────────────────────────────

    function test_constructor_setsAgent() public view {
        assertEq(registry.agent(), agent, "Agent should be set");
    }

    function test_constructor_setsOwner() public view {
        assertEq(registry.owner(), owner, "Owner should be deployer");
    }

    function test_constructor_revertsOnZeroAddress() public {
        vm.expectRevert(HephaestusRegistry.ZeroAddress.selector);
        new HephaestusRegistry(address(0));
    }

    // ─────────────────────────────────────────────────────────────
    // Access control tests
    // ─────────────────────────────────────────────────────────────

    function test_setAgent_byOwner_succeeds() public {
        address newAgent = makeAddr("newAgent");
        registry.setAgent(newAgent);
        assertEq(registry.agent(), newAgent, "Agent should be updated");
    }

    function test_setAgent_byNonOwner_reverts() public {
        vm.prank(nonOwner);
        vm.expectRevert(abi.encodeWithSignature("OwnableUnauthorizedAccount(address)", nonOwner));
        registry.setAgent(nonAgent);
    }

    function test_setAgent_revertsOnZeroAddress() public {
        vm.expectRevert(HephaestusRegistry.ZeroAddress.selector);
        registry.setAgent(address(0));
    }

    function test_setAgent_emitsEvent() public {
        address newAgent = makeAddr("newAgent");
        vm.expectEmit(true, true, false, false);
        emit HephaestusRegistry.AgentSet(agent, newAgent);
        registry.setAgent(newAgent);
    }

    // ─────────────────────────────────────────────────────────────
    // recordDeploy tests
    // ─────────────────────────────────────────────────────────────

    function test_recordDeploy_byAgent_succeeds() public {
        address contractAddr = makeAddr("contract");
        address requester = makeAddr("requester");
        bytes32 specHash = keccak256("test spec");

        vm.prank(agent);
        registry.recordDeploy(contractAddr, requester, specHash, 0);

        HephaestusRegistry.DeployRecord memory record = registry.getDeployRecord(contractAddr);
        assertEq(record.contractAddr, contractAddr);
        assertEq(record.requester, requester);
        assertEq(record.specHash, specHash);
        assertEq(record.deployedAt, uint64(block.timestamp));
        assertEq(record.auditTier, 0);
    }

    function test_recordDeploy_byNonAgent_reverts() public {
        address contractAddr = makeAddr("contract");
        address requester = makeAddr("requester");

        vm.prank(nonAgent);
        vm.expectRevert(HephaestusRegistry.NotAgent.selector);
        registry.recordDeploy(contractAddr, requester, keccak256("test"), 0);
    }

    function test_recordDeploy_revertsOnZeroAddress() public {
        vm.prank(agent);
        vm.expectRevert(HephaestusRegistry.ZeroAddress.selector);
        registry.recordDeploy(address(0), makeAddr("requester"), keccak256("test"), 0);
    }

    function test_recordDeploy_revertsOnDuplicate() public {
        address contractAddr = makeAddr("contract");
        address requester = makeAddr("requester");

        vm.prank(agent);
        registry.recordDeploy(contractAddr, requester, keccak256("test"), 0);

        vm.prank(agent);
        vm.expectRevert(HephaestusRegistry.DeployExists.selector);
        registry.recordDeploy(contractAddr, requester, keccak256("test"), 0);
    }

    function test_recordDeploy_incrementsTotalDeploys() public {
        address contractAddr1 = makeAddr("contract1");
        address contractAddr2 = makeAddr("contract2");
        address requester = makeAddr("requester");

        vm.prank(agent);
        registry.recordDeploy(contractAddr1, requester, keccak256("test1"), 0);

        vm.prank(agent);
        registry.recordDeploy(contractAddr2, requester, keccak256("test2"), 0);

        assertEq(registry.totalDeploys(), 2);
    }

    function test_recordDeploy_emitsEvent() public {
        address contractAddr = makeAddr("contract");
        address requester = makeAddr("requester");
        bytes32 specHash = keccak256("test spec");

        vm.expectEmit(true, true, false, true);
        emit HephaestusRegistry.DeployRecorded(contractAddr, requester, 0);

        vm.prank(agent);
        registry.recordDeploy(contractAddr, requester, specHash, 0);
    }

    function test_recordDeploy_kratosDeepAuditTier() public {
        address contractAddr = makeAddr("contract");
        address requester = makeAddr("requester");

        vm.prank(agent);
        registry.recordDeploy(contractAddr, requester, keccak256("test"), 1);

        HephaestusRegistry.DeployRecord memory record = registry.getDeployRecord(contractAddr);
        assertEq(record.auditTier, 1);
    }

    // ─────────────────────────────────────────────────────────────
    // View function tests
    // ─────────────────────────────────────────────────────────────

    function test_getDeployRecord_returnsRecord() public {
        address contractAddr = makeAddr("contract");
        address requester = makeAddr("requester");
        bytes32 specHash = keccak256("test spec");

        vm.prank(agent);
        registry.recordDeploy(contractAddr, requester, specHash, 0);

        HephaestusRegistry.DeployRecord memory record = registry.getDeployRecord(contractAddr);
        assertEq(record.contractAddr, contractAddr);
        assertEq(record.requester, requester);
        assertEq(record.specHash, specHash);
    }

    function test_getDeployRecord_returnsZeroForUnknown() public {
        address unknown = makeAddr("unknown");
        HephaestusRegistry.DeployRecord memory record = registry.getDeployRecord(unknown);
        assertEq(record.contractAddr, address(0));
    }

    function test_getDeploysByRequester_returnsAll() public {
        address requester = makeAddr("requester");
        address contractAddr1 = makeAddr("contract1");
        address contractAddr2 = makeAddr("contract2");
        address contractAddr3 = makeAddr("contract3");

        vm.startPrank(agent);
        registry.recordDeploy(contractAddr1, requester, keccak256("test1"), 0);
        registry.recordDeploy(contractAddr2, requester, keccak256("test2"), 0);
        registry.recordDeploy(contractAddr3, requester, keccak256("test3"), 0);
        vm.stopPrank();

        address[] memory deploys = registry.getDeploysByRequester(requester);
        assertEq(deploys.length, 3);
        assertEq(deploys[0], contractAddr1);
        assertEq(deploys[1], contractAddr2);
        assertEq(deploys[2], contractAddr3);
    }

    function test_getDeploysByRequester_emptyForUnknown() public {
        address unknown = makeAddr("unknown");
        address[] memory deploys = registry.getDeploysByRequester(unknown);
        assertEq(deploys.length, 0);
    }

    function test_multipleRequesters_isolated() public {
        address requester1 = makeAddr("requester1");
        address requester2 = makeAddr("requester2");
        address contractAddr1 = makeAddr("contract1");
        address contractAddr2 = makeAddr("contract2");

        vm.startPrank(agent);
        registry.recordDeploy(contractAddr1, requester1, keccak256("test1"), 0);
        registry.recordDeploy(contractAddr2, requester2, keccak256("test2"), 0);
        vm.stopPrank();

        address[] memory deploys1 = registry.getDeploysByRequester(requester1);
        address[] memory deploys2 = registry.getDeploysByRequester(requester2);

        assertEq(deploys1.length, 1);
        assertEq(deploys1[0], contractAddr1);
        assertEq(deploys2.length, 1);
        assertEq(deploys2[0], contractAddr2);
    }
}
