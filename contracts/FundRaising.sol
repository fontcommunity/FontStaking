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
    uint256 private days30 = 2592000;
    address private fontStakingContract;

    uint256 public ProjectID = 1;
    IERC20 private FONTERC20 = IERC20(font_token_address);


    struct Project {
        uint256 softcap;
        uint256 hardcap;
        uint256 raised; //Amount raised so for 
        uint256 released; //Amount released so for to owner
        uint256 lastReleased; //Last released time
        uint256 dateStart; //Date is absloute date
        uint256 duration;
        uint256 maxContrib;
        uint256 minContrib; //min contribution
        uint256 nftID; //ID of the NFT s
        uint16 milestone; // number of months
        uint8 status; //0 = draft, 1 = started and in progress, 2 = filled, 3 = closed...
        address payment; // any erc20 token 
        address owner;
        bool disinvesment; 
        string ipfs;
        
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

    //Tax total 
    mapping (address => uint256) private taxTotal;
    
    //project => User => amount
    mapping (uint256 => mapping(address => uint256)) private UserContributions;


    constructor(address _font_ERC20) {
        //Mandatory for contracts to return these strings to receive ERC1155 and ERC721
        _onERC1155Received = bytes4(keccak256("onERC1155Received(address,address,uint256,uint256,bytes)"));
        _onERC1155BatchReceived = bytes4(keccak256("onERC1155BatchReceived(address,address,uint256[],uint256[],bytes)"));
        
        _setupRole(ADMIN_ROLE, msg.sender); // Assign admin role to contract creator

        FONTERC20 = IERC20(_font_ERC20);
    }


    /***************************************************************************/
    /*********************************** Projects ******************************/
    /***************************************************************************/    

    event ProjectCreated(uint256);
    function projectCreate(Project calldata _project) external {
        //Require to edit        
        _projectEditRequire(_project);

        uint256 _project_id = ProjectID; 
        Projects[_project_id] = _project;

        //Projects[_project_id].ipfs = ipfs;
        ProjectID++;

        //Move the NFT into Contract Custody 
        ProjectCreated(_project_id);
    }

    

    //Can able to edit only of project status is 0
    event ProjectEdited(uint256);
    function projectEdit(uint256 _project_id, Project calldata _project) external {
        //Require to edit 
        _projectEditRequire(_project);
        Projects[_project_id] = _project;
        //only if status is 0
        emit ProjectEdited(_project_id);
    }

    event ProjectStarted(uint256, uint256);
    function projectStart(uint256 _project_id, uint256 dateStart, uint256 _boostAmount) external {

        Project memory _project = Projects[_project_id];

        _projectEditRequire(_project);
        require(dateStart > block.timestamp, 'S');
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
        require((Projects[_project_id].owner == msg.sender || hasRole(ADMIN_ROLE, msg.sender)), "D");
        
        //draft or live project can be cancled 
        require(Projects[_project_id].status < 2, 'S');

        //@todo check real status before cancel 

        //update the status 
        Projects[_project_id].status = 4;

        //emit 
        emit ProjectCanceled(_project_id);
    }
    
    event ProjectBoosted(uint256, uint256);
    function projectBoost(uint256 _project_id, uint256 _amount) public {
        require(_amount > 0);
        Boost[_project_id] = Boost[_project_id].add(_amount);
        FONTERC20.safeTransferFrom(msg.sender, deadAddress, _amount);
        emit ProjectBoosted(_project_id, Boost[_project_id]);
    }    

    event ProjectFundWithdrawn(uint256 ProjectID, uint256 Amount);
    function projectFundWithdraw(uint256 _project_id) external {
        //only able to do by admin or owner
        require((Projects[_project_id].owner == msg.sender || hasRole(ADMIN_ROLE, msg.sender)), "D");
        //only for successful projects 
        require(Projects[_project_id].status == 2, 'S');
        //Only if withdrawed pending anything 
        require(Projects[_project_id].released < Projects[_project_id].raised, '0');
        require(Projects[_project_id].raised > 0, "0");
        //Check the last withdrawal time 
        require((Projects[_project_id].lastReleased + days30) < block.timestamp, "Wait");


        uint256 _amount = Projects[_project_id].raised.div(Projects[_project_id].milestone);
        if(_amount > 0) {
            Projects[_project_id].released = Projects[_project_id].released.add(_amount);
            Projects[_project_id].lastReleased = block.timestamp;

            IERC20(Projects[_project_id].payment).safeTransfer(Projects[_project_id].owner, _amount);
        }
        ProjectFundWithdrawn(_project_id, _amount);

    }


    function projectUpdateStatus(uint256 _project_id) external {
        _projectUpdateStatus(_project_id);
    }


    //update the status of the project one calling this.
    function _projectUpdateStatus(uint256 _project_id) internal {
        
        //Call this on 
        //  -   After Invest : [y]
        //  -   After Disinvestment : [y]
        //  -   After reduce investment : [y]
        //  -   After cancel project ?
        //  -   Project Start  ?

        //can get only update for ongoing project, leave the rest 
        if(Projects[_project_id].status == 1 && (Projects[_project_id].dateStart + Projects[_project_id].duration) <= block.timestamp) {
            if(Projects[_project_id].raised >= Projects[_project_id].softcap) {
                Projects[_project_id].status = 2; //Goal reached, min softcap reached 
            }
            else {
                //Goal not reached in time
                Projects[_project_id].status = 3;
            }
        }
    }


    function _projectEditRequire(Project memory _project) internal {
        require(_project.softcap <= _project.hardcap, 'SH');
        require(_project.duration < maxFundraisingDuration, 'DD');
        require(_project.duration > 0, 'DU');
        require(_project.softcap > 0, 'SC');
        require(_project.milestone <= 10000, 'MS');
        require(_project.dateStart > block.timestamp, 'DS');
        require(_project.owner == msg.sender || hasRole(ADMIN_ROLE, msg.sender), 'D');
        require(_project.raised == 0, 'R');
        require(_project.released == 0, 'r');
        require(_project.status == 0, 'S');
        require(_project.minContrib > 0, "Mn");
        //return true;
    }

    /***************************************************************************/
    /********************************* Fundraising *****************************/
    /***************************************************************************/   

    event Invested(uint256, uint256);
    function invest(uint256 _project_id, uint256 _amount) external {
        //Project should open
        require(Projects[_project_id].status == 1, 'Not Open');
        //Respect min contribution
        require(_amount > 0, '0');
        //Make sure time is not over yet 
        require((Projects[_project_id].dateStart + Projects[_project_id].duration) > block.timestamp, 'Expires');

        //Min Contribution 
        require((UserContributions[_project_id][msg.sender] + _amount) >= Projects[_project_id].minContrib, 'Min');

        //Respect Max Contribution
        require((UserContributions[_project_id][msg.sender] + _amount) < Projects[_project_id].maxContrib, 'Max');

        //Make sure amount raised is less than or equal to fund required 
        require((Projects[_project_id].raised + _amount) <= Projects[_project_id].hardcap, "Hardcap");

        //Add money to project 
        Projects[_project_id].raised = Projects[_project_id].raised.add(_amount);

        //Add user's contribution
        UserContributions[_project_id][msg.sender] = UserContributions[_project_id][msg.sender].add(_amount);

        //update the project status 
        _projectUpdateStatus(_project_id);

        //Transfer money into contract 
        IERC20(Projects[_project_id].payment).safeTransferFrom(msg.sender, address(this), _amount);

        //@emit 
        emit Invested(_project_id, _amount);
    }

    //this is removing investment from live project
    function investRemove(uint256 _project_id) external {
        //Project should open
        require(Projects[_project_id].status == 1, 'NO');        
        require(Projects[_project_id].disinvesment, 'D');
        //Make sure time is not over yet 
        require((Projects[_project_id].dateStart + Projects[_project_id].duration) > block.timestamp, 'X');  
        //Make sure Hardcap not reached yet
        require(Projects[_project_id].raised >= Projects[_project_id].hardcap, "H");
        //Make sure user have enough money 
        require(UserContributions[_project_id][msg.sender] > 0, 'N');
        
        uint256 _amount = UserContributions[_project_id][msg.sender];
        UserContributions[_project_id][msg.sender] = 0;

        Projects[_project_id].raised = Projects[_project_id].raised.sub(_amount); 

        //update the project status 
        _projectUpdateStatus(_project_id);        

        //@todo detuct tax;
        uint256 _tax = _amount.mul(taxFee).div(10**4);
        taxTotal[Projects[_project_id].payment] = taxTotal[Projects[_project_id].payment].add(_tax);

        IERC20(Projects[_project_id].payment).safeTransfer(msg.sender, (_amount - _tax));

    }
    //This is cancled and failed project 
    event InvestClaimed(uint256, uint256);
    function investClaim(uint256 _project_id) external {
        require((Projects[_project_id].status == 3 || Projects[_project_id].status == 4), "S");
        require(UserContributions[_project_id][msg.sender] > 0, '0');
        require(Projects[_project_id].raised > 0, "F");
        
        uint256 _amount = UserContributions[_project_id][msg.sender];
        //Remove users contribution
        UserContributions[_project_id][msg.sender] = 0;

        //Reduce total raised by the project
        Projects[_project_id].raised = Projects[_project_id].raised.sub(_amount);

        IERC20(Projects[_project_id].payment).safeTransfer(msg.sender, _amount);

        emit InvestClaimed(_project_id, _amount);
    }

    /***************************************************************************/
    /******************************** Admin Settings ***************************/
    /***************************************************************************/ 
    event AdminSettings(uint256, uint256, uint256, address);
    function adminSettings(uint256 _commissionFees, uint256 _maxFundraisingDuration, uint256 _taxFee, address _fontStakingContract) external {
        require(hasRole(ADMIN_ROLE, msg.sender), "D");
        require(_commissionFees > 0, 'C');
        require(_maxFundraisingDuration > 0, 'T');
        require(_taxFee > 0, 'T');

        commissionFees = _commissionFees;
        maxFundraisingDuration = _maxFundraisingDuration;
        taxFee = _taxFee;
        fontStakingContract = _fontStakingContract;

        emit AdminSettings(commissionFees, maxFundraisingDuration, taxFee, fontStakingContract);
    }

    event AdminWithdrawnTax(address Token, uint256 Amount);
    function adminWithdrawTax(address _token) external {
        require(taxTotal[_token] > 0, "0");
        uint256 _amount = taxTotal[_token];
        taxTotal[_token] = 0;
        IERC20(_token).safeTransfer(fontStakingContract, _amount);
        emit AdminWithdrawnTax(_token, _amount);
    }



    /***************************************************************************/
    /************************************ Views ********************************/
    /***************************************************************************/ 
    function viewProject(uint256 _project_id) external view returns (Project memory){
        return Projects[_project_id];
    }

    function viewProjectBoost(uint256 _project_id) external view returns (uint256) {
        return Boost[_project_id];
    }

    function viewUserContribution(uint256 _project_id, address _user) external view returns (uint256){
        return UserContributions[_project_id][_user];
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