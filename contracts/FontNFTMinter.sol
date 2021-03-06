// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";


interface IFontNFT {
    function mint(address to, uint256 id, uint256 amount, bytes memory data) external ;
    function mintBatch(address to, uint256[] memory ids, uint256[] memory amounts, bytes memory data) external ;
}

//user to ID to stats 


contract FontNFTMinter is AccessControl {
    using SafeMath for uint;    
    using SafeMath for uint8;
    using SafeMath for uint16;    
    using SafeMath for uint256;    
    using SafeERC20 for IERC20;

    bytes4 private _onERC1155Received;
    bytes4 private _onERC1155BatchReceived;

    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");

    bool public paused = false;

    //FONT NFT contract 
    IFontNFT FontNFT;

    struct NFT {
        bool status; //Status of this font 0 = not minter, 1 = minted 
        uint16 creator; //Real creator of this font. 
        uint32 qty; //reserverd default 1
    }
    mapping(uint256 => NFT) public NFTs;

    mapping(uint16 => address) private AddressUserID;



    uint32 chainID = 1;

    constructor(address _fontnft) {
        _setupRole(ADMIN_ROLE, msg.sender); // Assign admin role to contract creator
        FontNFT = IFontNFT(_fontnft);

        //Mandatory for contracts to return these strings to receive ERC1155 and ERC721
        _onERC1155Received = bytes4(keccak256("onERC1155Received(address,address,uint256,uint256,bytes)"));
        _onERC1155BatchReceived = bytes4(keccak256("onERC1155BatchReceived(address,address,uint256[],uint256[],bytes)"));

    }

    /***************************************************************************/
    /************************************ Admin ********************************/
    /***************************************************************************/     

    event UserAdded(address, uint16);
    function mapAddUser(address _address, uint16 _uid) external {
        require(hasRole(ADMIN_ROLE, msg.sender), "Denied");
        require(AddressUserID[_uid] == address(0), 'Exist');
        require(_uid > 0, '0');

        AddressUserID[_uid] = _address;
        emit UserAdded(_address, _uid);
    }

    event UserAddedBulk(uint256);
    function mapAddUserBulk(address[] calldata _address, uint16[] calldata _uid) external {
        require(hasRole(ADMIN_ROLE, msg.sender), "Denied");
        require(_address.length == _uid.length, "Mismatch");

        for(uint16 i = 0; i < _address.length; i++) {
            require(AddressUserID[_uid[i]] == address(0), 'Exist');
            AddressUserID[_uid[i]] = _address[i];
        }
        emit UserAddedBulk(_address.length);
    }

    event UserEdited(address, uint16);
    function mapEditUser(address _address, uint16 _uid) external {
        require(hasRole(ADMIN_ROLE, msg.sender), "Denied");
        require(AddressUserID[_uid] != address(0), 'Not Exist');
        require(_uid > 0, 'UID');

        AddressUserID[_uid] = _address;
        emit UserEdited(_address, _uid);
    }


    event Mapped(uint256 _nft_id);
    function mapNFT(uint256 _nft_id, uint16 creator, bool status, uint32 qty) external {
        require(hasRole(ADMIN_ROLE, msg.sender), "Denied");
        require(NFTs[_nft_id].qty == 0, "Exist");
        require(qty > 0, "Qty");
        require(_nft_id > 0, '0');

        NFTs[_nft_id].creator = creator;
        NFTs[_nft_id].status = status;
        NFTs[_nft_id].qty = qty;

        emit Mapped(_nft_id);
    }

    event MappedBulk(uint256);
    function mapNFTBulkStruct(uint256[] calldata _nft_ids, NFT[] calldata _nfts) external {
        require(hasRole(ADMIN_ROLE, msg.sender), "Denied");
        require(_nft_ids.length == _nfts.length && _nft_ids.length > 0);
        
        for(uint16 i = 0; i < _nft_ids.length; i++) {
            require(NFTs[_nft_ids[i]].qty == 0, "Exist");
            require(_nfts[i].qty > 0, "Qty");
            require(_nft_ids[i] > 0, "0");

            NFTs[_nft_ids[i]].creator = _nfts[i].creator;
            NFTs[_nft_ids[i]].status = _nfts[i].status;
            NFTs[_nft_ids[i]].qty = _nfts[i].qty;
        }
        
        emit MappedBulk(_nft_ids.length);
    }

    event MappedBulkPerUser(uint16, uint256);
    function mapNFTBulkPerUser(uint256[] memory _nft_ids, uint16 creator) external {
        require(hasRole(ADMIN_ROLE, msg.sender), "Denied");
        require(_nft_ids.length > 0, "length");
        require(creator > 0, "UID");
        
        for(uint16 i = 0; i < _nft_ids.length; i++) {
            require(NFTs[_nft_ids[i]].qty == 0, "Exist");
            require(_nft_ids[i] > 0, '0');

            NFTs[_nft_ids[i]].creator = creator;
            NFTs[_nft_ids[i]].status = false; //Set status to unminted
            NFTs[_nft_ids[i]].qty = 1; //Set qty 
        }
        emit MappedBulkPerUser(creator, _nft_ids.length);
    }

    
    //Think all the aspects before editing this
    event MapEdited(uint256);
    function editNFT(uint256 _nft_id, NFT calldata nft) external {
        require(hasRole(ADMIN_ROLE, msg.sender), "Denied");
        require(NFTs[_nft_id].qty > 0, "Not Exist");

        NFTs[_nft_id].creator = nft.creator;
        NFTs[_nft_id].status = nft.status; 
        NFTs[_nft_id].qty = nft.qty; 

        emit MapEdited(_nft_id);
    }

    event Pause(bool);
    function pause() external {
        require(hasRole(ADMIN_ROLE, msg.sender), "Denied");
        paused = true;
        emit Pause(paused);
    }

    function unpause() external {
        require(hasRole(ADMIN_ROLE, msg.sender), "Denied");
        paused = false;
        emit Pause(paused);
    }    

    function withdrawTokens(address _token, uint256 _amount) external {
        require(hasRole(ADMIN_ROLE, msg.sender), "Denied");
        IERC20(_token).safeTransfer(msg.sender, _amount);
    }

    function withdrawETH() external {
        require(hasRole(ADMIN_ROLE, msg.sender), "Denied");
        require(payable(msg.sender).send(address(this).balance));
    }


    /***************************************************************************/
    /************************************ Users ********************************/
    /***************************************************************************/     


    event NFTMinted(uint256);
    function mintNFT(uint256 _nft_id) external {
        require(!paused, "Paused");
        require(NFTs[_nft_id].qty > 0, "Not Exist");
        require(!NFTs[_nft_id].status, "Already");
        require(AddressUserID[NFTs[_nft_id].creator] == msg.sender, "Denied");

        //change the data to minted
        NFTs[_nft_id].status = true; 

        //mint the nft 
        FontNFT.mint(msg.sender, _nft_id, NFTs[_nft_id].qty, '');
        emit NFTMinted(_nft_id);
    }


    //Mint bulk NFTs by user
    event NFTMintedBulk(uint256, address);
    function mintNFTBulk(uint256[] calldata _nft_ids) external {
        require(!paused, "Paused");
        require(_nft_ids.length > 0, "length");

        uint256[] memory amounts = new uint256[](_nft_ids.length);
        
        for(uint256 i = 0; i < _nft_ids.length; i++) {
            require(NFTs[_nft_ids[i]].qty > 0, "Not Exist");
            require(!NFTs[_nft_ids[i]].status, "Already");
            require(AddressUserID[NFTs[_nft_ids[i]].creator] == msg.sender, "Denied");

            //Gather the amounts 
            amounts[i] = NFTs[_nft_ids[i]].qty; 

            //change the status to minted
            NFTs[_nft_ids[i]].status = true; 
        }
        FontNFT.mintBatch(msg.sender, _nft_ids, amounts, '');
        emit NFTMintedBulk(_nft_ids.length, msg.sender);
    }

    

    /***************************************************************************/
    /************************************ Views ********************************/
    /***************************************************************************/     

    //View NFT 
    function viewNFT(uint256 nft_id) external view returns (NFT memory) {
        return NFTs[nft_id];
    }

    function viewUser(uint16 _uid) external view returns (address) {
        return AddressUserID[_uid];
    }

    /***************************************************************************/
    /*********************************** Helpers *******************************/
    /***************************************************************************/ 

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