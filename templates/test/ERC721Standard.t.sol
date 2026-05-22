// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {ERC721Standard} from "../src/erc721-standard/ERC721Standard.sol";

contract ERC721StandardTest is Test {
    ERC721Standard public nft;
    address public owner;
    address public user;

    function setUp() public {
        owner = address(this);
        user = makeAddr("user");
        nft = new ERC721Standard("TestNFT", "TNFT");
    }

    function test_constructor_setsName() public view {
        assertEq(nft.name(), "TestNFT");
    }

    function test_mint_createsToken() public {
        uint256 tokenId = nft.mint(user, "ipfs://token/0");
        assertEq(nft.ownerOf(tokenId), user);
        assertEq(nft.tokenURI(tokenId), "ipfs://token/0");
    }

    function test_mint_revertsOnZeroAddress() public {
        vm.expectRevert(ERC721Standard.ZeroAddress.selector);
        nft.mint(address(0), "ipfs://token/0");
    }

    function test_batchMint_createsMultiple() public {
        string[] memory uris = new string[](3);
        uris[0] = "ipfs://0";
        uris[1] = "ipfs://1";
        uris[2] = "ipfs://2";
        uint256[] memory ids = nft.batchMint(user, uris);
        assertEq(ids.length, 3);
        assertEq(nft.ownerOf(ids[0]), user);
        assertEq(nft.ownerOf(ids[2]), user);
    }

    function test_mint_byNonOwner_reverts() public {
        vm.prank(user);
        vm.expectRevert();
        nft.mint(user, "ipfs://0");
    }
}
