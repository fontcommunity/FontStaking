// SPDX-License-Identifier: MIT
// Author: https://twitter.com/adalquardz
// For Error explainations, see bottom of the page. 

//This is Admin Mapper + minter + exchange + NFT for non eth chains without auctions

pragma solidity ^0.8.0;



import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Burnable.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";


contract FontNFT721 is Context, ReentrancyGuard, ERC721, ERC721URIStorage, ERC721Burnable, AccessControl, IERC721Receiver {

    using SafeERC20 for IERC20;


    //Address to distribute the Exchange fees, usually staking contract 
    address private feesDistributionAddress;
    //Address of the contract owner
    address private ownerAddress;

    //FONT ERC20 Address
    address private FontERC20Address = 0x4C25Bdf026Ea05F32713F00f73Ca55857Fbf6342; //@deploy change this per network 

    //Settings 
    uint256 private exchangeFees = 400; //1% = 100

    //Role for admin
    bytes32 private constant ADMIN_ROLE = keccak256("ADMIN_ROLE");

    //Maximum 50% royality allowed, 
    uint16 private maxRoyalityAllowed = 2500; //1% = 100, so 25% is max royality

    struct NFT {
        uint256 orderID; //Current Order ID
        uint16 royality; //Royality %. 1% = 100
        uint8 status;//check if the NFT is under contract custudy: 0 not exists, 1 under custody, 2 went out of contract
        address owner; // current owner of this nft
        address creator; // Royality receiver or initial owner in this excange, no need to be original creator of this nft
    }
    mapping (uint256 => NFT) private NFTs;

    //real creator of the font who is eligible to mint 
    mapping (uint256 => address) private OriginalNFTCreators;

    struct Order {
        uint256 nft; //NFT ID [f]
        uint256 price; //price for whole NFT, of acceptable price if its auction [f]
        uint256 minPrice; //Min price the bidding starts with [f]
        uint256 highestBidID; //Highest bid id. 
        
        uint16 referral; //Affiliate commission percentage
        uint8 status; //Order status : 1/open, 2/filled, 3/cancelled
        bool auction; //Order type : 0/normal, 1/auction
        
        address token; //ERC20 Token for payment     
        address seller; //current owner of this nft         
        address buyer; //new owner who bought this 
    }    
    mapping (uint256 => Order) private OrderBook;


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
    
    //Font rewards per token 
    mapping (address => uint256) private FontRewardPerToken;

    //Orders per user
    mapping (address => uint256[]) private UserOrders;

    uint256 private OrderID = 1;



    //Constructors
    constructor() ERC721("Font NFT", "FONT"){
        _setupRole(ADMIN_ROLE, msg.sender); // Assign admin role to contract creator
        ownerAddress = msg.sender;

        //Add ETH as payment token
        paymentTokens[address(0)] = true;
    }    

    //Mint the NFT and transfer to minter
    function safeMint(uint256 nft) public {
        require(OriginalNFTCreators[nft] == msg.sender, "Denied");
        _safeMint(msg.sender, nft);
    }
    
    //Mint the NFT and transfer to address, can be used by admin 
    function safeMintTo(address to, uint256 nft) external {
        require(hasRole(ADMIN_ROLE, msg.sender), "D");
        require(OriginalNFTCreators[nft] == to, "Denied");
        _safeMint(to, nft);        
    }

    //Mint an NFT and create sell order with price, royality and commssion
    
    function safeMintAndList(uint256 nft, uint256 price, uint256 minPrice, uint16 royality, uint16 referral, address token, bool auction) external {

        require(OriginalNFTCreators[nft] == msg.sender, "Denied");

        if(auction) {
            require(minPrice > 0, "MP"); //minPrice should be above 0
        }
        //Create the NFT 
        NFTs[nft].creator = msg.sender;
        NFTs[nft].owner = msg.sender;
        NFTs[nft].royality = royality;
        NFTs[nft].status = 1;

        uint256 _order_id = _orderCreate(nft, price, minPrice, referral, token, auction);

        _safeMint(address(this), nft);
    }

    function _burn(uint256 nft) internal override(ERC721, ERC721URIStorage) {
        require(NFTs[nft].creator == msg.sender, 'D');
        require(NFTs[nft].owner == msg.sender, 'D'); //only the owner cum creator can burn it.
        super._burn(nft);
    }

    function tokenURI(uint256 nft) public view override(ERC721, ERC721URIStorage) returns (string memory) {
        return super.tokenURI(nft);
    }

    function supportsInterface(bytes4 interfaceId) public view override(ERC721, AccessControl) returns (bool) {
        return super.supportsInterface(interfaceId);
    }    

    /*************************************************************************/
    /******************************** Move NFT *******************************/
    /*************************************************************************/    
    //Move NFT into contract
    function moveNFTin(uint256 nft) external {
        require(NFTs[nft].status != 1, 'NC');
        NFTs[nft].status = 1;
        NFTs[nft].owner = msg.sender;
        safeTransferFrom(msg.sender, address(this), nft, "");
    }
    //Move NFT from contract
    function moveNFTOut(uint256 nft) external {
        require(
            (NFTs[nft].owner == msg.sender 
            && NFTs[nft].status == 1 
            && NFTs[nft].orderID == 0), 'D');

        NFTs[nft].status = 2;
        safeTransferFrom(address(this), msg.sender, nft, "");
    }

    //Update the NFT royalities in bulk
    //@done
    event RoyalitiesUpdated(uint256 nft);
    function updateRoyality(uint256 nft, uint16 royality) external {
        require(
            (NFTs[nft].owner == msg.sender 
            && NFTs[nft].creator == msg.sender 
            && NFTs[nft].status == 1 
            && NFTs[nft].orderID == 0 
            && royality <= maxRoyalityAllowed), 'D');

        NFTs[nft].royality = royality;
        emit RoyalitiesUpdated(nft);
    }

    /*************************************************************************/
    /******************************** exchange *******************************/
    /*************************************************************************/
    

    event OrderCreated(uint256);
    function orderCreate(uint256 nft, uint256 price, uint256 minPrice, uint16 referral, address token, bool auction) external {
        //check all the requires

        require(
            (NFTs[nft].status == 1 
            && NFTs[nft].owner == msg.sender 
            && NFTs[nft].orderID == 0 
            && paymentTokens[token] 
            && referral < 8000), "D");

        if(auction) {
            require(minPrice > 0, "MP"); //minPrice should be above 0
        }        
        
        uint256 _order_id = _orderCreate(nft, price, minPrice, referral, token, auction);
        emit OrderCreated(_order_id);
    }

    function _orderCreate(uint256 nft, uint256 price, uint256 minPrice, uint16 referral, address token, bool auction) internal returns (uint256){
        uint256 _order_id = OrderID;

        OrderBook[_order_id].nft = nft;
        OrderBook[_order_id].referral = referral;
        OrderBook[_order_id].status = 1;
        OrderBook[_order_id].price = price;
        OrderBook[_order_id].token = token;
        OrderBook[_order_id].seller = msg.sender;

        //Auctions 
        OrderBook[_order_id].minPrice = minPrice;
        OrderBook[_order_id].auction = auction;

        NFTs[nft].orderID = _order_id;

        UserOrders[msg.sender].push(_order_id);

        OrderID++;     

        return _order_id;                   
    }
    
    event OrderEdited(uint256 _order_id);
    function orderEdit(uint256 _order_id, uint256 price, uint256 minPrice, uint16 referral, address token) external {

        require(
            (OrderBook[_order_id].seller == msg.sender 
            && NFTs[OrderBook[_order_id].nft].owner == msg.sender 
            && OrderBook[_order_id].status == 1 
            && NFTs[OrderBook[_order_id].nft].status == 1 
            && referral < 8000), 'D');

        //Auction
        if(OrderBook[_order_id].auction) {
            require(minPrice < price && minPrice > 0, 'M');
            OrderBook[_order_id].minPrice = minPrice;
        }

        //Token can be edited only for spot orders and auctions orders witout singe bid 
        if(!OrderBook[_order_id].auction || OrderBook[_order_id].highestBidID == 0) {
            OrderBook[_order_id].token = token;
        }

        OrderBook[_order_id].price = price;
        OrderBook[_order_id].referral = referral;

        emit OrderEdited(_order_id);
    }

    
    event OrderCanceled(uint256);
    function orderCancel(uint256 _order_id) external {

        require(
            (OrderBook[_order_id].seller == msg.sender 
            && NFTs[OrderBook[_order_id].nft].owner == msg.sender 
            && OrderBook[_order_id].status == 1 
            && NFTs[OrderBook[_order_id].nft].status == 1), 'D');

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

    //@todo add ETH support
    event BidOrder(uint256 _order_id, uint256 _amount, uint256 _bid_id);
    function orderBid(uint256 _order_id, uint256 _amount, address _ref) external {
        
        require((
            OrderBook[_order_id].status == 1
            && OrderBook[_order_id].auction
            && NFTs[OrderBook[_order_id].nft].status == 1
            && OrderBook[_order_id].minPrice < _amount
            && Bids[OrderBook[_order_id].highestBidID].offer < _amount
        ), 'D');

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
        if(_ref != address(0) && OrderBook[_order_id].referral > 0) {
            Bids[BidID].referral = _ref;
        }
        BidID++;

        IERC20(OrderBook[_order_id].token).safeTransferFrom(msg.sender, address(this), _amount);

        emit BidOrder(_order_id, _amount, BidID - 1);

    }    

    //@todo add ETH support
    event BidTopuped(uint256, uint256, uint256);
    function orderBidTopup(uint256 _bid_id, uint256 _amount) external {        
        require((
            //make sure the bidder is the owner of the bid 
            Bids[_bid_id].bidder == msg.sender
            //make sure the order is live 
            && OrderBook[Bids[_bid_id].orderID].status == 1
            //Only Auction type
            && OrderBook[Bids[_bid_id].orderID].auction
            //make sure the nft is under custody
            && NFTs[OrderBook[Bids[_bid_id].orderID].nft].status == 1
            //old amount and new amount should be higher than highest bid
            && (Bids[_bid_id].offer + _amount) > Bids[OrderBook[Bids[_bid_id].orderID].highestBidID].offer
        ), 'D');

        uint256 _order_id = Bids[_bid_id].orderID;

        //update offer to new amount 
        Bids[_bid_id].offer += _amount;

        //update the highestBidID to the order 
        OrderBook[_order_id].highestBidID = _bid_id;

        IERC20(OrderBook[_order_id].token).safeTransferFrom(msg.sender, address(this), _amount);

        emit BidTopuped(_order_id, _bid_id, _amount);
    }    


    event OrderBidApproved(uint256 _bid_id);
    function orderBidApprove(uint256 _bid_id, bool _withdrawNFT) external {
        
        require(
            (OrderBook[Bids[_bid_id].orderID].status == 1
            && NFTs[OrderBook[Bids[_bid_id].orderID].nft].status == 1
            && OrderBook[Bids[_bid_id].orderID].seller == msg.sender
            && OrderBook[Bids[_bid_id].orderID].auction), 'D');

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
            safeTransferFrom(address(this), Bids[_bid_id].bidder, OrderBook[Bids[_bid_id].orderID].nft, '');            
        }
        else {
            NFTs[OrderBook[Bids[_bid_id].orderID].nft].status = 1;
        }

        //Distribute Money and distribute font
        _distributePayment(Bids[_bid_id].offer, OrderBook[Bids[_bid_id].orderID].referral, OrderBook[Bids[_bid_id].orderID].token, Bids[_bid_id].referral,  OrderBook[Bids[_bid_id].orderID].seller, Bids[_bid_id].bidder);

        //emit the event 
        emit OrderBidApproved(_bid_id);
    }

    
    event BidCanceled(uint256);
    function orderBidCancel(uint256 _bid_id) external {
        
        require((
            //only open bids can be cancled, other 2 bids are filled and cancled 
            Bids[_bid_id].status == 1 
            //Only bid owner able to cancel it
            && Bids[_bid_id].bidder == msg.sender
            //make sure the order is live 
            && OrderBook[Bids[_bid_id].orderID].status == 1
            //make sure the nft is under custody
            && NFTs[OrderBook[Bids[_bid_id].orderID].nft].status == 1
            //Order should be auction
            && OrderBook[Bids[_bid_id].orderID].auction
        ), 'D');

        Bids[_bid_id].status = 3;

        IERC20(OrderBook[Bids[_bid_id].orderID].token).safeTransfer(Bids[_bid_id].bidder, Bids[_bid_id].offer);

        //@todo if a bid cancled, find highest bid and update the order book highest bid 
        _setOrderHighestBid(Bids[_bid_id].orderID);

        //@todo emit
        emit BidCanceled(_bid_id);
    }



    //Buy the spot order. 
    event OrderBought(uint256 _order_id);
    function orderBuy(uint256 _order_id, address _ref, bool _withdrawNFT) external {
        //allrequires 
        require(NFTs[OrderBook[_order_id].nft].status == 1, "NC"); 
        require(OrderBook[_order_id].status == 1);


        IERC20(OrderBook[_order_id].token).safeTransferFrom(msg.sender, address(this), OrderBook[_order_id].price);


        _orderBuy(_order_id, _ref, _withdrawNFT);
    }

    function orderBuyWithETH(uint256 _order_id, address _ref, bool _withdrawNFT) public payable nonReentrant {
        require ((
            //Check enough ETH
            msg.value >= OrderBook[_order_id].price
            //Only ETH 
            && OrderBook[_order_id].token == address(0)
            //Only for Live NFT
            && NFTs[OrderBook[_order_id].nft].status == 1
            // Only for live order
            && OrderBook[_order_id].status == 1
        ), 'D');

        _orderBuy(_order_id, _ref, _withdrawNFT);
    }

    function _orderBuy(uint256 _order_id, address _ref, bool _withdrawNFT) internal {
        //close the order 
        OrderBook[_order_id].status = 2; //2 means order filled 
        OrderBook[_order_id].buyer = msg.sender; //update the buyer 

        //change the NFT struct 
        NFTs[OrderBook[_order_id].nft].owner = msg.sender; //update the owner of NFT
        NFTs[OrderBook[_order_id].nft].orderID = 0; //set the NFT is not locked in order 

        if(_withdrawNFT) {
            NFTs[OrderBook[_order_id].nft].status = 2;
            safeTransferFrom(address(this), msg.sender, OrderBook[_order_id].nft, "");            
        }

        _distributePayment(OrderBook[_order_id].price, OrderBook[_order_id].referral, OrderBook[_order_id].token, _ref,  OrderBook[_order_id].seller, msg.sender);


        //@todo emit the event 
        emit OrderBought(_order_id);
        
    }



    function orderBidsCancelAll(uint256 _order_id, uint256 _except) internal returns (bool){
        //@todo everything 
        
        require((
            //make sure the order is live 
            OrderBook[_order_id].status == 1
            //make sure the nft is under custody
            && NFTs[OrderBook[_order_id].nft].status == 1
            //Only Auction type
            && OrderBook[_order_id].auction
            //check if order have enough bids 
            && AuctionBids[_order_id].length > 0
        ), 'D');

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


    /*************************************************************************/
    /***************************** Admin settings ****************************/
    /*************************************************************************/


    function adminEditPaymentToken(address _address, bool _status) external {
        require(hasRole(ADMIN_ROLE, msg.sender), "D");
        paymentTokens[_address] = _status;         
    }

    //Admin can withdraw fees to fees distribution address
    function withdrawFees(address _token) external {
        require(hasRole(ADMIN_ROLE, msg.sender), "D");
        uint256 _amount = commissionFees[_token];
        commissionFees[_token] = 0;
        IERC20(_token).safeTransfer(feesDistributionAddress, _amount);
    }

    function adminSettings(uint16 _maxRoyalityAllowed, uint256 _exchangeFees, address _feesDistributionAddress, address _FontERC20Address) external {
        require(hasRole(ADMIN_ROLE, msg.sender), "D");
        require(_maxRoyalityAllowed < 5000, "H");
        
        exchangeFees = _exchangeFees;
        feesDistributionAddress = _feesDistributionAddress;
        maxRoyalityAllowed = _maxRoyalityAllowed;
        FontERC20Address = _FontERC20Address;
    }

    event UserAddedBulk(uint256);
    function mapAddUserBulk(address[] calldata _address, uint256[] calldata _nft) external {
        require(hasRole(ADMIN_ROLE, msg.sender), "D");
        require(_address.length == _nft.length, "Mm");

        for(uint16 i = 0; i < _address.length; i++) {
            require(OriginalNFTCreators[_nft[i]] == address(0), 'X');
            require(_address[i] != address(0), 'AD');
            OriginalNFTCreators[_nft[i]] = _address[i];
        }
        emit UserAddedBulk(_address.length);
    }

    event UserEdited(address, uint256);
    function mapEditUser(address _address, uint256 _nft) external {
        require(hasRole(ADMIN_ROLE, msg.sender), "D");
        require(OriginalNFTCreators[_nft] != address(0), 'NX');
        require(_nft > 0, 'UID');

        OriginalNFTCreators[_nft] = _address;
        emit UserEdited(_address, _nft);
    }

    /*************************************************************************/
    /*********************************** Views *******************************/
    /*************************************************************************/    

    function viewOrder(uint256 _id) external view returns (Order memory) {
        return OrderBook[_id];
    }

    function viewNFT(uint256 _id) external view returns (NFT memory) {
        return NFTs[_id];
    }    

    function viewUserOrders(address _user) external view returns (uint256[] memory) {
        return UserOrders[_user];
    }

    function viewPaymentMethod(address _token) external view returns (bool) {
        return paymentTokens[_token];
    }

    function viewEarnings(address _user, address _token) external view returns (uint256) {
        return ReferralFees[_user][_token];
    }

    function viewBid(uint256 _id) external view returns (Bid memory) {
        return Bids[_id];
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
        IERC20(FontERC20Address).safeTransfer(msg.sender, _amount);
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


    //Take the order payment, distribute the money to refferal commisions and exchange commission fees 
    function _distributePayment(uint256 _amount, uint256 _refCommission, address _token, address _ref, address _seller, address _buyer) internal {
        
        uint256 _fees = 0;
        uint256 _tmp = 0;
        

        //Calculate exchange fee
        if(_token != FontERC20Address) {
            _tmp = _amount * exchangeFees / (10**4);
            commissionFees[_token] += _tmp;
            _fees += _tmp;
            _tmp = 0;
        }

        //Calculate Referral Fee
        if(_ref != address(0) && _refCommission > 0) {
            _tmp = _amount * _refCommission / (10**4);
            ReferralFees[_ref][_token] += _tmp;
            _fees += _tmp;
        }

        _tmp = _amount - _fees;

        if(_token == address(0)) { //Send ETH
            payable(_seller).transfer(_tmp);
        }
        else { //Send  ERC20 token
            IERC20(_token).safeTransfer(_seller,_tmp);
        }

        //Font Rewards
        if(_amount > 0 && FontRewardPerToken[_token] > 0) {
            FontRewards[_buyer] = _amount / FontRewardPerToken[_token];
        }
    }



    function onERC721Received(address, address, uint256, bytes memory) public virtual override returns (bytes4) {
        return this.onERC721Received.selector;
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



    
    