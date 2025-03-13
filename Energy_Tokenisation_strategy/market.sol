// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./auctionRules.sol";

/// @title Energy Market Contract (Acts as Escrow)
/// @dev Inherits AuctionRules & manages auctions, bids, and escrow
contract EnergyMarket is AuctionRules {
    struct Bid {
        address bidder;
        uint256 amount;
        uint256 timestamp;
    }

    struct Auction {
        address seller;
        IERC20 token;
        uint256 amount;
        uint256 minPrice;
        bool active;
        mapping(uint256 => Bid) bids;
        uint256 bidCount;
        uint256 highestBid;
        address highestBidder;
        uint256 endTime;
        bool requiresVerification;
    }

    mapping(uint256 => Auction) public auctions;
    uint256 public auctionCounter;
    // uint256 auctionstarttime = block.timestamp;

    event AuctionCreated(uint256 indexed auctionId, address seller, address token, uint256 amount, uint256 minPrice, uint256 endTime);
    event NewBid(uint256 indexed auctionId, address bidder, uint256 bidAmount);
    event AuctionFinalized(uint256 indexed auctionId, address winner, uint256 winningBid);
    event AuctionCancelled(uint256 indexed auctionId);

    /// @notice Creates an auction and locks tokens in escrow
    function createAuction(IERC20 token, uint256 amount, uint256 minPrice, uint256 auctionId) external {
        require(amount > 0, "Amount must be greater than zero");
        require(minPrice > 0, "Minimum price must be greater than zero");
        require(token.balanceOf(msg.sender) >= amount, "Insufficient token balance");
        require(token.allowance(msg.sender, address(this)) >= amount, "Token allowance too low");

        token.transferFrom(msg.sender, address(this), amount);  // 🔒 LOCKING tokens in escrow

        // Get auction rules from AuctionRules contract
        AuctionData memory rules = auctionSettings[auctionId];

        Auction storage auction = auctions[auctionCounter];
        auction.seller = msg.sender;
        auction.token = token;
        auction.amount = amount;
        auction.minPrice = minPrice;
        auction.active = true;
        auction.bidCount = 0;
        auction.highestBid = 0;
        auction.highestBidder = address(0);
        auction.endTime = block.timestamp + rules.duration * 1 minutes;
        auction.requiresVerification = rules.requiresVerification;

        emit AuctionCreated(auctionCounter, msg.sender, address(token), amount, minPrice, auction.endTime);
        auctionCounter++;
    }

    /// @notice Allows users to place bids and locks ETH in escrow
    function placeBid(uint256 auctionId) external payable {
        Auction storage auction = auctions[auctionId];
        require(auction.active, "Auction inactive");
        require(block.timestamp < auction.endTime, "Auction has ended");
        require(msg.value >= auction.minPrice, "Bid too low");

        // Get auction rules
        AuctionData memory rules = auctionSettings[auctionId];
        require(msg.value >= auction.highestBid + rules.minIncrement, "Bid increment too low");

        auction.bids[auction.bidCount] = Bid({
            bidder: msg.sender,
            amount: msg.value,
            timestamp: block.timestamp
        });
        auction.bidCount++;

        // Update highest bid
        auction.highestBid = msg.value;
        auction.highestBidder = msg.sender;

        emit NewBid(auctionId, msg.sender, msg.value);
    }

    /// @notice Finalizes an auction, transferring tokens & ETH, refunding losing bidders
    function finalizeAuction(uint256 auctionId) external {
        Auction storage auction = auctions[auctionId];
        require(auction.active, "Auction inactive");
        require(block.timestamp >= auction.endTime, "Auction not yet ended");
        require(msg.sender == auction.seller || msg.sender == owner(), "Unauthorized");

        auction.active = false;
        address winner = auction.highestBidder;
        uint256 highestBid = auction.highestBid;

        require(winner != address(0), "No valid bids");

        // Transfer tokens to the winner
        auction.token.transfer(winner, auction.amount);

        // Transfer ETH to the seller
        payable(auction.seller).transfer(highestBid);

        // Refund all losing bidders
        for (uint256 i = 0; i < auction.bidCount; i++) {
            address bidder = auction.bids[i].bidder;
            uint256 bidAmount = auction.bids[i].amount;

            if (bidder != winner) {
                payable(bidder).transfer(bidAmount);
            }
        }

        emit AuctionFinalized(auctionId, winner, highestBid);
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
