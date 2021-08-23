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


contract FontNFT721Tiny is Context, ERC721, ERC721URIStorage, ERC721Burnable, AccessControl, IERC721Receiver {

    using SafeERC20 for IERC20;


    //Address to distribute the Exchange fees, usually staking contract 
    //@Settings: yes
    address private feesDistributionAddress; 

    //FONT ERC20 Address
    //@Settings: yes
    //@deploy: change this per network 
    address private FontERC20Address; 

    //Settings: yes
    //Exchange commission
    uint256 private exchangeFees = 400; //1% = 100

    //Role for admin
    bytes32 private constant ADMIN_ROLE = keccak256("ADMIN_ROLE");

    //Maximum 50% royality allowed, 
    //@Settings: no
    uint16 private maxRoyalityAllowed = 5000; //1% = 100, so 25% is max royality


    struct NFT {

        bool auction; //If order id is auction or not 
        
        uint8 status;//check if the NFT is under contract custudy: 0 not exists, 1 under custody, 2 not under contract custody

        uint16 royality; //Royality %. 1% = 100
        uint16 referralCommission; //% of referral commission for current order
        
        address owner; // current owner of this nft when NFT is under custody 
        address token; // Payment ERC20 token for current order 

        uint256 orderID; //Current Order ID, 0 = not in order, this is needed for auction type orders but not needed for spot orders 
        uint256 price; //Current order price 
        uint256 minPrice; //min price if order is auction
        uint256 highestBidID; //Hisghed bid ID, if order is auction 
        
    }
    //List of NFTs
    mapping (uint256 => NFT) private NFTs;

    //real creator of the font who is eligible to mint the NFT, able to set and edit by admin, no use once it minted 
    mapping (uint256 => address) public OriginalNFTCreators;

    uint256 private OrderID = 1;

    //Bidding item stored here. 
    struct Bid {
        uint8 status; //Order status : 1/open, 2/filled, 3/cancelled
        address bidder; //Address of the bidder
        address referral; //referral address
        uint256 orderID; //ID of the order 
        uint256 offer; //Offer set be the bidder         
    }
    mapping (uint256 => Bid) private Bids;
    
    //Bids per order 
    mapping (uint256 => uint256[]) private AuctionBids;
    //Bid id counter
    uint256 private BidID = 1;    

    //Payment Tokens, ERC20 contract address
    mapping (address => bool) private paymentTokens;
        
    //Referral fees earned by user per token, subject to reset on claim 
    mapping (address => mapping(address => uint256)) private Earnings;

    //Commission fees earned by exchange, per token, subject to reset on withdrawan
    mapping (address => uint256) private commissionFees;

    //Font Rewards for buyers. Keep it only to buyers, no reward for sellers.
    mapping (address => uint256) private FontRewards;
    
    //Font rewards per token, this is set by admin later by oracle, make sure it should be using pull method  
    mapping (address => uint256) private FontRewardPerToken;

    //Reward Withdrawal pauasable
    bool private FontRewardPaused  = true;    

    //Orders per user
    //mapping (address => uint256[]) private UserOrders;


    //Constructors
    constructor(address _FontERC20Address, address _feesDistributionAddress) ERC721("Font NFT", "FONT"){
        //Assign admin role to contract creator
        _setupRole(ADMIN_ROLE, msg.sender); 
        //Set FONT ERC20 address
        FontERC20Address = _FontERC20Address;
        //Fees distribution address, contract address
        feesDistributionAddress = _feesDistributionAddress;
        //Add ETH as payment token
        paymentTokens[address(0)] = true;
        //Add FONT as Payment Token 
        paymentTokens[_FontERC20Address] = true;
    }    

    //Mint the NFT and transfer to minter
    function safeMint(uint256 nft, uint16 royality) external {
        _minter(msg.sender, nft, royality);
    }
    
    //Mint the NFT and transfer to address, should be used by admin 
    function safeMintTo(address to, uint256 nft, uint16 royality) external {
        //Admin can mint the NFT on behalf of Real owner, gas is on admin, because many admins 
        require(hasRole(ADMIN_ROLE, msg.sender), "D");
        _minter(to, nft, royality);
    }

    function _minter(address to, uint256 nft, uint16 royality) internal {
        require(
            //Make sure the NFT belongs to the creator
            OriginalNFTCreators[nft] == to             
            //Royality should not cross the limit 
            && royality < maxRoyalityAllowed, "D");

        //Set the NFT status, mint will move the NFT to owner wallet, so status is 2
        NFTs[nft].status = 2;
        //Mint the NFT to the owner 
        NFTs[nft].owner = to;
        //Set the royality     
        NFTs[nft].royality = royality;
        //Mint now
        _safeMint(to, nft);        

    }

    //Mint an NFT and create sell order with price, royality and commssion
    //Either Admin or real owner can mint it
    event OrderCreated(uint256);
    function safeMintAndList(uint256 nft, uint256 price, uint256 minPrice, uint16 royality, uint16 referral, address token, bool auction) external {

        require((
            //Only real creator of the font can mint it
            (OriginalNFTCreators[nft] == msg.sender || hasRole(ADMIN_ROLE, msg.sender))
            //Royality should be in allowed limit 
            && royality < maxRoyalityAllowed
            ), "D");

        //Real owner is the owner
        NFTs[nft].owner = OriginalNFTCreators[nft];
        //Royality for this NFT 
        NFTs[nft].royality = royality;
        //NFT is under contract custody, so cheers. 
        NFTs[nft].status = 1;
        //Create order
        _orderCreate(nft, price, minPrice, referral, token, auction);

        _safeMint(address(this), nft);

        emit OrderCreated(OrderID);
    }

    //@todo testing, check all the requirs, security check, change the status (like burned or to 0)
    function _burn(uint256 nft) internal override(ERC721, ERC721URIStorage) {
        
        require(
            ownerOf(nft) == msg.sender || //only the owner 
            (NFTs[nft].owner == msg.sender && NFTs[nft].status == 1), 'D'); //Only if nft is under custody can burn it
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
        //Only of NFT is already minted as well as not under custody of contract
        require(NFTs[nft].status == 2, 'NC');
        NFTs[nft].status = 1;
        NFTs[nft].owner = msg.sender;
        safeTransferFrom(msg.sender, address(this), nft);
    }
    //Move NFT from contract
    function moveNFTOut(uint256 nft) external {
        require(
            //Sender must be the owner of NFT
            (NFTs[nft].owner == msg.sender 
            //Can able to transfer only if NFT is under contract custody 
            && NFTs[nft].status == 1 
            //Can only able to transfer if NFT not locked in any Order 
            && NFTs[nft].orderID == 0), 'D');
        //Set the NFT status to not under custody 
        NFTs[nft].status = 2;
        _safeTransfer(address(this), msg.sender, nft, "");
    }

    //Update the NFT royalities in bulk
    //@done
    event RoyalitiesUpdated(uint256 nft);
    function updateRoyality(uint256 nft, uint16 royality) external {
        require(
            //Royality can be updated only if sender is owner of the NFT 
            (NFTs[nft].owner == msg.sender 
            //Royality can be updated only if sender is creator of the NFT 
            && OriginalNFTCreators[nft] == msg.sender
            //NFT should be under contract custody 
            && NFTs[nft].status == 1 
            //NFT should not locked in any order
            && NFTs[nft].orderID == 0 
            //Royality should be under control
            && royality <= maxRoyalityAllowed), 'D');

        NFTs[nft].royality = royality;
        emit RoyalitiesUpdated(nft);
    }

    /*************************************************************************/
    /******************************** exchange *******************************/
    /*************************************************************************/
    

    
    function orderCreate(uint256 nft, uint256 price, uint256 minPrice, uint16 referralCommission, address token, bool auction) external {
        //check all the requires

        require(
            //Check if NFT is under contract custody
            (NFTs[nft].status == 1 
            //Check if creator is owner
            && NFTs[nft].owner == msg.sender 
            //Check if NFT is not under any order 
            && NFTs[nft].orderID == 0), "D"); 
        
        _orderCreate(nft, price, minPrice, referralCommission, token, auction);
        emit OrderCreated(OrderID);
    }

    function _orderCreate(uint256 nft, uint256 price, uint256 minPrice, uint16 referralCommission, address token, bool auction) internal {

        require(
            //Check if payment token exists
            paymentTokens[token]
            //check if referral commission is not more than 80% 
            && referralCommission < 8000, "D");

        //Auction order have different need 
        if(auction) {

            //minPrice should be above 0
            require(minPrice > 0 && minPrice < price, "MP"); 
            
            //Auctions 
            NFTs[nft].minPrice = minPrice;
            NFTs[nft].auction = auction;            
        }        

        //Set the referral commission 
        NFTs[nft].referralCommission = referralCommission;

        //Set the price
        NFTs[nft].price = price;
        //Set the token 
        NFTs[nft].token = token;

        //Set the Current order of NFT id 
        NFTs[nft].orderID = OrderID;

        //Add the Order ID to user orders 
        //UserOrders[msg.sender].push(OrderID);

        //Increase the Order ID count to next ID
        OrderID++;     

    }
    
    //@done
    event OrderEdited(uint256 nft);
    function orderEdit(uint256 nft, uint256 price, uint256 minPrice, uint16 referralCommission, address token) external {

        require(
            //Only order owner can edit it 
            (NFTs[nft].owner == msg.sender 
            //Only Open order can be edited 
            && NFTs[nft].orderID > 0 
            //NFT must my under contract custody 
            && NFTs[nft].status == 1 
            //Referral commission should be over 80%
            && referralCommission < 8000), 'D');

        //Auction
        if(NFTs[nft].auction) {
            require(minPrice < price && minPrice > 0, 'M');
            NFTs[nft].minPrice = minPrice;
        }

        //Token can be edited only for spot orders and auctions orders witout single bid 
        if(!NFTs[nft].auction || NFTs[nft].highestBidID == 0) {
            require(paymentTokens[token]);
            NFTs[nft].token = token;
        }

        //Update the Order sell price
        NFTs[nft].price = price;
        //Update the referral commission
        NFTs[nft].referralCommission = referralCommission;

        emit OrderEdited(nft);
    }

    
    event OrderCanceled(uint256);
    function orderCancel(uint256 nft) external {

        require(
            //Only order creator can cancel it
            (NFTs[nft].owner == msg.sender 
            //Only open order can be canceled 
            && NFTs[nft].orderID > 0
            //Only NFT under contract custody can be cancled 
            && NFTs[nft].status == 1), 'D');

        //Auction, cancel all the bids
        if(NFTs[nft].auction) {
            //cancel all bids and refund it. 
            require(_orderBidsCancelAll(NFTs[nft].orderID, 0));        
        }
        //Cancel the order 
        _orderReset(nft);
        //Emit Event 
        emit OrderCanceled(nft);
    }

    //Helper function to cancel the order
    //@done
    function _orderReset(uint256 nft) internal {

        NFTs[nft].orderID = 0;
        NFTs[nft].price = 0;
        NFTs[nft].minPrice = 0;
        NFTs[nft].highestBidID = 0;
        NFTs[nft].referralCommission = 0;
        
        NFTs[nft].auction = false;
        NFTs[nft].token = address(0);
    }

    //@todo add ETH support
    event BidOrder(uint256 nft, uint256 _amount, uint256 _bid_id);
    function orderBid(uint256 nft, uint256 _amount, address _ref) external payable {
        
        require((
            //Can Bid only for open order 
            NFTs[nft].orderID > 0
            //Can bid only for auction orders 
            && NFTs[nft].auction
            //Can bid only if NFT is under contract custody 
            && NFTs[nft].status == 1
            //Can Bid only if amount is above min price 
            && NFTs[nft].minPrice < _amount
            //Can bid only if amount is above previous higher bid
            && Bids[NFTs[nft].highestBidID].offer < _amount
        ), 'D');

        uint256 _bid_id = BidID;

        Bids[_bid_id].orderID = NFTs[nft].orderID;
        Bids[_bid_id].bidder = msg.sender;
        Bids[_bid_id].offer = _amount;
        Bids[_bid_id].status = 1;

        //push the bid id to order id
        AuctionBids[NFTs[nft].orderID].push(_bid_id);

        //update the order with highest bid 
        NFTs[nft].highestBidID = _bid_id;

        //referral link
        if(_ref != address(0) && NFTs[nft].referralCommission > 0) {
            Bids[_bid_id].referral = _ref;
        }
        
        BidID++;

        //ITRC20(OrderBook[_order_id].token).safeTransferFrom(msg.sender, address(this), _amount);

        _receiveMoney(msg.sender, NFTs[nft].token, _amount);

        emit BidOrder(nft, _amount, _bid_id);

    }     


    event OrderBidApproved(uint256 _bid_id);
    function orderBidApprove(uint256 _bid_id, uint256 nft, bool _withdrawNFT) external {
        
        require(
            //Order should be open
            (NFTs[nft].orderID > 0
            //Order ID of bid and NFT should match 
            && NFTs[nft].orderID == Bids[_bid_id].orderID
            //Only able to approve open bids 
            && Bids[_bid_id].status == 1
            //NFT should be under contract custody 
            && NFTs[nft].status == 1
            //Only seller can approve it
            && NFTs[nft].owner == msg.sender
            //Only able to approve order of auction tyep 
            && NFTs[nft].auction), 'D');

        //update the bid 
        Bids[_bid_id].status = 2;

        //cancel all other bids 
        require(_orderBidsCancelAll(Bids[_bid_id].orderID, _bid_id));

        //move nft to buyer 
        if(_withdrawNFT) {
            NFTs[nft].status = 2;
            _safeTransfer(address(this), Bids[_bid_id].bidder, nft, '');            
        }
        else {
            NFTs[nft].status = 1;
        }

        //Distribute Money and distribute font
        _distributePayment(Bids[_bid_id].offer, nft, NFTs[nft].referralCommission, NFTs[nft].token, Bids[_bid_id].referral,  NFTs[nft].owner, Bids[_bid_id].bidder);

        //close the order 
        NFTs[nft].orderID = 0; //set the NFT is not locked in order 
        NFTs[nft].owner = Bids[_bid_id].bidder; //update the owner of NFT

        //emit the event 
        emit OrderBidApproved(_bid_id);
    }
  
    event BidCanceled(uint256);
    function orderBidCancel(uint256 _bid_id, uint256 nft) external {
        
        require((
            //only open bids can be cancled, other 2 bids are filled and cancled 
            Bids[_bid_id].status == 1 
            //Only bid owner able to cancel it
            && Bids[_bid_id].bidder == msg.sender
            //make sure the order is live 
            && NFTs[nft].orderID > 0
            //make sure the nft is under custody
            && NFTs[nft].status == 1
            //Order should be auction
            && NFTs[nft].auction
        ), 'D');

        Bids[_bid_id].status = 3;

        //Send the money
        _sendMoney(Bids[_bid_id].bidder, Bids[_bid_id].offer, NFTs[nft].token);        

        //@todo if a bid cancled, find highest bid and update the order book highest bid 
        _setOrderHighestBid(Bids[_bid_id].orderID);

        //emit
        emit BidCanceled(_bid_id);
    }

    function _orderBidsCancelAll(uint256 nft, uint256 _except) internal returns (bool){
        //@todo everything 
        
        require((
            //make sure the order is live 
            NFTs[nft].orderID > 0
            //make sure the nft is under custody
            && NFTs[nft].status == 1
            //Only Auction type
            && NFTs[nft].auction
            //check if order have enough bids 
            && AuctionBids[NFTs[nft].orderID].length > 0
        ), 'D');

        for(uint256 i = 0; i < AuctionBids[NFTs[nft].orderID].length; i++) {
            if(Bids[AuctionBids[NFTs[nft].orderID][i]].status == 1 && AuctionBids[NFTs[nft].orderID][i] != _except) {
                //Set the bit void
                Bids[AuctionBids[NFTs[nft].orderID][i]].status = 3;
                
                //Send money
                _sendMoney(Bids[AuctionBids[NFTs[nft].orderID][i]].bidder, Bids[AuctionBids[NFTs[nft].orderID][i]].offer, NFTs[nft].token);
                //Or should i send the money, so others can withdraw?

                delete Bids[AuctionBids[NFTs[nft].orderID][i]]; //@todo remove if this brings issue 
            }
        }
        NFTs[nft].highestBidID = 0;
        return true;
    }


    //Buy the spot order. 
    event OrderBought(uint256 nft);
    function orderBuy(uint256 nft, address _ref, bool _withdrawNFT) external payable {
        //allrequires 
        require((
            //Only if NFT is under custody
            NFTs[nft].status == 1
            //Only if order is live 
            && NFTs[nft].orderID > 0
            //Only of order is auction 
            && !NFTs[nft].auction), "D"); 
        
        //Get money from buyer and keep under contract custody
        _receiveMoney(msg.sender, NFTs[nft].token, NFTs[nft].price);
        //Buy the order, take money
        _orderBuy(nft, _ref, _withdrawNFT);
    }

    function orderBuyWithETH(uint256 nft, address _ref, bool _withdrawNFT) public payable {
        require ((
            //Check enough ETH
            msg.value >= NFTs[nft].price
            //Only ETH 
            && NFTs[nft].token == address(0)
            //Only for Live NFT
            && NFTs[nft].status == 1
            //Order type should not be auction.
            && !NFTs[nft].auction
            // Only for live order
            && NFTs[nft].status == 1
        ), 'D');

        _orderBuy(nft, _ref, _withdrawNFT);
    }

    function _orderBuy(uint256 nft, address _ref, bool _withdrawNFT) internal {
        //close the order 
        //Change the order status 
        //Update the order id to 0
        
        uint256 _order_id = NFTs[nft].orderID;
        uint256 _price = NFTs[nft].price;
        uint256 _referralCommission = NFTs[nft].referralCommission;
        address _currentOwner = NFTs[nft].owner;
        address _token = NFTs[nft].token;

        //Change the owner  
        NFTs[nft].owner = msg.sender;    
        //Reset NFT order data
        _orderReset(nft);
        //Distribute the payments
        _distributePayment(_price, nft, _referralCommission, _token, _ref, _currentOwner, msg.sender);  

        if(_withdrawNFT) {
            NFTs[nft].status = 2;
            _safeTransfer(address(this), msg.sender, nft, "");   
        }

        //@todo emit the event 
        emit OrderBought(_order_id);
        
    }





    /*************************************************************************/
    /***************************** Admin settings ****************************/
    /*************************************************************************/

    event EditedPaymentTokens(address  token, bool status, uint256 miningReward);
    function adminEditPaymentToken(address _address, bool _status, uint256 _rewardAmount) external {
        require(hasRole(ADMIN_ROLE, msg.sender), "D");
        //Edit the payment tokens 
        paymentTokens[_address] = _status;         
        if(_rewardAmount > 0) {
            //Set the font reward per ERC20 token
            FontRewardPerToken[_address] = _rewardAmount;
        }
        emit EditedPaymentTokens(_address, _status, _rewardAmount);
    }
    

    //Admin can withdraw fees to fees distribution address
    function withdrawFees(address _token) external {
        require(hasRole(ADMIN_ROLE, msg.sender), "D");
        
        uint256 _amount = commissionFees[_token];
        //Rest it to 0
        commissionFees[_token] = 0;

        //Send money
        _sendMoney(feesDistributionAddress, _amount, _token);
    }

    //All settings into single function 
    function adminSettings( uint256 _exchangeFees, address _feesDistributionAddress, address _FontERC20Address, bool _FontRewardPaused) external {
        require(hasRole(ADMIN_ROLE, msg.sender), "D");
        //require(_maxRoyalityAllowed < 5000, "H");
        //Exchange fees
        exchangeFees = _exchangeFees;
        //Staking address for fee distribution
        feesDistributionAddress = _feesDistributionAddress;
        //Set the maxiumum royality allowd
        //maxRoyalityAllowed = _maxRoyalityAllowed;
        //Set the $FONT ERC20 token address
        FontERC20Address = _FontERC20Address;
        //Set the font reward status 
        FontRewardPaused = _FontRewardPaused;
    }

    event UserAddedBulk(uint256);
    function mapAddUserBulk(address[] calldata _address, uint256[] calldata _nft) external {
        //Only admin can add this
        require(hasRole(ADMIN_ROLE, msg.sender), "D");
        //Data length check
        require(_address.length == _nft.length, "Mm");

        for(uint16 i = 0; i < _address.length; i++) {
            //NFT should not mapped already by admin
            require(OriginalNFTCreators[_nft[i]] == address(0), 'X');
            //Address should not be 0
            require(_address[i] != address(0), 'AD');
            //Map the NFT to author
            OriginalNFTCreators[_nft[i]] = _address[i];
        }
        emit UserAddedBulk(_address.length);
    }

    event UserEdited(address, uint256);
    function mapEditUser(address _address, uint256 _nft) external {
        require((
            //Only Admin can edit it
            hasRole(ADMIN_ROLE, msg.sender)
            //NFT should exist in map
            && OriginalNFTCreators[_nft] != address(0)
            //Should not able to edit after NFT is minted
            && NFTs[_nft].status == 0
            //NFT id should above 0
            && _nft > 0
        ), 'D');

        OriginalNFTCreators[_nft] = _address;
        emit UserEdited(_address, _nft);
    }

    /*************************************************************************/
    /*********************************** Views *******************************/
    /*************************************************************************/    

    //function viewOrder(uint256 _id) external view returns (Order memory) {
    //    return OrderBook[_id];
    //}

    function viewNFT(uint256 _id) external view returns (NFT memory) {
        return NFTs[_id];
    }    

    //function viewUserOrders(address _user) external view returns (uint256[] memory) {
    //    return UserOrders[_user];
    //}

    function viewPaymentMethod(address _token) external view returns (bool) {
        return paymentTokens[_token];
    }

    function viewEarnings(address _user, address _token) external view returns (uint256) {
        return Earnings[_user][_token];
    }

    function viewFontRewards(address _user) external view returns (uint256) {
        return FontRewards[_user];
    }

    function viewBid(uint256 _id) external view returns (Bid memory) {
        return Bids[_id];
    }


    /*************************************************************************/
    /********************************** Claims *******************************/
    /*************************************************************************/    
    
    //Claim Referral Fees or royality fees
    //@todo for ETH 
    event EarningsClaimed(address, address, uint256);
    function claimEarnings(address _token) external {
        //Claimer should have enough balance
        require(Earnings[msg.sender][_token] > 0, "A");
        uint256 _amount = Earnings[msg.sender][_token];
        Earnings[msg.sender][_token] = 0;
        //Send money
        _sendMoney(msg.sender, _amount, _token);
        emit EarningsClaimed(msg.sender, _token, _amount);
    }


    //Font rewards from mining
    event RewardsClaimed(address, uint256);
    function claimFontRewards() external {
        require(FontRewards[msg.sender] > 0 && !FontRewardPaused, 'N');
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
    function _setOrderHighestBid(uint256 nft) internal {

        require((
            //Order should be Live
            NFTs[nft].orderID > 0
            //Order type should be auction
            && NFTs[nft].auction
            //NFT should be under contract custody 
            && NFTs[nft].status == 1
            //There should be minimum 1 auction
            && AuctionBids[NFTs[nft].orderID].length > 0
        ), 'D');
        
        uint256 _highestBidID = 0;
        uint256 _highestBidOffer = 0;
        for(uint256 i = 0; i < AuctionBids[NFTs[nft].orderID].length; i++) {
            if(Bids[AuctionBids[NFTs[nft].orderID][i]].status == 1 && Bids[AuctionBids[NFTs[nft].orderID][i]].offer > _highestBidOffer) {
                _highestBidOffer = Bids[AuctionBids[NFTs[nft].orderID][i]].offer;
                _highestBidID = AuctionBids[NFTs[nft].orderID][i];
            }
        }
        NFTs[nft].highestBidID = _highestBidID;
    }


    //Take the order payment from buyer, distribute the money to refferal commisions and exchange commission fees and to sellers
    function _distributePayment(uint256 _amount, uint256 nft, uint256 _refCommission, address _token, address _refAddress, address _seller, address _buyer) internal {
        
        uint256 _fees = 0;
        uint256 _tmp = 0;
        
        //Calculate exchange fee, only for non FONT tokens and ETH
        if(_token != FontERC20Address) {
            //Calculate the exchange commission
            _tmp = (_amount * exchangeFees) / (10**4);
            //Add it to exchange commission collection, we can take it later 
            commissionFees[_token] += _tmp;
            //Add the commission to fees 
            _fees += _tmp;
            _tmp = 0;
        }

        //Calculate Referral Fee, only if referral fee set and referral address is non 0
        if(_refAddress != address(0) && _refCommission > 0) {
            //Calculate the referral commission for the amount 
            _tmp = (_amount * _refCommission) / (10**4);
            //Add commission fees to referrer balance 
            Earnings[_refAddress][_token] += _tmp;
            //Add Referral fess to total fees 
            _fees += _tmp;
            _tmp = 0;
        }

        //Take the Royality, if royality is above 0 and add it to royality collections 
        if(NFTs[nft].royality > 0) {
            //Calculate the royality in amount
            _tmp = (_amount * NFTs[nft].royality) / (10**4);
            //Add Royality fees to referrer balance 
            Earnings[OriginalNFTCreators[nft]][_token] += _tmp;
            //Add Referral fess to total fees 
            _fees += _tmp;            
            _tmp = 0;
        }

        //Font Rewards only of amount is greater than 0 and token have reward program
        if(_amount > 0 && FontRewardPerToken[_token] > 0) {
            //@todo test this calculation
            FontRewards[_buyer] += (_amount * 10**18) / FontRewardPerToken[_token];
        }        

        //Calculate Final amount for seller
        _tmp = _amount - _fees;

        //Send the money to buyer
        _sendMoney(_seller, _tmp, _token);
    }

    //Helper function to send money, either ERC20 token or ETH, 
    //@todo safety check
    function _sendMoney(address to, uint256 amount, address token) internal {
        //https://solidity-by-example.org/sending-ether/
        if(token == address(0)) {
            (bool sent, bytes memory data) = to.call{value: amount}("");
            require(sent, "EF");
        }
        else {
            IERC20(token).safeTransfer(to, amount);
        }
    }

    //Helper function to receive money, either ERC20 or ETH, 
    //@todo safety check
    function _receiveMoney(address from, address token, uint256 amount) internal {
        if(token == address(0)) {
            require(msg.value >= amount, 'ETH');
        }
        else {
            IERC20(token).safeTransferFrom(from, address(this), amount);
        }
    }


    function onERC721Received(address, address, uint256, bytes memory) public virtual override returns (bytes4) {
        return this.onERC721Received.selector;
    }

}
/* Error Codes: This is reduce the contract size 
/* 
    EF ETH failed to send
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



    
    