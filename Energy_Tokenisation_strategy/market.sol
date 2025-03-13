// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/// @title Energy Market Contract (Acts as Escrow)
/// @dev Manages energy token transactions, auctions, and escrow functions
contract EnergyMarket is Ownable {
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
    }

    mapping(uint256 => Auction) public auctions;
    uint256 public auctionCounter;

    /// @notice Constructor, passing msg.sender to Ownable as the initial owner
    constructor() Ownable(msg.sender) {
        // The Ownable constructor will now properly set the deployer as the owner
    }

    event AuctionCreated(uint256 indexed auctionId, address seller, address token, uint256 amount, uint256 minPrice);
    event NewBid(uint256 indexed auctionId, address bidder, uint256 bidAmount);
    event AuctionFinalized(uint256 indexed auctionId, address winner, uint256 winningBid);
    event AuctionCancelled(uint256 indexed auctionId);

    /// @notice Creates an auction and locks tokens in escrow
    function createAuction(IERC20 token, uint256 amount, uint256 minPrice) external {
        require(amount > 0, "Amount must be greater than zero");
        require(minPrice > 0, "Minimum price must be greater than zero");
        require(token.balanceOf(msg.sender) >= amount, "Insufficient token balance");
        require(token.allowance(msg.sender, address(this)) >= amount, "Token allowance too low");

        token.transferFrom(msg.sender, address(this), amount);  // 🔒 LOCKING tokens in escrow

        Auction storage auction = auctions[auctionCounter];
        auction.seller = msg.sender;
        auction.token = token;
        auction.amount = amount;
        auction.minPrice = minPrice;
        auction.active = true;
        auction.bidCount = 0;

        emit AuctionCreated(auctionCounter, msg.sender, address(token), amount, minPrice);
        auctionCounter++;
    }

    /// @notice Allows users to place bids and locks ETH in escrow
    function placeBid(uint256 auctionId) external payable {
        Auction storage auction = auctions[auctionId];
        require(auction.active, "Auction inactive");
        require(msg.value >= auction.minPrice, "Bid too low");

        auction.bids[auction.bidCount] = Bid({
            bidder: msg.sender,
            amount: msg.value,
            timestamp: block.timestamp
        });
        auction.bidCount++;

        emit NewBid(auctionId, msg.sender, msg.value);
    }

    /// @notice Finalizes an auction, transferring tokens & ETH, refunding losing bidders
    function finalizeAuction(uint256 auctionId) external {
        Auction storage auction = auctions[auctionId];
        require(auction.active, "Auction inactive");
        require(msg.sender == auction.seller || msg.sender == owner(), "Unauthorized");

        auction.active = false;

        // Find the winning bid (oldest highest bid)
        address winner;
        uint256 highestBid = 0;
        uint256 earliestTimestamp = block.timestamp;

        for (uint256 i = 0; i < auction.bidCount; i++) {
            if (auction.bids[i].amount > highestBid || 
                (auction.bids[i].amount == highestBid && auction.bids[i].timestamp < earliestTimestamp)) {
                highestBid = auction.bids[i].amount;
                winner = auction.bids[i].bidder;
                earliestTimestamp = auction.bids[i].timestamp;
            }
        }

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
