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

  var stakeIdCounter = 0;


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

    it("Required minimum amount to stake", async function () {
        const addr1FontBalance = await fontToken.balanceOf(addr1.address);
        await fontToken.connect(addr1).approve(fontStakingContract.address, addr1FontBalance);
        await expect(fontStakingContract.connect(addr1).stake(addr1FontBalance)).to.be.revertedWith('Minimum required');
    });


    it("Able to stake and unstake it full", async function () {
        
        await fontStakingContract.connect(owner).setTimings(1,1,3);
        const addr3FontBalance = await fontToken.balanceOf(addr3.address);
        
        await fontToken.connect(addr3).approve(fontStakingContract.address, addr3FontBalance);

        await expect(fontStakingContract.connect(addr3).stake(addr3FontBalance)).to.emit(fontStakingContract, 'LogStake');

        await delay(5000);
        stakeIdCounter++;
        await expect(fontStakingContract.connect(addr3).unStake(stakeIdCounter)).to.emit(fontStakingContract, 'UnStaked');

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
        stakeIdCounter++;
        let unstake = await fontStakingContract.connect(addr2).unStake(stakeIdCounter);
        let fontStakingContractBalanceAfterUnstake = await fontToken.balanceOf(fontStakingContract.address);
        let addrBalanceAfterUnstake = await fontToken.connect(addr2).balanceOf(addr2.address);
        let total = addrBalanceAfterUnstake.add(fontStakingContractBalanceAfterUnstake);
        expect(total).to.equal(fontStakingContractBalanceBeforeUnstake);
    });    

    it("Anyone can burn the tax fee", async function () {
        let initialBalance = await fontToken.balanceOf(fontStakingContract.address);
        expect(initialBalance).not.equal(0);
        await expect(fontStakingContract.connect(addr3).burnFont()).to.emit(fontStakingContract, 'FontBurned');
        let BalanceAfterBurn = await fontToken.balanceOf(fontStakingContract.address);
        expect(BalanceAfterBurn).to.equal(0);
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

    it("Admin able to unstake it without tax detuction", async function () {
        await fontStakingContract.connect(owner).setTimings(1,1,30);
        const addr3FontBalance = await fontToken.balanceOf(addr3.address);
        await fontToken.connect(addr3).approve(fontStakingContract.address, addr3FontBalance);
        await expect(fontStakingContract.connect(addr3).stake(addr3FontBalance)).to.emit(fontStakingContract, 'LogStake');
        stakeIdCounter++;
        await expect(fontStakingContract.connect(owner).kickStake(stakeIdCounter)).to.emit(fontStakingContract, 'KickedStake');

        let stakeInfo = await fontStakingContract.connect(addr3).getStakeByID(stakeIdCounter);
        expect(stakeInfo['user']).to.equal(addr3.address);
        expect(stakeInfo['claimed']).to.equal(true);
        expect(stakeInfo['amount'].toString()).to.equal("7000000000000000000000");
    });        



  });

  describe("Retrive Contract Data", async function () {

    it("Retrive the right data from closed stake", async function () {
        let stakeInfo = await fontStakingContract.connect(addr1).getStakeByID(1);
        expect(stakeInfo['user']).to.equal(addr3.address);
        expect(stakeInfo['claimed']).to.equal(true);
        expect(stakeInfo['amount'].toString()).to.equal("7000000000000000000000");
        //console.log(stakeInfo);
    });

    it("Check user balance", async function () {
        const addr3FontBalance = await fontToken.balanceOf(addr3.address);
        await fontToken.connect(addr3).approve(fontStakingContract.address, addr3FontBalance);
        await expect(fontStakingContract.connect(addr3).stake(addr3FontBalance)).to.emit(fontStakingContract, 'LogStake');
        await expect(await fontToken.balanceOf(addr3.address)).to.equal(0);
        stakeIdCounter++;
        await expect(fontStakingContract.connect(addr3).unStake(stakeIdCounter)).to.emit(fontStakingContract,'UnStaked'); 
    });


    it("Check tax detected user balance after partial unstake", async function () {
        await fontStakingContract.connect(owner).setTimings(1,1,3600000);
        const initialBalance = await fontToken.balanceOf(addr3.address);
        await fontToken.connect(addr3).approve(fontStakingContract.address, initialBalance);
        await expect(fontStakingContract.connect(addr3).stake(initialBalance)).to.emit(fontStakingContract, 'LogStake');
        stakeIdCounter++;
        await expect(fontStakingContract.connect(addr3).unStake(stakeIdCounter)).to.emit(fontStakingContract,'UnStaked'); 
        
        const balanceAfterTax = await fontToken.balanceOf(addr3.address);
        var taxFee = initialBalance.sub(balanceAfterTax);

        var taxPercent = await fontStakingContract.connect(addr3).getTaxFee();

        var detectedFee = initialBalance.mul(taxPercent).div(10000);

        await expect(taxFee).to.equal(detectedFee);

        var taxAndBalance = taxFee.add(balanceAfterTax);

        await expect(taxAndBalance).to.equal(initialBalance);
    });

    it("Get user's stake ids", async function () {
        var ids = await fontStakingContract.connect(addr2).getStakeidsByUser(addr2.address);
        expect(ids.length).to.equal(1);
        ids = await fontStakingContract.connect(addr3).getStakeidsByUser(addr3.address);
        expect(ids.length).to.equal(4);
    });

    it("Get user's total stake", async function () {

        await fontStakingContract.connect(owner).setTimings(1,1,1);
        const initialBalance = await fontToken.balanceOf(addr4.address);
        await fontToken.connect(addr4).approve(fontStakingContract.address, initialBalance);
        await expect(fontStakingContract.connect(addr4).stake(initialBalance)).to.emit(fontStakingContract, 'LogStake');
        stakeIdCounter++;
        var stakeTotal = await fontStakingContract.connect(addr3).getStakeByUser(addr4.address);
        expect(stakeTotal).to.equal(initialBalance);
        await expect(fontStakingContract.connect(addr4).unStake(stakeIdCounter)).to.emit(fontStakingContract,'UnStaked'); 

    });    

    //getStakeByID

    //getStakeByUser

    //getStakeidsByUser

    //getCurrentRewardShare

  });

  describe("Admin Calls", async function () {
    it("Add a payment Token", async function () {
        await expect(fontStakingContract.connect(owner).addRewardToken(ptUSDA.address,1,true)).to.emit(fontStakingContract, 'NewRewardToken');
    });

    it("Should reject duplicate payment token", async function () {
        await expect(fontStakingContract.connect(owner).addRewardToken(ptUSDA.address,1,true)).to.be.revertedWith('Exists');
    });

    it("Should able to edit payment token", async function () {
        await expect(fontStakingContract.connect(owner).editRewardToken(ptUSDA.address,31,true)).to.emit(fontStakingContract, 'EditRewardToken');
    });
    it("Should reject the edit of non existing payment token", async function () {
        await expect(fontStakingContract.connect(owner).editRewardToken(ptUSDB.address,31,true)).to.be.revertedWith('Not Exists');
    });

    it("Non Admin cant add", async function () {
        await expect(fontStakingContract.connect(addr1).addRewardToken(ptUSDA.address,1,true)).to.be.revertedWith('Denied');
    });

    it("Non Admin cant edit", async function () {
        await expect(fontStakingContract.connect(addr1).editRewardToken(ptUSDA.address,1,true)).to.be.revertedWith('Denied');
    });


  });


  describe("Reward Supply", async function () {
    it("@todo Snapshot revert if no staking", async function () {

    });

    it("@todo Snapshot should not work within intervel", async function () {

    });    

  });  

});
 