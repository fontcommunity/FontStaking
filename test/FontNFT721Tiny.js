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



  //Deploy the token 
  before(async function () {

    provider = ethers.provider;


    [owner, addr1, addr2, addr3, addr4, addr5, addr6, addr7, addr8, ...addrs] = await ethers.getSigners(25);


    //Get all the contracts 
    FontNFT721 = await ethers.getContractFactory("FontNFT721Tiny");
    FontToken = await ethers.getContractFactory("MockToken");
    PaymentTokenA = await ethers.getContractFactory("MockToken"); 
    PaymentTokenB = await ethers.getContractFactory("MockToken");

    //Deploy all the contracts 
    fontToken = await FontToken.deploy("font", "FONT", 18);
    ptUSDA = await PaymentTokenA.deploy("USDA", "USDA", 6);
    ptUSDB = await PaymentTokenA.deploy("USDB", "USDB", 9);
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
        //await expect(exchange.connect(addr3).orderCancel(3)).to.emit(exchange, 'OrderCanceled');
    });            

    it("Owner should able to create a Spot order with ETH", async function () {
        await expect(exchange.connect(addr3).safeMintAndList(6, "100" + dec18zerosStr, 0, 400, 400, ZERO_ADDRESS, false)).to.emit(exchange, 'OrderCreated');
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
        //LogOrder(anOrder);

        addr1balance_1 = await provider.getBalance(addr1.address);
        console.log("Balance of Addr1", parseInt(addr1balance.div(10**15).toString())/1000, parseInt(addr1balance_1.div(10**15).toString()) / 1000); // 0

        exchangebalance_1 = await provider.getBalance(exchange.address);
        console.log("Balance of exchange", exchangebalance.div(10**15).toString(), parseInt(exchangebalance_1.div(10**15).toString()) / 1000); // 0
        
        addr3balance_1 = await provider.getBalance(addr3.address);
        console.log("Balance of addr3", parseInt(addr3balance.div(10**15).toString())/1000, parseInt(addr3balance_1.div(10**15).toString()) / 1000); // 0

        addr4balance_4 = await provider.getBalance(addr4.address);
        ETHReferralCommission = await exchange.connect(addr3).viewEarnings(addr4.address, ZERO_ADDRESS);

        console.log("Balance of referral", parseInt(addr4balance.div(10**15).toString())/1000, parseInt(ETHReferralCommission.div(10**15).toString())/1000); // 0

        

    });          
    
    


    //let send = web3.eth.sendTransaction({from:eth.coinbase,to:contract_address, value:web3.toWei(0.05, "ether")});

    


  });

 
  describe("Auction Orders", async function () {

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
    console.log("Status :: ", structr.status);
    console.log("Auction? :: ", structr.auction);
    console.log("Referral :: ", structr.referral);
    console.log("Token :: ", structr.token);
    console.log("Seller :: ", structr.seller);
    console.log("Buyer :: ", structr.buyer);
    console.log();console.log();console.log();
    
}