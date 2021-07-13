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

    //Address to distribute the Exchange fees, usually staking contract 
    address public feesDistributionAddress;
    //Address of the contract owner, usually to have some ownership rights 
    address public ownerAddress;

    //Settings 
    uint256 _exchangeFees; //1% = 100

    //FONT NFT contract 
    IERC1155 FontNFT = IERC1155(0x15790FD4AeEd8B28a02f72787C77B1Be43a196F5);

    //Role for admin
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");

    //Maximum 50% royality allowed, 
    uint16 maxRoyalityAllowed = 5000; //1% = 100

    //ERC20 token address for payments
    mapping (address => bool) public PaymentTokenContracts; 

    struct NFT {
        uint256 nftid; //NFT ID 
        uint256 orderID; //Current Order ID
        uint16 royality; //Royality %. 1% = 100
        uint8 status;//check if the NFT is under contract custudy: 0 not exists, 1 under custody, 2 went out of contract
        address creatror; // Royality receiver or initial owner in this excange, no need to be original creator of this nft
        address owner; //current owner         
    }
    mapping (uint256 => NFT) private NFTs;

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
    mapping (uint256 => Order) private OrderBook;

    struct Bid {
        uint256 id;
        uint256 orderID;
        uint256 offer;
        uint256 timestamp;
        address bidder;
        uint8 status; //Order status : 1/open, 2/filled, 3/cancelled
    }
    mapping (uint256 => Bid) private Bids;

    struct PaymentToken { 
        uint16 commission; //1% = 100
        uint8 status; //1 = open, 2 is paused
    }
    mapping (address => PaymentToken) public paymentTokens;
        
    //Referral fees earned per user per token, subject to reset on claim 
    mapping (address => mapping(address => uint256)) public ReferralFees;
    //Referral fees earned so for. just to keep the count 
    mapping (address => mapping(address => uint256)) public ReferralFeesTotal;
    //Commission fees earned so for, subject to reset on claim
    mapping (address => uint256) public commissionFees;
    //Commission fees earned so for, just to use in views 
    mapping (address => uint256) public commissionFeesTotal;

    //Bids per auction order 
    mapping (uint256 => uint256[]) private AuctionBids;

    Counters.Counter private OrderID;
    Counters.Counter private BidID;


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

    //Move single NFT from user address to Exchange contract. 
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
        
        uint256 _order_id = OrderID.current();

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

        OrderID.increment();

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
        


        //Auction, cancel all the bids
        if(OrderBook[_order_id].orderType == 2) {
            //cancel all bids and refund it. 
            orderBidsCancelAll(_order_id, 0);        
        }
        //update the order to cancled
        OrderBook[_order_id].status = 3;
        //update the nft book
        NFTs[OrderBook[_order_id].nft].orderID = 0;

        //@todo emit it
    }

    

    function orderBid(uint256 _order_id, uint256 _amount) external {
        //make sure the order is live 
        require(OrderBook[_order_id].status == 1, "Not Open");
        //Only Auction type
        require(OrderBook[_order_id].orderType == 2, "Not Auction");
        //make sure the nft is under custody
        require(NFTs[OrderBook[_order_id].nft].status == 1, "Not in Custody"); 
        //Make sure amount is higher than base price 
        require(OrderBook[_order_id].minPrice < _amount, "Min Price");
        //make sure amount have highest bid 
        require(Bids[OrderBook[_order_id].highestBidID].offer < _amount, "Not enough"); 

        

        uint256 _bid_id = BidID.current();


        Bids[_bid_id].id = _bid_id;
        Bids[_bid_id].orderID = _order_id;
        Bids[_bid_id].bidder = msg.sender;
        Bids[_bid_id].timestamp = block.timestamp;
        Bids[_bid_id].offer = _amount;
        Bids[_bid_id].status = 1;

        //push the bid id to order id
        AuctionBids[_order_id].push(_bid_id);

        //update the order with highest bid 
        OrderBook[_order_id].highestBidID = _bid_id;

        OrderID.increment();

        IERC20(OrderBook[_order_id].token).safeTransferFrom(msg.sender, address(this), _amount);

    }

    function orderBidTopup(uint256 _order_id, uint256 _bid_id, uint256 _amount) external {
        //@todo remove _order_id from parameter and take it from bid id 

        //make sure the order is live 
        require(OrderBook[_order_id].status == 1, "Not Open");
        //Only Auction type
        require(OrderBook[_order_id].orderType == 2, "Not Auction");        
        //make sure the nft is under custody
        require(NFTs[OrderBook[_order_id].nft].status == 1, "Not in Custody");      
        //make sure the bidder is the owner of the bid 
        require(Bids[_bid_id].bidder == msg.sender, "Denied"); 
        //Make sure the bid belong to the offer 
        require(Bids[_bid_id].orderID == _order_id, "Mismatch"); 

        //old amount and new amount should be higher than highest bid
        require((Bids[_bid_id].offer + _amount) > Bids[OrderBook[_order_id].highestBidID].offer, "Not Enough");

        //update offer to new amount 
        Bids[_bid_id].offer = Bids[_bid_id].offer.add(_amount);

        //update the highestBidID to the order 
        OrderBook[_order_id].highestBidID = _bid_id;

        IERC20(OrderBook[_order_id].token).safeTransferFrom(msg.sender, address(this), _amount);

        //@todo emit 
    }

    function orderBidApprove(uint256 _bid_id) external {
        //make sure the order is live 
        require(OrderBook[Bids[_bid_id].orderID].status == 1, "Not Open");
        //make sure the nft is under custody
        require(NFTs[OrderBook[Bids[_bid_id].orderID].nft].status == 1, "Not in Custody"); 
        //Make sure only seller can approve the bid 
        require(OrderBook[Bids[_bid_id].orderID].seller == msg.sender, "Denied");

        Bids[_bid_id].status = 2;

        //cancel all other bids 
        //take the commission and referral balances 
        //send money to seller 
        //move nft to buyer 
        //update the NFT 
        //update the order 
        //update the bid 
        //reward the font mining 
        //emit the event 

    }

    function orderBidCancel(uint256 _bid_id) external {
        //make sure the order is live 
        require(OrderBook[Bids[_bid_id].orderID].status == 1, "Order Not Open");
        //make sure the nft is under custody
        require(NFTs[OrderBook[Bids[_bid_id].orderID].nft].status == 1, "Not in Custody"); 
        //only open bids can be cancled, other 2 bids are filled and cancled 
        require(Bids[_bid_id].status == 1, "Bid not open"); 
        //Only bid owner able to cancel it
        require(Bids[_bid_id].bidder == msg.sender, "Denied");
        
        Bids[_bid_id].status = 3;

        IERC20(OrderBook[Bids[_bid_id].orderID].token).safeTransfer(Bids[_bid_id].bidder, Bids[_bid_id].offer);

        //@todo if a bid cancled, find highest bid and update the order book highest bid 
        _setOrderHighestBid(Bids[_bid_id].orderID);

        //@todo emit
        
    }

    function orderBidsCancelAll(uint256 _order_id, uint256 _except) internal returns (bool){
        //@todo everything 
        //only for open order and open nft 
        //loop all bid ids 
        //for all bids thats not cancled, transfer the amount 
            //if expect id is present, dont cancel it 
    
        return true;
    }

    //Buy the spot order. 
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

        //@todo send the font minng rewards, use function

        //Send money to seller
        IERC20(OrderBook[_order_id].token).safeTransfer(OrderBook[_order_id].seller, finalAmount);

        

        //@todo emit the event 

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

    function adminTradeFees(uint256 _adminFee) external {

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

    function viewOrder(uint256 _id) external view returns (Order memory) {
        return OrderBook[_id];
    }

    function viewBid(uint256 _id) external view returns (Bid memory) {
        return Bids[_id];
    }

    function viewNFT(uint256 _id) external view returns (NFT memory) {
        return NFTs[_id];
    }    

    function viewUserOrders(address _user) external view returns (uint256[] memory) {

    }

    function viewPaymentMethod(address _token) external view returns (PaymentToken memory) {

    }

    function viewMiningRewards() external view returns (uint256, uint256) {

    }

    function viewRoyalityEarnings(address _user, address _token) external view returns (uint256) {

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

    //Set the highest bid for order in order book
    //@todo test this 
    function _setOrderHighestBid(uint256 _order_id) internal {
        require(OrderBook[_order_id].status == 1, "Not Open");
        require(OrderBook[_order_id].orderType == 2, "Not Auction");
        require(NFTs[OrderBook[_order_id].nft].status == 1, "Not in Custody"); 
        require(AuctionBids[_order_id].length > 0, "No Bids"); 
        
        uint256 _highestBidID = 0;
        uint256 _highestBidOffer = 0;
        for(uint256 i = 0; i < AuctionBids[_order_id].length; i++) {
            if(Bids[AuctionBids[_order_id][i]].status == 1 && Bids[AuctionBids[_order_id][i]].offer > _highestBidOffer) {
                _highestBidOffer = Bids[AuctionBids[_order_id][i]].offer;
                _highestBidID = Bids[AuctionBids[_order_id][i]].id;
            }
        }
        OrderBook[_order_id].highestBidID = _highestBidID;
    }

}
