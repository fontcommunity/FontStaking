const { expect } = require("chai");
const { BN, expectEvent, expectRevert, time, block } = require('@openzeppelin/test-helpers');

const _ = require("underscore");

describe("NFT EXchange", function() {


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


  const Mn = 1000000;
  const Bn = 1000000000;

  let fontNFTTokens;
  let exchange;

  let gnfts = _.range(2,10);
  let gamounts = Array.from({length:8}).map(x => 1);
  let groyalities = Array.from({length:8}).map(x => 1);



  const ZERO_BYTES32 = 0x0000000000000000000000000000000000000000000000000000000000000000;
  const ZERO_ADDRESS = '0x0000000000000000000000000000000000000000';


  const delay = ms => new Promise(res => setTimeout(res, ms));



  //Deploy the token 
  before(async function () {

    

    [owner, addr1, addr2, addr3, addr4, addr5, addr6, addr7, addr8, ...addrs] = await ethers.getSigners(25);


    //Get all the contracts 
    FontNFTTokens = await ethers.getContractFactory("FontNFT");
    FontToken = await ethers.getContractFactory("MockToken");
    PaymentTokenA = await ethers.getContractFactory("MockToken"); 
    PaymentTokenB = await ethers.getContractFactory("MockToken");
    PaymentTokenC = await ethers.getContractFactory("MockToken");
    PaymentTokenD = await ethers.getContractFactory("MockToken");
    ExchangeContract = await ethers.getContractFactory("FontNFTExchange");

    //Deploy all the contracts 
    fontNFTTokens = await FontNFTTokens.deploy();
    fontToken = await FontToken.deploy("font", "FONT", 18);
    ptUSDA = await PaymentTokenA.deploy("USDA", "USDA", 6);
    ptUSDB = await PaymentTokenA.deploy("USDB", "USDB", 9);
    ptUSDC = await PaymentTokenA.deploy("USDC", "USDC", 12);
    ptUSDD = await PaymentTokenA.deploy("USDD", "USDD", 18);     
    exchange = await ExchangeContract.deploy(fontNFTTokens.address);

    console.log("FONT Token Deployed at ::", fontToken.address);
    console.log("Payment Token A Deployed at ::", ptUSDA.address);
    console.log("Payment Token A Deployed at ::", ptUSDB.address);
    console.log("Payment Token A Deployed at ::", ptUSDC.address);
    console.log("Payment Token A Deployed at ::", ptUSDD.address);

    console.log("FONT NFT Token Deployed at ::", fontNFTTokens.address);

    console.log("Exchange Contract Deployed at ::", exchange.address);

    console.log();console.log();console.log();console.log();

  });


  

  //check initial balance of both the tokens 
  describe("Minting NFT", async function () {


    it("Owner can mint NFT", async function () {
        await fontNFTTokens.connect(owner).mint(addr1.address, 1, 1, ZERO_BYTES32);
        await expect(await fontNFTTokens.connect(owner).balanceOf(addr1.address, 1)).to.equal(1);
    });

    it("Owner can mint NFT in Batch", async function () {
        await fontNFTTokens.connect(owner).mintBatch(addr2.address, gnfts, gamounts, ZERO_BYTES32);
        //await expect(await fontNFTTokens.connect(owner).balanceOf(addr2.address, 2)).to.equal(1);
        await expect(await fontNFTTokens.connect(owner).balanceOf(addr2.address, 3)).to.equal(1);
        await expect(await fontNFTTokens.connect(owner).balanceOf(addr2.address, 4)).to.equal(1);
        await expect(await fontNFTTokens.connect(owner).balanceOf(addr2.address, 5)).to.equal(1);
    });    
  });

  describe("Move NFT", async function () {

    it("Non Owner should not move tokens", async function () {
        await fontNFTTokens.connect(addr1).setApprovalForAll(exchange.address, true);
        await expect(exchange.connect(addr1).nftMoveInBulk(gnfts,gamounts)).to.be.reverted;
    });

    it("Move NFT into exchange", async function () {
        await fontNFTTokens.connect(addr2).setApprovalForAll(exchange.address, true);
        await expect(exchange.connect(addr2).nftMoveInBulk(gnfts,gamounts)).to.emit(exchange, 'NFTMovedInBulk');
    });    

    it("Non Ownershould not move the token into exchange", async function () {
        //await fontNFTTokens.connect(addr1).setApprovalForAll(exchange.address, true);
        await expect(exchange.connect(addr1).nftMoveOutBulk(gnfts)).to.be.reverted;
    });        

    it("Move NFT from exchange", async function () {
        //await fontNFTTokens.connect(addr1).setApprovalForAll(exchange.address, true);
        await expect(exchange.connect(addr2).nftMoveOutBulk(gnfts)).to.emit(exchange, 'NFTMovedOutBulk');
    });        

    it("Move NFT Again into exchange", async function () {
        await fontNFTTokens.connect(addr2).setApprovalForAll(exchange.address, true);
        await expect(exchange.connect(addr2).nftMoveInBulk(gnfts,gamounts)).to.emit(exchange, 'NFTMovedInBulk');
    });        

    it("Check balance of NFT", async function () {

        var exchangeAddress = Array.from({length:8}).map(x => exchange.address);

        var balances = (await fontNFTTokens.connect(addr2).balanceOfBatch(exchangeAddress, gnfts)).toString().split(",");

        await expect(balances.length).to.equal(gnfts.length);
    });        
  });

  describe("Admin  Stuffs", async function () {
    it("Set Token by Admin", async function () {
        await expect(exchange.connect(owner).adminEditPaymentToken(ptUSDA.address, true));
    });
  });

  describe("Spot Orders", async function () {

    //await fontNFTTokens.connect(owner).mint(addr1.address, 1, 1, ZERO_BYTES32);

    it("Create an Order", async function () {
        await expect(exchange.connect(addr2).orderCreate(2, 1000*Mn, 0,0, false, 100, ptUSDA.address)).to.emit(exchange, 'OrderCreated');
    });

    it("Should not create same Order again", async function () {
        await expect(exchange.connect(addr2).orderCreate(2, 1000*Mn, 0,0, false, 100, ptUSDA.address)).to.be.revertedWith("IO")
    });    

    it("Able to view an order", async function () {
        var anOrder = await exchange.connect(addr2).viewOrder(1);
        await expect(parseInt(anOrder.nft.toString())).to.equal(2);
    });    
        
    it("Owner can able to edit the order", async function () {
        await exchange.connect(addr2).orderEdit(1, 2000*Bn, 0, 0, 250, ptUSDB.address);
        var anOrder = await exchange.connect(addr2).viewOrder(1);
        await expect(parseInt(anOrder.nft.toString())).to.equal(2);
        await expect(parseInt(anOrder.price.toString())).to.equal(2000*Bn);
        await expect(parseInt(anOrder.referral.toString())).to.equal(250);
    });    
            

    it("Non owner shouldnt able to edit the order", async function () {
        await expect(exchange.connect(addr1).orderEdit(1, 2000*Bn, 0, 0, 250, ptUSDB.address)).to.be.revertedWith("D");
    });    
            
    it("Non Owner should not able to cancel the order", async function () {
        await expect(exchange.connect(addr1).orderCancel(1)).to.be.revertedWith("D");
        // time.advanceBlock();

    });    
                
    it("Owner should able to cancel the order", async function () {
        await exchange.connect(addr2).orderCancel(1)
        var anOrder = await exchange.connect(addr2).viewOrder(1);
        await expect(parseInt(anOrder.status.toString())).to.equal(3);
    });    
                
    it("Owner should not able to cancel the same order again ", async function () {
        await expect(exchange.connect(addr2).orderCancel(1)).to.be.revertedWith("NO");
    });    

    it("Owner should not able to edit the canceled order", async function () {
        await expect(exchange.connect(addr2).orderEdit(1, 2000*Bn, 0, 0, 250, ptUSDB.address)).to.be.revertedWith("NO");
        var anNFT = await exchange.viewNFT(2);
        //LogNFT(anNFT);

    });        

    it("Able to recreate the order of canceled NFT", async function () {
        await expect(exchange.connect(addr2).orderCreate(2, 1000*Mn, 0,0, false, 100, ptUSDA.address)).to.emit(exchange, 'OrderCreated').withArgs(2);
        var anNFT = await exchange.viewNFT(2);
        //LogNFT(anNFT);
    });            

    it("Able to buy the NFT by any user", async function () {

        await ptUSDA.transfer(addr3.address, "100000000000");
        await expect((await ptUSDA.connect(addr3).balanceOf(addr3.address)).toString()).to.equal("100000000000");
        const ptUSDABalance = await ptUSDA.balanceOf(addr3.address);
        await ptUSDA.connect(addr3).approve(exchange.address, ptUSDABalance);

            

        await expect(exchange.connect(addr3).orderBuy(2, ZERO_ADDRESS, false)).to.emit(exchange, 'OrderBought');
        var anNFT = await exchange.viewNFT(2);
        await expect(anNFT.owner).to.equal(addr3.address);
        await expect(anNFT.orderID.toString()).to.equal("0");

        
        var anOrder = await exchange.viewOrder(2);
        //LogOrder(anOrder);    
        
        await expect(anOrder.buyer).to.equal(addr3.address);
        await expect(anOrder.status).to.equal(2);

        //Check the nft balance

        await expect(exchange.connect(addr3).withdrawNFT(2)).to.emit(exchange, 'NFTWithdrawn');
        
        //check the buyer balance
        await expect((await fontNFTTokens.balanceOf(addr3.address, 2)).toString()).to.equal("1");

    });


    
    it("Able to create Order in bulk using orderCreateBulk", async function () {
        var _nfts = _.range(43,54);
        var _gamounts = Array.from({length:_nfts.length}).map(x => 1);
        var _prices = Array.from({length:_nfts.length}).map(x => 100*Mn);
        var _minPrices = Array.from({length:_nfts.length}).map(x => 23*Mn);
        var _expires = Array.from({length:_nfts.length}).map(x => 2);
        var _token = Array.from({length:_nfts.length}).map(x => ptUSDA.address);

        await fontNFTTokens.connect(owner).mintBatch(addr5.address, _nfts, _gamounts, ZERO_BYTES32);
        await fontNFTTokens.connect(addr5).setApprovalForAll(exchange.address, true);
        await expect(exchange.connect(addr5).nftMoveInBulk(_nfts,_gamounts)).to.emit(exchange, 'NFTMovedInBulk');
        await expect(exchange.connect(addr5).orderCreateBulk(_nfts, _prices, _minPrices, _expires, _gamounts, _expires, _token)).to.emit(exchange, 'OrderCreated');
    });    


  });

  describe("NFT Auctions", async function () {
   
    it("Able to create Auction Order", async function () {
        await fontNFTTokens.connect(addr3).setApprovalForAll(exchange.address, true);
        await expect(exchange.connect(addr3).nftMoveInBulk([2],[1])).to.emit(exchange, 'NFTMovedInBulk');
        await expect(exchange.connect(addr3).orderCreate(2, 45*Mn, 12*Mn,300, true, 100, ptUSDA.address)).to.emit(exchange, 'OrderCreated');

        var anNFT = await exchange.viewNFT(2);
        //LogNFT(anNFT);                

        var anOrder = await exchange.viewOrder(anNFT.orderID.toString());
        LogOrder(anOrder);        
        
        await expect(anOrder.status.toString()).to.equal("1");
        await expect(anOrder.auction).to.equal(true);
    });


    it("User wont able to bid below min price", async function () {
        await ptUSDA.transfer(addr1.address, 100*Mn);
        await ptUSDA.connect(addr1).approve(exchange.address, 100*Mn*Mn);
        await expect(exchange.connect(addr3).orderBid(14, 12*Mn, ZERO_ADDRESS)).to.be.revertedWith("M");
    });

    it("User able to bid above min price", async function () {
        await expect(exchange.connect(addr3).orderBid(14, (12*Mn + 1), ZERO_ADDRESS)).to.emit(exchange, 'BidOrder');

        var anNFT = await exchange.viewNFT(2);
        //LogNFT(anNFT);                
        var anOrder = await exchange.viewOrder(anNFT.orderID.toString());
        //LogOrder(anOrder); 
    });    

    it("User able to topup above the current bid price", async function () {
        await expect(exchange.connect(addr3).orderBidTopup( 1, 1000)).to.emit(exchange, 'BidTopuped');
    });    

    it("User should not able to bid below the highest offer", async function () {
        await ptUSDA.transfer(addr4.address, 100*Mn);
        await ptUSDA.connect(addr4).approve(exchange.address, 100*Mn*Mn);
        await expect(exchange.connect(addr4).orderBid(14, (12*Mn)+100, ZERO_ADDRESS)).to.be.revertedWith("NE");
        var anOrder = await exchange.viewOrder(14); 
        //LogOrder(anOrder); 

        var aBid = await exchange.viewBid(1); 
        //LogBid(aBid);

    });

    it("User should able to bid above the highest offer", async function () {
        await expect(exchange.connect(addr4).orderBid(14, (12*Mn)+100000, ZERO_ADDRESS)).to.emit(exchange, "BidOrder");
        var aBid = await exchange.viewBid(2); 
        //LogBid(aBid);        
        var anOrder = await exchange.viewOrder(14); 
        //LogOrder(anOrder); 
    });

    it("User should not able to cancel other's bid", async function () {
        await expect(exchange.connect(addr2).orderBidCancel(2)).to.be.revertedWith("D");
        var aBid = await exchange.viewBid(2); 
        //LogBid(aBid);        
        var anOrder = await exchange.viewOrder(14); 
        //LogOrder(anOrder); 
    });

    it("User should able to cancel his own bid", async function () {
        await expect(exchange.connect(addr4).orderBidCancel(2)).to.emit(exchange, "BidCanceled");
        var aBid = await exchange.viewBid(2); 
        //LogBid(aBid);        
        var anOrder = await exchange.viewOrder(14); 
        //LogOrder(anOrder); 
    });


    it("User should not able to cancel bid that already cancled", async function () {
        await expect(exchange.connect(addr4).orderBidCancel(2)).to.be.revertedWith("BN");
        var aBid = await exchange.viewBid(2); 
        //LogBid(aBid);        
        var anOrder = await exchange.viewOrder(14); 
        //LogOrder(anOrder); 
    });


  });

  describe("Move and create Order", async function () {

    it("Move and create order in single txn", async function () {
        var NFTID = 60;
        await fontNFTTokens.connect(owner).mint(addr3.address, NFTID, 1, ZERO_BYTES32);
        await fontNFTTokens.connect(addr3).setApprovalForAll(exchange.address, true);

        var price = 100*Mn;
        var minPrice = 23*Mn;
        var expires = 2;
        var auction = false;
        var referral = 350;
        var royality = 550;

        await expect(exchange.connect(addr3).moveCreateOrder(NFTID, price, minPrice, expires, auction, referral, royality, ptUSDA.address)).to.emit(exchange, 'MovedNFTCreatedOrder');        
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
    console.log("Creator :: ", nft.creatror);    
    console.log("Owner :: ", nft.owner);    
    console.log();console.log();console.log();
}

function LogBid(_Bid) {


    console.log("BID ID :: ", _Bid.orderID.toString());
    console.log("offer :: ", _Bid.offer.toString());    
    console.log("bidder :: ", _Bid.bidder);    
    console.log("status :: ", _Bid.status);    
    console.log();console.log();console.log();
}

function LogOrder(structr) {
    console.log("NFT :: ", structr.nft.toString());
    //console.log("Qty :: ", structr.qty.toString());
    console.log("Price :: ", structr.price.toString());
    console.log("minPrice :: ", structr.minPrice.toString());
    console.log("HighestBidID :: ", structr.highestBidID.toString());
    console.log("Expires :: ", structr.expires.toString());
    console.log("Status :: ", structr.status);
    console.log("Auction? :: ", structr.auction);
    console.log("Referral :: ", structr.referral);
    console.log("Token :: ", structr.token);
    console.log("Seller :: ", structr.seller);
    console.log("Buyer :: ", structr.buyer);
    console.log();console.log();console.log();
    
}