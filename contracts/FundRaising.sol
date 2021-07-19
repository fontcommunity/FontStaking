// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";


contract FontFundraising is AccessControl {

    using SafeMath for uint;    
    using SafeMath for uint8;
    using SafeMath for uint16;    
    using SafeMath for uint256;    
    using SafeERC20 for IERC20;

    /**********************************************************************************************************/
    /**********************************************   Variables  **********************************************/
    /**********************************************************************************************************/

    /*********** Settings ************/

    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");

    bytes4 private _onERC1155Received;
    bytes4 private _onERC1155BatchReceived;

    address private ownerAddress;
    address private deadAddress = 0x000000000000000000000000000000000000dEaD;
    address private font_token_address = 0x4C25Bdf026Ea05F32713F00f73Ca55857Fbf6342; //token address of the font
    

    uint256 private maxFundraisingDuration = 864000; //10 days 
    uint256 private taxFee = 750; //1% = 100
    uint256 private commissionFees = 100; //1% = 100
    address private fontStakingContract;

    uint256 private taxTotal;


    uint256 private ProjectID = 1;
    IERC20 private FONTERC20 = IERC20(font_token_address);


    struct Project {
        uint256 softcap;
        uint256 hardcap;
        uint256 raised; //Amount raised so for 
        uint256 released; //Amount released so for
        uint256 dateStart;
        uint256 duration;
        uint256 maxContrib;
        uint256 nftID; //ID of the NFT s
        uint16 milestone; // % of release per month 1% = 100, max 10000
        uint8 status; //0 = draft, 1 = started and in progress, 2 = filled, 3 = closed...
        address payment; // any erc20 token 
        address owner;
        bool disinvesment; 
        
    }

    

    //Project Status codes 
    // 00 = Draft (Defualt stage when creating)
    // 01 = In progress (able to invest, able to cancel it, disinvesment, ) (from 0,4)
    // 02 = success: atleast soft cap reached in time (from 1)
    // 03 = failed: cant reach the softcap in time (from 1(r))
    // 04 = canceled by owner or admin (0,1(r),3,4)
    

    mapping (uint256 => Project) private Projects;
    //ProjectID => amount
    mapping (uint256 => uint256) private Boost;

    //NFT id => Project
    mapping (uint256 => uint256) private NFT_Project;
    
    //User => project => amount
    mapping (address => mapping(uint256 => uint256)) private UserContributions;
    //User => project => amount
    mapping (address => mapping(uint256 => uint256)) private UserContributionRefund;


    constructor() {
        //Mandatory for contracts to return these strings to receive ERC1155 and ERC721
        _onERC1155Received = bytes4(keccak256("onERC1155Received(address,address,uint256,uint256,bytes)"));
        _onERC1155BatchReceived = bytes4(keccak256("onERC1155BatchReceived(address,address,uint256[],uint256[],bytes)"));
        

        _setupRole(ADMIN_ROLE, msg.sender); // Assign admin role to contract creator

    }


    /***************************************************************************/
    /*********************************** Projects ******************************/
    /***************************************************************************/    

    event ProjectCreated(uint256, string);
    function projectCreate(Project calldata _project, string calldata ipfs) external {
        //Require to edit        
        _projectEditRequire(_project);

        uint256 _project_id = ProjectID; 
        Projects[_project_id] = _project;
        ProjectID++;

        //Move the NFT into Contract Custody 
        ProjectCreated(_project_id, ipfs);
    }

    

    //Can able to edit only of project status is 0
    event ProjectEdited(uint256, string);
    function projectEdit(uint256 _project_id, Project calldata _project, string calldata ipfs) external {
        //Require to edit 
        _projectEditRequire(_project);
        Projects[_project_id] = _project;
        //only if status is 0
        emit ProjectEdited(_project_id, ipfs);
    }

    event ProjectStarted(uint256, uint256);
    function projectStart(uint256 _project_id, uint256 dateStart, uint256 _boostAmount) external {

        _projectEditRequire(Projects[_project_id]);
        //Set status 
        Projects[_project_id].status = 1;
        //Set start date
        Projects[_project_id].dateStart = dateStart;

        //Boost up 
        if(_boostAmount > 0) {
            projectBoost(_project_id, _boostAmount);
        }
        
        //emit 
        emit ProjectStarted(_project_id, dateStart);
    }

    event ProjectCanceled(uint256);
    function projectCancel(uint256 _project_id) external {
        //only owner or admin can cancel it
        require((Projects[_project_id].owner == msg.sender || hasRole(ADMIN_ROLE, msg.sender)), 'D');

        //draft or live project can be cancled 
        require(Projects[_project_id].status < 2, 'S');

        //canceling live project need distribution of money to user.
        if(Projects[_project_id].raised > 0) {
            projectRefund(_project_id);            
        }

        //update the status 
        Projects[_project_id].status = 4;

        //emit 
        emit ProjectCanceled(_project_id);
    }
    

    function projectRefund(uint256 _project_id) external {
        //only cancled project and failed projects can able to refund money 
        //Anyone can call it. 
        //Caller will earn nothing or something?
        //refunds are self claimable (to solve the large amount of loop and gas)
        //mark the 
    }

    
    event ProjectBoosted(uint256, uint256);
    function projectBoost(uint256 _project_id, uint256 _amount) public {
        require(_amount > 0);
        Boost[_project_id] = Boost[_project_id].add(_amount);
        FONTERC20.safeTransferFrom(msg.sender, deadAddress, _amount);

        emit ProjectBoosted(_project_id, Boost[_project_id]);
    }    

    function projectGetStatus(uint256 _project_id) external returns (uint8) {
        //@todo requires 

        //can get only status of ongoing project
        require(Projects[_project_id].status == 1, 'S');

        //Time expires and goal reached 
        if((Projects[_project_id].dateStart + Projects[_project_id].duration) < block.timestamp) {
            
            //goal Reached 

            //Goal not reached 
            Projects[_project_id].status = 3;
        }

        //time not expired yet

        //

        
    }

    function _projectRefund(uint256 _project_id) internal {
        //check all requires
        //move the money from UserContributions to UserContributionRefund
        //
    }

    function _projectEditRequire(Project calldata _project) internal {
        require(_project.softcap <= _project.hardcap, 'SH');
        require(_project.duration < maxFundraisingDuration, 'DD');
        require(_project.duration > 0, 'DU');
        require(_project.softcap > 0, 'SC');
        require(_project.milestone <= 10000, 'MS');
        require(_project.dateStart > block.timestamp, 'DS');
        require((_project.owner == msg.sender || hasRole(ADMIN_ROLE, msg.sender), 'D');
        require(_project.raised == 0, 'R');
        require(_project.released == 0, 'r');
        require(_project.status == 0, 'S');
        //return true;
    }

    /***************************************************************************/
    /********************************* Fundraising *****************************/
    /***************************************************************************/   

    //@todo mechanism for 
    event Invested(uint256, uint256);
    function invest(uint256 _project_id, uint256 _amount) external {
        //Project should open
        require(Projects[_project_id].status == 1, 'Not Open');
        //Respect min contribution
        require(_amount > 0, '0');
        //Respect Max Contribution
        require((UserContributions[msg.sender][_project_id] + _amount) < Projects[_project_id].maxContrib, 'Max');
        //Make sure time is not over yet 
        require((Projects[_project_id].dateStart + Projects[_project_id].duration) > block.timestamp, 'Expires');
        //Make sure amount raised amount is less than or equal to fund required 
        require((Projects[_project_id].raised + _amount) < Projects[_project_id].hardcap, "Hardcap");

        //Add money to project 
        Projects[_project_id].raised = Projects[_project_id].raised.add(_amount);

        //Add user's contribution
        UserContributions[msg.sender][_project_id] = UserContributions[msg.sender][_project_id].add(_amount);

        //Transfer money into contract 
        IERC20(Projects[_project_id].payment).safeTransferFrom(msg.sender, address(this), _amount);

        //@emit 
        emit Invested(_project_id, _amount);


    }

    function investRemove(uint256 _project_id) external {
        //Project should open
        require(Projects[_project_id].status == 1, 'NO');        
        require(Projects[_project_id].disinvesment, 'D');
        //Make sure time is not over yet 
        require((Projects[_project_id].dateStart + Projects[_project_id].duration) > block.timestamp, 'X');  
        //Make sure Hardcap not reached yet
        require(Projects[_project_id].raised >= Projects[_project_id].hardcap, "H");
        //Make sure user have enough money 
        require(UserContributions[msg.sender][_project_id] > 0, 'N');
        
        uint256 _amount = UserContributions[msg.sender][_project_id];
        UserContributions[msg.sender][_project_id] = 0;

        //@todo detuct tax;
        uint256 _tax = _amount.mul(taxFee).div(10**4);
        taxTotal = taxTotal.add(_tax);
        IERC20(Projects[_project_id].payment).safeTransfer(msg.sender, (_amount - _tax));

    }

    function investReduce(uint256 _project_id, uint256 _amount) external {
        require(Projects[_project_id].disinvesment, 'D');
    }


    /***************************************************************************/
    /******************************** Admin Settings ***************************/
    /***************************************************************************/ 
    function adminSettings(uint256 _commissionFees, uint256 _maxFundraisingDuration, uint256 _taxFee, address _fontStakingContract) external {
        require(hasRole(ADMIN_ROLE, msg.sender), "D");
        require(_commissionFees > 0, 'C');
        require(_maxFundraisingDuration > 0, 'T');
        require(_taxFee > 0, 'T');

        commissionFees = _commissionFees;
        taxFee = _taxFee;
        maxFundraisingDuration = _maxFundraisingDuration;
        fontStakingContract = _fontStakingContract;
    }



    /***************************************************************************/
    /************************************ Views ********************************/
    /***************************************************************************/ 
    function viewProject(uint256 _project_id) external view returns (Project memory){
        return Projects[_project_id];
    }

    /***************************************************************************/
    /*********************************** Helpers *******************************/
    /***************************************************************************/ 

    function isProjectOpened(uint256 _project_id, uint256 _amount) internal view returns (bool){

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