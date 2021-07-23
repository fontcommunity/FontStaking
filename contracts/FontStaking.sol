// SPDX-License-Identifier: MIT
// Author: https://twitter.com/adalquardz

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

contract FontStaking is AccessControl {

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

    address ownerAddress; //Main admin of this contract

    uint256 taxFee = 400; // 1 = 0.01% for premature unstake
    address font_token_address = 0x4C25Bdf026Ea05F32713F00f73Ca55857Fbf6342; //token address of the font
    uint256 public maxSnapshotLifetime = 259200; // 3 days Max freshness of snapshot before reward distribution
    uint256 public minSnapshotInterval = 7776000; //3 months this is used for both snapshot and reward distribution
    uint256 public minStakeTime = 7776000; //90 days in second
    uint256 public minStakeAmount = 500 * (10**18); // Minimum eligible fonts for staking 
    
    
    IERC20 public FONT_ERC20; //Font token address

    bool public stakingPaused; //Status of staking 
    uint256 public totalTaxAmount = 0; //Total tax accumulated, subjected to reset from 0 on burn 
    uint256 public lastRewardTime = 0; //time stamp of last time reward distributed 
    uint256 public stakeCounter; //Current stake ID. Counter
    uint256 public totalStaked = 0; //Total $FONTs currently staked
    uint256 public lastSnapshotTime; //Last time the snapshot made

    //stake id to skip, this helps to reduce gas as time goes. 
    uint256 firstUnclaimedStakeId = 1;    

    //Eligible number of fonts for rewards, this helps to calculate user share of rewards 
    uint256 totalEligibleFontsForRewards = 0; //This resets often

    //list of accounts excluded from rewards 
    mapping (address => bool) private excludedAccount; 

    //Total font token currently staked per user
    mapping (address => uint256) public usersStake; 

    //Holds the ERC address of reward tokens, usefull for multiple token payment 
    struct RewardToken { 
        //uint256 balance; //balance of this token
        uint256 minBalance; //Minimum balance to send rewards / No use of spending 1$ to 1000 people. 
        //address token; //ERC20 token for rewards
        bool status; //current status or this erc token
    }
    mapping (address => uint256) public rewardTokens;
    
        struct TT {
            address a;
            bool b;
        }    

    //Staking info
    struct stakingInfo {
        uint256 amount;
        uint256 lockedTime;
        uint256 unstakeTime;
        uint256 duration;
        address user;
        bool claimed;
    }
    mapping(uint256 => stakingInfo) private StakeMap; 


    //users stake ids 
    mapping(address => uint256[]) private userStakeIds;


    //snapshots
    mapping (uint256 => mapping(address => uint256)) public SnapShot; //User balance based on the snapshot 
    mapping (uint256 => address[]) private SnapShotUsers; //list of eligible users per snapshot 

    //User reward balance claimable
    mapping (address => mapping(address => uint256)) public UserRewardBalance;


    constructor(address _font_token_address)  {
        stakeCounter = 1;
        FONT_ERC20 = IERC20(_font_token_address); 
        ownerAddress = msg.sender;
        stakingPaused = false;
        _setupRole(ADMIN_ROLE, msg.sender); // Assign admin role to contract creator
    }

    //@done
    event LogStake(address _address, uint256 _stake_id, uint256 amount); 
    /**
    * @dev stake a specific amount to a token
    * @param _amount the amount to be staked
    * for demo purposes, not requiring user to actually send in tokens right now  
    */
    function stake(uint256 _amount) public {
        require(!stakingPaused, 'Paused');
        require(_amount > minStakeAmount, 'Minimum');

        uint256 _stake_id = stakeCounter;

        //Add total token staked per address
        usersStake[msg.sender] = usersStake[msg.sender].add(_amount);
        

        //Add item to StakeMap
        StakeMap[_stake_id].amount = _amount;
        StakeMap[_stake_id].claimed = false;
        StakeMap[_stake_id].lockedTime = block.timestamp;
        StakeMap[_stake_id].duration = minStakeTime;
        StakeMap[_stake_id].user = msg.sender;
        
        //stake ids per user
        userStakeIds[msg.sender].push(_stake_id);

        //Total font currently staked
        totalStaked = totalStaked.add(_amount);

        //Update Stake Counter 
        stakeCounter++;
        
        //safe transfer from 
        FONT_ERC20.safeTransferFrom(msg.sender, address(this), _amount);
        
        emit LogStake(msg.sender, _stake_id,  _amount);
    }
    
    //Unstake the font Token by stake id
    //@done
    event UnStaked(address _address, uint256 _stake_id, uint256 amount, uint256 _tax);
    function unStake(uint256 _stake_id) external {
        require(StakeMap[_stake_id].user == msg.sender, 'Denied');
        require(!StakeMap[_stake_id].claimed, 'Claimed');
        require(usersStake[msg.sender] > 0, 'No balance');

        uint256 _amount = StakeMap[_stake_id].amount; //@todo no need this variable
        uint256 _taxfee = 0;

        //Take tax for premeture unstake
        if((StakeMap[_stake_id].lockedTime + StakeMap[_stake_id].duration) > block.timestamp) {
            _taxfee = _amount.mul(taxFee).div(10**4);
            //Add tax amount to total tax    
            totalTaxAmount += _taxfee;// totalTaxAmount.add(_taxfee);
        }
        
        //Reduce the balance per user
        //usersStake[msg.sender] = usersStake[msg.sender].sub(_amount);
        usersStake[msg.sender] -= _amount;// usersStake[msg.sender].sub(_amount);
        
        //Update stake info 
        StakeMap[_stake_id].claimed = true;
        StakeMap[_stake_id].unstakeTime = block.timestamp;
        
        //Total font currently staked
        totalStaked -= _amount; //totalStaked.sub(_amount);      

        //Transfer token to user @todo safetransfer
        FONT_ERC20.safeTransfer(msg.sender, (_amount.sub(_taxfee)));

        UnStaked(msg.sender, _stake_id, _amount, _taxfee);
    }

    //Get detail about single stake info by address and id
    //@done
    function getStakeByID(uint256 _stake_id) external view returns (stakingInfo memory) {
        return StakeMap[_stake_id];
    }

    //Pause the staking
    //@done
    function pauseStaking() external {
      require(hasRole(ADMIN_ROLE, msg.sender), "Denied");
      stakingPaused = true;
    }

    //UnPause the staking
    //@done
    function unpauseStaking() external {
      require(hasRole(ADMIN_ROLE, msg.sender), "Denied");
      stakingPaused = false;
    }    

    //emergency 

    /**********************************************************************************************************/
    /********************************************   Admin Settings  *******************************************/
    /**********************************************************************************************************/
    
    //Change tax fee
    //@done
    event changedTaxFee(uint256);
    function setTaxFees(uint256 _fees) external {
        require(hasRole(ADMIN_ROLE, msg.sender), "Denied");
        require(_fees > 0, "0");
        taxFee = _fees;
        emit changedTaxFee(_fees);
    }

    //change min required stake amount
    //@done 
    event ChangedMinStakeRequired(uint256);
    function setMinStakeRequired(uint256 _amount) external {
        require(hasRole(ADMIN_ROLE, msg.sender), "Denied");
        minStakeAmount = _amount * (10**18);
        ChangedMinStakeRequired(_amount);
    }

    //Kick out a stake, dont take tax. This is to help test stakes to withdraw without tax.
    //@done
    event KickedStake(uint256);
    function kickStake(uint256 _stake_id) external {
        require(hasRole(ADMIN_ROLE, msg.sender), "Denied");
        require(!StakeMap[_stake_id].claimed, 'Claimed');
        require(StakeMap[_stake_id].amount > 0, 'No Stake Amount');
        require(totalStaked > 0, 'No FONT Balance');
        
        //Reduce the balance per user
        usersStake[StakeMap[_stake_id].user] -= StakeMap[_stake_id].amount;
        //usersStake[StakeMap[_stake_id].user].sub(StakeMap[_stake_id].amount);
        
        //Update stake info 
        StakeMap[_stake_id].claimed = true;
        StakeMap[_stake_id].unstakeTime = block.timestamp;
        
        //Total font currently staked
        totalStaked -= StakeMap[_stake_id].amount;// totalStaked.sub(StakeMap[_stake_id].amount);      

        //safetransfer token to user 
        FONT_ERC20.safeTransfer(StakeMap[_stake_id].user, StakeMap[_stake_id].amount);

        emit KickedStake(_stake_id);
    }
    
    //Add an account to exclude from payment splits and rewards. 
    //this is to exclude the team / test accounts. 
    //@done
    event accountExcluded(address);
    function excludeAccount(address _address) external {
        require(hasRole(ADMIN_ROLE, msg.sender), "Denied");
        excludedAccount[_address] = true;
        emit accountExcluded(_address);
    }

    //Add an account to include from payment splits and rewards. 
    //@done
    event accountIncluded(address);
    function includeAccount(address _address) external {
        require(hasRole(ADMIN_ROLE, msg.sender), "Denied");
        excludedAccount[_address] = false;
        emit accountIncluded(_address);
    }

    //Helper function to move the stake ID pointer for first open stake
    //@done
    function setFirstUnclaimedStakeId(uint256 _id) external {
        require(hasRole(ADMIN_ROLE, msg.sender), "Denied");
        firstUnclaimedStakeId = _id;
    }

    //Edit existing reward token
    //@done
    event EditRewardToken(address _address, uint256 _minBalance);
    function editRewardToken(address _address, uint256 _minBalance) external {
        require(hasRole(ADMIN_ROLE, msg.sender), "Denied");
        rewardTokens[_address] = _minBalance;
        emit EditRewardToken(_address, _minBalance);        
    }        

    //Burn the tax, let anyone call it. 
    //@done
    event FontBurned(uint256 amount);
    function burnFont() external {
        uint256 _totalTaxAmount = totalTaxAmount;
        totalTaxAmount = 0;
        FONT_ERC20.safeTransfer(0x000000000000000000000000000000000000dEaD, _totalTaxAmount);
        FontBurned(totalTaxAmount);
    }

    //withdraw the tokens that sent accidently 
    function withdrawErc20(address _token, uint256 _amount) public {
        require(msg.sender == ownerAddress, "Denied");
        require(_token != font_token_address, "FONT");
        IERC20(_token).transfer(msg.sender, _amount);
    }    


    function makeAdmin(address _address) public {
        require(msg.sender == ownerAddress, "Denied");
        grantRole(ADMIN_ROLE, _address);
    }

    function revokeAdmin(address _address) public {
        require(msg.sender == ownerAddress, "Denied");
        revokeRole(ADMIN_ROLE, _address);
    }    


    //change the time settings 
    event TimingsChanged(uint256, uint256, uint256);
    function setTimings(uint256 _maxSnapshotLifetime, uint256 _minSnapshotInterval, uint256 _minStakeTime) external {
        require(msg.sender == ownerAddress, "Denied");
        maxSnapshotLifetime = _maxSnapshotLifetime; //3 days default
        minSnapshotInterval = _minSnapshotInterval; //90 days defualt 
        minStakeTime = _minStakeTime; //90 days default 
        emit TimingsChanged(_maxSnapshotLifetime, _minSnapshotInterval, _minStakeTime);
    }

    /**********************************************************************************************************/
    /************************************************   views  ************************************************/
    /**********************************************************************************************************/
    //Get the number of tokens staked by user
    //@done
    function getStakeByUser(address _address) external view returns (uint256) {
        return usersStake[_address];
    }

    //Get list of all users stake ids
    function getStakeidsByUser(address _address) external view returns (uint256[] memory) {
        return userStakeIds[_address];
    }

    //get current reward share percentage per address.
    //
    function getCurrentRewardShare(address _user) external view returns (uint256) {
        return SnapShot[lastSnapshotTime][_user];
    }

    function getUserRewardBalance(address _token, address _user) external view returns (uint256) {
        return UserRewardBalance[_user][_token];
    }

    function getTaxFee() external view returns (uint256) {
        return taxFee;
    }

    function getTotalEligibleFontsForRewards() external view returns (uint256) {
        return totalEligibleFontsForRewards;
    }

    function getlastSnapshotTime() external view returns (uint256) {
        return lastSnapshotTime;
    }

    function getSnapShotUsers(uint256 _snapshotTime) external view returns (address[] memory) {
        return SnapShotUsers[_snapshotTime];
    }

    /**********************************************************************************************************/
    /************************************************   Helpers  **********************************************/
    /**********************************************************************************************************/

    //calculate tax fee
    //@done
    function calculateTax(uint256 _amount) internal view returns (uint256) {
        return _amount.mul(taxFee).div(10**4);
    }

    /**********************************************************************************************************/
    /************************************************  Rewards  **********************************************/
    /**********************************************************************************************************/
    //Take snapshot of reward eligibility>
    //Should able to take min of 3 months 
    event SnapShoted(uint256, uint256);
    function takeSnapshot() external {
        require(hasRole(ADMIN_ROLE, msg.sender), "Denied");

        uint256 _blockTimestamp = block.timestamp;
        require(lastSnapshotTime < (_blockTimestamp - minSnapshotInterval), "Wait"); //@done
        uint256 _totalEligibleFontsForRewards = 0;
        

        for(uint256 i = firstUnclaimedStakeId; i < stakeCounter; i++) {
            stakingInfo memory _StakeMap = StakeMap[i];
            //check if user is not already claimed, have crosed the date, and account is not excluded to get rewards
            if(!_StakeMap.claimed && (_StakeMap.lockedTime + _StakeMap.duration < _blockTimestamp)) { //@done date
                //calculate the total eligible fonts for staking rewards 
                _totalEligibleFontsForRewards += _StakeMap.amount;
                //add eligible number of tokens per user address
                if(SnapShot[_blockTimestamp][_StakeMap.user] == 0) {
                    SnapShotUsers[_blockTimestamp].push(_StakeMap.user);
                }
                SnapShot[_blockTimestamp][_StakeMap.user] += _StakeMap.amount;
                //
            }
        }

        //update the metadatas 
        lastSnapshotTime = _blockTimestamp;
        totalEligibleFontsForRewards = _totalEligibleFontsForRewards;
        emit SnapShoted(lastSnapshotTime, totalEligibleFontsForRewards);
    }

    //Distribute the reward 
    event RewardsDistributed(uint256, uint256);
    function DistributeRewards(address[] memory _tokens) external {
        require(hasRole(ADMIN_ROLE, msg.sender), "Denied");

        uint256 _blockTimestamp = block.timestamp;

        //should be called AFTER x days (30 days ) from last withdrawals
        require(lastRewardTime < (_blockTimestamp - minSnapshotInterval), 'wait'); //@done        
        //should have snapshotred before x mins (4 hours?)
        require(lastSnapshotTime > (_blockTimestamp - maxSnapshotLifetime), 'SnapShot'); //@done 
        //make sure there is enough staking from last snapshot
        require(totalEligibleFontsForRewards > 0, '0 stake'); //@done
        
        //uint256 _rewardAmount = 0;
        uint256 _token_balance = 0;
        address __address;
        uint256 _totalEligibleFontsForRewards = totalEligibleFontsForRewards;
        uint256 _min_token_balance = 0;
        address[] memory _SnapShotUsers = SnapShotUsers[lastSnapshotTime];

        mapping (address => uint256) storage _SnapShot = SnapShot[lastSnapshotTime];

        for(uint256 i = 0; i < _tokens.length; i++ ) {
            _min_token_balance = rewardTokens[_tokens[i]];
            if(_min_token_balance > 0) {
                _token_balance = IERC20(_tokens[i]).balanceOf(address(this));
                if(_token_balance >= _min_token_balance) { 
                    for(uint256 _user = 0; _user < _SnapShotUsers.length; _user++) { 
                        __address = _SnapShotUsers[_user];
                        UserRewardBalance[__address][_tokens[i]] += (_SnapShot[__address].mul(_token_balance).div(_totalEligibleFontsForRewards));
                    } //take all the users in current snapshop
                }
            } //check if reward token is enabled and its not font token 

        } // Main for loop

        //update the needed metadata 
        lastRewardTime = _blockTimestamp;

        //emit 
        emit RewardsDistributed(_tokens.length, SnapShotUsers[lastSnapshotTime].length);

    }

    //Users can cliam the reward. Can claim the multiple number of tokens in single shot
    //@todo, only allowed tokens
    event RewardClaimed(address, uint256);
    function claimRewards(address[] memory _tokens) public {
        //loop all tokens 
        uint256 _amount = 0;
        for(uint256 i = 0; i < _tokens.length; i++ ) {
            _amount = UserRewardBalance[msg.sender][_tokens[i]];
            if(_amount > 0) {
                UserRewardBalance[msg.sender][_tokens[i]] = 0;
                IERC20(_tokens[i]).safeTransfer(msg.sender, _amount);
            }
        }
        emit RewardClaimed(msg.sender, block.timestamp);
    }

    /****************************************************************/
    /************** Testing functions here ********************/
    /****************************************************************/

    //function debugger() external view returns (uint256, uint256, uint256, uint256, uint256, uint256, uint256) {
             
      //  return (ddtotalTokens,ddtotalTokensenabled ,ddtotalTokensBalance, ddtotalusers, ddtotalusersWithMoney, ddtotalreward, totalEligibleFontsForRewards);
    //}
    
}


