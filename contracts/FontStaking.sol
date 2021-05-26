pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";


contract Staking is Ownable {

    using SafeMath for uint;
    
    uint BIGNUMBER = 10**18;
    uint DECIMAL = 10**3;

    IERC20 public FONT_ERC20; //Font token address

    uint public stakeCounter;

    bool public stakingPaused;

    struct stakingInfo {
        uint amount;
        bool claimed;
        uint lockedTime;
        uint unlockTime;
    }
    
    //Address to Staking 
    mapping (address => mapping(uint => stakingInfo)) public StakeMap; //tokenAddr to user to stake amount

    //Total token staked
    mapping (address => uint) public totalStaked; 
    
    constructor(FontTokenAddress) public{
        stakeCounter = 0;
        FONT_ERC20 = IERC20(FontTokenAddress);
        paused = false;
    }
    

    event LogStake(address _address, uint _stake_id, uint amount, uint _unlockTime);

    /**
    * @dev stake a specific amount to a token
    * @param _amount the amount to be staked
    * @param _tokenAddr the token the user wish to stake on
    * for demo purposes, not requiring user to actually send in tokens right now
    */
    
    function stake(uint _amount, uint _unlockTime) external public returns (uint256 _stake_id){
        require(!stakingPaused);
        require(_amount > 0);

        uint _stake_id = stakeCounter.add(1);
        uint _stakedDate = block.timestamp;

        //Add total token staked per address
        if(totalStaked[msg.sender] == 0){
            totalStaked[msg.sender] = _amount;
        } else {
            totalStaked[msg.sender] = totalStaked[msg.sender].add(_amount);
        }

        //Add item to StakeMap
        StakeMap[msg.sender][_stake_id].amount = _amount;
        StakeMap[msg.sender][_stake_id].claimed = false;
        StakeMap[msg.sender][_stake_id].lockedTime = _stakedDate;
        StakeMap[msg.sender][_stake_id].unlockTime = _unlockTime;

        stakeCounter = _stake_id;

        uint256 allowance = FONT_ERC20.allowance(msg.sender, address(this));
        require(allowance >= _amount, "Check the token allowance");

        require(FONT_ERC20.transferFrom(msg.sender, address(this), _amount));
        event LogStake(msg.sender, _stake_id,  _amount, _unlockTime);
    }
    
       
    event LogUnStake(address _address, uint _stake_id, uint amount);
    

    //Unstake the font Token by stake id
    function unStake(uint _stake_id)  constant external returns (bool) {
        require(totalStaked[msg.sender] > 0);
        require(!StakeMap[msg.sender][_stake_id].claimed);
        require(StakeMap[msg.sender][_stake_id].amount > 0);
        require(StakeMap[msg.sender][_stake_id].unlockTime < block.timestamp);
        

        uint _amount = StakeMap[msg.sender][_stake_id].amount;
        
        //Reduce the balance per address
        totalStaked[msg.sender] = totalStaked[msg.sender].min(_amount);

        StakeMap[msg.sender][_stake_id].claimed = true;
        
        //Transfer token to wallet address.
        require(FONT_ERC20.transfer(msg.sender, _amount));
        
        LogUnStake(msg.sender, _stake_id, _amount);
    }


    //Get total FONTs staked per address. 
    function getStakedPerAddress(address _address) external view returns (uint256) {
        return totalStaked[_address];
    }

    //Get detail about single stake info by address and id
    function getStakeByID(address _address, uint _stake_id) external view returns (uint, bool, uint, uint) {
        return (
          StakeMap[_address][_stake_id].amount,
          StakeMap[_address][_stake_id].claimed,
          StakeMap[_address][_stake_id].lockedTime,
          StakeMap[_address][_stake_id].unlockTime,

        );
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


}
