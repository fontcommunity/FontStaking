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
    fundraising = await FundraisingContract.deploy();

    console.log("FONT Token Deployed at ::", fontToken.address);
    console.log("Payment Token A Deployed at ::", ptUSDA.address);
    console.log("Payment Token A Deployed at ::", ptUSDB.address);
    console.log("Payment Token A Deployed at ::", ptUSDC.address);
    console.log("Payment Token A Deployed at ::", ptUSDD.address);

    console.log("FONT NFT Token Deployed at ::", fontNFTTokens.address);

    console.log("Fundraising Contract Deployed at ::", fundraising.address);

    console.log();console.log();console.log();console.log();

  });


  

  //check initial balance of both the tokens 
  describe("Project", async function () {


    it("Create A Project", async function () {

        var Milestones = [
            [10,20,0],
            [20,20,0],
            [30,20,0],
            [40,20,0],
            [50,20,0]
        ];
        /*
        struct Project {
            uint256 softcap;
            uint256 hardcap;
            uint256 raised; //Amount raised so for 
            uint256 released; //Amount released so for
            uint256 dateStart;
            uint256 duration;
            uint256 maxContrib;
            uint256 nftID; //ID of the NFT s
            uint16 milestone; // % of release per month 1% = 100, max 10000
            uint8 status; //0 = draft, 1 = started and in progress, 2 = filled, 3 = closed...
            address payment; // any erc20 token 
            address owner;
            bool disinvesment; 
            
        }
    
*/
        var Project = [
            1000*Mn,
            2000*Mn,
            0,
            0,
            0,
            604800,
            10*Mn, 
            1,
            10000,
            0,
            addr1.address,
            addr1.address,
            true,

        ];
        await expect(await fundraising.connect(addr1).projectCreate(Project, "b45165ed3cd437b9ffad02a2aad22a4ddc69162470e2622982889ce5826f6e3d")).to.emit(fundraising, "ProjectCreated");

        //await expect(await fundraising.connect(addr1).projectCreate2(1000*Mn, 2000*Mn, 604800, 0, 10*Mn, 1, ptUSDA.address, true, 1000,"b45165ed3cd437b9ffad02a2aad22a4ddc69162470e2622982889ce5826f6e3d")).to.emit(fundraising, "ProjectCreated");
    });

    it("View Project 2", async function () {
        var Project1 = await fundraising.connect(addr1).viewProject(1);
        //var Project2 = await fundraising.connect(addr1).viewProject(2);
        console.log(Project1, Project1.dateStart.toString());
    });    
  });


});

function LogProject(project) {
    //console.log("Qty :: ", nft.qty.toString());
    console.log("Order ID :: ", nft.orderID.toString());
    console.log("Royality :: ", nft.royality);    
    console.log("Status :: ", nft.status);    
    console.log("Creator :: ", nft.creatror);    
    console.log("Owner :: ", nft.owner);    
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