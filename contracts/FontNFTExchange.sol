// SPDX-License-Identifier: MIT
// Author: https://twitter.com/adalquardz

/* Error Codes: This is reduce the contract size 
/* 
    A Already
    D Denied
    UL Unequal length
    NC Not under custody
    H High
    R Referral is high
    T Payment token status 
    IO Already in Order 
    M Minprice >= price
    E Expiry Date
    NO Order Not Open
    NA Not Auction
    NE NOt Enough
    NB No Bids
    NS Not a Sport Order 
    Mm Mismatch
    X Exist
    NX Not Exist

*/

pragma solidity ^0.8.0;


import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";


contract FontNFTExchange is Context, AccessControl {

    using SafeMath for uint;
    using SafeMath for uint256;
    using SafeERC20 for IERC20;


    //Constants
    bytes4 _onERC1155Received;
    bytes4 _onERC1155BatchReceived;

    //Address to distribute the Exchange fees, usually staking contract 
    address public feesDistributionAddress;
    //Address of the contract owner, usually to have some ownership rights 
    address public ownerAddress;

    address public fontERC20Address;

    //uint256 private auctionExpiresMaxTime = 63072000; // 2 years 

    //Settings 
    uint256 exchangeFees = 400; //1% = 100

    //FONT NFT contract 
    IERC1155 FontNFT;

    //Role for admin
    bytes32 private constant ADMIN_ROLE = keccak256("ADMIN_ROLE");

    //Maximum 50% royality allowed, 
    uint16 maxRoyalityAllowed; //1% = 100

    //ERC20 token address for payments
    mapping (address => bool) private PaymentTokenContracts; 

    struct NFT {
        uint256 orderID; //Current Order ID
        uint16 royality; //Royality %. 1% = 100
        uint8 status;//check if the NFT is under contract custudy: 0 not exists, 1 under custody, 2 went out of contract
        address creatror; // Royality receiver or initial owner in this excange, no need to be original creator of this nft
        address owner; //current owner         
    }
    mapping (uint256 => NFT) private NFTs;

    struct Order {
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

    struct NFTOrder {
        uint256 nft; //NFT ID
        uint256 price; //Price the nft 
        uint256 minPrice; //Min price if the order is auction
        uint256 expires; //if order is auction, its expiration time 
        address token; //Payment token
        uint16 royality; //royality % 
        uint16 referral; //referral commission
        uint8 orderType; //type of the order, spot or auction
    }

    struct Bid {
        uint256 orderID;
        uint256 offer;
        //uint256 timestamp;
        address bidder;
        address referral; //referral address
        uint8 status; //Order status : 1/open, 2/filled, 3/cancelled
    }
    mapping (uint256 => Bid) private Bids;

    
    mapping (address => bool) private paymentTokens;
        
    //Referral fees earned per user per token, subject to reset on claim 
    mapping (address => mapping(address => uint256)) private ReferralFees;
    //Referral fees earned so for. just to keep the count 
    //mapping (address => mapping(address => uint256)) public ReferralFeesTotal;
    //Commission fees earned so for, subject to reset on claim
    mapping (address => uint256) private commissionFees;
    //Commission fees earned so for, just to use in views 
    //mapping (address => uint256) public commissionFeesTotal;

    //Bids per auction order 
    mapping (uint256 => uint256[]) private AuctionBids;

    uint256 private OrderID = 1;
    uint256 private BidID = 1;


    //Constructors
    constructor(address _fontnft) {

        //Mandatory for contracts to return these strings to receive ERC1155 and ERC721
        _onERC1155Received = bytes4(keccak256("onERC1155Received(address,address,uint256,uint256,bytes)"));
        _onERC1155BatchReceived = bytes4(keccak256("onERC1155BatchReceived(address,address,uint256[],uint256[],bytes)"));

        _setupRole(ADMIN_ROLE, msg.sender); // Assign admin role to contract creator

        ownerAddress = msg.sender;

        FontNFT = IERC1155(_fontnft);

        maxRoyalityAllowed = 5000;


    }    

    /*************************************************************************/
    /******************************** Move NFT *******************************/
    /*************************************************************************/    

    
    

    event NFTMovedInBulk(uint256 items);
    function nftMoveInBulk(uint256[] memory nfts, uint16[] memory royalities) external {
        require(nfts.length == royalities.length, "UL");

        uint256[] memory amounts = new uint256[](nfts.length);

        for(uint256 i = 0; i < nfts.length; i++) {
            require(NFTs[nfts[i]].status != 1, 'A'); //@todo check 

            amounts[i] = 1; //.push(1);

            //If moving for first time
            if(NFTs[nfts[i]].status == 0) {
                NFTs[nfts[i]].creatror = msg.sender; 
                NFTs[nfts[i]].royality = royalities[i];
            }        

            NFTs[nfts[i]].status = 1;
            NFTs[nfts[i]].owner = msg.sender;
            NFTs[nfts[i]].orderID = 0;

    
        }
        FontNFT.safeBatchTransferFrom(msg.sender, address(this), nfts, amounts, '');
        NFTMovedInBulk(nfts.length);
    }
    
    event NFTMovedOutBulk(uint256);
    function nftMoveOutBulk(uint256[] memory nfts) external {
        uint256[] memory amounts = new uint256[](nfts.length);

        for(uint256 i = 0; i < nfts.length; i++) {
            require(NFTs[nfts[i]].owner == msg.sender, 'D');
            require(NFTs[nfts[i]].status == 1, 'NC');
            require(NFTs[nfts[i]].orderID == 0, 'CO');

            amounts[i] = 1; //.push(1);

            NFTs[nfts[i]].status = 2;
        }

        FontNFT.safeBatchTransferFrom(address(this), msg.sender, nfts, amounts, '');
        NFTMovedOutBulk(nfts.length);
    }

    event RoyalitiesUpdated(uint256 items);
    function nftUpdateRoyalities(uint256[] calldata nfts, uint16[] calldata royalities) external {
        require(nfts.length == royalities.length, "UL");

        for(uint256 i = 0; i < nfts.length; i++) {
            require(NFTs[nfts[i]].status == 1, 'NC');
            require(NFTs[nfts[i]].owner == msg.sender, 'D');
            require(NFTs[nfts[i]].creatror == msg.sender, 'D');
            require(royalities[i] < maxRoyalityAllowed, 'H');
            NFTs[nfts[i]].royality = royalities[i];
        }
        emit RoyalitiesUpdated(nfts.length);
    }

    event BulkNFTOrderCreated(uint256); //uint256[] ids, uint256 orders
    function nftMoveCreateBulk(NFTOrder[] calldata nftorder) external {
        require(nftorder.length > 0, 'L');

        uint256[] memory amounts = new uint256[](nftorder.length);
        uint256[] memory nftIDs = new uint256[](nftorder.length);

        //uint256 _order_id = OrderID;

        for(uint256 i = 0; i < nftorder.length; i++) {
            require(NFTs[nftorder[i].nft].status != 1, 'A'); //@todo check 
            require(paymentTokens[nftorder[i].token], 'T');
            amounts[i] = 1; 
            nftIDs[i] = nftorder[i].nft;

            //If moving for first time
            if(NFTs[nftorder[i].nft].status == 0) {
                NFTs[nftorder[i].nft].creatror = msg.sender; 
                NFTs[nftorder[i].nft].royality = nftorder[i].royality;
            }        

            NFTs[nftorder[i].nft].status = 1;
            NFTs[nftorder[i].nft].owner = msg.sender;
            NFTs[nftorder[i].nft].orderID = 0;


            //Create Order 
            //Common settings for both the types 
            OrderBook[OrderID].nft = nftorder[i].nft;
            OrderBook[OrderID].orderType = nftorder[i].orderType;
            OrderBook[OrderID].referral = nftorder[i].referral;
            OrderBook[OrderID].status = 1;
            OrderBook[OrderID].highestBidID = 0;
            OrderBook[OrderID].price = nftorder[i].price;
            OrderBook[OrderID].minPrice = nftorder[i].minPrice;
            //OrderBook[OrderID].expires = expires;
            OrderBook[OrderID].token = nftorder[i].token;
            OrderBook[OrderID].seller = msg.sender;

            if(nftorder[i].expires  > 0) {
                OrderBook[OrderID].expires = nftorder[i].expires.add(block.timestamp); //@todo fix this expires thing
            }
            

            NFTs[nftorder[i].nft].orderID = OrderID;

            OrderID++;

        }
        FontNFT.safeBatchTransferFrom(msg.sender, address(this), nftIDs, amounts, '');

        emit BulkNFTOrderCreated(nftorder.length);
    }


    /*************************************************************************/
    /******************************** exchange *******************************/
    /*************************************************************************/
    
    function orderCreateBulk(uint256[] memory nfts, uint256[] memory  price, uint256[] memory  minPrice, uint256[] memory  expires, uint8[] memory  orderType, uint16[] memory  referral, address[] memory  token) external {
        require(nfts.length == price.length && nfts.length == minPrice.length && nfts.length == expires.length, "Mm");
        require(nfts.length == orderType.length && nfts.length == referral.length && nfts.length == token.length, "Mm");
       

        for(uint256 i = 0; i < nfts.length; i++) {
            require(NFTs[nfts[i]].status == 1, 'NC');
            require(NFTs[nfts[i]].owner == msg.sender, 'D');
            require(NFTs[nfts[i]].orderID == 0, 'IO');
            require(paymentTokens[token[i]], 'T');
            require(referral[i] < 9999, 'R');

            if(orderType[i] == 2) {
                //require(expires > block.timestamp, 'E');
                require(minPrice[i] < price[i] && minPrice[i] > 0, 'M');
            }

            //Common settings for both the types 
            OrderBook[OrderID].nft = nfts[i];
            OrderBook[OrderID].orderType = orderType[i];
            OrderBook[OrderID].referral = referral[i];
            OrderBook[OrderID].status = 1;
            OrderBook[OrderID].highestBidID = 0;
            OrderBook[OrderID].price = price[i];
            OrderBook[OrderID].minPrice = minPrice[i];
            //OrderBook[OrderID].expires = expires;
            OrderBook[OrderID].token = token[i];
            OrderBook[OrderID].seller = msg.sender;
            if(expires[i]  > 0) {
                OrderBook[OrderID].expires = expires[i].add(block.timestamp); //@todo fix this expires thing
            }
            NFTs[nfts[i]].orderID = OrderID;
            OrderID++;
        }

        emit OrderCreated(nfts.length);
    }

    event OrderCreated(uint256);
    function orderCreate(uint256 nft, uint256 price, uint256 minPrice, uint256 expires, uint8 orderType, uint16 referral, address token) external {
        //check all the requires
        require(NFTs[nft].status == 1, 'NC');
        require(NFTs[nft].owner == msg.sender, 'D');
        require(NFTs[nft].orderID == 0, 'IO');
        require(paymentTokens[token], 'T');
        require(referral < 9999, 'R');
        
        uint256 _order_id = OrderID;

        // Auction
        if(orderType == 2) {
            //require(expires > block.timestamp, 'E');
            require(minPrice < price && minPrice > 0, 'M');
        }

        //Common settings for both the types 
        OrderBook[OrderID].nft = nft;
        OrderBook[OrderID].orderType = orderType;
        OrderBook[OrderID].referral = referral;
        OrderBook[OrderID].status = 1;
        OrderBook[OrderID].highestBidID = 0;
        OrderBook[OrderID].price = price;
        OrderBook[OrderID].minPrice = minPrice;
        //OrderBook[OrderID].expires = expires;
        OrderBook[OrderID].token = token;
        OrderBook[OrderID].seller = msg.sender;

        if(expires  > 0) {
            OrderBook[OrderID].expires = expires.add(block.timestamp); //@todo fix this expires thing
        }
        

        NFTs[nft].orderID = OrderID;

        OrderID++;

        emit OrderCreated(_order_id);
    }
    
    event OrderEdited(uint256 _order_id);
    function orderEdit(uint256 _order_id, uint256 price, uint256 minPrice, uint256 expires, uint16 referral, address token) external {
        require(OrderBook[_order_id].seller == msg.sender, "D");
        require(NFTs[OrderBook[_order_id].nft].owner == msg.sender, "D");        
        require(OrderBook[_order_id].status == 1, "NO");
        require(NFTs[OrderBook[_order_id].nft].status == 1, "NC");

        //Auction
        if(OrderBook[_order_id].orderType == 2) {
            require(expires > 0, 'E');
            require(minPrice < price && minPrice > 0, 'M');
        }
        
        if(OrderBook[_order_id].orderType == 1) {
            OrderBook[_order_id].token = token;
        }

        OrderBook[_order_id].price = price;
        OrderBook[_order_id].minPrice = minPrice;
        //OrderBook[_order_id].expires = expires;
        OrderBook[_order_id].referral = referral;

        if(expires  > 0) {
            expires = expires.add(block.timestamp);
        }        
        emit OrderEdited(_order_id);
    }

    
    event OrderCanceled(uint256);
    function orderCancel(uint256 _order_id) external {
        require(OrderBook[_order_id].seller == msg.sender, "D");
        require(NFTs[OrderBook[_order_id].nft].owner == msg.sender, "D");
        require(OrderBook[_order_id].status == 1, "NO");
        require(NFTs[OrderBook[_order_id].nft].status == 1, "NC");

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
        emit OrderCanceled(_order_id);
    }

    
    event BidOrder(uint256 _order_id, uint256 _amount, uint256 _bid_id);
    function orderBid(uint256 _order_id, uint256 _amount, address _ref) external {
        //make sure the order is live 
        require(OrderBook[_order_id].status == 1, "NO");
        //Only Auction type
        require(OrderBook[_order_id].orderType == 2, "NA");
        //make sure the nft is under custody
        require(NFTs[OrderBook[_order_id].nft].status == 1, "NC"); 
        //Make sure amount is higher than base price 
        require(OrderBook[_order_id].minPrice < _amount, "M");
        //make sure amount have highest bid 
        require(Bids[OrderBook[_order_id].highestBidID].offer < _amount, "NE"); 


        Bids[BidID].orderID = _order_id;
        Bids[BidID].bidder = msg.sender;
        //Bids[BidID].timestamp = block.timestamp;
        Bids[BidID].offer = _amount;
        Bids[BidID].status = 1;

        //push the bid id to order id
        AuctionBids[_order_id].push(BidID);

        //update the order with highest bid 
        OrderBook[_order_id].highestBidID = BidID;

        //referral link
        if(_ref != 0x0000000000000000000000000000000000000000 && OrderBook[_order_id].referral > 0) {
            Bids[BidID].referral = _ref;
        }

        

        BidID++;


        IERC20(OrderBook[_order_id].token).safeTransferFrom(msg.sender, address(this), _amount);

        emit BidOrder(_order_id, _amount, BidID - 1);

    }

    event BidTopuped(uint256, uint256, uint256);
    function orderBidTopup(uint256 _order_id, uint256 _bid_id, uint256 _amount) external {
        //@todo remove _order_id from parameter and take it from bid id 

        //make sure the order is live 
        require(OrderBook[_order_id].status == 1, "NO");
        //Only Auction type
        require(OrderBook[_order_id].orderType == 2, "NA");        
        //make sure the nft is under custody
        require(NFTs[OrderBook[_order_id].nft].status == 1, "NC");      
        //make sure the bidder is the owner of the bid 
        require(Bids[_bid_id].bidder == msg.sender, "D"); 
        //Make sure the bid belong to the offer 
        require(Bids[_bid_id].orderID == _order_id, "Mm"); 

        //old amount and new amount should be higher than highest bid
        require((Bids[_bid_id].offer + _amount) > Bids[OrderBook[_order_id].highestBidID].offer, "NE");

        //update offer to new amount 
        Bids[_bid_id].offer = Bids[_bid_id].offer.add(_amount);

        //update the highestBidID to the order 
        OrderBook[_order_id].highestBidID = _bid_id;

        IERC20(OrderBook[_order_id].token).safeTransferFrom(msg.sender, address(this), _amount);

        emit BidTopuped(_order_id, _bid_id, _amount);
        //@todo emit 
    }

    function orderBidApprove(uint256 _bid_id, bool withdrawNFT) external {
        //make sure the order is live 
        require(OrderBook[Bids[_bid_id].orderID].status == 1, "NO");
        //make sure the nft is under custody
        require(NFTs[OrderBook[Bids[_bid_id].orderID].nft].status == 1, "NC"); 
        //Make sure only seller can approve the bid 
        require(OrderBook[Bids[_bid_id].orderID].seller == msg.sender, "D");
        //Only Auction type
        require(OrderBook[Bids[_bid_id].orderID].orderType == 2, "NA");                

        //update the bid 
        Bids[_bid_id].status = 2;

        //cancel all other bids 
        orderBidsCancelAll(Bids[_bid_id].orderID, _bid_id);

        //take the commission and referral balances 
        uint256 _commission = _calculateFee(Bids[_bid_id].offer, OrderBook[Bids[_bid_id].orderID].token);

        uint256 _referral_commision = 0;

        if(Bids[_bid_id].referral != 0x0000000000000000000000000000000000000000 && OrderBook[Bids[_bid_id].orderID].referral > 0) {
            _referral_commision = Bids[_bid_id].offer.mul(OrderBook[Bids[_bid_id].orderID].referral).div(10**4);
        }

        //send money to seller 
        IERC20(OrderBook[Bids[_bid_id].orderID].token).safeTransfer(OrderBook[_order_id].seller, (Bids[_bid_id].offer).sub(_commission).sub(_referral_commision));
        
        //move nft to buyer 
        if(withdrawNFT) {
            
        }

        //update the NFT 
        //update the order 
        //update the bid 
        //reward the font mining 
        //emit the event 

    }
    
    event BidCanceled(uint256);
    function orderBidCancel(uint256 _bid_id) external {
        //make sure the order is live 
        require(OrderBook[Bids[_bid_id].orderID].status == 1, "No");
        //make sure the nft is under custody
        require(NFTs[OrderBook[Bids[_bid_id].orderID].nft].status == 1, "NC"); 
        //only open bids can be cancled, other 2 bids are filled and cancled 
        require(Bids[_bid_id].status == 1, "BN"); 
        //Only bid owner able to cancel it
        require(Bids[_bid_id].bidder == msg.sender, "D");
        
        Bids[_bid_id].status = 3;

        IERC20(OrderBook[Bids[_bid_id].orderID].token).safeTransfer(Bids[_bid_id].bidder, Bids[_bid_id].offer);

        //@todo if a bid cancled, find highest bid and update the order book highest bid 
        _setOrderHighestBid(Bids[_bid_id].orderID);

        //@todo emit
        emit BidCanceled(_bid_id);
    }

    function orderBidsCancelAll(uint256 _order_id, uint256 _except) internal returns (bool){
        //@todo everything 
        //make sure the order is live 
        require(OrderBook[_order_id].status == 1, "No");
        //make sure the nft is under custody
        require(NFTs[OrderBook[_order_id].nft].status == 1, "NC"); 
        //Only Auction type
        require(OrderBook[_order_id].orderType == 2, "NA");
        //check if order have enough bids 
        require(AuctionBids[_order_id].length > 0, "NB");

        for(uint256 i = 0; i < AuctionBids[_order_id].length; i++) {
            if(Bids[AuctionBids[_order_id][i]].status == 1 && AuctionBids[_order_id][i] != _except) {
                Bids[AuctionBids[_order_id][i]].status = 3;
                IERC20(OrderBook[_order_id].token).safeTransfer(Bids[AuctionBids[_order_id][i]].bidder, Bids[AuctionBids[_order_id][i]].offer);
            }
        }
    
        return true;
    }
    
    

    //Buy the spot order. 
    event OrderBought(uint256 _order_id);
    function orderBuy(uint256 _order_id, address _ref, bool _withdraw) external {
        //allrequires 
        require(OrderBook[_order_id].status == 1 && OrderBook[_order_id].orderType == 1, "NO");
        //require(OrderBook[_order_id].orderType == 1, "NS");
        require(NFTs[OrderBook[_order_id].nft].status == 1, "NC"); 


        //Take money from buyer 
        IERC20(OrderBook[_order_id].token).safeTransferFrom(msg.sender, address(this),OrderBook[_order_id].price);

        //Take the referral Bonus 
        uint256 _referralBonus = 0;
        if(_ref != 0x0000000000000000000000000000000000000000 && OrderBook[_order_id].referral > 0) {
            _referralBonus = OrderBook[_order_id].price.mul(OrderBook[_order_id].referral).div(10**4);
            ReferralFees[_ref][OrderBook[_order_id].token] = ReferralFees[_ref][OrderBook[_order_id].token].add(_referralBonus);
        }

        //Take the exchange commissions 
        uint256 _commissionFees = 0;
        if(OrderBook[_order_id].token != fontERC20Address) {
            _commissionFees = OrderBook[_order_id].price.mul(exchangeFees).div(10**4);
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

        
        if(_withdraw) {
            NFTs[OrderBook[_order_id].nft].status = 2;
            FontNFT.safeTransferFrom(address(this), msg.sender, OrderBook[_order_id].nft, 1, '');            
        }

        //@todo emit the event 
        emit OrderBought(_order_id);

    }

    event NFTWithdrawn(uint256 nft);
    function withdrawNFT(uint256 nft) public {
        require(NFTs[nft].status == 1, 'NC');
        require(NFTs[nft].owner == msg.sender, 'D');
        require(NFTs[nft].orderID == 0, 'IO');

        NFTs[nft].status = 2;
        FontNFT.safeTransferFrom(address(this), msg.sender, nft, 1, '');
        emit NFTWithdrawn(nft);
    }


    /*************************************************************************/
    /***************************** Admin settings ****************************/
    /*************************************************************************/


    function adminEditPaymentToken(address _address, bool _status) external {
        require(hasRole(ADMIN_ROLE, msg.sender), "D");
        paymentTokens[_address] = _status;         
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

    function viewPaymentMethod(address _token) external view returns (bool) {
        return paymentTokens[_token];
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


    //Set the highest bid for order in order book
    //@todo test this 
    function _setOrderHighestBid(uint256 _order_id) internal {
        require(OrderBook[_order_id].status == 1, "NO");
        require(OrderBook[_order_id].orderType == 2, "NA");
        require(NFTs[OrderBook[_order_id].nft].status == 1, "NC"); 
        require(AuctionBids[_order_id].length > 0, "NB"); 
        
        uint256 _highestBidID = 0;
        uint256 _highestBidOffer = 0;
        for(uint256 i = 0; i < AuctionBids[_order_id].length; i++) {
            if(Bids[AuctionBids[_order_id][i]].status == 1 && Bids[AuctionBids[_order_id][i]].offer > _highestBidOffer) {
                _highestBidOffer = Bids[AuctionBids[_order_id][i]].offer;
                _highestBidID = AuctionBids[_order_id][i];
            }
        }
        OrderBook[_order_id].highestBidID = _highestBidID;
    }

    //done
    function _calculateFee(uint256 _amount, address _token) internal view returns (uint256) {
        if(_token == fontERC20Address) {
            return 0;
        }
        return _amount.mul(exchangeFees).div(10**4);
    }

    //Contract must have onERC1155Received() to receive the ERC1155 
    //@done
    function onERC1155Received(address operator, address from, uint256 id, uint256 value, bytes calldata data) external returns(bytes4) {
        return _onERC1155Received;
    }

    //Contract must have to onERC1155BatchReceived() receive the ERC1155 in batch
    //@done
    function onERC1155BatchReceived(address operator, address from, uint256[] calldata ids, uint256[] calldata values, bytes calldata data) external returns(bytes4) {
        return _onERC1155BatchReceived;
    }


}



    /*

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

    event NFTMovedOut(uint256);
    function nftMoveOut(uint256 nft) external {
        require(NFTs[nft].owner == msg.sender, 'Not Owner');
        require(NFTs[nft].status == 1, 'Not under custody');
        require(NFTs[nft].orderID == 0, 'Cancel Order');

        NFTs[nft].status = 2;

        FontNFT.safeTransferFrom(address(this), msg.sender, nft, 1, '');
        emit NFTMovedOut(nft);
    }    
    
    */


    
    