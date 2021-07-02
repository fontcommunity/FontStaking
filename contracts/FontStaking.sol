// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";


contract Staking is Ownable {

    using SafeMath for uint;    
    using SafeMath for uint8;
    using SafeMath for uint16;    
    using SafeMath for uint256;    
    using SafeERC20 for IERC20;

    /**********************************************************************************************************/
    /**********************************************   Variables  **********************************************/
    /**********************************************************************************************************/

    
    uint256 taxFee = 100; // 1 = 0.01%
    
    IERC20 public FONT_ERC20; //Font token address

    address font_token_address = 0x4C25Bdf026Ea05F32713F00f73Ca55857Fbf6342; //token address of the font

    bool public stakingPaused; //Status of staking 
    uint256 public taxAmount = 0; //Total tax accumulated
    uint256 public minStakeTime = 2592000; //30 days in second
    uint256 public lastRewardTime = 0;
    uint256 public stakeCounter; //Current stake id 
    uint256 public totalStaked = 0; //Total $FONTs currently staked
    uint256 public maxSnapshotLifetime = 14400; //Max Time intervel for snapshot

    //list of accounts excluded from rewards 
    mapping (address => bool) private excludedAccount; 

    //Total token staked per user
    mapping (address => uint256) public usersStake; 

    //Holds the ERC address of reward tokens, usefull for multiple token payment 
    struct RewardToken { 
        address token; //ERC20 token for rewards
        bool status; //current status 
        uint256 balance; //balance of this token
        uint256 minBalance; //Minimum balance to send rewards / No use of spending 1$ to 1000 people. 
    }

    mapping (address => RewardToken) public rewardTokens;
    

    //Staking info
    struct stakingInfo {
        uint256 amount;
        uint256 lockedTime;
        uint256 unstakeTime;
        uint256 duration;
        address user;
        bool claimed;
    }
    mapping(uint256 => stakingInfo) public StakeMap; 

    //stake ID to user 
    mapping(uint256 => address) public stakeIdtoUser;


    //users stake ids 
    mapping(address => uint256[]) private userStakeIds;

    //list of all current eligible stake ids
    uint256[] currentStakeIds; 

    //usershare eligible based on stake 
    mapping (address => uint256) private userShareTemp;

    //first eligible stake id, this helps to reduce gas as time goes. 
    uint256 firstEligibleStakeID = 0;

    //Eligible number of fonts for rewards
    uint256 totalEligibleFontsForRewards = 0;

    //snapshots
    mapping (uint256 => mapping(address => uint256)) public SnapShot;
    mapping (uint256 => address[]) private SnapShotUsers;
    
    uint256 public lastSnapshotTime; //Last time the snapshot made
    
    constructor(bool _paused)  {
        stakeCounter = 0;
        //FONT_ERC20 = IERC20(); //@todo add manually 
        stakingPaused = _paused;
    }

    event LogStake(address _address, uint256 _stake_id, uint256 amount);

    /**
    * @dev stake a specific amount to a token
    * @param _amount the amount to be staked
    * for demo purposes, not requiring user to actually send in tokens right now
    */
    
    function stake(uint256 _amount) public {
        require(!stakingPaused);
        require(_amount > 0);

        uint256 _stake_id = stakeCounter.add(1);
        uint256 _stakedDate = block.timestamp;

        //Add total token staked per address
        if(usersStake[msg.sender] == 0){
            usersStake[msg.sender] = _amount;
        } else {
            usersStake[msg.sender] = usersStake[msg.sender].add(_amount);
        }

        //Add item to StakeMap
        StakeMap[_stake_id].amount = _amount;
        StakeMap[_stake_id].claimed = false;
        StakeMap[_stake_id].lockedTime = _stakedDate;
        StakeMap[_stake_id].duration = minStakeTime;
        StakeMap[_stake_id].user = msg.sender;
        
        //Stake to user id 
        stakeIdtoUser[_stake_id] = msg.sender;
        //stake ids per user
        userStakeIds[msg.sender].push(_stake_id);

        stakeCounter = _stake_id;

        uint256 allowance = FONT_ERC20.allowance(msg.sender, address(this));
        require(allowance >= _amount, "Check the token allowance");

        require(FONT_ERC20.transferFrom(msg.sender, address(this), _amount));

        //Total font currently staked
        totalStaked = totalStaked.add(_amount);
        
        emit LogStake(msg.sender, _stake_id,  _amount);
    }
    
    event UnStaked(address _address, uint256 _stake_id, uint256 amount);
    //Unstake the font Token by stake id
    function unStake(uint256 _stake_id) external {
        require(StakeMap[_stake_id].user == msg.sender, 'Denied');
        require(usersStake[msg.sender] > 0);
        require(totalStaked > 0);
        require(!StakeMap[_stake_id].claimed);
        require(StakeMap[_stake_id].amount > 0);

        uint256 _amount = StakeMap[_stake_id].amount; //@todo no need this variable
        uint256 _taxfee = 0;

        //Take tax for premeture unstake
        if((StakeMap[_stake_id].lockedTime + StakeMap[_stake_id].duration) > block.timestamp) {
            _taxfee = calculateTax(_amount);    
            taxAmount = taxAmount.add(_taxfee);
        }
        
        //Add tax amount to total tax 
        
        //Reduce the balance per user
        usersStake[msg.sender] = usersStake[msg.sender].sub(_amount);
        
        //Update stake info 
        StakeMap[_stake_id].claimed = true;
        StakeMap[_stake_id].unstakeTime = block.timestamp;
        
        //Transfer token to user @todo safetransfer
        require(FONT_ERC20.transfer(msg.sender, _amount.sub(_taxfee)));

        //Total font currently staked
        totalStaked = totalStaked.sub(_amount);        
        
        UnStaked(msg.sender, _stake_id, _amount);
    }


    //Get total FONTs staked per address. 
    //@done
    function getStakedPerAddress(address _address) external view returns (uint256) {
        return usersStake[_address];
    }

    //Get detail about single stake info by address and id

    function getStakeByID(uint256 _stake_id) external view returns (stakingInfo memory) {
        return StakeMap[_stake_id];
    }

    //Pause the staking
    //@done
    function pauseStaking() external onlyOwner {
      stakingPaused = true;
    }

    //UnPause the staking
    //@done
    function unpauseStaking() external onlyOwner {
      stakingPaused = false;
    }    

    //emergency 

    /**********************************************************************************************************/
    /********************************************   Admin Settings  *******************************************/
    /**********************************************************************************************************/
    
    //Change tax fee
    //@done
    event changedTaxFee(uint256);
    function setTaxFees(uint256 _fees) external onlyOwner {
        taxFee = _fees;
        emit changedTaxFee(_fees);
    }
    
    //Add an account to exclude from payment splits and rewards. 
    //this is to exclude the team / test accounts. 
    //@done
    event accountExcluded(address);
    function excludeAccount(address _address) external onlyOwner {
        excludedAccount[_address] = true;
        emit accountExcluded(_address);
    }

    //Add an account to include from payment splits and rewards. 
    //@done
    event accountIncluded(address);
    function includeAccount(address _address) external onlyOwner{
        excludedAccount[_address] = false;
        emit accountIncluded(_address);
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

    //Get list of all users stake ids
    function getStakeidsByUser(address _address) external view returns (uint256[] memory) {
        return userStakeIds[_address];
    }

    //get current reward share percentage per address.
    function getCurrentRewardShare(address _user) external view returns (uint256) {
        if(SnapShot[lastSnapshotTime][_user] > 0 && totalEligibleFontsForRewards > 0) {
            return SnapShot[lastSnapshotTime][_user].mul(totalEligibleFontsForRewards).div(100);
        }
        return 0;
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
    event SnapShoted(uint256, uint256);
    function takeShapshot() external {

        //requires
        //should not call often 

        uint256 _firstEligibleStakeID = firstEligibleStakeID;
        uint256 _totalEligibleFontsForRewards = 0;

        //loop through all the stakes 
        for(uint256 i = _firstEligibleStakeID; i <= stakeCounter; i++) {
            //check if user is not already claimed, have crosed the date, and account is not excluded to get rewards
            if(!StakeMap[i].claimed && (StakeMap[i].lockedTime + StakeMap[i].duration < block.timestamp) && !excludedAccount[StakeMap[i].user]) {
                //update the first elibible Stake id 
                firstEligibleStakeID = i;

                //calculate the total eligible fonts for staking rewards 
                _totalEligibleFontsForRewards = _totalEligibleFontsForRewards.add(StakeMap[i].amount);

                //add eligible number of tokens per user address
                SnapShot[block.timestamp][StakeMap[i].user] = SnapShot[block.timestamp][StakeMap[i].user].add(StakeMap[i].amount);
                SnapShotUsers[block.timestamp].push(StakeMap[i].user);

            }
        }
        //update the metadatas 
        lastSnapshotTime = block.timestamp;             
        totalEligibleFontsForRewards = _totalEligibleFontsForRewards;
        emit SnapShoted(lastSnapshotTime, totalEligibleFontsForRewards);
    }



    /**********************************************************************************************************/
    /**********************************************   test area  **********************************************/
    /**********************************************************************************************************/
    event RewardsDistributed(uint256, uint256);
    function sendRewards(address[] memory _tokens) external {
        //requires
        //@todo: make sure this can be called twice by user in same block / timestamp. Add time limit that can call only once per certain period 
        //make sure ethere is enough staking from last snapshot
        require(totalEligibleFontsForRewards > 0, '0 stake');
        //should be last withdrawal called in x days 
        require(lastRewardTime < (block.timestamp - minStakeTime), 'wait'); //done
        //should have snapshotred before x mins (4 hours?)
        require(lastSnapshotTime > (block.timestamp - maxSnapshotLifetime), 'SnapShot' );

        uint256 _temp = 0;

        for(uint256 i = 0; i <= _tokens.length; i++ ) {
            if(rewardTokens[_tokens[i]].status && _tokens[i] !=  font_token_address) {
                uint256 _token_balance = IERC20(_tokens[i]).balanceOf(address(this));
                if(_token_balance > 0) {
                    for(uint256 _user = 0; _user <= SnapShotUsers[lastSnapshotTime].length; _user++) {
                        if(SnapShot[lastSnapshotTime][SnapShotUsers[lastSnapshotTime][_user]] > 0) {
                            _temp = SnapShot[lastSnapshotTime][SnapShotUsers[lastSnapshotTime][_user]].div(totalEligibleFontsForRewards).div(_token_balance);
                            SnapShot[lastSnapshotTime][SnapShotUsers[lastSnapshotTime][_user]] = 0;        
                            IERC20(_tokens[i]).safeTransfer(SnapShotUsers[lastSnapshotTime][_user] , _temp);
                        } //check if user in this snapshot have enough balance                         
                    } //take all the users in current snapshop
                } // check if we have enough balance per contract 
            } //check if reward token is enabled and its not font token 
        } // Main for loop

        //update the needed metadata 

        lastRewardTime = block.timestamp;

        //emit 
        emit RewardsDistributed(_tokens.length, SnapShotUsers[lastSnapshotTime].length);

    }




}


