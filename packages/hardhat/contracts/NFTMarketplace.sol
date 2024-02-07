// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// Importing the required contracts from the OpenZeppelin library
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

// NFT Marketplace contract
contract NFTMarketplace is ERC721Holder, Ownable {
    using SafeMath for uint256;
    
    // Structure to store information about NFT listing
    struct Listing {
        uint256 price;
        address seller;
        bool isActive;
    }
    
    // List of supported NFT contracts
    mapping(address => bool) private supportedContracts;
    
    // Mapping to track NFT listings
    mapping(uint256 => Listing) private listings;
    
    // Fee percentage charged by the marketplace
    uint256 private feePercentage;
    
    // Events to track NFT listing, sale, and fee collection
    event NFTListed(address indexed seller, address indexed contractAddress, uint256 indexed tokenId, uint256 price);
    event NFTSold(address indexed seller, address indexed buyer, address indexed contractAddress, uint256 tokenId, uint256 price);
    event FeeCollected(address indexed collector, uint256 amount);
    
    // Modifier to check if the NFT contract is supported
    modifier isSupportedContract(address contractAddress) {
        require(supportedContracts[contractAddress], "NFT contract not supported");
        _;
    }
    
    // Modifier to check if the listing exists and is active
    modifier isActiveListing(uint256 tokenId) {
        require(listings[tokenId].isActive, "Listing not found or inactive");
        _;
    }
    
    // Constructor - Initialize the contract
    constructor() {
        feePercentage = 2; // Set the default fee percentage to 2%
    }
    
    // Function to add a supported NFT contract
    function addSupportedContract(address contractAddress) external onlyOwner {
        supportedContracts[contractAddress] = true;
    }
    
    // Function to remove a supported NFT contract
    function removeSupportedContract(address contractAddress) external onlyOwner {
        delete supportedContracts[contractAddress];
    }
    
    // Function to update the fee percentage
    function updateFeePercentage(uint256 newFeePercentage) external onlyOwner {
        feePercentage = newFeePercentage;
    }
    
    // Function to list an NFT for sale
    function listNFT(address contractAddress, uint256 tokenId, uint256 price) external isSupportedContract(contractAddress) {
        require(price > 0, "Price must be greater than zero");
        require(IERC721(contractAddress).ownerOf(tokenId) == msg.sender, "Only NFT owner can list");
        
        // Transfer the NFT to the marketplace contract
        IERC721(contractAddress).safeTransferFrom(msg.sender, address(this), tokenId);
        
        // Create a new listing
        Listing storage listing = listings[tokenId];
        listing.price = price;
        listing.seller = msg.sender;
        listing.isActive = true;
        
        // Emit the NFTListed event
        emit NFTListed(msg.sender, contractAddress, tokenId, price);
    }
    
    // Function to buy an NFT from the marketplace
    function buyNFT(address contractAddress, uint256 tokenId) external payable isSupportedContract(contractAddress) isActiveListing(tokenId) {
        uint256 price = listings[tokenId].price;
        address seller = listings[tokenId].seller;
        
        // Calculate the marketplace fee
        uint256 feeAmount = price.mul(feePercentage).div(100);
        
        // Validate the payment amount
        require(msg.value == price, "Invalid payment amount");
        
        // Transfer the NFT to the buyer
        IERC721(contractAddress).safeTransferFrom(address(this), msg.sender, tokenId);
        
        // Transfer the payment to the seller
        payable(seller).transfer(price.sub(feeAmount));
        
        // Transfer the fee to the marketplace owner
        payable(owner()).transfer(feeAmount);
        
        // Deactivate the listing
        listings[tokenId].isActive = false;
        
        // Emit the NFTSold event
        emit NFTSold(seller, msg.sender, contractAddress, tokenId, price);
        
        // Emit the FeeCollected event
        emit FeeCollected(owner(), feeAmount);
    }
    
    // Function to change the price of a listed NFT
    function changePrice(address contractAddress, uint256 tokenId, uint256 newPrice) external isSupportedContract(contractAddress) isActiveListing(tokenId) {
        require(IERC721(contractAddress).ownerOf(tokenId) == msg.sender, "Only NFT owner can change price");
        require(newPrice > 0, "Price must be greater than zero");
        
        listings[tokenId].price = newPrice;
    }
    
    // Function to unlist a listed NFT
    function unlistNFT(address contractAddress, uint256 tokenId) external isSupportedContract(contractAddress) isActiveListing(tokenId) {
        require(IERC721(contractAddress).ownerOf(tokenId) == msg.sender, "Only NFT owner can unlist");
        
        // Transfer the NFT back to the owner
        IERC721(contractAddress).safeTransferFrom(address(this), msg.sender, tokenId);
        
        // Deactivate the listing
        listings[tokenId].isActive = false;
    }
    
    // Function to get the details of a listed NFT
    function getListing(address contractAddress, uint256 tokenId) external view returns (address, uint256, bool) {
        Listing memory listing = listings[tokenId];
        require(listing.isActive, "Listing not found or inactive");
        
        return (listing.seller, listing.price, listing.isActive);
    }
}