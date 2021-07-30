// SPDX-License-Identifier: MIT
// Author: https://twitter.com/adalquardz
// For Error explainations, see bottom of the page. 

//This is Admin Mapper + minter + exchange + NFT + bridge? for non eth chains without auctions

pragma solidity ^0.8.0;



import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Burnable.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";


contract FontNFT721 is Context, ERC721, ERC721URIStorage, ERC721Burnable, AccessControl, IERC721Receiver {

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


    mapping (uint256 => address) private OriginalNFTCreators;

    struct Order {
        uint256 nft; //NFT ID [f]
        uint256 price; //price for whole NFT, of acceptable price if its auction [f]
        uint16 referral; //Affiliate commission percentage
        uint8 status; //Order status : 1/open, 2/filled, 3/cancelled
        address token; //ERC20 Token for payment     
        address seller; //current owner of this nft         
        address buyer; //new owner who bought this 
    }    
    mapping (uint256 => Order) private OrderBook;

    //Payment Tokens 
    mapping (address => bool) private paymentTokens;
        
    //Referral fees earned per user per token, subject to reset on claim 
    mapping (address => mapping(address => uint256)) private ReferralFees;

    //Commission fees earned by exchange, per token so for, subject to reset on claim
    mapping (address => uint256) private commissionFees;

    //Orders per user
    mapping (address => uint256[]) private UserOrders;

    uint256 private OrderID = 1;

    //Constructors
    constructor() ERC721("Font NFT", "FONT"){
        _setupRole(ADMIN_ROLE, msg.sender); // Assign admin role to contract creator
        ownerAddress = msg.sender;
    }    

    //Mint and NFT and transfer to minter
    function safeMint(address to, uint256 nft) public {
        require(OriginalNFTCreators[nft] == msg.sender, "Denied");

        _safeMint(to, nft);
    }

    //Mint an NFT and create sell order with price, royality and commssion
    function safeMintAndList(uint256 nft, uint256 price, uint16 royality, uint16 referralCommision, address token) external {

        require(OriginalNFTCreators[nft] == msg.sender, "Denied");

        //Create the NFT 
        NFTs[nft].creator = msg.sender;
        NFTs[nft].owner = msg.sender;
        NFTs[nft].royality = royality;
        NFTs[nft].status = 1;

        //Create the order 
        if(price > 0) {
            OrderBook[OrderID].nft = nft;
            OrderBook[OrderID].referral = referralCommision;
            OrderBook[OrderID].status = 1;
            OrderBook[OrderID].price = price;
            OrderBook[OrderID].token = token;
            OrderBook[OrderID].seller = msg.sender;

            NFTs[nft].orderID = OrderID;        

            UserOrders[msg.sender].push(OrderID);
            OrderID++;
        }
        _safeMint(address(this), nft);
    }

    function _burn(uint256 nft) internal override(ERC721, ERC721URIStorage) {
        require(NFTs[nft].creator == msg.sender, 'D');
        require(NFTs[nft].owner == msg.sender, 'D'); //only the owner and creator can burn it.
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

    function moveNFTin(uint256 nft) external {
        require(NFTs[nft].status != 1, 'NC');

        NFTs[nft].status = 1;
        NFTs[nft].owner = msg.sender;

        safeTransferFrom(msg.sender, address(this), nft, "");
    }

    function moveNFTOut(uint256 nft) external {
        require(NFTs[nft].owner == msg.sender, 'D');
        require(NFTs[nft].status == 1, 'NC');
        require(NFTs[nft].orderID == 0, 'CO');
        NFTs[nft].status = 2;
        safeTransferFrom(address(this), msg.sender, nft, "");
    }


    //Update the NFT royalities in bulk
    //@done
    event RoyalitiesUpdated(uint256 nft);
    function updateRoyality(uint256 nft, uint16 royality) external {
        require(ownerOf(nft) == msg.sender, 'D');
        require(NFTs[nft].status == 1, 'NC');
        require(NFTs[nft].creator == msg.sender, 'D');
        require(royality <= maxRoyalityAllowed, 'H');
        NFTs[nft].royality = royality;
        emit RoyalitiesUpdated(nft);
    }

    /*************************************************************************/
    /******************************** exchange *******************************/
    /*************************************************************************/
    

    event OrderCreated(uint256);
    function orderCreate(uint256 nft, uint256 price, uint16 referral, address token) external {
        //check all the requires
        require(NFTs[nft].status == 1, 'NC');
        require(NFTs[nft].owner == msg.sender, 'D');
        require(NFTs[nft].orderID == 0, 'IO');
        require(paymentTokens[token], 'T');
        require(referral < 8000, 'R');
        
        uint256 _order_id = OrderID;


        //Common settings for both the types 
        OrderBook[_order_id].nft = nft;
        
        OrderBook[_order_id].referral = referral;
        OrderBook[_order_id].status = 1;
        OrderBook[_order_id].price = price;
        
        OrderBook[_order_id].token = token;
        OrderBook[_order_id].seller = msg.sender;

        NFTs[nft].orderID = _order_id;

        UserOrders[msg.sender].push(_order_id);

        OrderID++;
        emit OrderCreated(_order_id);
    }
    
    event OrderEdited(uint256 _order_id);
    function orderEdit(uint256 _order_id, uint256 price, uint16 referral, address token) external {
        require(OrderBook[_order_id].seller == msg.sender, "D");
        require(NFTs[OrderBook[_order_id].nft].owner == msg.sender, "D");        
        require(OrderBook[_order_id].status == 1, "NO");
        require(NFTs[OrderBook[_order_id].nft].status == 1, "NC");

        OrderBook[_order_id].price = price;
        OrderBook[_order_id].token = token;
        OrderBook[_order_id].referral = referral;

        emit OrderEdited(_order_id);
    }

    
    event OrderCanceled(uint256);
    function orderCancel(uint256 _order_id) external {
        require(OrderBook[_order_id].seller == msg.sender, "D");
        require(NFTs[OrderBook[_order_id].nft].owner == msg.sender, "D");
        require(OrderBook[_order_id].status == 1, "NO");
        require(NFTs[OrderBook[_order_id].nft].status == 1, "NC");

        //update the order to cancled
        OrderBook[_order_id].status = 3;
        //update the nft book
        NFTs[OrderBook[_order_id].nft].orderID = 0;

        
        emit OrderCanceled(_order_id);
    }

    //Buy the spot order. 
    event OrderBought(uint256 _order_id);
    function orderBuy(uint256 _order_id, address _ref, bool _withdraw) external {
        //allrequires 
        require(NFTs[OrderBook[_order_id].nft].status == 1, "NC"); 
        require(OrderBook[_order_id].status == 1);

        //Take money from buyer 
        IERC20(OrderBook[_order_id].token).safeTransferFrom(msg.sender, address(this), OrderBook[_order_id].price);

        //close the order 
        OrderBook[_order_id].status = 2; //2 means order filled 
        OrderBook[_order_id].buyer = msg.sender; //update the buyer 

        //change the NFT struct 
        NFTs[OrderBook[_order_id].nft].owner = msg.sender; //update the owner of NFT
        NFTs[OrderBook[_order_id].nft].orderID = 0; //set the NFT is not locked in order 

        if(_withdraw) {
            NFTs[OrderBook[_order_id].nft].status = 2;
            safeTransferFrom(address(this), msg.sender, OrderBook[_order_id].nft, "");            
        }

        _distributePayment(OrderBook[_order_id].price, OrderBook[_order_id].referral, OrderBook[_order_id].token, _ref,  OrderBook[_order_id].seller, _withdraw);


        //@todo emit the event 
        emit OrderBought(_order_id);
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

    function adminSettings(uint16 _maxRoyalityAllowed, uint256 _exchangeFees, address _feesDistributionAddress, address _FontERC20Address) external {
        require(hasRole(ADMIN_ROLE, msg.sender), "D");
        require(_maxRoyalityAllowed < 5000, "H");
        exchangeFees = _exchangeFees;
        feesDistributionAddress = _feesDistributionAddress;
        maxRoyalityAllowed = _maxRoyalityAllowed;
        FontERC20Address = _FontERC20Address;
    }


    event UserAdded(address, uint256);
    function mapAddUser(address _address, uint256 _nft) external {
        require(hasRole(ADMIN_ROLE, msg.sender), "Denied");
        require(OriginalNFTCreators[_nft] == address(0), 'Exist');
        require(_nft > 0, '0');

        OriginalNFTCreators[_nft] = _address;

        emit UserAdded(_address, _nft);
    }

    event UserAddedBulk(uint256);
    function mapAddUserBulk(address[] calldata _address, uint256[] calldata _nft) external {
        require(hasRole(ADMIN_ROLE, msg.sender), "Denied");
        require(_address.length == _nft.length, "Mismatch");

        for(uint16 i = 0; i < _address.length; i++) {
            require(OriginalNFTCreators[_nft[i]] == address(0), 'Exist');
            OriginalNFTCreators[_nft[i]] = _address[i];
        }
        emit UserAddedBulk(_address.length);
    }

    event UserEdited(address, uint256);
    function mapEditUser(address _address, uint256 _nft) external {
        require(hasRole(ADMIN_ROLE, msg.sender), "Denied");
        require(OriginalNFTCreators[_nft] != address(0), 'Not Exist');
        require(_nft > 0, 'UID');

        OriginalNFTCreators[_nft] = _address;
        emit UserEdited(_address, _nft);
    }




    event MappedBulkPerUser(address, uint256);
    function mapNFTBulkPerUser(uint256[] memory _nft_ids, address creator) external {
        require(hasRole(ADMIN_ROLE, msg.sender), "Denied");
        require(_nft_ids.length > 0, "length");
        require(creator != address(0), "UID");
        
        for(uint16 i = 0; i < _nft_ids.length; i++) {
            require(OriginalNFTCreators[_nft_ids[i]] == address(0), "Exist");
            require(_nft_ids[i] > 0, '0');

            OriginalNFTCreators[_nft_ids[i]] = creator;
        }
        emit MappedBulkPerUser(creator, _nft_ids.length);
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

    

    /*************************************************************************/
    /********************************* Helpers *******************************/
    /*************************************************************************/ 

    function _distributePayment(uint256 _amount, uint256 _refCommission, address _token, address _ref, address _seller, bool sendMoney) internal {
        
        uint256 _fees = 0;
        uint256 _tmp = 0;
        

        //Calculate exchange fee
        if(_token != FontERC20Address) {
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



    
    