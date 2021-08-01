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
        await expect(await fontNFTMinter.connect(owner).mapNFT(1, 1, false, 1)).to.emit(fontNFTMinter, 'Mapped');
        var NFTMap = await fontNFTMinter.viewNFT(1);
        //LogNFTMap(NFTMap);
        //await fontNFTTokens.connect(owner).mint(addr1.address, 1, 1, ZERO_BYTES32);
        //await expect(await fontNFTTokens.connect(owner).balanceOf(addr1.address, 1)).to.equal(1);
    });

    it("Admin able to create an user", async function () {
        await expect(fontNFTMinter.connect(owner).mapAddUser(addr1.address, 1)).to.emit(fontNFTMinter, 'UserAdded');
    });

    it("Admin should not able to create same user", async function () {
        await expect(fontNFTMinter.connect(owner).mapAddUser(addr1.address, 1)).to.be.revertedWith('Exist');
    });

    it("Non Admin should not able to create user", async function () {
        await expect(fontNFTMinter.connect(addr1).mapAddUser(addr1.address, 1)).to.be.revertedWith('Denied');
    });

    it("Admin able to create an user in bulk", async function () {

        var Users  = [
            addr2.address, addr3.address, addr4.address, addr5.address,
            addr6.address, addr7.address, addr8.address
        ];

        var IDS = [2,3,4,5,6,7,8];

        await expect(fontNFTMinter.connect(owner).mapAddUserBulk(Users, IDS)).to.emit(fontNFTMinter, 'UserAddedBulk');
    });

    it("Admin able to edit an user", async function () {
        var User = await fontNFTMinter.viewUser(1);
        await expect(fontNFTMinter.connect(owner).mapEditUser(addr2.address, 1)).to.emit(fontNFTMinter, 'UserEdited');
        User = await fontNFTMinter.viewUser(1);
        await expect(User).to.equal(addr2.address);
        await expect(fontNFTMinter.connect(owner).mapEditUser(addr1.address, 1)).to.emit(fontNFTMinter, 'UserEdited');


    });

    it("Non owner should not able to mint an NFT via minter", async function () {
        await expect(fontNFTMinter.connect(addr3).mintNFT(1)).to.be.revertedWith('Denied');
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
        await expect(fontNFTMinter.connect(addr2).mintNFT(1)).to.be.revertedWith('Already');
    });

  });
  
  describe("Admin Settings", async function () {

    it("Editing a MAP", async function () {
        var MAP = [false, 2,2];
        var NFTMap = await fontNFTMinter.viewNFT(1);

        await expect(fontNFTMinter.connect(owner).editNFT(1, MAP)).to.emit(fontNFTMinter, 'MapEdited');
        NFTMap = await fontNFTMinter.viewNFT(1);

        await expect(NFTMap.creator).to.equal(2);
        await expect(NFTMap.status).to.equal(false);

    });

    
    it("Non Admin should not able edit MAP", async function () {
        var MAP = [false, 2,2];
        await expect(fontNFTMinter.connect(addr3).editNFT(1, MAP)).to.be.revertedWith('Denied');
    });

    it("Admin able to bulk map multiple NFTs", async function () {
        var BulkMap = [
            [false,2,1],
            [false,3,1],
            [false,4,1],
            [false,5,1],
            [false,6,1],
            [false,7,1],
            [false,8,1],
        ];
        var Creators = [2,3,4,5,6,7,8];
        var ChainIDs = [1,1,1,1,1,1,2];
        var NFTIDs = [2,3,4,5,6,7,8];
        var NFTIDs100 = _.range(9,21);
        var Status = [false,false,false,false,false,false,false];
        var Qtys = [1,1,1,1,1,1,2];

        await expect(await fontNFTMinter.connect(owner).mapNFTBulkPerUser(NFTIDs100, 2)).to.emit(fontNFTMinter, 'MappedBulkPerUser');

    });

    it("Should not Able to mint bulk NFT from Minter by non owner", async function () {
        var NFTIDs100 = _.range(9,21);
        await expect(fontNFTMinter.connect(addr3).mintNFTBulk(NFTIDs100)).to.be.revertedWith("Denied");
    });    

    it("Able to mint bulk NFT from Minter", async function () {
        var NFTIDs100 = _.range(9,21);
        await expect(await fontNFTMinter.connect(addr2).mintNFTBulk(NFTIDs100)).to.emit(fontNFTMinter, "NFTMintedBulk");
    });
    
  });
  
});

function LogNFTMap(_a) {
    console.log("Creator :: ", _a.creator);
    console.log("Status :: ", _a.status);    
    console.log("Qty :: ", _a.qty.toString());    
    console.log();console.log();console.log();    
}

