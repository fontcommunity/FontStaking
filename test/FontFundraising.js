const { expect } = require("chai");
const { BN, expectEvent, expectRevert, time, block } = require('@openzeppelin/test-helpers');

const _ = require("underscore");

describe("Font Fundraising", function() {


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
  const BnBn0 = "000000000000000000";

  let fontNFTTokens;
  let fundraising;

  let gnfts = _.range(2,10);
  let gamounts = Array.from({length:8}).map(x => 1);
  let groyalities = Array.from({length:8}).map(x => 1);



  const ZERO_BYTES32 = 0x0000000000000000000000000000000000000000000000000000000000000000;
  const ZERO_ADDRESS = '0x0000000000000000000000000000000000000000';


  const delay = ms => new Promise(res => setTimeout(res, ms));

  let ProjectData;
  let UTCTimestamp;

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
    FundraisingContract = await ethers.getContractFactory("FontFundraising");

    //Deploy all the contracts 
    fontNFTTokens = await FontNFTTokens.deploy();
    fontToken = await FontToken.deploy("font", "FONT", 18);
    ptUSDA = await PaymentTokenA.deploy("USDA", "USDA", 6);
    ptUSDB = await PaymentTokenA.deploy("USDB", "USDB", 9);
    ptUSDC = await PaymentTokenA.deploy("USDC", "USDC", 12);
    ptUSDD = await PaymentTokenA.deploy("USDD", "USDD", 18);     
    fundraising = await FundraisingContract.deploy(fontToken.address);

    console.log("FONT Token Deployed at ::", fontToken.address);
    console.log("Payment Token A Deployed at ::", ptUSDA.address);
    console.log("Payment Token A Deployed at ::", ptUSDB.address);
    console.log("Payment Token A Deployed at ::", ptUSDC.address);
    console.log("Payment Token A Deployed at ::", ptUSDD.address);

    console.log("FONT NFT Token Deployed at ::", fontNFTTokens.address);

    console.log("Fundraising Contract Deployed at ::", fundraising.address);

    console.log();console.log();console.log();console.log();

    UTCTimestamp = Math.floor((new Date()).getTime() / 1000);
    ProjectData = [
        1000*Mn, //sc
        2000*Mn, //hc
        0, //raised
        0, //released
        0,//lastReleased date
        UTCTimestamp + 100000, //datestart
        604800, //duration
        10*Mn, //max
        1*Mn, //min
        1,
        10000,
        0,
        ptUSDA.address,
        addr1.address,
        true,
        'b45165ed3cd437b9ffad02a2aad22a4ddc69162470e2622982889ce5826f6e3d'
    ];    


  });


  

  //check initial balance of both the tokens 
  describe("Project", async function () {


    it("Create A Project", async function () {
        await expect(await fundraising.connect(addr1).projectCreate(ProjectData)).to.emit(fundraising, "ProjectCreated");
        var Project_ = await fundraising.connect(addr1).viewProject(1);
        //LogProject(Project_);
    });

    it("Edit A Project", async function () {
        var ProjectDataEdited = ProjectData;
        ProjectDataEdited[14] = "c45165ed3cd437b9ffad02a2aad22a4ddc69162470e2622982889ce5826f6e3d";
        await expect(await fundraising.connect(addr1).projectEdit(1, ProjectDataEdited)).to.emit(fundraising, "ProjectEdited");
        var Project_ = await fundraising.connect(addr1).viewProject(1);
        //LogProject(Project_);        
    });


    it("Start A Project", async function () {
        await fontToken.connect(owner).transfer(addr1.address, 1000000);
        const fontBalance = await fontToken.balanceOf(addr1.address);
        await fontToken.connect(addr1).approve(fundraising.address, fontBalance);

        await expect(await fundraising.connect(addr1).projectStart(1, UTCTimestamp + 20000, 123)).to.emit(fundraising, "ProjectStarted");

        var Boost = await fundraising.connect(addr1).viewProjectBoost(1);
    });

    it("Anyone able to boost the project", async function () {
        var Boost = await fundraising.connect(addr1).viewProjectBoost(1);   
        //console.log("Before :: ", Boost.toString());
        await fontToken.connect(owner).transfer(addr2.address, 1000000);
        const fontBalance = await fontToken.balanceOf(addr2.address);
        await fontToken.connect(addr2).approve(fundraising.address, fontBalance);
        await expect(await fundraising.connect(addr1).projectBoost(1, 1232)).to.emit(fundraising, "ProjectBoosted");

        Boost = await fundraising.connect(addr1).viewProjectBoost(1);   
        //console.log("After :: ", Boost.toString());

    });

    it("Others should not able to cancel the project", async function () {
        await expect(fundraising.connect(addr2).projectCancel(1)).to.be.revertedWith('D');//.be.reverted;//With("D");
    });   

    it("Owner or Admin should able to cancel the project", async function () {
        //await expect(fundraising.connect(addr1).projectCancel(1)).to.emit(fundraising, 'ProjectCanceled');
    });

    it("Admin should able to cancel the project", async function () {
        //await expect(fundraising.connect(owner).projectCancel(1)).to.emit(fundraising, 'ProjectCanceled');
    });    
  });

  describe("Invest", async function () {
    
    it("Should not able to invest more than MAX amount", async function () {
        await ptUSDA.connect(owner).transfer(addr2.address, 1000000*Mn);
        const USDABalance = await ptUSDA.balanceOf(addr2.address);
        await ptUSDA.connect(addr2).approve(fundraising.address, USDABalance);
        await expect(fundraising.connect(addr2).invest(1, 100*Mn)).to.be.revertedWith("Max");//(fundraising, "ProjectBoosted");
    });

    it("Should not able to invest less than MIN amount", async function () {
        await expect(fundraising.connect(addr2).invest(1, 1)).to.be.revertedWith("Min");//(fundraising, "ProjectBoosted");
    });    

    it("Should able to invest", async function () {
        await expect(fundraising.connect(addr2).invest(1, 2*Mn)).to.emit(fundraising, "Invested");//(fundraising, "ProjectBoosted");
    });      
    
  });

});

function LogProject(project) {
    //console.log("Qty :: ", nft.qty.toString());
    console.log("Softcap :: ", project.softcap.toString());
    console.log("hardcap :: ", project.hardcap.toString());
    console.log("raised :: ", project.raised.toString());
    console.log("released :: ", project.released.toString());
    console.log("dateStart :: ", project.dateStart.toString());
    console.log("lastReleased :: ", project.lastReleased.toString());
    
    console.log("duration :: ", project.duration.toString());
    console.log("maxContrib :: ", project.maxContrib.toString());
    console.log("minContrib :: ", project.minContrib.toString());
    console.log("nftID :: ", project.nftID.toString());

    console.log("milestone :: ", project.milestone);
    console.log("status :: ", project.status);
    console.log("payment :: ", project.payment);
    console.log("owner :: ", project.owner);
    console.log("disinvesment :: ", project.disinvesment);
    console.log("IPFS :: ", project.ipfs);
    
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

        /*
        struct Project {
        uint256 softcap;
        uint256 hardcap;
        uint256 raised; //Amount raised so for 
        uint256 released; //Amount released so for
        uint256 dateStart; //Date is absloute date
        uint256 duration;
        uint256 maxContrib;
        uint256 minContrib; //min contribution
        uint256 nftID; //ID of the NFT s
        uint16 milestone; // % of release per month 1% = 100, max 10000
        uint8 status; //0 = draft, 1 = started and in progress, 2 = filled, 3 = closed...
        address payment; // any erc20 token 
        address owner;
        bool disinvesment; 
            
        }
        */
