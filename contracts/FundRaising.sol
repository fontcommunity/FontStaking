// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

contract FontFundraising is AccessControl {

    using SafeMath for uint;    
    using SafeMath for uint8;
    using SafeMath for uint16;    
    using SafeMath for uint256;    
    using SafeERC20 for IERC20;

    /**********************************************************************************************************/
    /**********************************************   Variables  **********************************************/
    /**********************************************************************************************************/

    /*********** Settings ************/

    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");

    address ownerAddress;

    uint256 taxFee = 100; // 1 = 0.01%
    address font_token_address = 0x4C25Bdf026Ea05F32713F00f73Ca55857Fbf6342; //token address of the font



    constructor() {
        
    }

}