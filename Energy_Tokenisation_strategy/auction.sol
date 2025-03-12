// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";

/// @title Auction Rules Contract
/// @dev Defines auction parameters and interacts with the Market contract
contract AuctionRules is Ownable {
    struct AuctionData {
        uint256 duration;
        uint256 minIncrement;
        bool requiresVerification;
    }

    mapping(uint256 => AuctionData) public auctionSettings;
    event AuctionRulesSet(uint256 auctionId, uint256 duration, uint256 minIncrement, bool requiresVerification);

    /// @notice Constructor setting initial owner
    constructor() Ownable(msg.sender) {}

    function setAuctionRules(uint256 auctionId, uint256 duration, uint256 minIncrement, bool requiresVerification) external onlyOwner {
        auctionSettings[auctionId] = AuctionData(duration, minIncrement, requiresVerification);
        emit AuctionRulesSet(auctionId, duration, minIncrement, requiresVerification);
    }

    function getAuctionRules(uint256 auctionId) external view returns (AuctionData memory) {
        return auctionSettings[auctionId];
    }
}
