// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {MerkleAirdrop} from "../src/merkle-airdrop/MerkleAirdrop.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract AirdropToken is ERC20 {
    constructor() ERC20("Airdrop", "ARP") {
        _mint(msg.sender, 1_000_000e18);
    }
}

contract MerkleAirdropTest is Test {
    MerkleAirdrop public airdrop;
    AirdropToken public token;
    address public user;
    uint256 public constant AMOUNT = 100e18;
    bytes32 public root;

    function setUp() public {
        token = new AirdropToken();
        user = makeAddr("user");
        // Calculate leaf exactly as contract does
        root = keccak256(abi.encodePacked(user, AMOUNT));
        airdrop = new MerkleAirdrop(token, root);
        token.transfer(address(airdrop), AMOUNT);
    }

    function test_claim_withValidProof() public {
        // For single leaf tree, proof is empty
        bytes32[] memory proof = new bytes32[](0);
        vm.prank(user);
        airdrop.claim(proof, AMOUNT);
        assertEq(token.balanceOf(user), AMOUNT);
    }

    function test_claim_alreadyClaimed_reverts() public {
        bytes32[] memory proof = new bytes32[](0);
        vm.prank(user);
        airdrop.claim(proof, AMOUNT);
        vm.prank(user);
        vm.expectRevert(MerkleAirdrop.AlreadyClaimed.selector);
        airdrop.claim(proof, AMOUNT);
    }

    function test_claim_invalidProof_reverts() public {
        bytes32[] memory proof = new bytes32[](0);
        address other = makeAddr("other");
        vm.prank(other);
        vm.expectRevert(MerkleAirdrop.InvalidProof.selector);
        airdrop.claim(proof, AMOUNT);
    }
}
