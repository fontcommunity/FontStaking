const { expect } = require("chai");
const { BN, expectEvent, expectRevert, time, block } = require('@openzeppelin/test-helpers');

const _ = require("underscore");

describe("NFT Minter", function() {



  let ptUSDA;

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
  let fontNFTMinter;

  let gnfts = _.range(2,10);
  let gamounts = Array.from({length:8}).map(x => 1);
  let groyalities = Array.from({length:8}).map(x => 1);



  const ZERO_BYTES32 = 0x0000000000000000000000000000000000000000000000000000000000000000;
  const ZERO_ADDRESS = '0x0000000000000000000000000000000000000000';


  const delay = ms => new Promise(res => setTimeout(res, ms));

  let MINTER_ROLE;

  //Deploy the token 
  before(async function () {

    

    [owner, addr1, addr2, addr3, addr4, addr5, addr6, addr7, addr8, ...addrs] = await ethers.getSigners(25);


    //Get all the contracts 
    MockFontNFT = await ethers.getContractFactory("MockFontNFT");
    PaymentTokenA = await ethers.getContractFactory("MockToken"); 
    FontNFTMinter = await ethers.getContractFactory("FontNFTMinter");

    //Deploy all the contracts 
    fontNFTTokens = await MockFontNFT.deploy();
    ptUSDA = await PaymentTokenA.deploy("USDA", "USDA", 6);
    fontNFTMinter = await FontNFTMinter.deploy(fontNFTTokens.address);

    console.log("Payment Token A Deployed at ::", ptUSDA.address);
    console.log("FONT NFT Token Deployed at ::", fontNFTTokens.address);
    console.log("fontNFTMinter Contract Deployed at ::", fontNFTMinter.address);

    console.log();console.log();console.log();console.log();

  });


  

  //check initial balance of both the tokens 
  describe("Map NFT", async function () {

    it("Owner can add minter address to Font Minter", async function () {
        MINTER_ROLE = await fontNFTTokens.MINTER_ROLE();
        await expect(await fontNFTTokens.connect(owner).grantRole(MINTER_ROLE, fontNFTMinter.address)).to.emit(fontNFTTokens, "RoleGranted");
        await expect(await fontNFTTokens.connect(owner).getRoleMember(MINTER_ROLE, 1)).to.equal(fontNFTMinter.address);
    });

    it("Admin can Create Map", async function () {
        await expect(await fontNFTMinter.connect(owner).mapNFT(1, addr1.address, false, 1)).to.emit(fontNFTMinter, 'Mapped');
        var NFTMap = await fontNFTMinter.viewNFT(1);
        //LogNFTMap(NFTMap);
        //await fontNFTTokens.connect(owner).mint(addr1.address, 1, 1, ZERO_BYTES32);
        //await expect(await fontNFTTokens.connect(owner).balanceOf(addr1.address, 1)).to.equal(1);
    });

    it("Non owner should not able to mint an NFT via minter", async function () {
        await expect(fontNFTMinter.connect(addr2).mintNFT(1)).to.be.revertedWith('Denied');
    });       
    
    it("Non Admin should not able to pause", async function () {
        await expect(fontNFTMinter.connect(addr1).pause()).to.be.revertedWith('Denied');
    });    

    it("Admin should able to pause", async function () {
        await expect(fontNFTMinter.connect(owner).pause()).to.emit(fontNFTMinter, 'Pause');
    });    

    it("Can't mint while pause", async function () {
        await expect(fontNFTMinter.connect(addr1).mintNFT(1)).to.be.revertedWith('Paused');
    });        

    it("Non Admin should not able to Unpause", async function () {
        await expect(fontNFTMinter.connect(addr1).unpause()).to.be.revertedWith('Denied');
    });    

    it("Admin should able to unpause", async function () {
        await expect(fontNFTMinter.connect(owner).unpause()).to.emit(fontNFTMinter, 'Pause');
    });        




    it("Minter can mint an NFT", async function () {
        await expect(await fontNFTMinter.connect(addr1).mintNFT(1)).to.emit(fontNFTMinter, 'NFTMinted');
        var NFTMap = await fontNFTMinter.viewNFT(1);
        //LogNFTMap(NFTMap);        
        var asdasd = await fontNFTTokens.balanceOf(addr1.address, 1);
    });    

    it("Should not able to Mint again", async function () {
        await expect(fontNFTMinter.connect(addr2).mintNFT(1)).to.be.revertedWith('Already Minted');
    });

  });
  
  describe("Admin Settings", async function () {

    it("Editing a MAP", async function () {
        var MAP = [addr2.address,false, 1];
        var NFTMap = await fontNFTMinter.viewNFT(1);

        await expect(fontNFTMinter.connect(owner).editNFT(1, MAP)).to.emit(fontNFTMinter, 'MapEdited');
        NFTMap = await fontNFTMinter.viewNFT(1);

        await expect(NFTMap.creator).to.equal(addr2.address);
        await expect(NFTMap.status).to.equal(false);

    });

    
    it("Non Admin should not able edit MAP", async function () {
        var MAP = [addr3.address,false,2];
        await expect(fontNFTMinter.connect(addr3).editNFT(1, MAP)).to.be.revertedWith('Denied');
    });

    it("Admin able to bulk map multiple NFTs", async function () {
        var BulkMap = [
            [addr2.address,false,1],
            [addr3.address,false,1],
            [addr4.address,false,1],
            [addr5.address,false,1],
            [addr6.address,false,1],
            [addr7.address,false,1],
            [addr8.address,false,1],
        ];
        var Creators = [addr2.address, addr3.address, addr4.address, addr5.address, addr6.address, addr7.address, addr8.address];
        var ChainIDs = [1,1,1,1,1,1,2];
        var NFTIDs = [2,3,4,5,6,7,8];
        var NFTIDs100 = _.range(9,110);
        var Status = [false,false,false,false,false,false,false];
        var Qtys = [1,1,1,1,1,1,2];

        //await expect(await fontNFTMinter.connect(owner).mapNFTBulk(NFTIDs, Creators, Status, Qtys)).to.emit(fontNFTMinter, 'MappedBulk');

        //await expect(await fontNFTMinter.connect(owner).mapNFTBulk2(NFTIDs, Creators, Status, Qtys)).to.emit(fontNFTMinter, 'MappedBulk');

        
        NFTMap = await fontNFTMinter.viewNFT(1);

        await expect(await fontNFTMinter.connect(owner).mapNFTBulkPerUser(NFTIDs100, addr8.address)).to.emit(fontNFTMinter, 'MappedBulkPerUser');

        

        //await expect(await fontNFTMinter.connect(owner).mapNFTBulkStruct(NFTIDs, BulkMap)).to.emit(fontNFTMinter, 'MappedBulk');


    });

    it("Able to mint bulk NFT from Minter", async function () {
        var NFTIDs100 = _.range(9,110);
        await expect(await fontNFTMinter.connect(addr8).mintNFTBulk(NFTIDs100)).to.emit(fontNFTMinter, "NFTMintedBulk");


    });
    
  });
  /*
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
        await expect(exchange.connect(addr3).orderBidTopup(14, 1, 1000)).to.emit(exchange, 'BidTopuped');
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
  */
});

function LogNFTMap(_a) {
    console.log("Creator :: ", _a.creator);
    console.log("Chain ID :: ", _a.chainID.toString());    
    console.log("Status :: ", _a.status);    
    console.log("Qty :: ", _a.qty.toString());    
    console.log();console.log();console.log();    
}

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