// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./FuSES_FT.sol";
import "./FuSE_FT.sol";

contract TokenConversion {
    FuSESFT public fusesFT;  // FuSESFT contract
    FuSEFT public fuseFT;    // FuSEFT contract

    constructor(address _fusesFTAddress, address _fuseFTAddress) {
        fusesFT = FuSESFT(_fusesFTAddress);
        fuseFT = FuSEFT(_fuseFTAddress);
    }

    // Convert FuSES FT → FuSE FT (Withdraw stored energy)
    function convertFuSESFTToFuSEFT(uint256 amount) external {
        uint256 allowance = fusesFT.allowance(msg.sender, address(this));
        require(allowance >= amount, "Allowance is too low");

        // Transfer FuSES FT to burn
        require(fusesFT.transferFrom(msg.sender, address(this), amount), "Transfer failed");
        fusesFT.burn(amount);

        // Mint equivalent FuSE FT tokens
        fuseFT.mint(msg.sender, amount);
    }

    // Convert FuSE FT → FuSES FT (Store excess energy)
    function convertFuSEFTToFuSESFT(uint256 amount) external {
        uint256 allowance = fuseFT.allowance(msg.sender, address(this));
        require(allowance >= amount, "Allowance is too low");

        // Transfer FuSE FT to burn
        require(fuseFT.transferFrom(msg.sender, address(this), amount), "Transfer failed");
        fuseFT.burn(amount);

        // Mint equivalent FuSES FT tokens
        fusesFT.mint(msg.sender, amount);
    }
}
