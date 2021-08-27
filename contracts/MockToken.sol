// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";


contract MockToken is ERC20, ERC20Burnable {
    constructor(string memory name,string memory symbol, uint8 decimals) ERC20(name, symbol) {
        _mint(msg.sender, 200000000 * (10 ** decimals));
    }
}

