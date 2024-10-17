// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract NFTMarket {
    struct Listing {
        address seller;
        uint256 price;
    }

    mapping(address => mapping(uint256 => Listing)) public listings; // NFT地址 -> NFT ID -> Listing

    event Listed(address indexed seller, address indexed nftAddress, uint256 indexed tokenId, uint256 price);
    event Purchased(address indexed buyer, address indexed nftAddress, uint256 indexed tokenId, uint256 price);

    function listNFT(address nftAddress, uint256 tokenId, uint256 price) external {
        require(price > 0, "Price must be greater than 0");
        IERC721(nftAddress).transferFrom(msg.sender, address(this), tokenId);
        listings[nftAddress][tokenId] = Listing(msg.sender, price);
        emit Listed(msg.sender, nftAddress, tokenId, price);
    }

    function getListing(address nftAddress, uint256 tokenId) external view returns (Listing memory) {
        return listings[nftAddress][tokenId];
    }

    function purchaseNFT(address nftAddress, uint256 tokenId, address erc20Address) external {
        Listing memory listing = listings[nftAddress][tokenId];
        require(listing.price > 0, "NFT not for sale");
        require(msg.sender != listing.seller, "Cannot buy your own NFT");
        require(IERC20(erc20Address).balanceOf(msg.sender) >= listing.price, "Insufficient funds");

        uint256 payment = listing.price;
        IERC20(erc20Address).transferFrom(msg.sender, listing.seller, payment);
        IERC721(nftAddress).transferFrom(address(this), msg.sender, tokenId);

        // require(IERC20.transferFrom(msg.sender, listing.seller, payment), "Transfer failed");

        delete listings[nftAddress][tokenId];

        emit Purchased(msg.sender, nftAddress, tokenId, payment);
    }
}
