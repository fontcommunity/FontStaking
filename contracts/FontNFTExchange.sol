// SPDX-License-Identifier: MIT
// Author: https://twitter.com/adalquardz
// For Error explainations, see bottom of the page. 

pragma solidity ^0.8.0;


import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";


interface FontRewardOracle {
    function getFontRewardPrice(address _token) external view returns (uint256);
}

contract FontNFTExchange is Context, AccessControl {

    using SafeERC20 for IERC20;


    //Constants
    bytes4 _onERC1155Received;
    bytes4 _onERC1155BatchReceived;

    //Address to distribute the Exchange fees, usually staking contract 
    address private feesDistributionAddress;
    //Address of the contract owner
    address private ownerAddress;

    //Price oracle address
    FontRewardOracle private priceOracle;

    //font ERC20 Address
    address private fontERC20Address = 0x4C25Bdf026Ea05F32713F00f73Ca55857Fbf6342; //@deploy change this per network 

    //uint256 private auctionExpiresMaxTime = 63072000; // 2 years 

    //Settings 
    uint256 private exchangeFees = 400; //1% = 100

    //FONT NFT contract 
    IERC1155 FontNFT;

    //Role for admin
    bytes32 private constant ADMIN_ROLE = keccak256("ADMIN_ROLE");

    //Maximum 50% royality allowed, 
    uint16 private maxRoyalityAllowed = 2500; //1% = 100


    //Font rewards per token 
    mapping (address => uint256) private FontRewardPerToken;

    //ERC20 token address for payments
    mapping (address => bool) private PaymentTokenContracts; 

    struct NFT {
        uint256 orderID; //Current Order ID
        uint16 royality; //Royality %. 1% = 100
        uint8 status;//check if the NFT is under contract custudy: 0 not exists, 1 under custody, 2 went out of contract
        address creator; // Royality receiver or initial owner in this excange, no need to be original creator of this nft
        address owner; //current owner         
    }
    mapping (uint256 => NFT) private NFTs;

    struct Order {
        uint256 nft; //NFT ID [f]
        //uint256 qty; // quantity of this font nft (for now just 1) //@todo should we beed this [f]
        uint256 price; //price for whole NFT, of acceptable price if its auction [f]
        uint256 minPrice; //Min price the bidding starts with [f]
        uint256 highestBidID; //Highest bid id. 
        uint256 expires; //auction expires. post expire date, no one can bid id  @todo
        uint16 referral; //Affiliate commission percentage
        uint8 status; //Order status : 1/open, 2/filled, 3/cancelled
        
        bool auction; //Order type : 0/normal, 1/auction
        //For auction specific 
        address token; //ERC20 Token for payment     
        address seller; //current owner of this nft         
        address buyer; //new owner who bought this 
    }    
    mapping (uint256 => Order) private OrderBook;

    //This is temp struct used in function argument
    struct NFTOrder {
        uint256 nft; //NFT ID
        uint256 price; //Price the nft 
        uint256 minPrice; //Min price if the order is auction
        uint256 expires; //if order is auction, its expiration time 
        
        uint16 royality; //royality % 
        uint16 referral; //referral commission
        
        address token; //Payment token
    }

    //Bidding item stored here. 
    struct Bid {
        uint256 orderID;
        uint256 offer;
        //uint256 timestamp;
        uint8 status; //Order status : 1/open, 2/filled, 3/cancelled
        address bidder;
        address referral; //referral address
        
    }
    mapping (uint256 => Bid) private Bids;
    //Bids per auction order 
    mapping (uint256 => uint256[]) private AuctionBids;
    uint256 private BidID = 1;

    //Payment Tokens 
    mapping (address => bool) private paymentTokens;
        
    //Referral fees earned per user per token, subject to reset on claim 
    mapping (address => mapping(address => uint256)) private ReferralFees;
    //Commission fees earned by exchange, per token so for, subject to reset on claim
    mapping (address => uint256) private commissionFees;
    //Font Rewards for buyers and selles
    mapping (address => uint256) private FontRewards;
    //Orders per user
    mapping (address => uint256[]) private UserOrders;

    uint256 private OrderID = 1;
    


    //Constructors
    constructor(address _fontnft) {

        //Mandatory for contracts to return these strings to receive ERC1155 and ERC721
        _onERC1155Received = bytes4(keccak256("onERC1155Received(address,address,uint256,uint256,bytes)"));
        _onERC1155BatchReceived = bytes4(keccak256("onERC1155BatchReceived(address,address,uint256[],uint256[],bytes)"));

        _setupRole(ADMIN_ROLE, msg.sender); // Assign admin role to contract creator

        ownerAddress = msg.sender;

        FontNFT = IERC1155(_fontnft);

        priceOracle = FontRewardOracle(_fontnft); //@deploy the right one

    }    

    /*************************************************************************/
    /******************************** Move NFT *******************************/
    /*************************************************************************/    

    //Move NFTs into contract in bulk
    //@done
    event NFTMovedInBulk(uint256 items);
    function nftMoveInBulk(uint256[] memory nfts, uint16[] memory royalities) external {
        require(nfts.length == royalities.length, "UL");
        uint256[] memory amounts = new uint256[](nfts.length);
        for(uint256 i = 0; i < nfts.length; i++) {
            require(NFTs[nfts[i]].status != 1, 'A');  //
            amounts[i] = 1; 

            //If moving for first time
            if(NFTs[nfts[i]].status == 0) {
                NFTs[nfts[i]].creator = msg.sender; 
                NFTs[nfts[i]].royality = royalities[i];
            }        
            NFTs[nfts[i]].status = 1;
            NFTs[nfts[i]].owner = msg.sender;
            NFTs[nfts[i]].orderID = 0;

        }
        FontNFT.safeBatchTransferFrom(msg.sender, address(this), nfts, amounts, '');
        NFTMovedInBulk(nfts.length);
    }

    //Move NFTs out from contract in bulk
    //@done    
    event NFTMovedOutBulk(uint256);
    function nftMoveOutBulk(uint256[] memory nfts) external {
        uint256[] memory amounts = new uint256[](nfts.length);
        for(uint256 i = 0; i < nfts.length; i++) {
            require(NFTs[nfts[i]].owner == msg.sender, 'D');
            require(NFTs[nfts[i]].status == 1, 'NC');
            require(NFTs[nfts[i]].orderID == 0, 'CO');
            amounts[i] = 1;
            NFTs[nfts[i]].status = 2;
        }
        FontNFT.safeBatchTransferFrom(address(this), msg.sender, nfts, amounts, '');
        NFTMovedOutBulk(nfts.length);
    }

    //Update the NFT royalities in bulk
    //@done
    event RoyalitiesUpdated(uint256 items);
    function nftUpdateRoyalities(uint256[] calldata nfts, uint16[] calldata royalities) external {
        require(nfts.length == royalities.length, "Mm");
        for(uint256 i = 0; i < nfts.length; i++) {
            require(NFTs[nfts[i]].status == 1, 'NC');
            require(NFTs[nfts[i]].owner == msg.sender, 'D');
            require(NFTs[nfts[i]].creator == msg.sender, 'D');
            require(royalities[i] < maxRoyalityAllowed, 'H');
            NFTs[nfts[i]].royality = royalities[i];
        }
        emit RoyalitiesUpdated(nfts.length);
    }

    /*************************************************************************/
    /******************************** exchange *******************************/
    /*************************************************************************/
    event MovedNFTCreatedOrder(uint256);
    function moveCreateOrder(uint256 nft, uint256 price, uint256 minPrice, uint256 expires, bool auction, uint16 referral, uint16 royality, address token ) external {
        require(NFTs[nft].status != 1, 'A');  //
        require(royality < maxRoyalityAllowed, 'H');
        require(paymentTokens[token], 'T');
        require(referral < 8000, 'R');
        require(NFTs[nft].orderID == 0, 'IO');

        address _msgSender = msg.sender;

        if(NFTs[nft].status == 0) {
            NFTs[nft].creator = _msgSender; 
        }
        if(NFTs[nft].creator == _msgSender) {
            NFTs[nft].royality = royality;
        }
        
        NFTs[nft].owner = _msgSender; 
        NFTs[nft].status = 1;

        if(auction) {
            //require(expires > block.timestamp, 'E');
            require(minPrice < price && minPrice > 0, 'M');
            OrderBook[OrderID].minPrice = minPrice;

            if(expires  > 0) {
                OrderBook[OrderID].expires = expires + block.timestamp; //@todo fix this expires thing
            }                

            OrderBook[OrderID].auction = auction;
        }

        //Common settings for both the types 
        OrderBook[OrderID].nft = nft;
        
        OrderBook[OrderID].referral = referral;
        OrderBook[OrderID].status = 1;
        //OrderBook[OrderID].highestBidID = 0;
        OrderBook[OrderID].price = price;
        OrderBook[OrderID].token = token;
        OrderBook[OrderID].seller = _msgSender;

        NFTs[nft].orderID = OrderID;
        //User Orders
        UserOrders[_msgSender].push(OrderID);
        OrderID++;

        
        FontNFT.safeTransferFrom(msg.sender, address(this), nft, 1, '');
        emit MovedNFTCreatedOrder(nft);
    }
    
    function orderCreateBulk(uint256[] memory nfts, uint256[] memory  price, uint256[] memory  minPrice, uint256[] memory  expires, bool[] memory  auction, uint16[] memory  referral, address[] memory  token) external {
        require(nfts.length == price.length && nfts.length == minPrice.length && nfts.length == expires.length, "Mm");
        require(nfts.length == auction.length && nfts.length == referral.length && nfts.length == token.length, "Mm");
       
        for(uint256 i = 0; i < nfts.length; i++) {
            require(NFTs[nfts[i]].status == 1, 'NC');
            require(NFTs[nfts[i]].owner == msg.sender, 'D');
            require(NFTs[nfts[i]].orderID == 0, 'IO');
            require(paymentTokens[token[i]], 'T');
            require(referral[i] < 8000, 'R');

            if(auction[i]) {
                //require(expires > block.timestamp, 'E');
                require(minPrice[i] < price[i] && minPrice[i] > 0, 'M');
                OrderBook[OrderID].minPrice = minPrice[i];

                if(expires[i]  > 0) {
                    OrderBook[OrderID].expires = expires[i] + block.timestamp; //@todo fix this expires thing
                }                
            }

            //Common settings for both the types 
            OrderBook[OrderID].nft = nfts[i];
            OrderBook[OrderID].auction = auction[i];
            OrderBook[OrderID].referral = referral[i];
            OrderBook[OrderID].status = 1;
            //OrderBook[OrderID].highestBidID = 0;
            OrderBook[OrderID].price = price[i];
            OrderBook[OrderID].token = token[i];
            OrderBook[OrderID].seller = msg.sender;

            NFTs[nfts[i]].orderID = OrderID;
            //User Orders
            UserOrders[msg.sender].push(OrderID);
            OrderID++;
        }
        emit OrderCreated(nfts.length);
    }

    event OrderCreated(uint256);
    function orderCreate(uint256 nft, uint256 price, uint256 minPrice, uint256 expires, bool auction, uint16 referral, address token) external {
        //check all the requires
        require(NFTs[nft].status == 1, 'NC');
        require(NFTs[nft].owner == msg.sender, 'D');
        require(NFTs[nft].orderID == 0, 'IO');
        require(paymentTokens[token], 'T');
        require(referral < 8000, 'R');
        
        uint256 _order_id = OrderID;

        // Auction
        if(auction) {
            //require(expires > block.timestamp, 'E');
            require(minPrice < price && minPrice > 0, 'M');
            OrderBook[OrderID].minPrice = minPrice;

            if(expires  > 0) {
                OrderBook[OrderID].expires = expires + block.timestamp; //@todo fix this expires thing
            }            

            OrderBook[OrderID].auction = auction;
        }

        //Common settings for both the types 
        OrderBook[OrderID].nft = nft;
        
        OrderBook[OrderID].referral = referral;
        OrderBook[OrderID].status = 1;
        //OrderBook[OrderID].highestBidID = 0;
        OrderBook[OrderID].price = price;
        
        //OrderBook[OrderID].expires = expires;
        OrderBook[OrderID].token = token;
        OrderBook[OrderID].seller = msg.sender;

        NFTs[nft].orderID = OrderID;

        UserOrders[msg.sender].push(OrderID);

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
        if(OrderBook[_order_id].auction) {
            require(expires > 0, 'E');
            require(minPrice < price && minPrice > 0, 'M');
            OrderBook[_order_id].minPrice = minPrice;

            if(expires  > 0) {
                OrderBook[_order_id].expires = expires + block.timestamp;
            }            
        }
        //Token can be edited only for spot orders and auctions orders witout bid 
        if(!OrderBook[_order_id].auction || OrderBook[_order_id].highestBidID == 0) {
            OrderBook[_order_id].token = token;
        }
        OrderBook[_order_id].price = price;
        OrderBook[_order_id].referral = referral;
        emit OrderEdited(_order_id);
    }

    
    event OrderCanceled(uint256);
    function orderCancel(uint256 _order_id) external {
        require(OrderBook[_order_id].seller == msg.sender, "D");
        require(NFTs[OrderBook[_order_id].nft].owner == msg.sender, "D");
        require(OrderBook[_order_id].status == 1, "NO");
        require(NFTs[OrderBook[_order_id].nft].status == 1, "NC");

        //Auction, cancel all the bids
        if(OrderBook[_order_id].auction) {
            //cancel all bids and refund it. 
            orderBidsCancelAll(_order_id, 0);        
        }
        //update the order to cancled
        OrderBook[_order_id].status = 3;
        //update the nft book
        NFTs[OrderBook[_order_id].nft].orderID = 0;

        
        emit OrderCanceled(_order_id);
    }

    
    event BidOrder(uint256 _order_id, uint256 _amount, uint256 _bid_id);
    function orderBid(uint256 _order_id, uint256 _amount, address _ref) external {
        //make sure the order is live 
        require(OrderBook[_order_id].status == 1, "NO");
        //Only Auction type
        require(OrderBook[_order_id].auction, "NA");
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
    function orderBidTopup(uint256 _bid_id, uint256 _amount) external {
        //@todo remove _order_id from parameter and take it from bid id 
        
        //make sure the bidder is the owner of the bid 
        require(Bids[_bid_id].bidder == msg.sender, "D"); 

        uint256 _order_id = Bids[_bid_id].orderID;
        //make sure the order is live 
        require(OrderBook[_order_id].status == 1, "NO");
        //Only Auction type
        require(OrderBook[_order_id].auction, "NA");        
        //make sure the nft is under custody
        require(NFTs[OrderBook[_order_id].nft].status == 1, "NC");      

        

        //old amount and new amount should be higher than highest bid
        require((Bids[_bid_id].offer + _amount) > Bids[OrderBook[_order_id].highestBidID].offer, "NE");

        //update offer to new amount 
        Bids[_bid_id].offer += _amount;

        //update the highestBidID to the order 
        OrderBook[_order_id].highestBidID = _bid_id;

        IERC20(OrderBook[_order_id].token).safeTransferFrom(msg.sender, address(this), _amount);

        emit BidTopuped(_order_id, _bid_id, _amount);
        //@todo emit 
    }

    event OrderBidApproved(uint256 _bid_id);
    function orderBidApprove(uint256 _bid_id, bool _withdrawNFT) external {
        //make sure the order is live 
        require(OrderBook[Bids[_bid_id].orderID].status == 1, "NO");
        //make sure the nft is under custody
        require(NFTs[OrderBook[Bids[_bid_id].orderID].nft].status == 1, "NC"); 
        //Make sure only seller can approve the bid 
        require(OrderBook[Bids[_bid_id].orderID].seller == msg.sender, "D");
        //Only Auction type
        require(OrderBook[Bids[_bid_id].orderID].auction, "NA");                

        //update the bid 
        Bids[_bid_id].status = 2;

        //cancel all other bids 
        orderBidsCancelAll(Bids[_bid_id].orderID, _bid_id);

        //close the order 
        OrderBook[Bids[_bid_id].orderID].status = 2; //2 means order filled 
        OrderBook[Bids[_bid_id].orderID].buyer = Bids[_bid_id].bidder; //update the buyer 

        //update the NFT 
        NFTs[OrderBook[Bids[_bid_id].orderID].nft].owner = Bids[_bid_id].bidder; //update the owner of NFT
        NFTs[OrderBook[Bids[_bid_id].orderID].nft].orderID = 0; //set the NFT is not locked in order 

        //move nft to buyer 
        if(_withdrawNFT) {
            NFTs[OrderBook[Bids[_bid_id].orderID].nft].status = 2;
            FontNFT.safeTransferFrom(address(this), Bids[_bid_id].bidder, OrderBook[Bids[_bid_id].orderID].nft, 1, '');            
        }
        else {
            NFTs[OrderBook[Bids[_bid_id].orderID].nft].status = 1;
        }

        //Distribute Money
        _distributePayment(Bids[_bid_id].offer, OrderBook[Bids[_bid_id].orderID].referral, OrderBook[Bids[_bid_id].orderID].token, Bids[_bid_id].referral,  OrderBook[Bids[_bid_id].orderID].seller, true);

        //reward the font mining 
        fontReward(Bids[_bid_id].offer, OrderBook[Bids[_bid_id].orderID].token, Bids[_bid_id].bidder);

        //emit the event 
        emit OrderBidApproved(_bid_id);
    }
    
    event BidCanceled(uint256);
    function orderBidCancel(uint256 _bid_id) external {
        //only open bids can be cancled, other 2 bids are filled and cancled 
        require(Bids[_bid_id].status == 1, "BN"); 
        //Only bid owner able to cancel it
        require(Bids[_bid_id].bidder == msg.sender, "D");
        //make sure the order is live 
        require(OrderBook[Bids[_bid_id].orderID].status == 1, "No");
        //make sure the nft is under custody
        require(NFTs[OrderBook[Bids[_bid_id].orderID].nft].status == 1, "NC"); 

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
        require(OrderBook[_order_id].auction, "NA");
        //check if order have enough bids 
        require(AuctionBids[_order_id].length > 0, "NB");

        for(uint256 i = 0; i < AuctionBids[_order_id].length; i++) {
            if(Bids[AuctionBids[_order_id][i]].status == 1 && AuctionBids[_order_id][i] != _except) {
                Bids[AuctionBids[_order_id][i]].status = 3;
                IERC20(OrderBook[_order_id].token).safeTransfer(Bids[AuctionBids[_order_id][i]].bidder, Bids[AuctionBids[_order_id][i]].offer);
                delete Bids[AuctionBids[_order_id][i]]; //@todo remove if this brings issue 
            }
        }
        OrderBook[_order_id].highestBidID = 0;
        return true;
    }
    
    

    //Buy the spot order. 
    event OrderBought(uint256 _order_id);
    function orderBuy(uint256 _order_id, address _ref, bool _withdraw) external {
        //allrequires 
        require(NFTs[OrderBook[_order_id].nft].status == 1, "NC"); 
        require(OrderBook[_order_id].status == 1);
        require(!OrderBook[_order_id].auction, "NS");

        //Take money from buyer 
        IERC20(OrderBook[_order_id].token).safeTransferFrom(msg.sender, address(this), OrderBook[_order_id].price);


        //close the order 
        OrderBook[_order_id].status = 2; //2 means order filled 
        OrderBook[_order_id].buyer = msg.sender; //update the buyer 

        //change the NFT struct 
        NFTs[OrderBook[_order_id].nft].owner = msg.sender; //update the owner of NFT
        NFTs[OrderBook[_order_id].nft].orderID = 0; //set the NFT is not locked in order 

        // send the font minng rewards, use function
        fontReward(OrderBook[_order_id].price, OrderBook[_order_id].token, msg.sender);

        if(_withdraw) {
            NFTs[OrderBook[_order_id].nft].status = 2;
            FontNFT.safeTransferFrom(address(this), msg.sender, OrderBook[_order_id].nft, 1, '');            
        }

        _distributePayment(OrderBook[_order_id].price, OrderBook[_order_id].referral, OrderBook[_order_id].token, _ref,  OrderBook[_order_id].seller, _withdraw);


        //emit the event 
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

    //Anyone can call this price oracle and update price of any asset
    event OraclePriceUpdated(address, uint256);
    function updateOraclePrice(address _token) external {
        uint256 _amount = priceOracle.getFontRewardPrice(_token);
        if(_amount > 0) {
            FontRewardPerToken[_token] = _amount;
        }
        emit OraclePriceUpdated(_token, _amount);
    }


    /*************************************************************************/
    /***************************** Admin settings ****************************/
    /*************************************************************************/


    function adminEditPaymentToken(address _address, bool _status) external {
        require(hasRole(ADMIN_ROLE, msg.sender), "D");
        paymentTokens[_address] = _status;         
    }


    function withdrawFees(address _token) external {
        require(hasRole(ADMIN_ROLE, msg.sender), "D");
        uint256 _amount = commissionFees[_token];
        commissionFees[_token] = 0;
        IERC20(_token).safeTransfer(feesDistributionAddress, _amount);
    }

    function adminSettings(uint16 _maxRoyalityAllowed, uint256 _exchangeFees, address _feesDistributionAddress, address _priceOracle) external {
        require(hasRole(ADMIN_ROLE, msg.sender), "D");
        require(_maxRoyalityAllowed < 5000, "H");
        exchangeFees = _exchangeFees;
        feesDistributionAddress = _feesDistributionAddress;
        maxRoyalityAllowed = _maxRoyalityAllowed;
        priceOracle = FontRewardOracle(_priceOracle);
    }

    //@deploy: set all the price per token
    function setFontRewardPerToken(address _token, uint256 _amount) external {
        require(hasRole(ADMIN_ROLE, msg.sender), "D");
        FontRewardPerToken[_token] = _amount;
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
        return UserOrders[_user];
    }

    function viewOrderBids(uint256 _order_id) external view returns (uint256[] memory) {
        return AuctionBids[_order_id];
    }

    function viewPaymentMethod(address _token) external view returns (bool) {
        return paymentTokens[_token];
    }

    function viewFontRewards(address _user) external view returns (uint256) {
        return FontRewards[_user];
    }
    
    function viewEarnings(address _user, address _token) external view returns (uint256) {
        return ReferralFees[_user][_token];
    }


    /*************************************************************************/
    /********************************** Claims *******************************/
    /*************************************************************************/    
    
    //Claim ReferralFees 
    event EarningsClaimed(address, address, uint256);
    function claimEarnings(address _token) external {
        require(ReferralFees[msg.sender][_token] > 0, "A");
        uint256 _amount = ReferralFees[msg.sender][_token];
        ReferralFees[msg.sender][_token] = 0;
        IERC20(_token).safeTransfer(msg.sender, _amount);
        emit EarningsClaimed(msg.sender, _token, _amount);
    }

    //Font rewards from mining
    event RewardsClaimed(address, uint256);
    function claimFontRewards() external {
        require(FontRewards[msg.sender] > 0, 'N');
        uint256 _amount = FontRewards[msg.sender];  
        FontRewards[msg.sender] = 0;
        IERC20(fontERC20Address).safeTransfer(msg.sender, _amount);
        emit RewardsClaimed(msg.sender, _amount);
    }

    /*************************************************************************/
    /********************************* Helpers *******************************/
    /*************************************************************************/ 


    //Set the highest bid for order in order book
    //@todo test this 
    function _setOrderHighestBid(uint256 _order_id) internal {
        require(OrderBook[_order_id].status == 1, "NO");
        require(OrderBook[_order_id].auction, "NA");
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

    function _distributePayment(uint256 _amount, uint256 _refCommission, address _token, address _ref, address _seller, bool sendMoney) internal {
        
        uint256 _fees = 0;
        uint256 _tmp = 0;
        

        //Calculate exchange fee
        if(_token != fontERC20Address) {
            _tmp = _amount * exchangeFees / (10**4);
            commissionFees[_token] = commissionFees[_token] + _tmp;
            _fees = _fees + _tmp;
            _tmp = 0;
        }

        //Calculate Referral Fee
        if(_ref != 0x0000000000000000000000000000000000000000 && _refCommission > 0) {
            _tmp = _amount * _refCommission / (10**4);
            ReferralFees[_ref][_token] = ReferralFees[_ref][_token] + _tmp;
            _fees = _fees + _tmp;
        }

        //Send money to NFT seller
        if(sendMoney) {
            IERC20(_token).safeTransfer(_seller, (_amount - _fees));
        }

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

    //Calculate the font reward based on trade volume 
    function fontReward(uint256 _amount, address _token, address _buyer) internal {
        if(_amount > 0 && FontRewardPerToken[_token] > 0) {
            FontRewards[_buyer] = _amount / FontRewardPerToken[_token];
        }
    }


}

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
            NFTs[nft].creator = msg.sender;
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


    
    