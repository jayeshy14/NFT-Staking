// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

contract ERC721Mock is ERC721 {
    uint256 initialSupply;

    constructor(string memory name, string memory symbol, uint256 _initialSupply) ERC721(name, symbol) {
        initialSupply = _initialSupply;
    }
    
    function mint(address to, uint256 tokenId) external {
        _mint(to, tokenId);
    }
}
