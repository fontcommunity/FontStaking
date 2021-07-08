const { expect } = require("chai");


const { BN, expectEvent, expectRevert } = require('@openzeppelin/test-helpers');




describe("FONT Staking", function() {


  let FontToken;

  let PaymentTokenA;
  let PaymentTokenB;
  let PaymentTokenC;
  let PaymentTokenD;

  let owner;
  let addr1;
  let addr2;
  let addr3;
  let addr4;
  let addrs;


  let srcToken;
  let dstToken;
  let cateswap;

  const delay = ms => new Promise(res => setTimeout(res, ms));


  //Deploy the token 
  before(async function () {

    

    [owner, addr1, addr2, addr3, addr4, addr5, addr6, ...addrs] = await ethers.getSigners();

    FontToken = await ethers.getContractFactory("MockToken");

    PaymentTokenA = await ethers.getContractFactory("MockToken");
    PaymentTokenB = await ethers.getContractFactory("MockToken");
    PaymentTokenC = await ethers.getContractFactory("MockToken");
    PaymentTokenD = await ethers.getContractFactory("MockToken");

    FontStakeContract = await ethers.getContractFactory("FontStaking");

    fontToken = await FontToken.deploy("font", "FONT", 18);
    ptUSDA = await PaymentTokenA.deploy("USDA", "USDA", 6);
    ptUSDB = await PaymentTokenA.deploy("USDB", "USDB", 9);
    ptUSDC = await PaymentTokenA.deploy("USDC", "USDC", 12);
    ptUSDD = await PaymentTokenA.deploy("USDD", "USDD", 18);     
    
    fontStakingContract = await FontStakeContract.deploy(fontToken.address);

    console.log("FONT Token Deployed at ::", fontToken.address);
    console.log("Payment Token A Deployed at ::", ptUSDA.address);
    console.log("Payment Token A Deployed at ::", ptUSDB.address);
    console.log("Payment Token A Deployed at ::", ptUSDC.address);
    console.log("Payment Token A Deployed at ::", ptUSDD.address);

    console.log("Font Staking Contract Deployed at ::", fontStakingContract.address);

    console.log();console.log();console.log();console.log();
    

    //send some FONT tokens to all the addresses 
    await fontToken.transfer(addr1.address, "70000000000000000000");
    await fontToken.transfer(addr2.address, "700000000000000000000");
    await fontToken.transfer(addr3.address, "7000000000000000000000");
    await fontToken.transfer(addr4.address, "501000000000000000000");
    await fontToken.transfer(addr5.address, "1400000000000000000000"); //000000000000000000


  });


  //check initial balance of both the tokens 
  describe("Font Staking", async function () {

    it("Able to stake and unstake it full", async function () {
        
        await fontStakingContract.connect(owner).setTimings(1,1,3);
        const addr3FontBalance = await fontToken.balanceOf(addr3.address);
        
        await fontToken.connect(addr3).approve(fontStakingContract.address, addr3FontBalance);

        await expect(fontStakingContract.connect(addr3).stake(addr3FontBalance)).to.emit(fontStakingContract, 'LogStake');

        await delay(5000);

        await expect(fontStakingContract.connect(addr3).unStake(1)).to.emit(fontStakingContract, 'UnStaked');

        await expect(await fontToken.balanceOf(fontStakingContract.address)).to.equal(0);

    });
    
    it("Able to Stake if more than 500", async function () {
        const addr2Balance = await fontToken.balanceOf(addr2.address);
        await fontToken.connect(addr2).approve(fontStakingContract.address, addr2Balance);
        await fontStakingContract.connect(addr2).stake(addr2Balance);
        expect(await fontToken.balanceOf(fontStakingContract.address)).to.equal(addr2Balance);
    });

    it("Non owner cannot unstake", async function () {
        let fontStakingContractBalanceBeforeUnstake = await fontToken.balanceOf(fontStakingContract.address);
        await expect(fontStakingContract.connect(addr1).unStake(2)).to.be.revertedWith('Denied');
    });

    it("Able to UnStake Partial by Stake owner", async function () {
        let fontStakingContractBalanceBeforeUnstake = await fontToken.balanceOf(fontStakingContract.address);
        let unstake = await fontStakingContract.connect(addr2).unStake(2);
        let fontStakingContractBalanceAfterUnstake = await fontToken.balanceOf(fontStakingContract.address);
        let addrBalanceAfterUnstake = await fontToken.connect(addr2).balanceOf(addr2.address);
        let total = addrBalanceAfterUnstake.add(fontStakingContractBalanceAfterUnstake);
        expect(total).to.equal(fontStakingContractBalanceBeforeUnstake);
    });    

    it("Should not claim same stake again", async function () {
        await expect(fontStakingContract.connect(addr2).unStake(2)).to.be.revertedWith('Claimed');
    });        

    it("Stake wont work when paused", async function () {
        await fontStakingContract.connect(owner).pauseStaking();
        const addr5Balance = await fontToken.balanceOf(addr5.address);
        await fontToken.connect(addr5).approve(fontStakingContract.address, addr5Balance);
        await expect(fontStakingContract.connect(addr5).stake(addr5Balance)).to.be.revertedWith('Paused');
        await fontStakingContract.connect(owner).unpauseStaking();
    });            

  });

  describe("", async function () {



  });

  
});
 