// SPDX-License-Identifier: MIT
// Author: https://twitter.com/adalquardz

pragma solidity ^0.8.0;


import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";


contract OwnershipExchange is Context, AccessControl {

    using SafeMath for uint;
    using SafeMath for uint256;
    using SafeERC20 for IERC20;
    using Counters for Counters.Counter;


    //Constants
    bytes4 _onERC721Received;
    bytes4 _onERC1155Received;
    bytes4 _onERC1155BatchReceived;

    address public rewardDistributionAddress;
    address public ownerAddress;

    //Settings 
    uint256 _exchangeFees; //1% = 100
    IERC1155 FontNFT = IERC1155(0x15790FD4AeEd8B28a02f72787C77B1Be43a196F5);


    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");


    uint16 maxRoyalityAllowed = 5000; //1% = 100

    //ERC20 token address for payments
    mapping (address => bool) public PaymentTokenContracts; 

    uint256 public OrderID; //Current order ID. Counter

    struct NFT {
        uint256 nftid; //NFT ID 
        uint256 orderID; //Current Order ID
        uint16 royality; //Royality %. 1% = 100
        uint8 status;//check if the NFT is under contract custudy: 0 not exists, 1 under custody, 2 went out of contract
        address creatror; // Royality receiver or initial owner in this excange, no need to be original creator of this nft
        address owner; //current owner         
    }

    struct Order {
        uint256 id; //Order id //@todo should we need it 
        uint256 nft; //NFT ID [f]
        uint256 qty; // quantity of this font nft (for now just 1) //@todo should we beed this [f]
        uint256 price; //price for whole NFT, of acceptable price if its auction [f]
        uint256 minPrice; //Min price the bidding starts with [f]
        uint256 highestBidID; //Highest bid id. 
        uint256 expires; //auction expires. 0 means non auction 
        uint8 status; //Order status : 1/open, 2/filled, 3/cancelled
        uint8 orderType; //Order type : 1/normal, 2/auction
        uint16 referral; //Affiliate commission percentage

        //For auction specific 
        address token; //ERC20 Token for payment     
        address seller; //current owner of this nft         
        address buyer; //new owner who bought this 
    }    

    struct Bids {
        uint256 id;
        uint256 orderID;
        uint256 price;
        address bidder;
        uint8 status;
    }

    struct PaymentToken { 
        uint16 commission; //1% = 100
        uint8 status; //1 = open, 2 is paused
    }
    mapping (address => PaymentToken) public paymentTokens;
        
    mapping (address => mapping(address => uint256)) public ReferralFees;
    mapping (address => mapping(address => uint256)) public ReferralFeesTotal;
    mapping (address => uint256) public commissionFees;
    mapping (address => uint256) public commissionFeesTotal;

    mapping (uint256 => Order) private OrderBook;
    mapping (uint256 => uint256) private orderID_NFT;

    mapping (uint256 => NFT) private NFTs;

    Counters.Counter private orderID;
    Counters.Counter private bidID;


    //Constructors
    constructor() {

        //contract_owner = payable(_msgSender());
        //commission_address = payable(_msgSender());



        //Mandatory for contracts to return these strings to receive ERC1155 and ERC721
        _onERC721Received = bytes4(keccak256("onERC721Received(address,uint256,bytes)"));
        _onERC1155Received = bytes4(keccak256("onERC1155Received(address,address,uint256,uint256,bytes)"));
        _onERC1155BatchReceived = bytes4(keccak256("onERC1155BatchReceived(address,address,uint256[],uint256[],bytes)"));

        _setupRole(ADMIN_ROLE, msg.sender); // Assign admin role to contract creator

        ownerAddress = msg.sender;

    }    

    /*************************************************************************/
    /******************************** Move NFT *******************************/
    /*************************************************************************/    

    event NFTMovedIn(uint256, uint16);
    function nftMoveIn(uint256 nft, uint16 royality) external {
        require(NFTs[nft].status != 1, 'Already');
        require(royality < maxRoyalityAllowed, 'High');
        

        NFTs[nft].status = 1;
        NFTs[nft].owner = msg.sender;
        NFTs[nft].orderID = 0;


        //If moving for first time
        if(NFTs[nft].status == 0) {
            NFTs[nft].creatror = msg.sender;
            NFTs[nft].royality = royality;
        }
        
        FontNFT.safeTransferFrom(msg.sender, address(this), nft, 1, '');
        emit NFTMovedIn(nft, royality);
    }

    event NFTMovedInBulk(uint256 items);
    function nftMoveInBulk(uint256[] calldata nfts, uint16[] calldata royalities) external {
        require(nfts.length == royalities.length, "Unequal");
        
        uint256 _length = nfts.length;

        uint256[] memory amounts = new uint256[](_length);

        for(uint256 i = 0; i < nfts.length; i++) {
            require(NFTs[nfts[i]].status != 1, 'Already');

            amounts[i] = 1; //.push(1);
            
            NFTs[nfts[i]].status = 1;
            NFTs[nfts[i]].owner = msg.sender;
            NFTs[nfts[i]].orderID = 0;

            //If moving for first time
            if(NFTs[nfts[i]].status == 0) {
                NFTs[nfts[i]].creatror = msg.sender;
                NFTs[nfts[i]].royality = royalities[i];
            }            
        }

        FontNFT.safeBatchTransferFrom(msg.sender, address(this), nfts, amounts, '');
        
        NFTMovedInBulk(nfts.length);
    }

    event NFTMovedOut(uint256);
    function nftMoveOut(uint256 nft) external {
        require(NFTs[nft].owner == msg.sender, 'Not Owner');
        require(NFTs[nft].status == 1, 'Not under custody');
        require(NFTs[nft].orderID == 0, 'Cancel Order');

        NFTs[nft].status = 2;

        FontNFT.safeTransferFrom(address(this), msg.sender, nft, 1, '');
        emit NFTMovedOut(nft);
    }

    event NFTMovedOutBulk(uint256);
    function nftMoveOutBulk(uint256[] calldata nfts) external {

        uint256 _length = nfts.length;

        uint256[] memory amounts = new uint256[](_length);

        for(uint256 i = 0; i < _length; i++) {
            require(NFTs[nfts[i]].owner == msg.sender, 'Not Owner');
            require(NFTs[nfts[i]].status == 1, 'Not under custody');
            require(NFTs[nfts[i]].orderID == 0, 'Cancel Order');

            amounts[i] = 1; //.push(1);

            NFTs[nfts[i]].status = 2;
        }

        FontNFT.safeBatchTransferFrom(address(this), msg.sender, nfts, amounts, '');
        NFTMovedOutBulk(nfts.length);
    }

    event RoyalityUpdated(uint256 nft, uint16 royality);
    function nftUpdateRoyality(uint256 nft, uint16 royality) external {
        require(NFTs[nft].status == 1, 'Not under custody');
        require(NFTs[nft].owner == msg.sender, 'Not Owner');
        require(NFTs[nft].creatror == msg.sender, 'Not Creator');
        require(royality < maxRoyalityAllowed, 'High');
        
        NFTs[nft].royality = royality;
        emit RoyalityUpdated(nft, royality);
    }

    /*************************************************************************/
    /******************************** exchange *******************************/
    /*************************************************************************/

    function orderCreate(uint256 nft, uint256 price, uint256 minPrice, uint256 expires, uint8 orderType, uint16 referral, address token) external {
        //check all the requires
        require(NFTs[nft].status == 1, 'Not under custody');
        require(NFTs[nft].owner == msg.sender, 'Not Owner');
        require(NFTs[nft].orderID == 0, 'In Order');
        require(paymentTokens[token].status == 1, 'Token');
        require(referral < 9999, 'Referral');
        
        uint256 _order_id = OrderID.add(1);

        // Auction
        if(orderType == 2) {
            require(expires > block.timestamp, 'Expiry Date');
            require(minPrice < price, 'Minprice >= price');
        }

        //Common settings for both the types 
        OrderBook[_order_id].nft = nft;
        OrderBook[_order_id].orderType = orderType;
        OrderBook[_order_id].referral = referral;
        OrderBook[_order_id].status = 1;
        OrderBook[_order_id].highestBidID = 0;
        OrderBook[_order_id].price = price;
        OrderBook[_order_id].minPrice = minPrice;
        OrderBook[_order_id].expires = expires;
        OrderBook[_order_id].token = token;
        OrderBook[_order_id].seller = msg.sender;

        NFTs[nft].orderID = _order_id;

    }

    function orderEdit(uint256 _order_id, uint256 price, uint256 minPrice, uint256 expires, uint16 referral, address token) external {
        require(OrderBook[_order_id].seller == msg.sender, "Denied");
        require(NFTs[OrderBook[_order_id].nft].owner == msg.sender, "Denied 2");        
        require(OrderBook[_order_id].status == 1, "Not Open");

        //Auction
        if(OrderBook[_order_id].orderType == 2) {
            require(expires > block.timestamp, 'Expiry Date');
            require(minPrice < price, 'Minprice >= price');
        }

        OrderBook[_order_id].price = price;
        OrderBook[_order_id].minPrice = minPrice;
        OrderBook[_order_id].expires = expires;
        OrderBook[_order_id].referral = referral;
        OrderBook[_order_id].token = token;

    }

    function orderCancel(uint256 _order_id) external {
        require(OrderBook[_order_id].seller == msg.sender, "Denied");
        require(NFTs[OrderBook[_order_id].nft].owner == msg.sender, "Denied 2");
        require(OrderBook[_order_id].status == 1, "Not Open");
        require(NFTs[OrderBook[_order_id].nft].status == 1, "Not in Custody");
        

        OrderBook[_order_id].status = 3;
        NFTs[OrderBook[_order_id].nft].orderID = 0;

        //@todo cancel all bids and refund it. 

    }

    

    function orderBid(uint256 _order_id, uint256 _amount) external {
        //make sure the order is live 
        require(OrderBook[_order_id].status == 1, "Not Open");
        //make sure the nft is under custody
        require(NFTs[OrderBook[_order_id].nft].status == 1, "Not in Custody"); 
        //make sure amount have highest bid 
        
    }

    function orderBidApprove(uint256 _bid_id) external {

    }

    function orderBidCancel(uint256 _bit_id) external {

    }

    function orderBidsCancelAll(uint256 _order_id) {

    }


    function orderBuy(uint256 _order_id, address _ref) external {
        //allrequires 
        require(OrderBook[_order_id].status == 1, "Not Open");
        require(OrderBook[_order_id].orderType == 1, "Not Spot");
        require(NFTs[OrderBook[_order_id].nft].status == 1, "Not in Custody"); 


        //Take money from buyer 
        IERC20(OrderBook[_order_id].token).safeTransferFrom(msg.sender, address(this),OrderBook[_order_id].price);

        //Take the referral Bonus 
        uint256 _referralBonus = 0;
        if(_ref != 0x0000000000000000000000000000000000000000 && OrderBook[_order_id].referral > 0) {
            _referralBonus = OrderBook[_order_id].price.mul(OrderBook[_order_id].referral).div(10**4);
            ReferralFees[_ref][OrderBook[_order_id].token] = ReferralFees[_ref][OrderBook[_order_id].token].add(_referralBonus);
            ReferralFeesTotal[_ref][OrderBook[_order_id].token] = ReferralFeesTotal[_ref][OrderBook[_order_id].token].add(_referralBonus);
        }

        //Take the exchange commissions 
        uint256 _commissionFees = 0;
        if(paymentTokens[OrderBook[_order_id].token].commission > 0) {
            _commissionFees = OrderBook[_order_id].price.mul(paymentTokens[OrderBook[_order_id].token].commission).div(10**4);
            commissionFees[OrderBook[_order_id].token] = commissionFees[OrderBook[_order_id].token].add(_commissionFees);            
        }        

        uint256 finalAmount = OrderBook[_order_id].price.sub(_referralBonus).sub(_commissionFees);

        //close the order 
        OrderBook[_order_id].status = 2; //2 means order filled 
        OrderBook[_order_id].buyer = msg.sender; //update the buyer 

        //change the NFT struct 
        NFTs[OrderBook[_order_id].nft].owner = msg.sender; //update the owner of NFT
        NFTs[OrderBook[_order_id].nft].orderID = 0; //set the NFT is not locked in order 

        //Send money to seller
        IERC20(OrderBook[_order_id].token).safeTransfer(OrderBook[_order_id].seller, finalAmount);

        //emit the event 

    }


    /*************************************************************************/
    /***************************** Admin settings ****************************/
    /*************************************************************************/

    event PaymentTokenAdded(address _address, uint8 _status, uint16 _commission);
    function adminAddPaymentToken(address _address, uint8 _status, uint16 _commission) external {
        require(hasRole(ADMIN_ROLE, msg.sender), "Denied");
        require(!isPaymentTokenExists(_address), "Exists");
        paymentTokens[_address].status = _status;
        paymentTokens[_address].commission = _commission;
        emit PaymentTokenAdded(_address, _status, _commission);
    }


    event PaymentTokenEdited(address _address, uint8 _status, uint16 _commission);
    function adminEditPaymentToken(address _address, uint8 _status, uint16 _commission) external {
        require(hasRole(ADMIN_ROLE, msg.sender), "Denied");
        require(isPaymentTokenExists(_address), "Not Exists");
        paymentTokens[_address].status = _status;         
        paymentTokens[_address].commission = _commission;
        emit PaymentTokenEdited(_address, _status, _commission);        
    }

    function adminUpdateFeesAddress() external {

    }

    function adminTradeFees(uint256 _takerFee, uint256 _makerFee) external {

    }

    event AdminAdded(address _address);
    function adminAddAdmin(address _address) external {
        require(msg.sender == ownerAddress, "Denied");
        grantRole(ADMIN_ROLE, _address);
        emit AdminAdded(_address);
    }

    event AdminRemoved(address _address);
    function adminRevokeAdmin(address _address) external {
        require(msg.sender == ownerAddress, "Denied");
        revokeRole(ADMIN_ROLE, _address);
        emit AdminRemoved(_address);
    }

    function adminEditFontRewardRate(uint256 _forMakers, uint256 _forTakers) external {

    }

    function adminWithdrawFonts() external {

    }

    function adminWithdrawETH() external {
        
    }

    function adminExcludeAddressForRewards() external {

    }

    function adminIncludeAddressForRewards() external {
        
    }    

    /*************************************************************************/
    /*********************************** Views *******************************/
    /*************************************************************************/    

    function viewOrder(uint256 _id) external view returns (Order memory){

    }

    function viewUserOrders(address _user) external view returns (uint256[] memory){

    }

    function viewPaymentMethod(address _token) external view returns (PaymentToken memory){

    }

    function viewMiningRewards() external view returns (uint256, uint256){

    }

    function viewRoyalityEarnings(address _user, address _token) external view returns (uint256){

    }


    /*************************************************************************/
    /********************************** Claims *******************************/
    /*************************************************************************/    
    
    function claimRoyalityEarnings(address _token) external {

    }

    function claimFontRewards() external {

    }

    /*************************************************************************/
    /********************************* Helpers *******************************/
    /*************************************************************************/ 

    //Check if reward token already exist
    //@done
    function isPaymentTokenExists(address _address) internal view returns (bool) {
        return paymentTokens[_address].status > 0;
    }



}
