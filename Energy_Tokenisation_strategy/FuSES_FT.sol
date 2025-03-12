// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract FuSESFT is ERC20, Ownable {
    address public minter;  // Authorized contract to mint tokens

    constructor(uint256 initialSupply) ERC20("FuSESFT", "FST") Ownable(msg.sender) {
        _mint(msg.sender, initialSupply);
    }

    // Allow the contract owner to set a minter
    function setMinter(address _minter) external onlyOwner {
        minter = _minter;
    }

    // Only the authorized minter can mint new FuSES FT tokens
    function mint(address to, uint256 amount) external {
        require(msg.sender == minter, "Not authorized to mint");
        _mint(to, amount);
    }

    function burn(uint256 amount) external {
        _burn(msg.sender, amount);
    }
}
