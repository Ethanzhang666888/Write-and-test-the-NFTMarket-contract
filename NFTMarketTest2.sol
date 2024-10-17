// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "forge-std/Test.sol";
import "src/NFTMarket2.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

contract MockERC20 is ERC20 {
    constructor() ERC20("MockToken", "MTK") {
        _mint(msg.sender, 10000 * 10 ** decimals());
    }
}

contract MockERC721 is ERC721 {
    uint256 public tokenCounter;

    constructor() ERC721("MockNFT", "MNFT") {
        tokenCounter = 0;
    }

    function mintNFT() public {
        _mint(msg.sender, tokenCounter);
        tokenCounter++;
    }
}

contract NFTMarketTest is Test {
    NFTMarket market;
    MockERC20 token;
    MockERC721 nft;

    function setUp() public {
        token = new MockERC20();
        nft = new MockERC721();
        market = new NFTMarket();
    }

    function testListNFTSuccess() public {
        nft.mintNFT();
        nft.approve(address(market), 0);
        market.listNFT(address(nft), 0, 100);
        NFTMarket.Listing memory listing = market.getListing(address(nft), 0);
        assertEq(listing.seller, address(this));
        assertEq(listing.price, 100);
    }

    function testListNFTFailPriceZero() public {
        nft.mintNFT();
        nft.approve(address(market), 0);
        vm.expectRevert("Price must be greater than 0");
        market.listNFT(address(nft), 0, 0);
    }

    function testPurchaseNFTSuccess() public {
        nft.mintNFT();
        nft.approve(address(market), 0); //批转合约市场管理NFT
        market.listNFT(address(nft), 0, 100); //列出nft 价格

        address customer = address(0x123456789); //新客户地址
        token.transfer(customer, 100); // 转移100个代币给客户地址// ？ vm.deal(customer, 1000); // 为客户地址提供100个代币

        vm.prank(address(market)); // 切换到市场的身份
        nft.approve(customer, 0); // 授权客户使用nft

        vm.prank(customer); // 切换到客户地址的身份
        token.approve(address(market), 100); // 客户授权市场合约使用100个代币

        vm.prank(customer); // 切换到市场合约的上下文
        market.purchaseNFT(address(nft), 0, address(token)); // 市场合约调用purchaseNFT函数，购买nft

        assertEq(nft.ownerOf(0), customer); // 检查nft的所有权是否转移到市场合约
    }

    function testPurchaseNFTFailSelfPurchase() public {
        nft.mintNFT();
        nft.approve(address(market), 0);
        market.listNFT(address(nft), 0, 100);

        vm.expectRevert("Cannot buy your own NFT");
        market.purchaseNFT(address(nft), 0, address(token));
    }

    function testPurchaseNFTFailAlreadySold() public {
        nft.mintNFT();
        nft.approve(address(market), 0);
        market.listNFT(address(nft), 0, 100);

        address customer = address(0x123456789); //新客户地址
        token.transfer(customer, 100);

        vm.prank(address(market));
        nft.approve(customer, 0);

        vm.prank(customer);
        token.approve(address(market), 100);

        vm.prank(customer);
        market.purchaseNFT(address(nft), 0, address(token));

        vm.expectRevert("NFT not for sale");
        vm.prank(customer);
        market.purchaseNFT(address(nft), 0, address(token));
    }

    function testPaymentTooLow() public {
        nft.mintNFT();
        nft.approve(address(market), 0);
        market.listNFT(address(nft), 0, 100);

        address customer = address(0x123456789);
        token.transfer(customer, 50);

        vm.prank(address(market));
        nft.approve(customer, 0);

        vm.prank(customer);
        token.approve(address(market), 100);

        vm.expectRevert("Insufficient funds");
        vm.prank(customer);
        market.purchaseNFT(address(nft), 0, address(token));
    }

    function testNoTokenHolding() public {
        nft.mintNFT();
        nft.approve(address(market), 0);
        market.listNFT(address(nft), 0, 100);

        address customer = address(0x123456789);

        vm.prank(address(market));
        nft.approve(customer, 0);

        vm.prank(customer);
        token.approve(address(market), 100);

        vm.expectRevert("Insufficient funds");
        vm.prank(customer);
        market.purchaseNFT(address(nft), 0, address(token));

        assertEq(token.balanceOf(address(customer)), 0);
    }

    function testFuzzListAndPurchaseNFT(uint256 randomValue) public {
        nft.mintNFT();
        uint256 tokenId = nft.tokenCounter() - 1;
        address customer = vm.addr(uint256(keccak256(abi.encodePacked(block.timestamp, randomValue))));

        // 限制价格范围
        uint256 price = (uint256(keccak256(abi.encodePacked(block.timestamp, randomValue))) % 10000) + 1; // 生成1到10000之间的整数
        price = price * 10 ** 18; // 转换为Token单位
        require(price > 0, "Price must be positive");
        require(customer != address(0), "Invalid customer address");

        nft.approve(address(market), tokenId);
        market.listNFT(address(nft), tokenId, price);

        // 模拟客户购买
        token.transfer(customer, price);
        vm.prank(address(market));
        nft.approve(customer, tokenId);
        vm.prank(customer);
        token.approve(address(market), price);
        vm.prank(customer);
        market.purchaseNFT(address(nft), tokenId, address(token));

        // 验证所有权和余额
        assertEq(nft.ownerOf(tokenId), customer); // 检查nft的所有权是否转移
        assertEq(token.balanceOf(customer), 0); // 客户的Token余额应为0
        assertEq(token.balanceOf(address(this)), 10000 * 10 ** 18); // 市场应收到正确的价格
    }
}
