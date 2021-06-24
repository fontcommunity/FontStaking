pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";


contract Staking is Ownable {

    using SafeMath for uint;

    /**********************************************************************************************************/
    /**********************************************   Variables  **********************************************/
    /**********************************************************************************************************/

    
    uint32 taxFee = 100; // 1 = 0.01%
    
    IERC20 public FONT_ERC20; //Font token address

    bool public stakingPaused; //Status of staking 

    mapping (address => bool) private excludedAccount; //list of accounts excluded from rewards 

    uint256 public stakeCounter; //Current stake id 

    uint256 public minStakeTime = 2592000; //30 days in second

    uint256 public lastSnapshotTime; //Last time the snapshot made @todo

    uint256 public taxAmount = 0; //Total tax accumulated



    //Total token staked
    mapping (address => uint256) public usersStake; //number of tokens staked per user

    //Holds the ERC address of reward tokens, usefull for multiple token payment 
    struct RewardToken { 
        address token; //ERC20 token for rewards
        bool status; //current status 
        uint256 balance; //balance of this token
    }
    mapping (address => RewardToken) public rewardTokens;
    

    //Staking info
    struct stakingInfo {
        uint256 amount;
        uint256 lockedTime;
        uint256 unlockTime;
        uint256 duration;
        bool claimed;
    }
    mapping (address => mapping(uint256 => stakingInfo)) public StakeMap; 


    
    constructor() public {
        stakeCounter = 0;
        //FONT_ERC20 = IERC20(); //@todo add manually 
        stakingPaused = false;
    }
    

    event LogStake(address _address, uint256 _stake_id, uint256 amount);

    /**
    * @dev stake a specific amount to a token
    * @param _amount the amount to be staked
    * for demo purposes, not requiring user to actually send in tokens right now
    */
    
    function stake(uint _amount) public {
        require(!stakingPaused);
        require(_amount > 0);

        uint _stake_id = stakeCounter.add(1);
        uint _stakedDate = block.timestamp;

        //Add total token staked per address
        if(usersStake[msg.sender] == 0){
            usersStake[msg.sender] = _amount;
        } else {
            usersStake[msg.sender] = usersStake[msg.sender].add(_amount);
        }

        //Add item to StakeMap
        StakeMap[msg.sender][_stake_id].amount = _amount;
        StakeMap[msg.sender][_stake_id].claimed = false;
        StakeMap[msg.sender][_stake_id].lockedTime = _stakedDate;
        StakeMap[msg.sender][_stake_id].duration = minStakeTime;
        

        stakeCounter = _stake_id;

        uint256 allowance = FONT_ERC20.allowance(msg.sender, address(this));
        require(allowance >= _amount, "Check the token allowance");

        require(FONT_ERC20.transferFrom(msg.sender, address(this), _amount));
        emit LogStake(msg.sender, _stake_id,  _amount);
    }
    
       
    event UnStaked(address _address, uint256 _stake_id, uint256 amount);
    

    //Unstake the font Token by stake id
    function unStake(uint256 _stake_id) external {
        require(usersStake[msg.sender] > 0);
        require(!StakeMap[msg.sender][_stake_id].claimed);
        require(StakeMap[msg.sender][_stake_id].amount > 0);
        

        uint256 _amount = StakeMap[msg.sender][_stake_id].amount;
        uint256 _taxfee = 0;

        //Take tax for premeture unstake
        if((StakeMap[msg.sender][_stake_id].lockedTime + StakeMap[msg.sender][_stake_id].duration) > block.timestamp) {
            _taxfee = calculateTax(_amount);    
            taxAmount = taxAmount.add(_taxfee);
        }
        

        //Add tax amount to total tax 
        
        
        //Reduce the balance per user
        usersStake[msg.sender] = usersStake[msg.sender].sub(_amount);
        
        

        //Update stake info 
        StakeMap[msg.sender][_stake_id].claimed = true;
        StakeMap[msg.sender][_stake_id].unlockTime = block.timestamp;
        
        //Transfer token to user
        require(FONT_ERC20.transfer(msg.sender, _amount.sub(_taxfee)));
        
        UnStaked(msg.sender, _stake_id, _amount);
    }


    //Get total FONTs staked per address. 
    function getStakedPerAddress(address _address) external view returns (uint256) {
        return usersStake[_address];
    }

    //Get detail about single stake info by address and id
    function getStakeByID(address _address, uint _stake_id) external view returns (uint256, bool, uint256, uint256) {
        return (StakeMap[_address][_stake_id].amount, StakeMap[_address][_stake_id].claimed, StakeMap[_address][_stake_id].lockedTime, StakeMap[_address][_stake_id].unlockTime);
    }

    //Pause the staking
    function pauseStaking() external onlyOwner {
      stakingPaused = true;
    }

    //UnPause the staking
    function unpauseStaking() external onlyOwner {
      stakingPaused = false;
    }    

    //emergency 

    /**********************************************************************************************************/
    /********************************************   Admin Settings  ********************************************/
    /**********************************************************************************************************/
    
    //Change tax fee
    event changedTaxFee(uint256);
    function setTaxFees(uint32 _fees) external onlyOwner {
        taxFee = _fees;
        emit changedTaxFee(_fees);
    }
    
    //Add an account to exclude from payment splits and rewards. 
    //this is to exclude the team / test accounts. 
    event accountExcluded(address);
    function excludeAccount(address _address) external onlyOwner{
        excludedAccount[_address] = true;
        emit accountExcluded(address);
    }

    //Add an account to include from payment splits and rewards. 
    event accountIncluded(address);
    function includeAccount(address _address) external onlyOwner{
        excludedAccount[_address] = false;
        emit accountIncluded(address);
    }

    //Add new play token for games  
    event NewRewardToken(address _address, bool _status);
    function addRewardToken(address _address, bool _status) external onlyOwner {
        require(!isRewardTokenExists(_address), "Exists");

        RewardToken memory _rewardToken;
    
        _rewardToken.status = _status; 
        _rewardToken.balance = 0; 
        _rewardToken.token = _address; 
    
        rewardTokens[_address] = _rewardToken;

        // emit
        emit NewRewardToken(_address, _status);
    }  

    //Edit existing play token
    event EditRewardToken(address _address, bool _status);
    function editRewardToken(address _address, bool _status) external onlyOwner {
        require(isRewardTokenExists(_address), "Not Exists");
        rewardTokens[_address].status = _status;         
        emit EditRewardToken(_address, _status);        
    }        

    //Burn the tax, let anyone call it. 
    event FontBurned(uint256 amount);
    function burnFont() external {
        require(FONT_ERC20.transfer(address(0), taxAmount));
        FontBurned(taxAmount);
        taxAmount = 0;
    }

    /**********************************************************************************************************/
    /************************************************   views  ************************************************/
    /**********************************************************************************************************/
    //Get the number of tokens staked by user
    function getStakeByUser(address _address) external view returns (uint256) {
        return usersStake[_address];
    }




    /**********************************************************************************************************/
    /************************************************   Helpers  **********************************************/
    /**********************************************************************************************************/

    //Check if reward token already exist
    function isRewardTokenExists(address _address) internal view returns (bool) {
        return rewardTokens[_address].token == _address;
    }

    //calculate tax fee
    function calculateTax(uint256 _amount) internal view returns (uint256) {
        //if no tax fee then there is no tax
        if(taxFee == 0) {
            return 0;
        }
        return _amount.mul(taxFee).div(10**4);
    }

    //create split list, can be called by anyone


}


