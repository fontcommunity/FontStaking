// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MockToken is ERC20 {
    constructor(string memory name,string memory symbol, uint8 decimals) ERC20(name, symbol) {
        _mint(msg.sender, 2000000 * 10 ** decimals);
    }
}
