pragma solidity ^0.8.0;


import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";


contract OwnershipExchange is Context, Ownable {

    using SafeMath for uint;
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    //Constants
    bytes4 _onERC721Received;
    bytes4 _onERC1155Received;
    bytes4 _onERC1155BatchReceived;

    address public rewardDistributionAddress;

    //Settings 
    uint256 _exchangeFees; //1% = 100
    IERC1155 fontNFTAddress = IERC1155(0x15790FD4AeEd8B28a02f72787C77B1Be43a196F5);

    //ERC20 token address for payments
    mapping (address => bool) public PaymentTokenContracts; 

    uint256 public OrderID; //Current order ID. Counter

    struct NFT {
        uint256 nftid; //NFT ID 
        uint256 royality; //Royality %. 1% = 100
        address creatror; // Royality receiver 
        uint8 status;//check if the NFT is under contract custudy 
    }

    struct Order {
        uint256 id; //Order id //@todo should we need it 
        uint256 nft; //NFT ID 
        uint256 qty; // quantity of this font nft (for now just 1) //@todo should we beed this
        uint256 price; //price for whole NFT, of acceptable price if its auction 
        uint256 minPrice; //Min price the bidding starts with
        uint256 highestBidID; //Highest bid id. 
        uint256 expires; //auction expires. 0 means non auction 
        uint8 status; //Order status : 1/open, 2/filled, 3/cancelled
        uint8 referral; //Affiliate commission percentage

        //For auction specific 
        address token; //ERC20 Token for payment     
        address seller; //creator address for royality 
        address buyer; //current owner of this nft         
    }    

    struct Auction {
        uint256 id;
        uint256 nft;
        uint256 MinPrice;
        uint256 price;
        uint256 token;
        uint256 deadline;
        uint256 referral;
        address owner;
        address buyer;        
        uint8 status;
    }

    struct Bids {
        uint256 id;
        uint256 auction;
        uint256 price;
        address bidder;
        uint8 status;
    }

    struct PaymentToken { 
        uint8 commission; //1% = 100
        bool status; //current status or this erc token
    }
    mapping (address => PaymentToken) public paymentTokens;
        

    mapping (uint256 => Order) private OrderBook;
    mapping (uint256 => uint256) private royality;
    mapping (uint256 => uint256) private nftVSorderid;

    //Constructors
    constructor() {

        //contract_owner = payable(_msgSender());
        //commission_address = payable(_msgSender());



        //Mandatory for contracts to return these strings to receive ERC1155 and ERC721
        _onERC721Received = bytes4(keccak256("onERC721Received(address,uint256,bytes)"));
        _onERC1155Received = bytes4(keccak256("onERC1155Received(address,address,uint256,uint256,bytes)"));
        _onERC1155BatchReceived = bytes4(keccak256("onERC1155BatchReceived(address,address,uint256[],uint256[],bytes)"));


    }    

    /*************************************************************************/
    /******************************** exchange *******************************/
    /*************************************************************************/
    
    function createOrder(uint256 _nft, uint256 _price, uint256 _royality, address _paymentToken, address _creator) public {
        require(nftVSorderid[_nft] == 0);
        
        uint256 _order_id = OrderID.add(1);

        OrderBook[_order_id].nft = _nft;
        OrderBook[_order_id].price = _price;
        OrderBook[_order_id].token = _paymentToken;
        OrderBook[_order_id].seller = msg.sender;
        OrderBook[_order_id].status = 1;
        
        //@todo royality based on creator / owner etc 
        //if()

        //@todo quantity 

        fontNFTAddress.safeTransferFrom(msg.sender, address(this), _nft, 1, '');


    }

    function editOrder() public {

    }

    function cancelOrder() public {

    }

    function buyOrder(uint256 _order_id) public {
        

    }


    /*************************************************************************/
    /******************************** Helpers ********************************/
    /*************************************************************************/



    /*************************************************************************/
    /*************************** Admin Settings ******************************/
    /*************************************************************************/

    //Set the admin fee
    function setFees(uint256 _fees) public onlyOwner {
        _exchangeFees = _fees;
    }

    //change the reward distribution address. 
    function rewardAddress(address _address) public onlyOwner {
        rewardDistributionAddress = _address;
    }
    
    //Add token address for the payment 
    function addTokenAddress(address _address) public onlyOwner {
        PaymentTokenContracts[_address] = true;
    }

    //Edit existing token address for payments
    function editTokenAddress(address _address, bool _status) public onlyOwner {
        PaymentTokenContracts[_address] = _status;
    }

    function withdrawFont(address _address) public onlyOwner {
        
    }

}
