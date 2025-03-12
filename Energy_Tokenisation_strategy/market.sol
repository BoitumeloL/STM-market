// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/// @title Energy Market Contract (Acts as Escrow)
/// @dev Manages energy token transactions, auctions, and escrow functions
contract EnergyMarket is Ownable {
    struct Auction {
        address seller;
        IERC20 token;
        uint256 amount;
        uint256 minPrice;
        address highestBidder;
        uint256 highestBid;
        bool active;
    }

    mapping(uint256 => Auction) public auctions;
    uint256 public auctionCounter;

    event AuctionCreated(uint256 indexed auctionId, address seller, address token, uint256 amount, uint256 minPrice);
    event NewBid(uint256 indexed auctionId, address bidder, uint256 bidAmount);
    event AuctionFinalized(uint256 indexed auctionId, address winner, uint256 winningBid);
    event AuctionCancelled(uint256 indexed auctionId);
    
    /// @notice Constructor, passing msg.sender to Ownable as the initial owner
    constructor() Ownable(msg.sender) {
        // The Ownable constructor will now properly set the deployer as the owner
    }
    
    /// @notice Creates an auction and locks tokens in escrow
    function createAuction(IERC20 token, uint256 amount, uint256 minPrice) external {
        require(amount > 0, "Amount must be greater than zero");
        require(minPrice > 0, "Minimum price must be greater than zero");
        require(token.balanceOf(msg.sender) >= amount, "Insufficient token balance");
        require(token.allowance(msg.sender, address(this)) >= amount, "Token allowance too low");

        token.transferFrom(msg.sender, address(this), amount);  // 🔒 LOCKING tokens in escrow

        auctions[auctionCounter] = Auction({
            seller: msg.sender,
            token: token,
            amount: amount,
            minPrice: minPrice,
            highestBidder: address(0),
            highestBid: 0,
            active: true
        });

        emit AuctionCreated(auctionCounter, msg.sender, address(token), amount, minPrice);
        auctionCounter++;
    }

    /// @notice Allows users to place bids and locks ETH in escrow
    function placeBid(uint256 auctionId) external payable {
        Auction storage auction = auctions[auctionId];
        require(auction.active, "Auction inactive");
        require(msg.value > auction.highestBid && msg.value >= auction.minPrice, "Bid too low");

        if (auction.highestBid > 0) {
            payable(auction.highestBidder).transfer(auction.highestBid);  // Refund previous highest bidder
        }

        auction.highestBidder = msg.sender;
        auction.highestBid = msg.value;

        emit NewBid(auctionId, msg.sender, msg.value);
    }

    /// @notice Finalizes an auction, transferring tokens & ETH
    function finalizeAuction(uint256 auctionId) external {
        Auction storage auction = auctions[auctionId];
        require(auction.active, "Auction inactive");
        require(msg.sender == auction.seller || msg.sender == owner(), "Unauthorized");

        auction.active = false;
        auction.token.transfer(auction.highestBidder, auction.amount);  // 🔓 RELEASING tokens
        payable(auction.seller).transfer(auction.highestBid);          // 🔓 RELEASING ETH

        emit AuctionFinalized(auctionId, auction.highestBidder, auction.highestBid);
    }

    /// @notice Cancels an auction and refunds the seller
    function cancelAuction(uint256 auctionId) external {
        Auction storage auction = auctions[auctionId];
        require(auction.active, "Auction inactive");
        require(msg.sender == auction.seller || msg.sender == owner(), "Unauthorized");

        auction.active = false;
        auction.token.transfer(auction.seller, auction.amount);  // Refund tokens to seller

        emit AuctionCancelled(auctionId);
    }
}
