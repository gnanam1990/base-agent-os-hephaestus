// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {ERC721URIStorage} from "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

/// @title ERC721Standard
/// @notice A standard ERC721 with URI storage and batch minting.
contract ERC721Standard is ERC721, ERC721URIStorage, Ownable {
    uint256 private _nextTokenId;

    error ZeroAddress();

    /// @param name Collection name
    /// @param symbol Collection symbol
    constructor(string memory name, string memory symbol) ERC721(name, symbol) Ownable(msg.sender) {}

    /// @notice Mint a token with metadata URI
    /// @param to Recipient address
    /// @param uri Token metadata URI
    function mint(address to, string memory uri) external onlyOwner returns (uint256) {
        if (to == address(0)) revert ZeroAddress();
        uint256 tokenId = _nextTokenId++;
        _safeMint(to, tokenId);
        _setTokenURI(tokenId, uri);
        return tokenId;
    }

    /// @notice Batch mint tokens
    /// @param to Recipient address
    /// @param uris Array of metadata URIs
    function batchMint(address to, string[] memory uris) external onlyOwner returns (uint256[] memory) {
        if (to == address(0)) revert ZeroAddress();
        uint256[] memory tokenIds = new uint256[](uris.length);
        for (uint256 i; i < uris.length; i++) {
            uint256 tokenId = _nextTokenId++;
            _safeMint(to, tokenId);
            _setTokenURI(tokenId, uris[i]);
            tokenIds[i] = tokenId;
        }
        return tokenIds;
    }

    function supportsInterface(bytes4 interfaceId) public view override(ERC721, ERC721URIStorage) returns (bool) {
        return super.supportsInterface(interfaceId);
    }

    function tokenURI(uint256 tokenId) public view override(ERC721, ERC721URIStorage) returns (string memory) {
        return super.tokenURI(tokenId);
    }
}
