const { expect } = require("chai");
const { BN, expectEvent, expectRevert, time, block } = require('@openzeppelin/test-helpers');

const _ = require("underscore");

describe("FontNFT721Tiny", function() {


  let fontToken;

  let ptUSDA;
  let ptUSDB;
  let ptUSDC;
  let ptUSDD;

  let owner;
  let addr1;
  let addr2;
  let addr3;
  let addr4;
  let addr5;
  let addr6;
  let addr7;
  let addr8;
  let addrs;


  let provider;

  const Mn = 1000000;
  const Bn = 1000000000;
  const dec18zerosStr = "000000000000000000";

  let fontNFTTokens;
  let exchange;

  let gnfts = _.range(2,10);
  let gamounts = Array.from({length:8}).map(x => 1);
  let groyalities = Array.from({length:8}).map(x => 1);



  const ZERO_BYTES32 = 0x0000000000000000000000000000000000000000000000000000000000000000;
  const ZERO_ADDRESS = '0x0000000000000000000000000000000000000000';

  const StakingAddress = '0xe771De05b68515Cbb31207D180f3352CA04FdeF6';


  const delay = ms => new Promise(res => setTimeout(res, ms));


  async function printBids(NFTID) {
    console.log("##############################################################################");
    
    let anNFT = await exchange.connect(addr7).viewNFT(NFTID);
    //console.log("Order ID", anNFT.orderID);
    LogNFT(anNFT);          
    let Bids = await exchange.connect(addr7).viewOrderBids(anNFT.orderID);
    for(let i = 0; i < Bids.length; i++) {
        var bidID = Bids[i];
        var BID = await exchange.connect(addr7).viewBid(bidID);
        console.log(bidID.toString());
        LogBid(BID);
        //console.log("--------------------------------------------------------")
        //console.log();console.log();console.log();
    }
         
  }

  //Deploy the token 
  before(async function () {

    provider = ethers.provider;


    [owner, addr1, addr2, addr3, addr4, addr5, addr6, addr7, addr8, ...addrs] = await ethers.getSigners(25);


    //Get all the contracts 
    FontNFT721 = await ethers.getContractFactory("FontNFT721Tiny");
    FontToken = await ethers.getContractFactory("MockToken");
    PaymentTokenA = await ethers.getContractFactory("MockToken"); 
    PaymentTokenB = await ethers.getContractFactory("MockToken");
    PaymentTokenC = await ethers.getContractFactory("MockToken");

    //Deploy all the contracts 
    fontToken = await FontToken.deploy("font", "FONT", 18);
    ptUSDA = await PaymentTokenA.deploy("USDA", "USDA", 6);
    ptUSDB = await PaymentTokenA.deploy("USDB", "USDB", 6);
    ptUSDC = await PaymentTokenC.deploy("USDC", "USDC", 6);
    exchange = await FontNFT721.deploy(fontToken.address, StakingAddress);

    console.log("FONT Token Deployed at ::", fontToken.address);
    console.log("Payment Token A Deployed at ::", ptUSDA.address);
    console.log("Payment Token A Deployed at ::", ptUSDB.address);
    console.log("Exchange Contract Deployed at ::", exchange.address);
    console.log();console.log();console.log();console.log();

    

  });

  describe("Mapping NFT", async function () {

    it("Non Admin should not MAP NFT", async function () {
        let NFTs = _.range(1,2);
        let Address = Array.from({length:1}).map(x => addr3.address);
        await expect(exchange.connect(addr1).mapAddUserBulk(Address, NFTs)).to.be.revertedWith('D');
    });

    it("Admin should able MAP NFT", async function () {
        let NFTs = _.range(1,11);
        let Address = Array.from({length:10}).map(x => addr3.address);
        await expect(exchange.connect(owner).mapAddUserBulk(Address, NFTs)).to.emit(exchange, 'UserAddedBulk');
        let _address = await exchange.OriginalNFTCreators(1);
        await expect(_address).to.equal(addr3.address);
    });

  });

  describe("Admin settings", async function(){
    it("Admin can set Font Reward", async function () {
        await exchange.connect(owner).adminEditPaymentToken(ZERO_ADDRESS, true, "1000000000000000");
    });
  });

  describe("Minting NFT", async function () {
    it("Non Owner should not able to mint NFT", async function () {
        await expect(exchange.connect(addr2).safeMint(1, 250)).to.be.revertedWith('D');
    });
    it("Owner should able to mint NFT", async function () {
        await expect(exchange.connect(addr3).safeMint(1, 250)).to.emit(exchange, 'Transfer');
    });    
    it("Admin can mint on behalf of others", async function () {
        await expect(exchange.connect(owner).safeMintTo(addr3.address, 2, 350)).to.emit(exchange, 'Transfer');
    });        

    it("Admin cannot mint on behalf of non owners", async function () {
        await expect(exchange.connect(owner).safeMintTo(addr2.address, 2, 350)).to.be.revertedWith('D');
    });            

    it("Non Owner should not able to do safeMintAndList", async function () {
        await expect(exchange.connect(addr2).safeMintAndList(3, 100*Mn, 0, 100, 200, ptUSDA.address, false)).to.be.revertedWith('D');
    });    

    it("Owner should able to do safeMintAndList Normal Order", async function () {

        await exchange.connect(owner).adminEditPaymentToken(ptUSDA.address, true, 25*Mn);

        await expect(exchange.connect(addr3).setApprovalForAll(exchange.address, true)).to.emit(exchange, 'ApprovalForAll');
        await expect(exchange.connect(addr3).safeMintAndList(3, 100*Mn, 0, 100, 200, ptUSDA.address, false)).to.emit(exchange, 'OrderCreated');
    });        

    it("Owner should able to do safeMintAndList Auction Order", async function () {
        await expect(exchange.connect(addr3).safeMintAndList(4, 100*Mn, 10*Mn, 100, 200, ptUSDA.address, true)).to.emit(exchange, 'OrderCreated');
    });


    it("Admin should able to do safeMintAndList on behalf of owner", async function () {
        await expect(exchange.connect(owner).safeMintAndList(5, 100*Mn, 0, 100, 200, ptUSDA.address, false)).to.emit(exchange, 'OrderCreated');
        var NFT = await exchange.connect(addr3).viewNFT(5);
        await expect(NFT.owner).to.equal(addr3.address);
        
        //LogNFT(NFT);        
    });

        
    

  });

  describe("Move NFTs", async function () {

    it("Non Owner should not able to do move out NFT", async function () {
        await expect(exchange.connect(addr2).moveNFTOut(6)).to.be.revertedWith('D');
    });    
    
    it("Owner should able to do bring the NFT under contract custody", async function () {
        var NFT = await exchange.connect(addr3).viewNFT(1);
        //LogNFT(NFT);
        await expect(exchange.connect(addr3).moveNFTin(1)).to.emit(exchange, 'Transfer');
        NFT = await exchange.connect(addr3).viewNFT(1);
        //LogNFT(NFT);        
    })

    it("Owner should able to move out NFT", async function () {
        //await expect(exchange.connect(addr3).setApprovalForAll(exchange.address, true)).to.emit(exchange, 'ApprovalForAll');
        var _owner = await exchange.connect(addr3).ownerOf(1);
        //console.log(_owner, exchange.address);
        //await exchange.connect(addr3).moveNFTOut(1);
        await expect(exchange.connect(addr3).moveNFTOut(1)).to.emit(exchange, 'Transfer');
        _owner = await exchange.connect(addr3).ownerOf(1);
        //console.log(_owner, exchange.address);
    });    


    it("Owner should able to Update Royality", async function () {
        var newRoyality = 754;
        await expect(exchange.connect(addr3).moveNFTin(2)).to.emit(exchange, 'Transfer');
        NFT = await exchange.connect(addr3).viewNFT(2);
        await expect(NFT.royality).to.equal(350);
        await expect(exchange.connect(addr3).updateRoyality(2, newRoyality)).to.emit(exchange, 'RoyalitiesUpdated');
        NFT = await exchange.connect(addr3).viewNFT(2);
        await expect(NFT.royality).to.equal(newRoyality);
    });    

    
    
  });  


  describe("Normal Orders", async function () {
    it("Non Owner should not able to create an Spot order", async function () {
        await expect(exchange.connect(addr2).orderCreate(2, 100*Mn, 0, 150, ptUSDA.address, false)).to.be.revertedWith('D');
    });

    it("Owner should able to create an Spot order", async function () {
        await expect(exchange.connect(addr3).orderCreate(2, 100*Mn, 0, 150, ptUSDA.address, false)).to.emit(exchange, 'OrderCreated');
        let anNFT = await exchange.connect(addr3).viewNFT(2);
        await expect(anNFT.referralCommission).to.equal(150);
        await expect(anNFT.orderID).to.equal(4);
        await expect(anNFT.owner).to.equal(addr3.address);

        //LogOrder(anOrder);
    });

    it("Non Owner should not able to edit a Spot order", async function () {
        await expect(exchange.connect(addr2).orderEdit(2, 100*Mn, 0, 150, ptUSDA.address)).to.be.revertedWith('D');
    });    

    it("Owner should able to edit his Spot order", async function () {
        await expect(exchange.connect(addr3).orderEdit(2, 80*Mn, 0, 500, ptUSDA.address)).to.emit(exchange, 'OrderEdited');
        let anNFT = await exchange.connect(addr3).viewNFT(2);
        await expect(anNFT.referralCommission).to.equal(500);
        await expect(anNFT.orderID).to.equal(4);
        await expect(anNFT.token).to.equal(ptUSDA.address);

    });        

    it("Should not able to buy a Non ETH Spot order with ETH", async function () {
        let anNFT = await exchange.connect(addr5).viewNFT(2);
        
        
        var ethValue = anNFT.price.toString();
        
        const transactionObject = {
            from: addr3.address,
            to: exchange.address,
            value:ethValue,// web3.utils.toWei(anOrder.price.toString(), 'wei'),
        };        



        var initbalance = await provider.getBalance(exchange.address);
      

        await ptUSDA.transfer(addr5.address, 1000*Mn);
        await ptUSDA.connect(addr5).approve(exchange.address, 1000*Mn);


        await expect(exchange.connect(addr5).orderBuy(2, addr4.address, false, { value: ethValue })).to.emit(exchange, 'OrderBought');

        var balance = await provider.getBalance(exchange.address);

        

        anNFT = await exchange.connect(addr5).viewNFT(2);
        
        await expect(anNFT.owner).to.equal(addr5.address);

        await expect(balance.toString()).to.equal(ethValue);
    });

    it("New owner should able to create order", async function () {
        await exchange.connect(owner).adminEditPaymentToken(ptUSDB.address, true, 50*Mn);
        await expect(exchange.connect(addr5).orderCreate(2, 180*Mn, 0, 500, ptUSDB.address, false)).to.emit(exchange, 'OrderCreated');
    });


    it("Anyone should able to buy a Non ETH Spot order", async function () {
        //Transfer the needed token to user wallet and approve it
        await ptUSDB.transfer(addr1.address, 1000*Mn);
        await ptUSDB.connect(addr1).approve(exchange.address, 1000*Mn);
        await expect(exchange.connect(addr1).orderBuy(2, addr4.address, false)).to.emit(exchange, 'OrderBought');
        
        let anOrder = await exchange.connect(addr3).viewNFT(2);

        var referralCommission = await exchange.connect(addr1).viewEarnings(addr4.address, ptUSDB.address);
        await expect(referralCommission.toString()).to.equal("9000000");

        
        await exchange.connect(owner).withdrawFees(ptUSDB.address);
        var StakingAddressBalance = await ptUSDB.balanceOf(StakingAddress);
        await expect(StakingAddressBalance.toString()).to.equal("7200000");
        

        var FontRewards = await exchange.connect(addr1).viewFontRewards(addr1.address);
        //console.log("FontRewards", FontRewards.toString());
        await expect(FontRewards.toString()).to.equal("3600000000000000000");
        

    });          
    
    

    it("Non Owner should not able to cancel a Spot order", async function () {
        await expect(exchange.connect(addr2).orderCancel(3)).to.be.revertedWith('D');
    });        

    it("Owner should able to cancel a Spot order", async function () {
        await expect(exchange.connect(addr3).safeMintAndList(10, "100" + dec18zerosStr, 0, 300, 500, ZERO_ADDRESS, false)).to.emit(exchange, 'OrderCreated');
        await expect(exchange.connect(addr3).orderCancel(10)).to.emit(exchange, 'OrderCanceled');
        let anNFT = await exchange.connect(addr3).viewNFT(10);
        
    });            

    it("Owner should able to create a Spot order with ETH", async function () {
        await expect(exchange.connect(addr3).safeMintAndList(6, "100" + dec18zerosStr, 0, 300, 500, ZERO_ADDRESS, false)).to.emit(exchange, 'OrderCreated');
        let anNFT = await exchange.connect(addr3).viewNFT(6);
        await expect(anNFT.token).to.equal(ZERO_ADDRESS);

    });

    it("Anyone should able to buy a Spot order With ETH", async function () {

        let anOrder = await exchange.connect(addr3).viewNFT(6);

        const transactionObject = {
            from: addr1.address,
            to: exchange.address,
            value:anOrder.price.toString(),// web3.utils.toWei(anOrder.price.toString(), 'wei'),
        };        

        addr1balance = await provider.getBalance(addr1.address);
        
        exchangebalance = await provider.getBalance(exchange.address);

        addr3balance = await provider.getBalance(addr3.address);

        addr4balance = await provider.getBalance(addr4.address);

        await expect(exchange.connect(addr1).orderBuy(6, addr4.address, false, { value: anOrder.price.toString() })).to.emit(exchange, 'OrderBought');

        
        anOrder = await exchange.connect(addr3).viewNFT(6);
        

        addr1balance_1 = await provider.getBalance(addr1.address);
        //console.log("Balance of Addr1", parseInt(addr1balance.div(10**15).toString())/1000, parseInt(addr1balance_1.div(10**15).toString()) / 1000); // 0

        exchangebalance_1 = await provider.getBalance(exchange.address);
        //console.log("Balance of exchange", exchangebalance.div(10**15).toString(), parseInt(exchangebalance_1.div(10**15).toString()) / 1000); // 0
        
        addr3balance_1 = await provider.getBalance(addr3.address);
        ETHRoyality = await exchange.connect(addr3).viewEarnings(addr3.address, ZERO_ADDRESS);

        //console.log("Balance of addr3", parseInt(addr3balance.div(10**15).toString())/1000, parseInt(addr3balance_1.div(10**15).toString()) / 1000, parseInt(ETHRoyality.div(10**15).toString() / 1000)); // 0

        addr4balance_4 = await provider.getBalance(addr4.address);
        ETHReferralCommission = await exchange.connect(addr3).viewEarnings(addr4.address, ZERO_ADDRESS);

        

        //console.log("Balance of referral", parseInt(addr4balance.div(10**15).toString())/1000, parseInt(ETHReferralCommission.div(10**15).toString())/1000); // 0

        

    });          
    
    


    //let send = web3.eth.sendTransaction({from:eth.coinbase,to:contract_address, value:web3.toWei(0.05, "ether")});

    


  });

 
  describe("Auction Orders for ERC20 Tokens", async function () {

    
    var NFTID = 9;

    var initialValue = null;

    var royalityforNFT = 400;

    it("Owner can mint and create Auction order", async function () {
        await expect(exchange.connect(addr3).safeMintAndList(NFTID, 100*Mn, 3*Mn, royalityforNFT, 500, ptUSDA.address, true)).to.emit(exchange, 'OrderCreated');
        let anNFT = await exchange.connect(addr3).viewNFT(NFTID);
        
    });

    it("Owner should able to edit order befor bidding", async function () {
        await expect(exchange.connect(addr3).orderEdit(NFTID, 80*Mn, 3*Mn, 800, ptUSDA.address)).to.emit(exchange, 'OrderEdited');
        let anNFT = await exchange.connect(addr3).viewNFT(NFTID);
        await expect(anNFT.referralCommission).to.equal(800);
        await expect(anNFT.owner).to.equal(addr3.address);
        await expect(anNFT.token).to.equal(ptUSDA.address);
        await expect(anNFT.price).to.equal(80*Mn);

    });    

    it("Non Owner should not able to edit order befor bidding", async function () {
        await expect(exchange.connect(addr4).orderEdit(NFTID, 80*Mn, 3*Mn, 400, ptUSDA.address)).to.be.revertedWith('D');

    });        

    it("Should not bid an order below min price", async function () {
        await expect(exchange.connect(addr4).orderBid(NFTID, 1*Mn, addr8.address)).to.be.revertedWith('D');
    });

    it("Anyone can bid an order", async function () {
        await ptUSDA.transfer(addr4.address, 1000*Mn);
        await ptUSDA.connect(addr4).approve(exchange.address, 1000*Mn);

        var _balance = await ptUSDA.balanceOf(addr4.address);
        //console.log("_balance", _balance.toString());

        await expect(exchange.connect(addr4).orderBid(NFTID, 4*Mn, addr8.address)).to.emit(exchange, 'BidOrder');

        _balance = await ptUSDA.balanceOf(addr4.address);
        //console.log("_balance after first bid", _balance.toString());        
        
        let anNFT = await exchange.connect(addr3).viewNFT(NFTID);
        //LogNFT(anNFT);

        let aBid = await exchange.connect(addr3).viewBid(1);
        //LogBid(aBid);
        
    });    

    it("Owner should not able to edit order after bidding", async function () {
        await expect(exchange.connect(addr3).orderEdit(NFTID, 80*Mn, 3*Mn, 800, ptUSDA.address)).to.be.revertedWith('M');

    });    

    it("Testing 100 bids gas cost", async function () {
        await ptUSDA.transfer(addr4.address, 700*Mn);
        await ptUSDA.connect(addr4).approve(exchange.address, 700*Mn);

        _balance = await ptUSDA.balanceOf(addr4.address);
        //console.log("_balance after topup", _balance.toString());           

        var totalIvest = 0;

        for(let i = 5; i<34; i++) {
            //console.log("reached :: ", i);
            await expect(exchange.connect(addr4).orderBid(NFTID, i*Mn, addr8.address)).to.emit(exchange, 'BidOrder');
            totalIvest += i;
        }

        //console.log("Total invested in Mn", totalIvest);   

        _balance = await ptUSDA.balanceOf(addr4.address);
        //console.log("_balance after 29 bids", _balance.toString());   

        for(let i = 2; i<30; i++) {
            let aBid = await exchange.connect(addr4).viewBid(i);

            await expect(aBid.offer).to.equal((i+3)*Mn);

        }

        let anNFT = await exchange.viewNFT(NFTID);
        //LogNFT(anNFT);
        //console.log(addr3.address);

        let aBid = await exchange.viewBid(29);
        //LogBid(aBid);       
        
        //console.log(addr4.address);
    });


    
    it("Bidder should able to Cancel own bid", async function () {
        await expect(exchange.connect(addr4).orderBidCancel(30, NFTID)).to.emit(exchange, 'BidCanceled');

        _balance = await ptUSDA.balanceOf(addr4.address);
        //console.log("_balance after cancel 30 BID", _balance.toString());   

        
        let anNFT = await exchange.connect(addr3).viewNFT(NFTID);
        //LogNFT(anNFT);        
    });    

    it("Bidder should not able to Cancel canceled bid", async function () {
        await expect(exchange.connect(addr4).orderBidCancel(30, NFTID)).to.be.revertedWith('D');
    });        

    it("Non Bidder should not able to Cancel others bid", async function () {
        await expect(exchange.connect(addr3).orderBidCancel(29, NFTID)).to.be.revertedWith('D');
    });        
    

    it("Bidder should not able to bid lower than highest bid", async function () {
        await expect(exchange.connect(addr4).orderBid(NFTID, 10*Mn, addr8.address)).to.be.revertedWith('D');
    });         

    it("Bidder should able to bid higher than highest bid @todo" , async function () {

        console.log("@todo testall");
        //@todo everything below 
        //Some tokens didnt worked, try few more tokens and test it for this, better 2 tokens 
        //Verfiy the balance mathamatcally 

        var thisUser = addr7;

        await ptUSDA.transfer(thisUser.address, 36*Mn);
        await ptUSDA.connect(thisUser).approve(exchange.address, 36*Mn);

        let anNFT = await exchange.connect(thisUser).viewNFT(NFTID);
        
        let aBid = await exchange.connect(thisUser).viewBid(29);
            
        ptUSDASupply = await ptUSDA.totalSupply();

        await expect(exchange.connect(thisUser).orderBid(NFTID, 35*Mn, addr8.address)).to.emit(exchange, 'BidOrder');

        anNFT = await exchange.connect(thisUser).viewNFT(NFTID);

        aBid = await exchange.connect(thisUser).viewBid(31);

    });             


    it("Owner should able to approve a bid ", async function () {
        console.log("@todo testall");
        //Test the referral commission @done
        //test the royality @done
        //test the exchange commission @done
        //test the buyer balance 
        //test the seler balance

        

        //viewEarnings

        var selectingBid = 26*Mn;
        

        commissionFeesBefore = await exchange.connect(owner).commissionFees(ptUSDA.address);
        commissionFeesBefore = parseInt(commissionFeesBefore.toString());

        referralCommissionBefore  = await exchange.connect(owner).viewEarnings(addr8.address, ptUSDA.address);
        referralCommissionBefore = parseInt(referralCommissionBefore.toString());

        royalityBefore = await exchange.connect(owner).viewEarnings(addr3.address, ptUSDA.address);
        royalityBefore = parseInt(royalityBefore.toString());

        sellerBalanceBefore = await ptUSDA.balanceOf(addr3.address);
        sellerBalanceBefore = parseInt(sellerBalanceBefore.toString());

        anNFT = await exchange.connect(addr3).viewNFT(NFTID);
        //LogNFT(anNFT);                   
        aBid = await exchange.connect(addr3).viewBid(23);
        //LogBid(aBid);            
        await expect(exchange.connect(addr3).orderBidApprove(23,NFTID, false)).to.emit(exchange, 'OrderBidApproved');
        anNFT = await exchange.connect(addr3).viewNFT(NFTID);
        //LogNFT(anNFT);      
        aBid = await exchange.connect(addr3).viewBid(23);

        _balance = await ptUSDA.balanceOf(addr4.address);
        //console.log("_balance after approval 23 BID 26mn", _balance.toString());         
        //LogBid(aBid);                             
        
        await expect(_balance.toString()).to.equal(((1700*Mn) - selectingBid) + '');

        anNFT = await exchange.viewNFT(NFTID);

        await expect(anNFT.owner).to.equal(addr4.address);

        //Test the exchange commission fees
        commissionFeesAfterApprove = await exchange.connect(owner).commissionFees(ptUSDA.address);
        commissionFeesAfterApprove = parseInt(commissionFeesAfterApprove.toString());

        referralCommissionAfter = await exchange.connect(owner).viewEarnings(addr8.address, ptUSDA.address);
        referralCommissionAfter = parseInt(referralCommissionAfter.toString());


        await expect(commissionFeesAfterApprove).to.equal((commissionFeesBefore + (selectingBid * 0.04)));
        await expect(referralCommissionAfter).to.equal((referralCommissionBefore + (selectingBid * 0.08)));
        
        //sellerBalanceBefore = await ptUSDC.balanceOf(addr3.address);
        //sellerBalanceBefore = parseInt(sellerBalanceBefore.toString());



        royalityAfter = await exchange.connect(owner).viewEarnings(addr3.address, ptUSDA.address);
        royalityAfter = parseInt(royalityAfter.toString());        

        //royalityforNFT

        //Should calcumate the roylaity + earnings 

        sellerBalanceAfter = await ptUSDA.balanceOf(addr3.address);
        sellerBalanceAfter = parseInt(sellerBalanceAfter.toString());


        NFTCuts = selectingBid - (selectingBid * ((royalityforNFT/10000) + 0.04 + 0.08));

        await expect((royalityAfter-royalityBefore)).to.equal(selectingBid * royalityforNFT / 10000);

        await expect((sellerBalanceAfter-sellerBalanceBefore)).to.equal(NFTCuts);

        //console.log("sellerBalanceAfter", sellerBalanceBefore , sellerBalanceAfter,  NFTCuts);

        //await printBids(NFTID);

    });             


    it("Owner should able to cancel an auction order", async function () {
        await exchange.connect(owner).adminEditPaymentToken(ptUSDC.address, true, 37*Mn);

        //mint and create order 
        await expect(exchange.connect(addr4).orderCreate(NFTID, 3*Mn, 1*Mn, 300, ptUSDC.address, true)).to.emit(exchange, 'OrderCreated');

        //add tons of bids

        await ptUSDC.transfer(addr5.address, 2000*Mn);
        await ptUSDC.connect(addr5).approve(exchange.address, 2000*Mn);
        
        _balance = await ptUSDC.balanceOf(addr5.address);
        //console.log("_balance adding ptUSDC", _balance.toString());           

        var totalIvest = 0;

        for(let i = 2; i<26; i++) {
            //console.log("reached :: ", i);
            await expect(exchange.connect(addr5).orderBid(NFTID, i*Mn, addr6.address)).to.emit(exchange, 'BidOrder');
            totalIvest += i;
        }

        _balance = await ptUSDC.balanceOf(addr5.address);
        //console.log("_balance after invest", _balance.toString());         

        //console.log("Total Invested ::", totalIvest);

        //cancel it
        await expect(exchange.connect(addr4).orderCancel(NFTID)).to.emit(exchange, 'OrderCanceled');

        _balance = await ptUSDC.balanceOf(addr5.address);
        //console.log("_balance after cancel", _balance.toString());        
        
        //printBids(NFTID);

        //anNFT = await exchange.connect(addr4).orderCreate(uint256 nft, uint256 price, uint256 minPrice, uint16 referralCommission, address token, bool auction)
    });            
  });
  
  describe("Auction Orders for ETH", async function () {

    
    var NFTID = 8;

    var initialValue = null;

    var royalityforNFT = 450;

    var referralCommissionForNFT = 125;

    it("Owner can mint and create Auction order", async function () {
        await expect(exchange.connect(addr3).safeMintAndList(NFTID, 5 + dec18zerosStr, 2 + dec18zerosStr, royalityforNFT, referralCommissionForNFT, ZERO_ADDRESS, true)).to.emit(exchange, 'OrderCreated');
        let anNFT = await exchange.connect(addr3).viewNFT(NFTID);
        
    });

    it("Should not bid an order below min price", async function () {
        await expect(exchange.connect(addr4).orderBid(NFTID, 1 + dec18zerosStr, addr8.address)).to.be.revertedWith('D');
    });

    it("Anyone can bid an order", async function () {

        const transactionObject = {
            from: addr4.address,
            to: exchange.address,
            value: 3+dec18zerosStr,// web3.utils.toWei(anOrder.price.toString(), 'wei'),
        };        

        
        //await expect(exchange.connect(addr4).orderBid(NFTID, 3+dec18zerosStr, addr8.address)).to.emit(exchange, 'BidOrder');

        await expect(exchange.connect(addr4).orderBid(NFTID, 3+dec18zerosStr, addr8.address, { value: 3+dec18zerosStr })).to.emit(exchange, 'BidOrder');

        //await expect(exchange.connect(addr1).orderBuy(6, addr4.address, false, { value: anOrder.price.toString() })).to.emit(exchange, 'OrderBought');
        
        
        let anNFT = await exchange.connect(addr3).viewNFT(NFTID);
        //LogNFT(anNFT);

        let aBid = await exchange.connect(addr3).viewBid(anNFT.highestBidID);
        //LogBid(aBid);
        
    });    

    

    it("Testing 100 bids gas cost", async function () {

        var totalIvest = 0;

        for(let i = 4; i<24; i++) {
            //console.log("reached :: ", i);
            await expect(exchange.connect(addr4).orderBid(NFTID, i+dec18zerosStr, addr8.address, { value: i+dec18zerosStr })).to.emit(exchange, 'BidOrder');
            totalIvest += i;
        }

        
        for(let i = 4; i < 24; i++) {
            let aBid = await exchange.connect(addr4).viewBid(i+53);

            await expect(aBid.offer).to.equal(i+dec18zerosStr);

        }

        //await printBids(NFTID);

        let anNFT = await exchange.viewNFT(NFTID);
        //LogNFT(anNFT);
        //console.log(addr3.address);

        //let aBid = await exchange.viewBid(29);
        //LogBid(aBid);       
        
        //console.log(addr4.address);
    });


    
    it("Bidder should able to Cancel own bid", async function () {

        addr4balanceBefore = await provider.getBalance(addr4.address);

        aBid = await exchange.connect(addr4).viewBid(72);
        //LogBid(aBid);

        await expect(exchange.connect(addr4).orderBidCancel(72, NFTID)).to.emit(exchange, 'BidCanceled');

        addr4balanceAfter = await provider.getBalance(addr4.address);
        //console.log("_balance after cancel 30 BID", _balance.toString());   

        aBid = await exchange.connect(addr4).viewBid(72);
        //LogBid(aBid);

        //console.log("addr4balanceAfter", addr4balanceBefore.div("1000000000000000000").toString(), addr4balanceAfter.div("1000000000000000000").toString());   
        

        ETHBalance = parseInt(addr4balanceAfter.div("1000000000000000000").toString()) - parseInt(addr4balanceBefore.div("1000000000000000000").toString());

        await expect(ETHBalance).to.equal(19);


        let anNFT = await exchange.connect(addr3).viewNFT(NFTID);


        //LogNFT(anNFT);        
    });    

    it("Bidder should not able to Cancel canceled bid", async function () {
        await expect(exchange.connect(addr4).orderBidCancel(30, NFTID)).to.be.revertedWith('D');
    });        

    it("Non Bidder should not able to Cancel others bid", async function () {
        await expect(exchange.connect(addr3).orderBidCancel(29, NFTID)).to.be.revertedWith('D');
    });        
    

    it("Bidder should not able to bid lower than highest bid", async function () {
        await expect(exchange.connect(addr4).orderBid(NFTID, 20 + dec18zerosStr, addr8.address)).to.be.revertedWith('D');
    });         

    it("Bidder should able to bid higher than highest bid @todo" , async function () {

        //console.log("@todo testall");
        //@todo everything below 
        //Some tokens didnt worked, try few more tokens and test it for this, better 2 tokens 
        //Verfiy the balance mathamatcally 

        var thisUser = addr7;


        let anNFT = await exchange.connect(thisUser).viewNFT(NFTID);
        
        let aBid = await exchange.connect(thisUser).viewBid(29);
            
        addr4balanceBefore = await provider.getBalance(thisUser.address);


        await expect(exchange.connect(thisUser).orderBid(NFTID, 25 + dec18zerosStr, addr8.address,{ value: 25+dec18zerosStr })).to.emit(exchange, 'BidOrder');


        addr4balanceAfter = await provider.getBalance(thisUser.address);


        ETHBalance = parseInt(addr4balanceBefore.div("1000000000000000000").toString()) - parseInt(addr4balanceAfter.div("1000000000000000000").toString());

        await expect(ETHBalance).to.equal(25);

        anNFT = await exchange.connect(thisUser).viewNFT(NFTID);

        aBid = await exchange.connect(thisUser).viewBid(31);

    });             


    it("Owner should able to approve a bid ", async function () {
        //console.log("@todo testall");

        
        var selectingBid = 20000000000000000000;

        commissionFeesBefore = await exchange.commissionFees(ZERO_ADDRESS);

        referralCommissionBefore = parseInt(((await exchange.viewEarnings(addr8.address, ZERO_ADDRESS)).div("100000000000000")).toString());        

        sellerBalanceBefore = parseInt(((await provider.getBalance(addr3.address)).div("100000000000000")).toString());

        royalityBefore = await exchange.viewEarnings(addr3.address, ZERO_ADDRESS);



        anNFT = await exchange.connect(addr3).viewNFT(NFTID);
        //LogNFT(anNFT);                   
        aBid = await exchange.connect(addr3).viewBid(73);
        //LogBid(aBid);            
        await expect(exchange.connect(addr3).orderBidApprove(73,NFTID, false)).to.emit(exchange, 'OrderBidApproved');
        anNFT = await exchange.connect(addr3).viewNFT(NFTID);
        //LogNFT(anNFT);      
        aBid = await exchange.connect(addr3).viewBid(73);

        _balance = (await provider.getBalance(addr4.address)).toString();

        //console.log("_balance after approval 23 BID 26mn", _balance.toString());         
        //LogBid(aBid);                             
        
        //await expect(_balance).to.equal(160000);
        //console.log("_balance", _balance);

        anNFT = await exchange.viewNFT(NFTID);

        await expect(anNFT.owner).to.equal(addr4.address);

        
        commissionFeesAfterApprove = await exchange.commissionFees(ZERO_ADDRESS);

        referralCommissionAfter = await exchange.viewEarnings(addr8.address, ZERO_ADDRESS);
        
        referralCommission__ = aBid.offer.mul(referralCommissionForNFT).div(10000);

        //var tmpCommission = selectingBid

        await expect((referralCommissionAfter)).to.equal(referralCommission__);

        _exchangeCommision = aBid.offer.mul("400").div(10000);

        
        await expect(commissionFeesAfterApprove.sub(commissionFeesBefore)).to.equal(_exchangeCommision);  
        
        
        //sellerBalanceBefore = await ptUSDC.balanceOf(addr3.address);
        //sellerBalanceBefore = parseInt(sellerBalanceBefore.toString());

        royalityAfter = await exchange.viewEarnings(addr3.address, ZERO_ADDRESS);
        _royalityAmount = aBid.offer.mul(royalityforNFT).div("10000");


        await expect(royalityAfter.sub(royalityBefore)).to.equal(_royalityAmount);

        //royalityforNFT

        //Should calcumate the roylaity + earnings 

        sellerBalanceAfter = await ptUSDA.balanceOf(addr3.address);
        sellerBalanceAfter = parseInt(sellerBalanceAfter.toString());


        NFTCuts = selectingBid - (selectingBid * ((royalityforNFT/10000) + 0.04 + 0.08));


        //await expect((sellerBalanceAfter-sellerBalanceBefore)).to.equal(NFTCuts);

        //console.log("sellerBalanceAfter", sellerBalanceBefore , sellerBalanceAfter,  NFTCuts);

        //await printBids(NFTID);

    });             


    it("Owner should able to cancel an auction order", async function () {

        //mint and create order 
        
        //await expect(exchange.connect(addr4).orderCreate(NFTID, 3*Mn, 1*Mn, 300, ptUSDC.address, true)).to.emit(exchange, 'OrderCreated');


        await expect(exchange.connect(addr4).orderCreate(NFTID, 5 + dec18zerosStr, 2 + dec18zerosStr, 300, ZERO_ADDRESS, true)).to.emit(exchange, 'OrderCreated');


        //add tons of bids

        _balance = await provider.getBalance(addr5.address);
        
        
        console.log("_balance before investment", _balance.div("1000000000000000000").toString());           

        var totalIvest = 0;

        for(let i = 3; i<23; i++) {
            //console.log("reached :: ", i);
            await expect(exchange.connect(addr5).orderBid(NFTID, i + dec18zerosStr, addr6.address, { value: i+dec18zerosStr })).to.emit(exchange, 'BidOrder');
            totalIvest += i;
        }

        _balance = await provider.getBalance(addr5.address);
        console.log("_balance after investment", _balance.div("1000000000000000000").toString());                   
        //console.log("_balance after invest", _balance.toString());         

        console.log("Total Invested ::", totalIvest);

        //cancel it
        await expect(exchange.connect(addr4).orderCancel(NFTID)).to.emit(exchange, 'OrderCanceled');

        _balance = await provider.getBalance(addr5.address);
        console.log("_balance after order cancel", _balance.div("1000000000000000000").toString()); 

        //console.log("_balance after cancel", _balance.toString());        
        
        //printBids(NFTID);

        //anNFT = await exchange.connect(addr4).orderCreate(uint256 nft, uint256 price, uint256 minPrice, uint16 referralCommission, address token, bool auction)
    });            
  });
  

  describe("Check the $FONT rewards", async function () {

    it("Check reward Balance", async function () {
        payments = [
            ZERO_ADDRESS,
            ptUSDA.address,
            ptUSDB.address,
            ptUSDC.address
        ];

        
        for(let p in payments) {
            var payment = payments[p];
            var _reward = await exchange.FontRewardPerToken(payment);
            console.log("Font Reward pr token :: ", payment, _reward.toString());
        }
    });

    it("Check reward Balance", async function () {

        users = [
            owner.address,
            addr1.address,
            addr2.address,
            addr3.address,
            addr4.address,
            addr5.address,
            addr6.address,
            addr7.address,
            addr8.address,
        ]


        for(let u in users) {
            var user = users[u];
            var _reward = await exchange.viewFontRewards(user);
            console.log("Font Reward for :: ", user, _reward.toString());
        }

    });
        

        

  });

});



function NFTOrderData(start, end, address) {
    Mn = 1000000;
    output = [];
    for(let i = start; i<=end; i++) {
        var _tmp = [
            i,
            (10+i)*Mn,
            (i)*Mn,
            300,//i, //expires
            address,
            200 + (i*10), //royality
            100 + (i*10), //referral
            false, //orderType
        ];
        output.push(_tmp);
    }
    return output;
}
 
function LogNFT(nft) {
    //console.log("Qty :: ", nft.qty.toString());
    console.log("Order ID :: ", nft.orderID.toString());
    console.log("Royality :: ", nft.royality);    
    console.log("Status :: ", nft.status);    
    console.log("Owner :: ", nft.owner);    

    console.log("Price :: ", nft.price.toString());
    console.log("minPrice :: ", nft.minPrice.toString());
    console.log("HighestBidID :: ", nft.highestBidID.toString());
    console.log("Auction? :: ", nft.auction);
    console.log("Referral :: ", nft.referralCommission);
    console.log("Token :: ", nft.token);    
    console.log();console.log();console.log();
}

function LogBid(_Bid) {
    console.log("Order ID :: ", _Bid.orderID.toString());
    console.log("offer :: ", _Bid.offer.toString());    
    console.log("bidder :: ", _Bid.bidder);    
    console.log("referral :: ", _Bid.referral);    
    console.log("status :: ", _Bid.status);    
    console.log("---------------------------------------------");
}

function LogOrder(structr) {
    console.log("NFT :: ", structr.nft.toString());
    //console.log("Qty :: ", structr.qty.toString());
    console.log("Price :: ", structr.price.toString());
    console.log("minPrice :: ", structr.minPrice.toString());
    console.log("HighestBidID :: ", structr.highestBidID.toString());
    console.log("Status :: ", structr.status);
    console.log("Auction? :: ", structr.auction);
    console.log("Referral :: ", structr.referral);
    console.log("Token :: ", structr.token);
    console.log("Seller :: ", structr.seller);
    console.log("Buyer :: ", structr.buyer);
    console.log();console.log();console.log();
    
}