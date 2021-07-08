/**
 * @type import('hardhat/config').HardhatUserConfig
 */

require('@nomiclabs/hardhat-ethers');
require("@nomiclabs/hardhat-waffle");
require("hardhat-gas-reporter");

  
module.exports = {
  solidity: "0.8.0",
  gasReporter: {
    currency: 'USD',
    gasPrice: 31
  }

};
