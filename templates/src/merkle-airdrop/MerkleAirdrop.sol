// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {MerkleProof} from "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";

/// @title MerkleAirdrop
/// @notice Merkle-tree based token airdrop with claim mechanism.
contract MerkleAirdrop {
    using SafeERC20 for IERC20;

    IERC20 public immutable token;
    bytes32 public immutable merkleRoot;
    mapping(bytes32 => bool) public claimed;

    error AlreadyClaimed();
    error InvalidProof();

    event Claimed(address indexed account, uint256 amount);

    /// @param token_ ERC20 token to distribute
    /// @param merkleRoot_ Merkle root of the airdrop tree
    constructor(IERC20 token_, bytes32 merkleRoot_) {
        token = token_;
        merkleRoot = merkleRoot_;
    }

    /// @notice Claim airdrop tokens
    /// @param proof Merkle proof
    /// @param amount Amount to claim
    function claim(bytes32[] calldata proof, uint256 amount) external {
        bytes32 leaf = keccak256(abi.encodePacked(msg.sender, amount));
        if (claimed[leaf]) revert AlreadyClaimed();
        if (!MerkleProof.verifyCalldata(proof, merkleRoot, leaf)) revert InvalidProof();
        claimed[leaf] = true;
        token.safeTransfer(msg.sender, amount);
        emit Claimed(msg.sender, amount);
    }
}
